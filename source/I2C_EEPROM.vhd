--------------------------------------------------------------------------------------------------------------
---------------------- Поведенческая модель I2C EEPROM M24C32 фирмы STMicroelectronics -----------------------
--------------------------------------------------------------------------------------------------------------
-- Реализованы все режимы записи и чтения, кроме:
-- При PAGE WRITE количество записываемых данных в модели произвольно, в datasheet - максимум 32 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity I2C_EEPROM is
    Port ( SCL  : inout STD_LOGIC;
           SDA  : inout STD_LOGIC;
           WC_n : in    STD_LOGIC;
           E    : in    STD_LOGIC_VECTOR(2 downto 0)
    );
end I2C_EEPROM;

architecture Behavioral of I2C_EEPROM is

-- идентификационный код микросхемы
constant ID_CODE : std_logic_vector(3 downto 0) := "1010";
-- внутренняя задержка после записи (память не реагирует на бит идентификации) 
constant Write_Delay_Time : time := 10 ms;

-- состояние внетреннего автомата управления
type EEPROM_FSM_Type is (IDLE, IDENTIFY, IDENTIFY_ACK, GET_ADDR_1, GET_ADDR_1_ACK,
                         GET_ADDR_2, GET_ADDR_2_ACK,  WRITE, SET_WR_ACK, READ, GET_RD_ACK);

signal EEPROM_State : EEPROM_FSM_Type := IDLE;

signal ID_Bits_Counter : integer := 0;
signal ID_Data_Bits    : std_logic_vector(6 downto 0);
signal RW_Bit          : std_logic;

signal ADD_Bits_Counter : integer := 0;
signal ADD_Data_Bits_1 : std_logic_vector(7 downto 0);
signal ADD_Data_Bits_2 : std_logic_vector(7 downto 0);

signal RW_Bits_Counter : integer := 0;
signal RW_Data_Bits    : std_logic_vector(7 downto 0);

-- адрес чтения и записи
signal RW_Address : integer := 0;
signal Write_Delay_ON : std_logic := '0';

-- массив данных памяти
type Mem_Data_Type is array (0 to 65535) of std_logic_vector(7 downto 0);
signal Mem_Data : Mem_Data_Type := (others => x"FF"); 

begin

process(SCL, SDA)

    variable ID_ACK_Flag    : std_logic := '0';
    variable ADD_ACK_1_Flag : std_logic := '0';
    variable ADD_ACK_2_Flag : std_logic := '0';
    variable WR_ACK_Flag    : std_logic := '0';
    
    variable RW_Address_Var : std_logic_vector(15 downto 0);

begin
    -- состояние ожидания начала транзакции
    if EEPROM_State = IDLE then
        SCL <= 'Z';
        SDA <= 'Z';
        if (SCL = 'H' or SCL = '1') and (SDA'event and SDA = '0') then
            EEPROM_State <= IDENTIFY; 
        end if;    
    end if;

    -- состояние идентификации устройства
    if EEPROM_State = IDENTIFY then
        SCL <= 'Z';
        SDA <= 'Z';
        if rising_edge(SCL) then
            if ID_Bits_Counter /= 7 then   -- получаем данные
                ID_Data_Bits(6 - ID_Bits_Counter) <= SDA;
                ID_Bits_Counter <= ID_Bits_Counter + 1;
            else                           -- получаем бит, определяющий чтение или запись
                 RW_Bit <= SDA;
                 EEPROM_State <= IDENTIFY_ACK;
                 ID_Bits_Counter <= 0;            
            end if;
        end if;
    end if;

    -- состояние подтверждения идентификации
    if EEPROM_State = IDENTIFY_ACK then
        SCL <= 'Z';
        if falling_edge(SCL) then
            -- высталяем бит подтверждения
            if ID_ACK_Flag = '0' then
                if ((ID_CODE & E) = ID_Data_Bits) and Write_Delay_ON = '0' then
                    SDA <= '0';
                else
                    SDA <= '1';        
                end if;
            else
                -- снимаем бит подтверждения и переходим в следующее состояние
                SDA <= 'Z';
                if SDA = '0' then
                    if RW_Bit = '1' then
                        EEPROM_State <= READ;
                    else
                        EEPROM_State <= GET_ADDR_1;
                    end if;
                else
                    EEPROM_State <= IDLE;
                end if;              
            end if;
            -- меняем значение флага
            ID_ACK_Flag := not ID_ACK_Flag;
        end if;
    end if;

    -- состояние получения адреса (первый байт)
    if EEPROM_State = GET_ADDR_1 then
        SCL <= 'Z';
        SDA <= 'Z';
        if rising_edge(SCL) then
            if ADD_Bits_Counter /= 7 then  
                ADD_Data_Bits_1(7 - ADD_Bits_Counter) <= SDA;
                ADD_Bits_Counter <= ADD_Bits_Counter + 1;
            else
                ADD_Data_Bits_1(7 - ADD_Bits_Counter) <= SDA;
                EEPROM_State <= GET_ADDR_1_ACK;
                ADD_Bits_Counter <= 0;            
            end if;
        end if;        
    end if;    
    
    -- состояние подтверждения первого байта адреса
    if EEPROM_State = GET_ADDR_1_ACK then
        SCL <= 'Z';
        if falling_edge(SCL) then  
            if ADD_ACK_1_Flag = '0' then -- высталяем бит подтверждения
                SDA <= '0';
            else -- снимаем бит подтверждения и переходим в следующее состояние
                SDA <= 'Z';
                EEPROM_State <= GET_ADDR_2;
            end if;    
            -- меняем значение флага
            ADD_ACK_1_Flag := not ADD_ACK_1_Flag;  
        end if;
    end if;
    
    -- состояние получения адреса (второй байт)
    if EEPROM_State = GET_ADDR_2 then
        SCL <= 'Z';
        SDA <= 'Z';
        if rising_edge(SCL) then
            if ADD_Bits_Counter /= 7 then  
                ADD_Data_Bits_2(7 - ADD_Bits_Counter) <= SDA;
                ADD_Bits_Counter <= ADD_Bits_Counter + 1;
            else
                ADD_Data_Bits_2(7 - ADD_Bits_Counter) <= SDA;
                EEPROM_State <= GET_ADDR_2_ACK;
                ADD_Bits_Counter <= 0;            
            end if;
        end if;
    end if;
    
    -- состояние подтверждения второго байта адреса
    if EEPROM_State = GET_ADDR_2_ACK then
        -- обновляем значение адреса
        RW_Address_Var(15 downto 8) := ADD_Data_Bits_2;
        RW_Address_Var(7 downto 0)  := ADD_Data_Bits_1;
        RW_Address <= TO_INTEGER(UNSIGNED(RW_Address_Var)); 
        
        SCL <= 'Z';
        if falling_edge(SCL) then  
            if ADD_ACK_2_Flag = '0' then -- высталяем бит подтверждения
                SDA <= '0';
            else -- снимаем бит подтверждения и переходим в следующее состояние
                SDA <= 'Z';
                EEPROM_State <= WRITE;
            end if;    
            -- меняем значение флага
            ADD_ACK_2_Flag := not ADD_ACK_2_Flag;  
        end if;    
    end if;
    
    -- состояние записи данных
    if EEPROM_State = WRITE then
        SCL <= 'Z';
        SDA <= 'Z';
        -- принимаем данные для записи
        if rising_edge(SCL) then
            if RW_Bits_Counter /= 7 then  
                RW_Data_Bits(7 - RW_Bits_Counter) <= SDA;
                RW_Bits_Counter <= RW_Bits_Counter + 1;
            else
                RW_Data_Bits(7 - RW_Bits_Counter) <= SDA;
                EEPROM_State <= SET_WR_ACK;
                RW_Bits_Counter <= 0;            
            end if;
        end if;
        -- если пришел стоп-бит
        if (SCL = 'H' or SCL = '1') and (SDA'event and SDA = 'H') then
            if Write_Delay_ON = '0' then -- переходим в состояния задержки на запись
                Write_Delay_ON <= '1', '0' after Write_Delay_Time;
            end if;
            EEPROM_State <= IDLE;
            RW_Bits_Counter <= 0; 
        end if;
        -- если пришел старт-бит 
        if (SCL = 'H' or SCL = '1') and (SDA'event and SDA = '0') then
            RW_Bits_Counter <= 0;
            EEPROM_State <= IDENTIFY; 
        end if; 
    end if;
        
    -- состояние подтверждения записи
    if EEPROM_State = SET_WR_ACK then
        SCL <= 'Z';
        if falling_edge(SCL) then  
            if WR_ACK_Flag = '0' then -- высталяем бит подтверждения
                if WC_n = '1' then           
                    SDA <= '1';
                else
                    SDA <= '0';
                end if;        
            else -- снимаем бит подтверждения и переходим в следующее состояние
                SDA <= 'Z';
                EEPROM_State <= WRITE;
                if SDA <= '0' then
                    -- записываем данные и увеличиваем адрес
                    Mem_Data(RW_Address) <= RW_Data_Bits;
                    RW_Address <= RW_Address + 1;
                end if;
            end if;    
            -- меняем значение флага
            WR_ACK_Flag := not WR_ACK_Flag;  
        end if;    
    end if;    
    
    -- состояние чтения данных
    if EEPROM_State = READ then
        SCL <= 'Z';
        SDA <= Mem_Data(RW_Address)(7-RW_Bits_Counter);
        -- принимаем данные для записи
        if falling_edge(SCL) then
            if RW_Bits_Counter /= 7 then  
                RW_Bits_Counter <= RW_Bits_Counter + 1;
            else
                EEPROM_State <= GET_RD_ACK;
                RW_Bits_Counter <= 0;            
            end if;
        end if;
    end if;
    
     -- состояние подтверждения чтения
    if EEPROM_State = GET_RD_ACK then
        SCL <= 'Z';
        SDA <= 'Z';
        if falling_edge(SCL) then  
            if SDA <= '0' then
                EEPROM_State <= READ;
            else
                EEPROM_State <= IDLE;
            end if;        
        RW_Address <= RW_Address + 1;
        end if;    
    end if;    
   
end process;

end Behavioral;

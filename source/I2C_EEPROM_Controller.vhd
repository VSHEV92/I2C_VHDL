--------------------------------------------------------------------------------------------------------------
-------------------------------- Синтезируемый блок контроллера I2C EEPROM -----------------------------------
-- Входные данные поступают из входного FIFO. На вход ctrl_byte поступают байты управления, которые определяют
-- дальнейшее поведение контроллера (идентификация устройства, запись, чтение). На вход data_to_eeprom 
-- поступают байты данных, значения которых будут выставлены на шину SDA при записи данных или адреса и 
-- при идентификации. При чтении этот байт не имеет значения.
-- Начало транзакции начаниется по сигналу transaction_start (активный уровень '1'). Транзакция заканчивается 
-- при записи последнего байта или считывании последнего байта (байты управлния x"05" и x"04") соответственно.
-- Если при идентификации получен NACK, то мастер считает, что EEPROM находится в режиме внутренней записи и
-- продолжает слать байт идентификации пока EEPROM не ответит (polling). 
-- Прочитанные данные из EEPROM записываются в выходное FIFO через выходы data_from_eeprom и fifo_we.
-- Выход error указывает на NACK от EEPROM, когда это не ожидается. 
-- Выход done сообщает, что блок готов к  налу новой транзакции.
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity I2C_EEPROM_Controller is
    Generic( Clk_Freq     : integer := 200000000;  -- частота тактового сигнала в Гц
             SCL_Freq     : integer := 100000;     -- частота сигнала SCL в Гц
             Fifo_Latency : integer := 1           -- задержка выдачи данных из fifo после fifi_re (1 или 2 такта)
    );
    Port ( clk               : in    STD_LOGIC;
           reset             : in    STD_LOGIC;                        -- сброс (активнй уровень '1')
           transaction_start : in    STD_LOGIC;                        -- сигнал сиарта транзакции
           ctrl_byte         : in    STD_LOGIC_VECTOR (7 downto 0);    -- байт управления автоматом состояний
           data_to_eeprom    : in    STD_LOGIC_VECTOR (7 downto 0);    -- данные для записи в EEPROM
           fifo_re           : out   STD_LOGIC;                        -- сигнал чтения из входного FIFO
           data_from_eeprom  : out   STD_LOGIC_VECTOR (7 downto 0);    -- данные считанные с EEPROM
           fifo_we           : out   STD_LOGIC;                        -- сигнал записи в выходное FIFO
           error             : out   STD_LOGIC;                        -- флаг, ошибки при работе с памятью
           done              : out   STD_LOGIC;                        -- флаг, готовности к транзакции
           SCL               : inout STD_LOGIC;                        -- I2C SCL
           SDA               : inout STD_LOGIC                         -- I2C SDA          
    );
end I2C_EEPROM_Controller;

architecture Behavioral of I2C_EEPROM_Controller is

-- количество тактов на бит четверть. Четверть бита используется, чтобы была
-- возможность изменять SDA на середине нулевого интервала SCL
constant Qauter_Bit_Period : integer := Clk_Freq/SCL_Freq/4;  

-- сигналы для конечного автомата управления
type Controller_FSM_Type is (IDLE, FIFO_RE_STATE, FIFO_DELAY_STATE, WAIT_FIFO_DATA, GET_FIFO_DATA,
                             START_TRANSACTION, WRITE_DATA_BYTE, READ_DATA_BYTE, ANTI_SPUR_DELAY);
signal FSM_State : Controller_FSM_Type;

--  счетчик, для создания тактового сигнал с частотой SCL_Freq
signal Tick_Gen_Reset         : std_logic;
signal Tick_Generator_Counter : integer;
signal Tick_Generator_Done    : std_logic; 

-- сигналы управления буферами с третьим состоянием
signal SCL_Value     : std_logic;
signal SCL_Tristate  : std_logic;
signal SDA_Value     : std_logic;
signal SDA_Tristate  : std_logic;

signal rx_data         : std_logic_vector (7 downto 0);
signal rx_valid        : std_logic;
signal rx_valid_delayd : std_logic;

begin

-- счетчик, отсчитывающий интервал времени, равный длительности четверти периода SCL 
Tick_Generator: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' or Tick_Gen_Reset = '1' then
            Tick_Generator_Counter <= 0;
            Tick_Generator_Done <= '0';  
        else
            Tick_Generator_Counter <= Tick_Generator_Counter + 1;
            Tick_Generator_Done <= '0'; 
            if Tick_Generator_Counter = Qauter_Bit_Period then
                Tick_Generator_Counter <= 0;
                Tick_Generator_Done <= '1';     
            end if;
        end if;
    end if;
end process; 

-- процесс управления состояниями конечного автомата
FSM_States_Controller: process(clk)

-- внутренние регистры, для байтов чтения, записи и управления
variable tx_byte       : std_logic_vector (7 downto 0);
variable rx_byte       : std_logic_vector (7 downto 0);
variable FSM_ctrl_byte : std_logic_vector (7 downto 0);

-- счетчики времени находжения в заданном состоянии
variable FSM_Counter : integer range 0 to 50 := 0;
variable RX_Counter  : integer range 0 to 8 := 8;
variable TX_Counter  : integer range 0 to 8:= 8;

variable device_ID_ACK : std_logic := '1';

begin
    if rising_edge(clk) then
        if reset = '1' then
            FSM_Counter := 0;
            RX_Counter := 8;
            TX_Counter := 8;
            FSM_State <= IDLE;
            SCL_Tristate <= '0';
            SDA_Tristate <= '0';
            Tick_Gen_Reset <= '1';
            error <= '0';
            done <= '1';
            fifo_re <= '0';
            rx_valid <= '0';      
        else
            case FSM_State is
            
                -- по сигналу старта начинаем транзакцию
                when IDLE => 
                    SCL_Tristate <= '0';
                    SDA_Tristate <= '0';
                    Tick_Gen_Reset <= '1';
                    error <= '0';
                    done <= '1';
                    fifo_re <= '0';
                    rx_valid <= '0';
                    if transaction_start = '1' then  
                        FSM_State <= FIFO_RE_STATE;
                    end if;
                
                -- посылаем сигнал запроса данных из FIFO;  в зависимости от Fifo_Latency
                -- данные будут получены на следующем такте или через один такт clk
                when FIFO_RE_STATE =>
                    error <= '0';
                    done <= '0';
                    fifo_re <= '1';    
                    FSM_State <= FIFO_DELAY_STATE;
                    
                -- задержка на такт для считывания данных    
                when FIFO_DELAY_STATE =>
                    fifo_re <= '0';
                    if Fifo_Latency = 1 then  
                        FSM_State <= GET_FIFO_DATA;
                    else
                        FSM_State <= WAIT_FIFO_DATA;    
                    end if;
                        
                -- ожидаем данные из FIFO один такт
                when WAIT_FIFO_DATA =>
                    FSM_State <= GET_FIFO_DATA;

                -- записываем данные из FIFO и байт управления во внутренние регистры
                when GET_FIFO_DATA =>
                    tx_byte := data_to_eeprom;
                    FSM_ctrl_byte := ctrl_byte;
                    -- выбор состояния на основании байта управления
                    case FSM_ctrl_byte is
                        when x"00"             =>  FSM_State <= START_TRANSACTION;
                        when x"01"|x"03"|x"05" =>  FSM_State <= WRITE_DATA_BYTE;
                        when x"02"|x"04"       =>  FSM_State <= READ_DATA_BYTE;
                        when others            =>  FSM_State <= IDLE;
                    end case;    
                    
                -- процесс идентификации устройства
                when START_TRANSACTION =>
                    Tick_Gen_Reset <= '0';
                    if Tick_Generator_Done = '1' then
                        FSM_Counter := FSM_Counter + 1;
                        --  ждем полпериода и высталяем 'Z' состояния на выходы
                        -- это нужно для реализации polling при доступе к EEPROM
                        case FSM_Counter is
                            when 2 =>
                                SCL_Tristate <= '0';
                                SDA_Tristate <= '0';
                            -- выставляем старт-бит
                            when 3 =>
                                SDA_Tristate <= '1';
                                SDA_Value <= '0';
                            when 4 =>
                                SCL_Tristate <= '1';
                                SCL_Value <= '0'; 
                            -- высталяем байт идентификации
                            -- ставим данные   
                            when 5|9|13|17|21|25|29|33 =>
                                TX_Counter := TX_Counter - 1;
                                SDA_Value <= tx_byte(TX_Counter);
                            -- поднимаем SCL
                            when 6|10|14|18|22|26|30|34 =>
                                SCL_Value <= '1';
                            -- опускаем SCL и отпускаем SDA
                            when 8|12|16|20|24|28|32 =>
                                SCL_Value <= '0';   
                            when 36 =>
                                SCL_Value <= '0';
                                SDA_Tristate <= '0';
                            -- получаем от памяти ACK и, если устройство не ответило, повторяем процедуру идентификации
                            -- поднимаем SCL
                            when 38 =>
                                SCL_Value <= '1';
                            -- принимаем от устройства ACK   
                            when 39 => 
                                device_ID_ACK := SDA;   
                            -- отпускаем SCL и переходим в новое состояние
                            when 40 =>
                                SCL_Value <= '0'; 
                                FSM_Counter := 0;
                                TX_Counter := 8;
                                if device_ID_ACK = '0' then
                                    FSM_State <= FIFO_RE_STATE;  
                                end if; 
                            when others => NULL;
                        end case;
                    end if;    
                
                -- запись байта данных
                when WRITE_DATA_BYTE =>
                    if Tick_Generator_Done = '1' then
                        FSM_Counter := FSM_Counter + 1;
                        
                        case FSM_Counter is
                            -- высталяем байт данных
                            -- ставим данные
                            when 1|5|9|13|17|21|25|29 =>
                                SDA_Tristate <= '1';
                                TX_Counter := TX_Counter - 1;
                                SDA_Value <= tx_byte(TX_Counter);
                            -- поднимаем SCL
                            when 2|6|10|14|18|22|26|30 =>
                                SCL_Value <= '1';
                            -- опускаем SCL и отпускаем SDA
                            when 4|8|12|16|20|24|28 =>
                                SCL_Value <= '0';   
                            when 32 =>
                                SCL_Value <= '0';
                                SDA_Tristate <= '0';
                            -- получаем от памяти ACK 
                            -- поднимаем SCL
                            when 34 =>
                                SCL_Value <= '1';
                            -- принимаем от устройства ACK   
                            when 35 => 
                                device_ID_ACK := SDA;   
                            -- отпускаем SCL и высталяем флаг ошибки
                            -- если это не последний байт, то сбрасываем счетчик и переходим считыванию следующего байта
                            when 36 =>
                                SCL_Value <= '0'; 
                                error <= device_ID_ACK;   
                                -- если это не последний байт, то сбрасываем счетчик и переходим считыванию следующего байта
                                if FSM_ctrl_byte /= x"05" then
                                    FSM_Counter := 0;
                                    TX_Counter := 8;
                                    FSM_State <= FIFO_RE_STATE;
                                end if;
                            -- если это последний байт, то выставляем стоп-бит
                            -- опускаем SDA
                            when 37 =>
                                error <= '0';    
                                SDA_Tristate <= '1';
                                SDA_Value <= '0';
                            -- отпускаем SCL
                            when 38 =>    
                                SCL_Tristate <= '0'; 
                            -- отпускаем SDA, сбрасываем счетчик и переходим ANTI_SPUR_DELAY
                            when 39 =>    
                                SDA_Tristate <= '0';
                                FSM_Counter := 0;
                                TX_Counter := 8;
                                FSM_State <= ANTI_SPUR_DELAY;                                           
                            when others => NULL;
                        end case;
                    end if;
                
                -- чтение байта данных
                when READ_DATA_BYTE =>
                    if Tick_Generator_Done = '1' then
                        FSM_Counter := FSM_Counter + 1;
                        
                        case FSM_Counter is
                            -- отпускаем SDA
                            when 1 =>
                            SDA_Tristate <= '0';
                            -- читаем байт данных
                            -- поднимаем SCL
                            when 2|6|10|14|18|22|26|30 =>
                                SCL_Value <= '1';                                
                            -- читаем данные    
                            when 3|7|11|15|19|23|27|31 =>
                                RX_Counter := RX_Counter - 1;
                                rx_byte(RX_Counter) := SDA;
                            -- опускаем SCL
                            when 4|8|12|16|20|24|28|32 =>
                                SCL_Value <= '0';   
                            -- выставляем ACK для EEPROM
                            -- если это последний байт ставим '1' 
                            when 33 =>
                                SDA_Tristate <= '1';
                                if FSM_ctrl_byte = x"04" then
                                    SDA_Value <= '1';
                                else    
                                    SDA_Value <= '0';
                                end if; 
                            -- поднимаем SCL и ставим флаг готовности считынных данных
                            when 34 =>
                                SCL_Value <= '1';
                                rx_data <= rx_byte; 
                                rx_valid <= '1';                             
                            -- опускаем SCL и снимаем флаг готовности считынных данных
                            when 36 =>
                                SCL_Value <= '0'; 
                                rx_valid <= '0';
                            -- если это не последний байт, то сбрасываем счетчик и переходим считыванию следующего байта    
                            when 37 =>
                                -- если это не последний байт, то сбрасываем счетчик и переходим считыванию следующего байта
                                if FSM_ctrl_byte /= x"04" then
                                    SDA_Tristate <= '0';
                                    FSM_Counter := 0;
                                    RX_Counter := 8;
                                    FSM_State <= FIFO_RE_STATE;
                                else
                                    SDA_Value <= '0';    
                                end if;
                            -- если это последний байт, то выставляем стоп-бит
                            -- отпускаем SCL
                            when 38 =>    
                                SCL_Tristate <= '0'; 
                            -- отпускаем SDA, сбрасываем счетчик и переходим ANTI_SPUR_DELAY
                            when 39 =>    
                                SDA_Tristate <= '0';
                                FSM_Counter := 0;
                                RX_Counter := 8;
                                FSM_State <= ANTI_SPUR_DELAY;                                           
                            when others => NULL;
                        end case;
                    end if;
                     
                -- состояние задержки после конца транзакии                
                when ANTI_SPUR_DELAY =>
                    if Tick_Generator_Done = '1' then
                        FSM_Counter := FSM_Counter + 1;
                        -- ждем период SCL, сбрасываем счетчик и переходим IDLE
                        if FSM_Counter = 4 then
                            FSM_Counter := 0;
                            FSM_State <= IDLE;
                        end if;
                    end if;
                    
                when others =>
                    FSM_State <= IDLE;
                    
            end case;
        end if;
    end if;
end process;

-- буферы с третьим состоянием
SCL <= SCL_Value when SCL_Tristate ='1' else 'Z';
SDA <= SDA_Value when SDA_Tristate ='1' else 'Z';

-- процесс для записи данных в выходное FIFO
write_to_FIFO: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            fifo_we <= '0';
            rx_valid_delayd <= '0';
        else    
            data_from_eeprom <= rx_data;
            rx_valid_delayd <= rx_valid;
            fifo_we <= not rx_valid_delayd and rx_valid;
        end if;    
    end if;
end process;

end Behavioral;

--------------------------------------------------------------------------------------------------------------
-------------------------------- Поведенческая модель мастера I2C --------------------------------------------
-- Входные данные для передачи считываются из файла, путь к которому указывается в generic Input_Data_File.
-- Содержимое строки файла состоит из двух целых чисел: первое число - байт управления; второе - байт данных.
-- Байт управления определяет дальнейшее поведение блока. Байт данных задает значение, которое будет выставлено
-- на шину SDA при записи данных или адреса и при идентификации. При чтении этот байт не имеет значения.
-- Если при идентификации получен NACK, то мастер считает, что EEPROM находится в режиме внутренней записи и
-- продолжает слать байт идентификации пока EEPROM не ответит (polling). 
-- Generics SCL_Freq задает частоту сигнала SCL в Гц. Выходы tx_data и rx_data выдает информационные данные
-- считанные из файла и полученные от EEPROM соответственно. Выход error указывает на NACK от EEPROM,
-- когда это не ожидается.  Выход done сообщает об окончании работы блока.
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use STD.textio.all;
use ieee.std_logic_textio.all;

use IEEE.NUMERIC_STD.ALL;

entity I2C_Master_Beh is
    Generic( Input_Data_File : string;     -- путь к файлу с передаваемыми данными
             SCL_Freq        : integer     -- частота сигнала SCL в Гц
    );
    Port ( SCL           : inout STD_LOGIC;                      -- I2C SCL
           SDA           : inout STD_LOGIC;                      -- I2C SDA
           tx_data       : out   STD_LOGIC_VECTOR (7 downto 0);  -- передаваемый вектор (для проверки)
           tx_data_valid : out   STD_LOGIC;                      -- строб для передаваемого вектор
           rx_data       : out   STD_LOGIC_VECTOR (7 downto 0);  -- вектор от Slave (для проверки)
           rx_data_valid : out   STD_LOGIC;                      -- строб для вектор от Slave
           error         : out   STD_LOGIC;                      -- флаг, ошибки при работе с памятью
           done          : out   STD_LOGIC                       -- флаг, указывающий, что переданы все данные из файла
    );
end I2C_Master_Beh;

architecture Behavioral of I2C_Master_Beh is

-- длительность одного бита
constant Bit_Period : time := 1000000000/SCL_Freq * 1 ns; 
file file_HANDLER : text;

-- значение байтов управления
constant START_TRANSACTION    : std_logic_vector(7 downto 0) := x"00"; -- начало транзакции и выдача идентификационного байта
constant WRITE_ADDR_BYTE      : std_logic_vector(7 downto 0) := x"01"; -- запись адреса
constant WRITE_DATA_BYTE      : std_logic_vector(7 downto 0) := x"03"; -- запись данных
constant WRITE_LAST_DATA_BYTE : std_logic_vector(7 downto 0) := x"05"; -- запись последнего байта данных
constant READ_DATA_BYTE       : std_logic_vector(7 downto 0) := x"02"; -- запись последнего байта данных
constant READ_LAST_DATA_BYTE  : std_logic_vector(7 downto 0) := x"04"; -- запись последнего байта данных

begin

process
    -- переменные для считывания из файла
    variable file_LINE : line;
    variable file_DATA : integer;
    variable SPACE     : character;
    
    variable data_bits : std_logic_vector(7 downto 0); -- байт данных
    variable ctrl_bits : std_logic_vector(7 downto 0); -- байт, управления
    
    variable device_ID_ACK : std_logic;
    
    variable read_byte : std_logic_vector(7 downto 0);
         
begin 
    SCL <= 'Z';
    SDA <= 'Z';
    done <= '0';
    tx_data <= (others => '0');
    tx_data_valid <= '0';
    rx_data <= (others => '0');
    rx_data_valid <= '0';
    error <= '0';
    
    wait for 100 ns;
    
    file_open(file_HANDLER, Input_Data_File,  read_mode);
    while not endfile(file_HANDLER) loop
        error <= '0';
        
        -- считываем входные данные
        readline(file_HANDLER, file_LINE);
        read(file_LINE, file_DATA);
        ctrl_bits := std_logic_vector(to_unsigned(file_DATA, 8));
        read(file_LINE, SPACE);
        read(file_LINE, file_DATA);
        data_bits := std_logic_vector(to_unsigned(file_DATA, 8));
        -----------------------------------------------------------------------------------------------------------
        -- если это начало транзакции
        if ctrl_bits = START_TRANSACTION then
     
            device_ID_ACK := '1';       
            while not (device_ID_ACK = '0') loop
                wait for Bit_Period/2;
                SCL <= 'Z';
                SDA <= 'Z';
                wait for Bit_Period/4;
            
                -- ставим старт-бит
                SCL <= 'Z';
                SDA <= '0';
                wait for Bit_Period/4;
                SCL <= '0';
                SDA <= '0';
                     
                -- выставляем идентификационный байт
                for idx in 7 downto 0 loop 
                    wait for Bit_Period/4;
                    SDA <= data_bits(idx);
                    wait for Bit_Period/4;
                    SCL <= '1';
                    wait for Bit_Period/2;
                    SCL <= '0';
                end loop;
            
                -- получаем от памяти ACK и, если устройство не ответило, повторяем процедуру идентификации 
                SDA <= 'Z';
                wait for Bit_Period/2;
                SCL <= '1';
                wait for Bit_Period/4;
                device_ID_ACK := SDA;
                wait for Bit_Period/4;
                SCL <= '0';
            end loop;   
        end if;
        -----------------------------------------------------------------------------------------------------------
        -- если это запись адреса
        if ctrl_bits = WRITE_ADDR_BYTE then
            -- выставляем адресный байт
            for idx in 7 downto 0 loop
                wait for Bit_Period/4; 
                SDA <= data_bits(idx);
                wait for Bit_Period/4;
                SCL <= '1';
                wait for Bit_Period/2;
                SCL <= '0';
            end loop;
            
            -- получаем от памяти ACK 
            SDA <= 'Z';
            wait for Bit_Period/2;
            SCL <= '1';
            wait for Bit_Period/4;
            error <= SDA;
            wait for Bit_Period/4;
            SCL <= '0';
        end if;
        -----------------------------------------------------------------------------------------------------------
        -- если это запись данных
        if ctrl_bits = WRITE_DATA_BYTE then
            -- выставляем байт данных
            for idx in 7 downto 0 loop
                wait for Bit_Period/4; 
                SDA <= data_bits(idx);
                wait for Bit_Period/4;
                SCL <= '1';
                wait for Bit_Period/2;
                SCL <= '0';
            end loop;
            
            -- получаем от памяти ACK
            SDA <= 'Z';
            tx_data <= data_bits;
            wait for Bit_Period/2;
            SCL <= '1';
            tx_data_valid <= '1';
            wait for Bit_Period/4;
            error <= SDA;
            wait for Bit_Period/4;
            SCL <= '0';
            tx_data_valid <= '0';
        end if;
        -----------------------------------------------------------------------------------------------------------
        -- если это запись последнего байта данных
        if ctrl_bits = WRITE_LAST_DATA_BYTE then
            -- выставляем байт данных
            for idx in 7 downto 0 loop
                wait for Bit_Period/4; 
                SDA <= data_bits(idx);
                wait for Bit_Period/4;
                SCL <= '1';
                wait for Bit_Period/2;
                SCL <= '0';
            end loop;
            
            -- получаем от памяти ACK
            SDA <= 'Z';
            tx_data <= data_bits;
            wait for Bit_Period/2;
            SCL <= '1';
            tx_data_valid <= '1';
            wait for Bit_Period/4;
            error <= SDA;
            wait for Bit_Period/4;
            SCL <= '0';
            tx_data_valid <= '0';
            wait for Bit_Period/4;
            SDA <= '0';
            -- высталяем стоп-бит
            wait for Bit_Period/4;
            SCL <= 'Z';
            wait for Bit_Period/4;
            SDA <= 'Z';
        end if;
        -----------------------------------------------------------------------------------------------------------
        -- если это чтение данных
        if ctrl_bits = READ_DATA_BYTE then
            -- выставляем на шину Z состояние
            wait for Bit_Period/4; 
            SDA <= 'Z';
            for idx in 7 downto 0 loop
                wait for Bit_Period/4; 
                SCL <= '1';
                wait for Bit_Period/4;
                read_byte(idx) := SDA;
                wait for Bit_Period/4;
                SCL <= '0';
            end loop;
            
            wait for Bit_Period/4;
            -- выставляем ACK в '0' для продолжения чтения 
            SDA <= '0';
            rx_data <= read_byte;
            wait for Bit_Period/4;
            SCL <= '1';
            rx_data_valid <= '1';
            wait for Bit_Period/2;
            SCL <= '0';
            rx_data_valid <= '0';
            wait for Bit_Period/4;
            SDA <= 'Z';
        end if;
        -----------------------------------------------------------------------------------------------------------
        -- если это последнее чтение данных
        if ctrl_bits = READ_LAST_DATA_BYTE then
            -- выставляем на шину Z состояние
            wait for Bit_Period/4; 
            SDA <= 'Z';
            for idx in 7 downto 0 loop
                wait for Bit_Period/4; 
                SCL <= '1';
                wait for Bit_Period/4;
                read_byte(idx) := SDA;
                wait for Bit_Period/4;
                SCL <= '0';
            end loop;
            
            wait for Bit_Period/4;
            -- выставляем ACK в '1' для окончания чтения 
            SDA <= '1';
            rx_data <= read_byte;
            wait for Bit_Period/4;
            SCL <= '1';
            rx_data_valid <= '1';
            wait for Bit_Period/2;
            SCL <= '0';
            rx_data_valid <= '0';
            wait for Bit_Period/4;
            -- высталяем стоп-бит
            SDA <= '0';
            wait for Bit_Period/4;
            SCL <= 'Z';
            wait for Bit_Period/4;
            SDA <= 'Z';
            
        end if;
        
    end loop; 
    
    -- завершение работы блока
    file_close(file_HANDLER);
    SCL <= 'Z';
    SDA <= 'Z';
    done <= '1';
    wait;
end process;


end Behavioral;

--------------------------------------------------------------------------------------------------------------
------------------------------- Тест поведенческих моделей I2C мастера и I2C EEPROM --------------------------
--------------------------------------------------------------------------------------------------------------
------------------------------------ Режим записи: BYTE WRITE ------------------------------------------------
------------------------------------ Режим чтения: первый байт RANDOM READ, остальные SEQUANTIALREAD ---------
------------------------------------ Время моделирования: 43 ms ----------------------------------------------
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BYTE_WR_RAND_RD_and_SEQ_RD_Beh is
end BYTE_WR_RAND_RD_and_SEQ_RD_Beh;

architecture Behavioral of BYTE_WR_RAND_RD_and_SEQ_RD_Beh is

-- процедура для вывода данных без сообщений от Vivado
procedure echo (arg : in string := "") is
begin
  std.textio.write(std.textio.output, arg);
end procedure echo;

------------------------------------ Параметры теста ------------------------------------
constant Input_Data_File : string  := "/home/vovan/VivadoProjects/I2C_EEPROM/tests/BYTE_WR_RAND_RD_and_SEQ_RD.txt";
constant SCL_Freq        : integer := 100000; -- частота сигнала SCL в Гц
-----------------------------------------------------------------------------------------

-- Поведенческая модель мастера I2C
component I2C_Master_Beh is
    Generic( Input_Data_File : string;   
             SCL_Freq        : integer 
    );
    Port ( SCL           : inout STD_LOGIC;                      
           SDA           : inout STD_LOGIC;                      
           tx_data       : out   STD_LOGIC_VECTOR (7 downto 0);  
           tx_data_valid : out   STD_LOGIC;                      
           rx_data       : out   STD_LOGIC_VECTOR (7 downto 0);  
           rx_data_valid : out   STD_LOGIC;
           error         : out   STD_LOGIC;                      
           done          : out   STD_LOGIC                       
    );
end component;

-- Поведенческая модель I2C EEPROM
component I2C_EEPROM is
    Port ( SCL  : inout STD_LOGIC;
           SDA  : inout STD_LOGIC;
           WC_n : in    STD_LOGIC;
           E    : in    STD_LOGIC_VECTOR(2 downto 0)
    );
end component;

signal SCL : STD_LOGIC;                      
signal SDA : STD_LOGIC;                      
signal tx_data : STD_LOGIC_VECTOR (7 downto 0);  
signal tx_data_valid : STD_LOGIC;                      
signal rx_data : STD_LOGIC_VECTOR (7 downto 0);  
signal rx_data_valid : STD_LOGIC;                      
signal error : STD_LOGIC; 
signal done : STD_LOGIC; 

type Results_Array_Type is array (0 to 100) of std_logic_vector(7 downto 0);

begin

SCL <= 'H';
SDA <= 'H';

-- Поведенческая модель мастера I2C
I2C_Master_Beh_1: I2C_Master_Beh 
    Generic Map (
        Input_Data_File => Input_Data_File,  
        SCL_Freq        => SCL_Freq
    )
    Port Map (
        SCL           => SCL,                    
        SDA           => SDA,                      
        tx_data       => tx_data, 
        tx_data_valid => tx_data_valid,                   
        rx_data       => rx_data,
        rx_data_valid => rx_data_valid,
        error         => error,                    
        done          => done                     
    );

-- Поведенческая модель I2C EEPROM
I2C_EEPROM_1: I2C_EEPROM
    Port Map (
        SCL  => SCL,
        SDA  => SDA,
        WC_n => '0',
        E    => "000"
    );

-----------------------------------------------------------------------------------------
--------------------------- проверка результатов ----------------------------------------
process (tx_data_valid, rx_data_valid, error, done)
    variable Time_Var : time := 0 ns;
    variable counter_tx : integer := 0;
    variable counter_rx : integer := 0;
    variable data_tx_var : Results_Array_Type;
    variable data_rx_var : Results_Array_Type;
    variable test_result : string(1 to 4) := "PASS";
begin
    -- записываем передаваемое слово
    if rising_edge(tx_data_valid) then
        data_tx_var(counter_tx) := tx_data;
        counter_tx := counter_tx + 1;
    end if;
    
    -- записываем полученное слово
    if rising_edge(rx_data_valid) then
        data_rx_var(counter_rx) := rx_data;
        -- сравниваем значение слов
        if data_rx_var(counter_rx) /= data_tx_var(counter_rx) then
            echo("TX and RX data doesn't match!" & LF);
            echo("TX word number " & integer'image(counter_rx) & " has value = " & integer'image(TO_INTEGER(UNSIGNED(data_tx_var(counter_rx)))) & LF);
            echo("RX word number " & integer'image(counter_rx) & " has value = " & integer'image(TO_INTEGER(UNSIGNED(data_rx_var(counter_rx)))) & LF);
            echo("" & LF);
            test_result := "FAIL";
        end if;
        counter_rx := counter_rx + 1; 
    end if;
    
     -- проверяем наличие ошибок при записи
    if rising_edge(error) then
        Time_Var := now;
        echo("Wrong ACK at time " & time'image(Time_Var) & LF);
        echo("" & LF);
        test_result := "FAIL";
    end if;
    
    -- вывод результатов теста
    if rising_edge(done) then
        echo("----------------------------------------------------------------------------------------" & LF);
        echo("Number of transmitted words: " & integer'image(counter_tx) & LF);
        echo("Number of received words: " & integer'image(counter_rx) & LF);
        echo("Test result: " & test_result & LF);
        echo("----------------------------------------------------------------------------------------" & LF);
    end if;
    
end process;


end Behavioral;

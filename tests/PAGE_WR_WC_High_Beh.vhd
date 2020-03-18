--------------------------------------------------------------------------------------------------------------
------------------------------- Тест поведенческих моделей I2C мастера и I2C EEPROM --------------------------
--------------------------------------------------------------------------------------------------------------
------------------------------------------- Режим записи: PAGE WRITE при высоком сигнале WC_n ----------------
------------------------------------------- Режим чтения: не важен -------------------------------------------
------------------------------------------- Время моделирования: 3 ms ----------------------------------------
--------------------------------------------------------------------------------------------------------------
-- I2C EEPROM должен посылать NACK при попытке записи байта, I2C мастера должен высталять '1' на выход 
-- error при получении NACK. Тест подсчитывает число импульсов error, при попытке записать 16 байт 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PAGE_WR_WC_High_Beh is
end PAGE_WR_WC_High_Beh;

architecture Behavioral of PAGE_WR_WC_High_Beh is

-- процедура для вывода данных без сообщений от Vivado
procedure echo (arg : in string := "") is
begin
  std.textio.write(std.textio.output, arg);
end procedure echo;

------------------------------------ Параметры теста ------------------------------------
constant Input_Data_File : string  := "/home/vovan/VivadoProjects/I2C_EEPROM/tests/PAGE_WR_WC_High.txt";
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
        WC_n => '1',  -- !!! высокий уровень препятствует записи
        E    => "000"
    );

-----------------------------------------------------------------------------------------
--------------------------- проверка результатов ----------------------------------------
process (error, done)
    variable Time_Var : time := 0 ns;
    variable counter_error : integer := 0;
    variable test_result : string(1 to 4) := "PASS";
begin
    
     -- подсчитываем число ошибок при записи
    if rising_edge(error) then
        Time_Var := now;
        echo("Error detected at time " & time'image(Time_Var) & LF);
        echo("" & LF);
        counter_error := counter_error + 1;
    end if;
    
    -- вывод результатов теста
    if rising_edge(done) then
        if counter_error /= 16 then
            test_result := "FAIL";
        end if;
        
        echo("----------------------------------------------------------------------------------------" & LF);
        echo("Number of errors: " & integer'image(counter_error) & LF);
        echo("Test result: " & test_result & LF);
        echo("----------------------------------------------------------------------------------------" & LF);
    end if;
    
end process;


end Behavioral;

--------------------------------------------------------------------------------------------------------------
------------------------------- Тест синтезируемой модели I2C EEPROM контроллера -----------------------------
--------------------------------------------------------------------------------------------------------------
------------------------------------------- Режим записи: PAGE WRITE при высоком сигнале WC_n ----------------
------------------------------------------- Режим чтения: не важен -------------------------------------------
------------------------------------------- Время моделирования: 4 ms ----------------------------------------
--------------------------------------------------------------------------------------------------------------
-- I2C EEPROM должен посылать NACK при попытке записи байта, I2C мастера должен высталять '1' на выход 
-- error при получении NACK. Тест подсчитывает число импульсов error, при попытке записать 16 байт 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PAGE_WR_WC_High is
end PAGE_WR_WC_High;

architecture Behavioral of PAGE_WR_WC_High is

-- процедура для вывода данных без сообщений от Vivado
procedure echo (arg : in string := "") is
begin
  std.textio.write(std.textio.output, arg);
end procedure echo;

------------------------------------ Параметры теста ------------------------------------
constant Input_Data_File : string  := "/home/vovan/VivadoProjects/I2C_EEPROM/tests/PAGE_WR_WC_High.txt";
constant SCL_Freq        : integer := 100000;     -- частота сигнала SCL в Гц
constant Clk_Freq        : integer := 200000000;  -- частота тактового сигнала в Гц
constant Fifo_Latency    : integer := 1;          -- задержка выдачи данных из fifo после fifi_re (1 или 2 такта)
-----------------------------------------------------------------------------------------

-- Поведенческая модель I2C EEPROM
component I2C_EEPROM is
    Port ( SCL  : inout STD_LOGIC;
           SDA  : inout STD_LOGIC;
           WC_n : in    STD_LOGIC;
           E    : in    STD_LOGIC_VECTOR(2 downto 0)
    );
end component;

-- Блок записи данных во входное FIFO
component Data_Generator is
Generic( Input_Data_File : string     
    );
    Port ( clk            : in  STD_LOGIC;                     
           fifo_data      : out STD_LOGIC_VECTOR (7 downto 0);  
           fifo_we        : out STD_LOGIC;
           tx_data        : out STD_LOGIC_VECTOR (7 downto 0);  
           tx_data_Valid  : out STD_LOGIC                                                       
    );
end component;

-- IP-ядро входного FIFO
COMPONENT IFIFO
  PORT (
    clk   : IN  STD_LOGIC;
    srst  : IN  STD_LOGIC;
    din   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN  STD_LOGIC;
    rd_en : IN  STD_LOGIC;
    dout  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full  : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

-- Блок защиты от метастабильности и поиска фронта
component Start_Edge_Detector is
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           Start_Button : in  STD_LOGIC;
           Start_EEPROM : out STD_LOGIC);
end component;

-- Контроллер I2C EEPROM
component I2C_EEPROM_Controller is
    Generic( Clk_Freq     : integer;  
             SCL_Freq     : integer;  
             Fifo_Latency : integer  
    );
    Port ( clk               : in    STD_LOGIC;
           reset             : in    STD_LOGIC;                       
           transaction_start : in    STD_LOGIC;                        
           ctrl_byte         : in    STD_LOGIC_VECTOR (7 downto 0);    
           data_to_eeprom    : in    STD_LOGIC_VECTOR (7 downto 0);    
           fifo_re           : out   STD_LOGIC;                        
           data_from_eeprom  : out   STD_LOGIC_VECTOR (7 downto 0);    
           fifo_we           : out   STD_LOGIC;                        
           error             : out   STD_LOGIC;                        
           done              : out   STD_LOGIC;                        
           SCL               : inout STD_LOGIC;                        
           SDA               : inout STD_LOGIC                                
    );
end component;

signal SCL : STD_LOGIC;                      
signal SDA : STD_LOGIC;                      

signal clk : STD_LOGIC;
signal reset : STD_LOGIC; 
constant clk_period : time := 1 sec / Clk_Freq;

signal data_to_IFIFO : STD_LOGIC_VECTOR (7 downto 0);  
signal IFIFO_we : STD_LOGIC;               

signal data_from_IFIFO : STD_LOGIC_VECTOR (15 downto 0);  
signal IFIFO_re : STD_LOGIC;           

signal data_to_OFIFO : STD_LOGIC_VECTOR (7 downto 0);  
signal OFIFO_we : STD_LOGIC;               

signal Start_Button : STD_LOGIC;           
signal Start_EEPROM : STD_LOGIC;           

signal Controller_Error : STD_LOGIC;           
signal Controller_Done  : STD_LOGIC;           

signal tx_data : STD_LOGIC_VECTOR (7 downto 0);                     
signal tx_data_valid : STD_LOGIC;  

type Results_Array_Type is array (0 to 100) of std_logic_vector(7 downto 0);

begin

SCL <= 'H';
SDA <= 'H';

start_stim: process
begin
    Start_Button <= '0';
    wait for 300 ns;
    -- транзакция на первую запись
    Start_Button <= '1';
    wait for 1 us;
    Start_Button <= '0';
    wait for 1 ms;
    -- транзакция на вторую запись
    Start_Button <= '1';
    wait for 1 us;
    Start_Button <= '0';
    wait for 1 ms;
    -- транзакция на третью запись
    Start_Button <= '1';
    wait for 1 us;
    Start_Button <= '0';
    wait;
end process;


clk_stim: process
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

reset_stim: process
begin
    reset <= '1';
    wait for 100 ns;
    reset <= '0';
    wait;
end process;

-- Поведенческая модель I2C EEPROM
I2C_EEPROM_1: I2C_EEPROM
    Port Map (
        SCL  => SCL,
        SDA  => SDA,
        WC_n => '1',  -- !!! высокий уровень препятствует записи
        E    => "000"
    );

-- Блок записи данных во входное FIFO
Data_Generator_1: Data_Generator
    Generic Map (
        Input_Data_File => Input_Data_File  
    )
    Port Map (
        clk           => clk,
        fifo_data     => data_to_IFIFO,
        fifo_we       => IFIFO_we,
        tx_data       => tx_data,
        tx_data_valid => tx_data_valid
    );

-- IP-ядро входного FIFO
Input_FIFO : IFIFO
  PORT MAP (
    clk   => clk,
    srst  => reset,
    din   => data_to_IFIFO,
    wr_en => IFIFO_we,
    rd_en => IFIFO_re, 
    dout  => data_from_IFIFO,
    full  => open,
    empty => open
  );
  
-- Блок защиты от метастабильности и поиска фронта
Start_Edge_Detector_1: Start_Edge_Detector
    Port Map ( clk          => clk,
               reset        => reset,
               Start_Button => Start_Button,
               Start_EEPROM => Start_EEPROM
     );

-- Контроллер I2C EEPROM
uut: I2C_EEPROM_Controller
    Generic Map ( Clk_Freq     => Clk_Freq,
                  SCL_Freq     => SCL_Freq,
                  Fifo_Latency => Fifo_Latency 
    )
    Port Map ( clk               => clk,
               reset             => reset,                     
               transaction_start => Start_EEPROM,                    
               ctrl_byte         => data_from_IFIFO(15 downto 8),   
               data_to_eeprom    => data_from_IFIFO(7 downto 0),  
               fifo_re           => IFIFO_re,                  
               data_from_eeprom  => data_to_OFIFO,  
               fifo_we           => OFIFO_we,                      
               error             => Controller_Error,                     
               done              => Controller_Done,                      
               SCL               => SCL,                     
               SDA               => SDA                             
    );

-----------------------------------------------------------------------------------------
--------------------------- проверка результатов ----------------------------------------
process (Controller_Error, Controller_Done)
    variable Time_Var : time := 0 ns;
    variable counter_error : integer := 0;
    variable test_result : string(1 to 4) := "PASS";
begin
    
     -- подсчитываем число ошибок при записи
    if rising_edge(Controller_Error) then
        Time_Var := now;
        echo("Error detected at time " & time'image(Time_Var) & LF);
        echo("" & LF);
        counter_error := counter_error + 1;
    end if;
    
    -- вывод результатов теста
    if rising_edge(Controller_Done) then
        Time_Var := now;
        if Time_Var > 2.8 ms then
            if counter_error /= 16 then
                test_result := "FAIL";
            end if;
        
            echo("----------------------------------------------------------------------------------------" & LF);
            echo("Number of errors: " & integer'image(counter_error) & LF);
            echo("Test result: " & test_result & LF);
            echo("----------------------------------------------------------------------------------------" & LF);
        end if;
    end if;
end process;  
end Behavioral;

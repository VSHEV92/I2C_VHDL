--------------------------------------------------------------------------------------------------------------
------------------------------- Тест синтезируемой модели I2C EEPROM контроллера -----------------------------
--------------------------------------------------------------------------------------------------------------
------------------------------------------- Режим записи: PAGE WRITE -----------------------------------------
------------------------------------------- Режим чтения: SEQUANTIAL RANDOM READ -----------------------------
------------------------------------------- Время моделирования: 12 ms ---------------------------------------
--------------------------------------------------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PAGE_WR_SEQ_RAND_RD is
end PAGE_WR_SEQ_RAND_RD;

architecture Behavioral of PAGE_WR_SEQ_RAND_RD is

-- процедура для вывода данных без сообщений от Vivado
procedure echo (arg : in string := "") is
begin
  std.textio.write(std.textio.output, arg);
end procedure echo;

------------------------------------ Параметры теста ------------------------------------
constant Input_Data_File : string  := "/home/vovan/VivadoProjects/I2C_EEPROM/tests/PAGE_WR_SEQ_RAND_RD.txt";
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
    -- транзакция на запись
    Start_Button <= '1';
    wait for 1 us;
    Start_Button <= '0';
    wait for 1 ms;
    -- транзакция на чтение
    Start_Button <= '1';
    wait for 1 us;
    Start_Button <= '0';
    wait for 1 ms;
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
        WC_n => '0',
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
process (tx_data_valid, OFIFO_we, Controller_Error, Controller_Done)
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
    if rising_edge(OFIFO_we) then
        data_rx_var(counter_rx) := data_to_OFIFO;
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
    if rising_edge(Controller_Error) then
        Time_Var := now;
        echo("Wrong ACK at time " & time'image(Time_Var) & LF);
        echo("" & LF);
        test_result := "FAIL";
    end if;
    
    -- вывод результатов теста
    if rising_edge(Controller_Done) then
        Time_Var := now;
        if Time_Var > 2 ms then
            echo("----------------------------------------------------------------------------------------" & LF);
            echo("Number of transmitted words: " & integer'image(counter_tx) & LF);
            echo("Number of received words: " & integer'image(counter_rx) & LF);
            echo("Test result: " & test_result & LF);
            echo("----------------------------------------------------------------------------------------" & LF);
        end if;
    end if;
    
end process;

  
end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity I2C_EEPROM_by_UART_Top is
    Port ( clk          : in    STD_LOGIC;
           reset        : in    STD_LOGIC;
           rx           : in    STD_LOGIC;
           tx           : out   STD_LOGIC;
           Start_Button : in    STD_LOGIC;
           SCL          : inout STD_LOGIC;                       
           SDA          : inout STD_LOGIC; 
           Done         : out   STD_LOGIC
    );
end I2C_EEPROM_by_UART_Top;

architecture Behavioral of I2C_EEPROM_by_UART_Top is

component Start_Edge_Detector is
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           Start_Button : in  STD_LOGIC;
           Start_EEPROM : out STD_LOGIC);
end component;

component I2C_EEPROM_Controller is
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
end component;

component UART_RX is
    Generic( Clk_Freq   : integer;  -- частота тактового сигнала в Гц
             Baud_Rate  : integer;  -- 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
             Byte_Size  : integer;  -- 5, 6, 7, 8, 9
             Stop_Bits  : integer;  -- 0, 1, 2
             Parity_Bit : integer   -- 0 - none, 1 - even, 2 - odd,
    );
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           rx           : in  STD_LOGIC;
           data         : out STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
           data_valid   : out STD_LOGIC;
           parity_error : out STD_LOGIC
    );
end component;

component UART_TX is
    Generic( Clk_Freq     : integer;  -- частота тактового сигнала в Гц
             Fifo_Latency : integer;  -- задержка выдачи данных из fifo после fifi_re (1 или 2 такта)
             Baud_Rate    : integer;  -- 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
             Byte_Size    : integer;  -- 5, 6, 7, 8, 9
             Stop_Bits    : integer;  -- 0, 1, 2
             Parity_Bit   : integer   -- 0 - none, 1 - even, 2 - odd,
    );
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           data         : in  STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
           fifo_empty   : in  STD_LOGIC;
           fifo_re      : out STD_LOGIC;
           tx           : out STD_LOGIC
    );
end component;

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

COMPONENT OFIFO
  PORT (
    clk   : IN  STD_LOGIC;
    srst  : IN  STD_LOGIC;
    din   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN  STD_LOGIC;
    rd_en : IN  STD_LOGIC;
    dout  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full  : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

signal Start_EEPROM : STD_LOGIC;

signal rx_data : STD_LOGIC_VECTOR (7 downto 0);
signal tx_data : STD_LOGIC_VECTOR (7 downto 0);

signal IFIFO_Out : STD_LOGIC_VECTOR (15 downto 0);

signal ctrl_byte        : STD_LOGIC_VECTOR (7 downto 0);
signal data_to_eeprom   : STD_LOGIC_VECTOR (7 downto 0);
signal data_from_eeprom : STD_LOGIC_VECTOR (7 downto 0);

signal ififo_we    : STD_LOGIC;
signal ififo_re    : STD_LOGIC;
signal ofifo_we    : STD_LOGIC;
signal ofifo_re    : STD_LOGIC;
signal ofifo_empty : STD_LOGIC;

begin

Start_Edge_Detector_1: Start_Edge_Detector
    Port Map ( clk          => clk,
               reset        => reset,
               Start_Button => Start_Button,
               Start_EEPROM => Start_EEPROM
    );

I2C_EEPROM_Controller_1: I2C_EEPROM_Controller 
    Generic Map ( Clk_Freq     => 200000000,
                  SCL_Freq     => 100000,
                  Fifo_Latency => 1
    )
    Port Map ( clk               => clk,
               reset             => reset,
               transaction_start => Start_EEPROM,
               ctrl_byte         => ctrl_byte,
               data_to_eeprom    => data_to_eeprom,
               fifo_re           => ififo_re,
               data_from_eeprom  => data_from_eeprom,
               fifo_we           => ofifo_we,
               error             => open,
               done              => Done,
               SCL               => SCL,
               SDA               => SDA      
    );

UART_RX_1: UART_RX
    Generic map( Clk_Freq   => 200000000,
                 Baud_Rate  => 9600,  
                 Byte_Size  => 8,
                 Stop_Bits  => 1,
                 Parity_Bit => 0
    )
    Port map ( clk          => clk,
               reset        => reset,
               rx           => rx, 
               data         => rx_data,
               data_valid   => ififo_we,
               parity_error => open
    );

UART_TX_1: UART_TX
    Generic map( Clk_Freq     => 200000000,
                 Fifo_Latency => 1,
                 Baud_Rate    => 9600,  
                 Byte_Size    => 8,
                 Stop_Bits    => 1,
                 Parity_Bit   => 0
    )
    Port map ( clk          => clk,
               reset        => reset,
               data         => tx_data,
               fifo_empty   => ofifo_empty,
               fifo_re      => ofifo_re,
               tx           => tx
    );

INFIFO : IFIFO
  PORT MAP (
    clk   => clk,
    srst  => reset,
    din   => rx_data,
    wr_en => ififo_we,
    rd_en => ififo_re,
    dout  => IFIFO_Out,
    full  => open,
    empty => open
  );

 ctrl_byte      <= IFIFO_Out(15 downto 8);   
 data_to_eeprom <= IFIFO_Out(7 downto 0);

OUTFIFO : OFIFO
  PORT MAP (
    clk   => clk,
    srst  => reset,
    din   => data_from_eeprom,
    wr_en => ofifo_we,
    rd_en => ofifo_re,
    dout  => tx_data,
    full  => open,
    empty => ofifo_empty
  );

end Behavioral;

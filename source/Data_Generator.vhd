--------------------------------------------------------------------------------------------------------------
-------------------------------- Блок для считывания данных из файла -----------------------------------------
-- Входные данные для передачи считываются из файла, путь к которому указывается в generic Input_Data_File.
-- Содержимое строки файла состоит из двух целых чисел: первое число - байт управления; второе - байт данных.
-- Байт управления определяет дальнейшее поведение блока. Байт данных задает значение, которое будет выставлено
-- на шину SDA при записи данных или адреса и при идентификации. При чтении этот байт не имеет значения.
-- Блок считывает файл от начала и до конца и записывает все данные в FIFO.
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use STD.textio.all;
use ieee.std_logic_textio.all;

use IEEE.NUMERIC_STD.ALL;

entity Data_Generator is
Generic( Input_Data_File : string     -- путь к файлу с передаваемыми данными
    );
    Port ( clk            : in  STD_LOGIC;                      -- тактовый сигнал
           fifo_data      : out STD_LOGIC_VECTOR (7 downto 0);  -- данне для FIFO
           fifo_we        : out STD_LOGIC;                      -- сигнал записи в FIFO
           tx_data        : out STD_LOGIC_VECTOR (7 downto 0);  -- данне, записываемые в EEPROM
           tx_data_Valid  : out STD_LOGIC                       -- строб для данных, записываемых в EEPROM            
    );
end Data_Generator;

architecture Behavioral of Data_Generator is

file file_HANDLER : text;


begin
process
    -- переменные для считывания из файла
    variable file_LINE : line;
    variable file_DATA : integer;
    variable SPACE     : character;
    
    variable data_bits : std_logic_vector(7 downto 0); -- байт данных
    variable ctrl_bits : std_logic_vector(7 downto 0); -- байт, управления
        
begin
    fifo_we <= '0';
    tx_data_Valid <= '0';
    wait for 150 ns;
    
    file_open(file_HANDLER, Input_Data_File,  read_mode);
    while not endfile(file_HANDLER) loop       
        -- считываем входные данные
        readline(file_HANDLER, file_LINE);
        read(file_LINE, file_DATA);
        ctrl_bits := std_logic_vector(to_unsigned(file_DATA, 8));
        read(file_LINE, SPACE);
        read(file_LINE, file_DATA);
        data_bits := std_logic_vector(to_unsigned(file_DATA, 8));
        
        -- записываем байт управления
        wait until rising_edge(clk);
        fifo_data <= ctrl_bits;
        fifo_we <= '1';
        wait until rising_edge(clk);
        fifo_we <= '0';
        
        -- записываем байт данных
        wait until rising_edge(clk);
        fifo_data <= data_bits;
        fifo_we <= '1';
        -- если это данные для записи в EEPROM выводим их
        if ctrl_bits = x"03" or ctrl_bits = x"05" then
            tx_data <= data_bits;
            tx_data_Valid <= '1';
        end if;
        wait until rising_edge(clk);
        fifo_we <= '0';
        tx_data_Valid <= '0';
          
    end loop;
    fifo_we <= '0';
    wait;
end process;

end Behavioral;

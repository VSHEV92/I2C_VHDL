--------------------------------------------------------------------------------------------------------------
------------------------- Блок защиты от метастабильности и поиск фронта -------------------------------------
-- Блок защищает от метастабильности, которая может возникнуть при нажатии кнопки, а также находит фронт
-- сигнала Start_Button и выдает команду на начало транзакции 
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Start_Edge_Detector is
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           Start_Button : in  STD_LOGIC;
           Start_EEPROM : out STD_LOGIC);
end Start_Edge_Detector;

architecture Behavioral of Start_Edge_Detector is

signal Start_Button_delayed_1 : STD_LOGIC;
signal Start_Button_delayed_2 : STD_LOGIC;
signal Start_Button_delayed_3 : STD_LOGIC;

begin

-- защита от метастабильности и поиск фронта
process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            Start_Button_delayed_1 <= '0';
            Start_Button_delayed_2 <= '0';
            Start_Button_delayed_3 <= '0';
        else
            Start_Button_delayed_1 <= Start_Button;
            Start_Button_delayed_2 <= Start_Button_delayed_1;
            Start_Button_delayed_3 <= Start_Button_delayed_2;
            Start_EEPROM <= not Start_Button_delayed_3 and Start_Button_delayed_2;
        end if;
    end if;
end process;



end Behavioral;

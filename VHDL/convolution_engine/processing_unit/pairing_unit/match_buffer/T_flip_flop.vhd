
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity t_flip_flop is
    Port ( toggle : in  STD_LOGIC;
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
           Dout : out  STD_LOGIC);
end t_flip_flop;

architecture Behavioral of t_flip_flop is

signal int_Dout : STD_LOGIC;
  
begin
SYNC_PROC: process (clk)
   begin
      if (clk'event and clk = '1') then
         if (reset = '1') then
            int_Dout <= '0';
         else
            if (toggle='1') then 
					int_Dout <= not(int_Dout);
				end if;	
         end if;        
      end if;
   end process;
Dout <= int_Dout;
end Behavioral;


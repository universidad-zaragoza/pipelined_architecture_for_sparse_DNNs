library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bidirectional_counter is
    generic(bits : positive := 2;
            step : positive := 1);
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         rst_2 : in STD_LOGIC;
         inc   : in STD_LOGIC;
         dec   : in STD_LOGIC;
         -----------------
         ---- OUTPUTS ----
         -----------------
         count : out STD_LOGIC_VECTOR(bits - 1 downto 0));
end bidirectional_counter;

architecture bidirectional_counter_arch of bidirectional_counter is	
	signal cs, ns : STD_LOGIC_VECTOR(bits - 1 downto 0);
begin	
	current_state:
	process(clk)		
	begin		
		if rising_edge(clk) then
			if rst = '1' then 
				cs <= (others => '0');
			else			 
				cs <= ns;
			end if;
		end if;
	end process; 
	
	next_state:
	process(cs, rst_2, inc, dec)
		begin
			if rst_2 = '1' then
                ns <= (others => '0');                
			elsif inc = '1' then 
                ns <= std_logic_vector(unsigned(cs) + step);
			elsif dec = '1' then 
                ns <= std_logic_vector(unsigned(cs) - step);
			else 
				ns <= cs;
         end if;
   end process;

   count <= cs;
end bidirectional_counter_arch;
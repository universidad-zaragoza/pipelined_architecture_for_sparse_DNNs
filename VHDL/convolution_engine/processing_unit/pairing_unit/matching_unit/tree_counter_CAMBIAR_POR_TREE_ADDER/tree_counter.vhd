library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity tree_counter is
	generic(input_width : positive := 32);
    port(----------------
         ---- INPUTS ----
         ----------------
         input : in STD_LOGIC_VECTOR(input_width - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         output : out STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0)
    );
end tree_counter;

architecture tree_counter_arch of tree_counter is
	component tree_counter
		generic(input_width : positive);
        port(----------------
			 ---- INPUTS ----
			 ----------------
             input : in STD_LOGIC_VECTOR(input_width - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             output : out STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0)
        );
    end component;
begin
	---------------
    -- Base case --
    ---------------
	base_case: if input_width = 1 generate
        output <= input;
    end generate;
    
    ---------------
    -- Recursion --
    ---------------
    -- Input width is even
    recursion_even_width: if (input_width >= 2) AND (input_width MOD 2 = 0) generate
        signal out_a, out_b : STD_LOGIC_VECTOR(log_2(input_width / 2 + 1) - 1 downto 0);
        signal stage_output : STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0);
    begin
        left_tree_counter: tree_counter generic map(input_width => input_width / 2)
            port map(input(input_width - 1 downto input_width / 2), out_a);
        
        right_tree_counter: tree_counter generic map(input_width => input_width / 2)
            port map(input((input_width / 2) - 1 downto 0), out_b);
        output <= c_add(out_a, out_b);
    end generate;
    
    -- Input width is odd
    recursion_odd_width: if (input_width > 2) AND (input_width MOD 2 /= 0) generate
        signal out_a, out_b: STD_LOGIC_VECTOR(log_2(input_width / 2 + 1) - 1 downto 0);
        signal stage_output : STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0);
    begin
        left_tree_counter: tree_counter generic map(input_width => input_width / 2)
            port map(input(input_width - 1 downto input_width / 2 + 1), out_a);
        
        right_tree_counter: tree_counter generic map(input_width => input_width / 2)
            port map(input(input_width / 2 downto 1), out_b);
 
        output <= add(c_add(out_a, out_b), input(0 downto 0));
    end generate;
end tree_counter_arch;
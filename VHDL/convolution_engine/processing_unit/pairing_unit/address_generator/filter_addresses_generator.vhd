library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity filter_addresses_generator is
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         convolution_step_done : in STD_LOGIC;
         indices_granted   : in STD_LOGIC;         
         match_processed   : in STD_LOGIC;
         last_match        : in STD_LOGIC;
         no_match          : in STD_LOGIC;
         -- Filter
         filter_jump : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
         filter_rest : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
         indices_convolution_step_done : in STD_LOGIC;         
         -----------------
         ---- OUTPUTS ----
         -----------------
         filter_indices_address : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_INDICES_WIDTH) - 1 downto 0);
         filter_values_address  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0)
    );
end filter_addresses_generator;

architecture filter_addresses_generator_arch of filter_addresses_generator is
    component counter
        generic(bits : positive := 2;
                step : positive := 1);
            port(----------------
                 ---- INPUTS ----
                 ----------------
                 clk : in STD_LOGIC;
                 rst : in STD_LOGIC;
                 rst_2 : in STD_LOGIC;
                 inc   : in STD_LOGIC;
                 -----------------
                 ---- OUTPUTS ----
                 -----------------
                 count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;
    
    component reg
		generic(bits       : natural := 128;
                init_value : natural := 0);
		port (----------------
			  ---- INPUTS ----
			  ----------------
              clk : in STD_LOGIC;
              rst : in STD_LOGIC;
              ld  : in STD_LOGIC;
              din : in STD_LOGIC_VECTOR(bits - 1 downto 0);
              -----------------
              ---- OUTPUTS ----
              -----------------
              dout : out STD_LOGIC_VECTOR(bits - 1 downto 0)
		);
	end component;
    
    -- Accumulator for filter values address
    signal new_filter_values_address : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    signal filter_values_address_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
signal filter_indices_address_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_INDICES_WIDTH) - 1 downto 0);
begin
    --------------------------------------
    -- Accumulators for filter addresses --
    --------------------------------------
    -- Indices
    filter_indices_address_count: counter generic map(bits => log_2(MAX_FILTER_ELEMENTS / FILTER_INDICES_WIDTH),
                                                      step => 1)
        port map(clk, rst, indices_convolution_step_done, indices_granted, filter_indices_address);

    -- Values
    filter_values_address_count: reg generic map(bits => log_2(MAX_FILTER_ELEMENTS))
        port map(clk, rst OR convolution_step_done, match_processed OR no_match, new_filter_values_address, filter_values_address_int);

    new_filter_values_address <= std_logic_vector(unsigned(filter_values_address_int) + (unsigned(filter_jump) + unsigned(filter_rest))) when last_match = '1' OR no_match = '1' else
                                 std_logic_vector(unsigned(filter_values_address_int) + unsigned(filter_jump));
                                 
    -- Output
    filter_values_address <= std_logic_vector(unsigned(filter_values_address_int) + (unsigned(filter_jump) - 1));
end filter_addresses_generator_arch;
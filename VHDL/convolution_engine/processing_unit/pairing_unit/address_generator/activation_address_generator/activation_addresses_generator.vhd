library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_addresses_generator is
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution     : in STD_LOGIC;
         convolution_step_done : in STD_LOGIC;
         -- Convolution dimensions
         activation_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);
         filter_depth              : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
         -- Value addressing
         activation_base           : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
         activation_section_offset : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
         filter_no : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
         filters_no : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
         -- Indices addressing control
         indices_filter_inc_x : in STD_LOGIC;
         indices_filter_inc_y : in STD_LOGIC;
         indices_filter_inc_z : in STD_LOGIC;
         indices_activation_inc_x : in STD_LOGIC;
         indices_activation_inc_y : in STD_LOGIC;
         indices_convolution_step_done : in STD_LOGIC;
         -----------------
         ---- OUTPUTS ----
         -----------------
         activation_indices_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
         activation_values_address  : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
         new_activation_values_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0)
    );
end activation_addresses_generator;

architecture activation_addresses_generator_arch of activation_addresses_generator is
    component step_base
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             start_convolution : in STD_LOGIC;
             -- Step when increasing x
             activation_inc_x : in STD_LOGIC;
             filter_depth     : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
             -- Step when increasing y
             activation_inc_y          : in STD_LOGIC;
             activation_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             activation_step_base : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0)
        );
    end component;
    
    component filter_offset
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             filter_inc_z : in STD_LOGIC;
             filter_inc_x : in STD_LOGIC;
             filter_inc_y : in STD_LOGIC;
             convolution_step_done : in STD_LOGIC;
             -- Convolution dimensions
             activation_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             row_offset : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH * MAX_FILTER_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
             col_offset : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_DEPTH * MAX_ACTIVATION_WIDTH * MAX_FILTER_HEIGHT / ACTIVATION_INDICES_WIDTH) - 1 downto 0)
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
    
    --------------------------------------
    -- Current layer activation address --
    --------------------------------------
    -- Values
    signal activation_step_base : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal row_offset : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH * MAX_FILTER_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal col_offset : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_DEPTH * MAX_ACTIVATION_WIDTH * MAX_FILTER_HEIGHT / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    -- Indices
    signal indices_activation_step_base : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal indices_row_offset : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH * MAX_FILTER_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal indices_col_offset : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_DEPTH * MAX_ACTIVATION_WIDTH * MAX_FILTER_HEIGHT / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal indices_section_beginning : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);    
    
    -----------------------------------------------
    -- Next layer activation address accumulator --
    -----------------------------------------------
    signal new_activation_values_address_current : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    signal new_activation_values_address_next    : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
begin
    --------------------------------------
    -- Current layer activation address --
    --------------------------------------
    -- Values addressing
    activation_values_address <= std_logic_vector(unsigned(activation_base)) & std_logic_vector(unsigned(activation_section_offset));

                                 
    -- Indices addressing
    indices_activation_step_base_I: step_base
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 -- Step when increasing x
                 activation_inc_x => indices_activation_inc_x,
                 filter_depth     => filter_depth(log_2(MAX_FILTER_DEPTH) - 1 downto log_2(ACTIVATION_INDICES_WIDTH)),
                 -- Step when increasing y
                 activation_inc_y          => indices_activation_inc_y,
                 activation_x_z_slice_size => activation_x_z_slice_size(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto log_2(ACTIVATION_INDICES_WIDTH)),
                 ---- OUTPUTS ----
                 activation_step_base => indices_activation_step_base
        );

    indices_filter_offset_I: filter_offset
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 filter_inc_z => indices_filter_inc_z,
                 filter_inc_x => indices_filter_inc_x,
                 filter_inc_y => indices_filter_inc_y,
                 convolution_step_done => indices_convolution_step_done,
                 -- Convolution dimensions
                 activation_x_z_slice_size => activation_x_z_slice_size(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto log_2(ACTIVATION_INDICES_WIDTH)),
                 ---- OUTPUTS ----
                 row_offset => indices_row_offset,
                 col_offset => indices_col_offset
        );

    -----------------------------------
    -- Next layer activation address --
    -----------------------------------
    new_activation_values_pos: reg generic map(bits => log_2(MAX_ACTIVATION_ELEMENTS))
        port map(clk, rst OR start_convolution, convolution_step_done, new_activation_values_address_next, new_activation_values_address_current);
    
    new_activation_values_address_next <= new_activation_values_address_current + filters_no;    
    
    -------------
    -- Outputs --
    -------------
    new_activation_values_address <= new_activation_values_address_current;
    -- activation_indices_address    <= indices_activation_step_base + (indices_row_offset + indices_col_offset);
activation_indices_address    <= resize(indices_activation_step_base + (indices_row_offset + indices_col_offset), log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH));
end activation_addresses_generator_arch;
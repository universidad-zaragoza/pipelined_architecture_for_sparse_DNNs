library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity address_generator is
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution     : in STD_LOGIC;
         convolution_step_done : in STD_LOGIC;
         indices_granted          : in STD_LOGIC;
         indices_buffer_processed : in STD_LOGIC;
         section_processed : in STD_LOGIC;
         -- Matching unit begins the exploration of a new section
         match_processed : in STD_LOGIC;
         last_match      : in STD_LOGIC;
         no_match        : in STD_LOGIC;
         -- Convolution dimensions
         activation_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);
         filter_depth              : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
         -- Filter
         filter_jump : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
         filter_rest : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
         indices_filter_inc_x : in STD_LOGIC;
         indices_filter_inc_y : in STD_LOGIC;
         indices_filter_inc_z : in STD_LOGIC;
         -- Activation
         activation_base           : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
         activation_section_offset : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
         filter_no : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
         filters_no : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
         indices_activation_inc_x : in STD_LOGIC;
         indices_activation_inc_y : in STD_LOGIC;
         indices_convolution_step_done : in STD_LOGIC;
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- Indices
         filter_indices_address     : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_INDICES_WIDTH) - 1 downto 0);
         activation_indices_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
         -- Values
         filter_values_address     : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
         activation_values_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
         new_activation_values_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0)
    );
end address_generator;

architecture address_generator_arch of address_generator is
    component filter_addresses_generator
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
    end component;
    
    component activation_addresses_generator
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
             -- Indices addressing
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
    end component;
begin
    filter_addresses_generator_I: filter_addresses_generator
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 convolution_step_done => convolution_step_done,
                 indices_granted   => indices_granted,                 
                 match_processed   => match_processed,
                 last_match        => last_match,
                 no_match          => no_match,
                 -- Filter
                 filter_jump => filter_jump,
                 filter_rest => filter_rest,
                 indices_convolution_step_done => indices_convolution_step_done,
                 ---- OUTPUTS ----
                 filter_indices_address => filter_indices_address,
                 filter_values_address  => filter_values_address
        );

    activation_addresses_generator_I: activation_addresses_generator
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 convolution_step_done => convolution_step_done,
                 -- Convolution dimensions
                 activation_x_z_slice_size => activation_x_z_slice_size,
                 filter_depth              => filter_depth,
                 -- Value addesssing control
                 activation_base           => activation_base,
                 activation_section_offset => activation_section_offset,
                 filter_no  => filter_no,
                 filters_no => filters_no,
                 -- Indices addressing control
                 indices_filter_inc_x     => indices_filter_inc_x,
                 indices_filter_inc_y     => indices_filter_inc_y,
                 indices_filter_inc_z     => indices_filter_inc_z,
                 indices_activation_inc_x => indices_activation_inc_x,
                 indices_activation_inc_y => indices_activation_inc_y,
                 indices_convolution_step_done => indices_convolution_step_done,                 
                 -----------------
                 ---- OUTPUTS ----
                 -----------------
                 activation_indices_address => activation_indices_address,
                 activation_values_address  => activation_values_address,
                 new_activation_values_address => new_activation_values_address
        );   
end address_generator_arch;
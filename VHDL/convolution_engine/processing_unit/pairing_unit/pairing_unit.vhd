library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity pairing_unit is
    port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution : in STD_LOGIC;
         -- Convolution dimensions
         activation_height         : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
         activation_width          : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
         activation_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);
         filter_height     : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
         filter_width      : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
         filter_depth      : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
         filter_no : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
         filters_no : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
         -- Indices
         indices_granted : in STD_LOGIC;
         indices_served     : in STD_LOGIC;
         filter_indices     : in STD_LOGIC_VECTOR(FILTER_INDICES_WIDTH - 1 downto 0);
         activation_indices : in STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
         -- Pairs buffer
         pair_taken : in STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- Indices
         request_indices            : out STD_LOGIC;
         filter_indices_address     : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_INDICES_WIDTH) - 1 downto 0);
         activation_indices_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
         -- Pairs buffer
         pairs_available      : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
         filter_addresses     : out tp_match_buffer_filter;
         activation_addresses : out tp_match_buffer_activation;
         -- Element position in the new activation
         new_activation_value_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
         convolution_step_done : out STD_LOGIC;
         convolution_done      : out STD_LOGIC
    );
end pairing_unit;

architecture pairing_unit_arch of pairing_unit is
    component sections_buffer_manager
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             start_convolution : in STD_LOGIC;
             indices_granted : in STD_LOGIC;
             indices_served     : in STD_LOGIC;
             filter_indices     : in STD_LOGIC_VECTOR(FILTER_INDICES_WIDTH - 1 downto 0);
             activation_indices : in STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
             section_processed     : in STD_LOGIC;
             -- Convolution control info
             convolution_step_done_in : in STD_LOGIC;
             convolution_done_in      : in STD_LOGIC;
             -- Activation base address
             activation_address_in : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             request_indices : out STD_LOGIC;
             section_available  : out STD_LOGIC;
             filter_section     : out STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
             activation_section : out STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
             indices_buffer_processed : out STD_LOGIC;
             -- Convolution control info             
             convolution_step_done : out STD_LOGIC;
             convolution_done      : out STD_LOGIC;
             -- Activation base address
             activation_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / SECTION_WIDTH) - 1 downto 0)
        );
    end component;
    
    component matching_unit
        port(------------
             -- INPUTS --
             ------------
             clk : in STD_LOGIC; 
             rst : in STD_LOGIC;
             start_convolution : in STD_LOGIC;
             new_section_available : in STD_LOGIC;
             filter_input          : in STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
             activation_input      : in STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
             match_taken : in STD_LOGIC;         
             convolution_step_done : in STD_LOGIC;
             convolution_done      : in STD_LOGIC;
             -------------
             -- OUTPUTS --
             -------------
             found    : out STD_LOGIC;
             no_match : out STD_LOGIC;
             position : out STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
             last     : out STD_LOGIC;
             filter_jump : out STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
             filter_rest : out STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0)
        );
    end component;
    
    component address_generator
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
    end component;
    
    component match_buffer
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in std_logic;
             rst : in std_logic;
             -- Pair to buffer
             new_pair_ready         : in STD_LOGIC;
             filter_address         : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
             activation_address     : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
             new_activation_address : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
             last_pair_step         : in STD_LOGIC;
             last_pair              : in STD_LOGIC;
             -- Read from buffer
             pair_taken : in STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             buffer_full  : out STD_LOGIC;             
             pairs : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
             filter_addresses           : out tp_match_buffer_filter;
             activation_addresses       : out tp_match_buffer_activation;
             new_activation_address_out : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
             convolution_step_done : out STD_LOGIC;
             convolution_done      : out STD_LOGIC
        );
    end component;
    
    component convolution_controller
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- Convolution dimensions
             activation_height : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
             activation_width  : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
             filter_height     : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
             filter_width      : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
             filter_depth      : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
             -- New section received
             indices_granted   : in STD_LOGIC;
             -----------------
             ---- OUTPUTS ----
             -----------------
             filter_inc_x : out STD_LOGIC;
             filter_inc_y : out STD_LOGIC;
             filter_inc_z : out STD_LOGIC;
             activation_inc_x : out STD_LOGIC;
             activation_inc_y : out STD_LOGIC;
             convolution_step_done : out STD_LOGIC;
             convolution_done      : out STD_LOGIC
        );
    end component;    
    
    -- Sections buffer
    signal filter_section     : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal activation_section : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal section_available : STD_LOGIC;
    signal indices_buffer_processed : STD_LOGIC;    
    signal convolution_step_done_buffer : STD_LOGIC;
    signal convolution_done_buffer      : STD_LOGIC;
    
    -- Matching unit
    signal match_found : STD_LOGIC;
    signal no_match : STD_LOGIC;
    signal match_position : STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
    signal last_match : STD_LOGIC;
    signal filter_jump : STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
    signal filter_rest : STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
    
    -- Address generator
    signal activation_base: STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
    signal activation_indices_address_int : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal filter_values_address     : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    signal activation_values_address : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    signal next_new_activation_value_address : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    
    -- Match buffer
    signal match_buffer_full  : STD_LOGIC;    
    
    -- Convolution controller
    signal filter_inc_x : STD_LOGIC;
    signal filter_inc_y : STD_LOGIC;
    signal filter_inc_z : STD_LOGIC;
    signal activation_inc_x : STD_LOGIC;
    signal activation_inc_y : STD_LOGIC;
    signal convolution_step_done_int : STD_LOGIC;
    signal convolution_done_int      : STD_LOGIC;
    signal indices_filter_inc_x     : STD_LOGIC;
    signal indices_filter_inc_y     : STD_LOGIC;
    signal indices_filter_inc_z     : STD_LOGIC;
    signal indices_activation_inc_x : STD_LOGIC;
    signal indices_activation_inc_y : STD_LOGIC;
    signal indices_convolution_step_done : STD_LOGIC;
    signal indices_convolution_done      : STD_LOGIC;
    
    -- Common
    signal section_processed : STD_LOGIC;
signal match_buffer_flushed : STD_LOGIC;
begin
    section_processed <= (last_match AND NOT(match_buffer_full)) OR no_match;
    
    ----------------------------
    -- Section buffer manager --
    ----------------------------
    sections_buffer_manager_I : sections_buffer_manager
        port map(-- INPUTS --
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 indices_granted => indices_granted,
                 indices_served     => indices_served,
                 filter_indices     => filter_indices,
                 activation_indices => activation_indices,
                 section_processed => section_processed,                 
                 convolution_step_done_in => convolution_step_done_int,
                 convolution_done_in      => convolution_done_int,
                 activation_address_in    => activation_indices_address_int,
                 -- OUTPUTS --
                 request_indices => request_indices,
                 section_available  => section_available,
                 filter_section     => filter_section,
                 activation_section => activation_section,
                 indices_buffer_processed => indices_buffer_processed,
                 -- Convolution control info                 
                 convolution_step_done => convolution_step_done_buffer,
                 convolution_done      => convolution_done_buffer,
                 activation_address    => activation_base
        );        

    -------------------
    -- Matching unit --
    -------------------
    matching_unit_I : matching_unit
        port map(-- INPUTS --
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 new_section_available => section_available,
                 filter_input          => filter_section,
                 activation_input      => activation_section,
                 match_taken => NOT(match_buffer_full),
                 convolution_step_done => convolution_step_done_buffer AND indices_buffer_processed,
                 convolution_done      => convolution_done_buffer AND indices_buffer_processed,
                 -- OUTPUTS --
                 found    => match_found,
                 no_match => no_match,
                 position => match_position,
                 last     => last_match,
                 filter_jump => filter_jump,
                 filter_rest => filter_rest
        );
 
    -----------------------
    -- Address generator --
    -----------------------
    address_generator_I: address_generator
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 indices_granted          => indices_granted,         
                 indices_buffer_processed => indices_buffer_processed,
                 section_processed => section_processed,
                 match_processed => match_found AND NOT(match_buffer_full),
                 last_match      => last_match,
                 no_match        => no_match,
                 -- Convolution dimensions
                 activation_x_z_slice_size => activation_x_z_slice_size,
                 filter_depth              => filter_depth,
                 -- Indices
                 indices_filter_inc_x => filter_inc_x,
                 indices_filter_inc_y => filter_inc_y,
                 indices_filter_inc_z => filter_inc_z,
                 indices_activation_inc_x => activation_inc_x,
                 indices_activation_inc_y => activation_inc_y,
                 indices_convolution_step_done => convolution_step_done_int,                 
                 -- Values
                 activation_base => activation_base,
                 convolution_step_done => convolution_step_done_buffer AND indices_buffer_processed,
                 filter_jump => filter_jump,
                 filter_rest => filter_rest,
                 activation_section_offset => match_position,
                 filter_no => filter_no,
                 filters_no => filters_no,
                 ---- OUTPUTS ----
                 -- Indices
                 filter_indices_address     => filter_indices_address,
                 activation_indices_address => activation_indices_address_int,
                 -- Values
                 filter_values_address     => filter_values_address,
                 activation_values_address => activation_values_address,
                 new_activation_values_address => next_new_activation_value_address
        );
activation_indices_address <= activation_indices_address_int;
    
    ------------------
    -- Match buffer --
    ------------------
    match_buffer_I : match_buffer
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Pair to buffer
                 new_pair_ready => match_found,
                 filter_address     => filter_values_address,
                 activation_address => activation_values_address,
                 new_activation_address => next_new_activation_value_address,
                 last_pair_step         => convolution_step_done_buffer AND indices_buffer_processed,
                 last_pair              => convolution_done_buffer      AND indices_buffer_processed,                 
                 -- Read from buffer
                 pair_taken => pair_taken,
                 ---- OUTPUTS ----
                 buffer_full  => match_buffer_full,                 
                 pairs                => pairs_available,
                 filter_addresses     => filter_addresses,
                 activation_addresses => activation_addresses,
                 new_activation_address_out => new_activation_value_address,                 
                 -- Last pairs of a convolution step have been read from the match buffer
                 convolution_step_done => match_buffer_flushed,
                 convolution_done      => convolution_done
        );
     
    ----------------------------
    -- Convolution controller --
    ----------------------------
    convolution_controller_I : convolution_controller
        port map(-- INPUTS --
                 clk => clk,
                 rst => rst,
                 -- Convolution dimensions
                 activation_height => activation_height,
                 activation_width  => activation_width,
                 filter_height     => filter_height,
                 filter_width      => filter_width,
                 filter_depth      => filter_depth,
                 -- New section received
                 indices_granted   => indices_granted,
                 -- OUTPUTS --
                 filter_inc_x => filter_inc_x,
                 filter_inc_y => filter_inc_y,
                 filter_inc_z => filter_inc_z,                 
                 activation_inc_x => activation_inc_x,
                 activation_inc_y => activation_inc_y,         
                 convolution_step_done => convolution_step_done_int,
                 convolution_done      => convolution_done_int
        );

    -- Outputs
    convolution_step_done <= match_buffer_flushed;
end pairing_unit_arch;
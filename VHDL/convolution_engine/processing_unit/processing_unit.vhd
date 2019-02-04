library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity processing_unit is
    generic(unit_no : natural := 0;
            bank_depth : positive := 8;
            mem_width  : positive := AXIS_BUS_WIDTH;
            data_width : positive := ACTIVATION_VALUE_WIDTH);
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         -- Filter from the DDR through the AXIS interface
         store_filter_indices : in STD_LOGIC;
         store_filter_values  : in STD_LOGIC;
         new_data     : in STD_LOGIC;
         filter_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);         
         -- Starts the convolution traversing all the activation
         start_convolution : in STD_LOGIC;
         -- Activation dimensions
         activation_height         : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
         activation_width          : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH)  - 1 downto 0);
         activation_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);
         -- ** Activation data **
         -- Request granted
         activation_indices_granted : in STD_LOGIC;
         -- Data are ready
         activation_indices_served : in STD_LOGIC;
         activation_indices        : in STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
         activation_value : in STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
         -- Pair taken by the activation value read arbiter
         request_served : in STD_LOGIC;
         request_no     : in STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
         -- Next layer activation value written
         new_activation_value_written : in STD_LOGIC;
         -----------------
         ---- OUTPUTS ----
         -----------------
-- Peformance monitoring
idle_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
mult_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
         filter_indices_stored : out STD_LOGIC;
         filter_values_stored  : out STD_LOGIC;
         -- ** Reads while convolving **
         -- Indices
         activation_indices_request       : out STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
         activation_indices_request_valid : out STD_LOGIC;
         -- Values
         activation_value_requests_bank_no : out tp_request_set;
         activation_value_request_valid   : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
         activation_value_bank    : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
         activation_value_address : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
         -- ** Writings while convoluting **
         new_value                    : out STD_LOGIC;
         new_activation_value         : out STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
         new_activation_value_element_no : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
--         new_activation_value_address : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH) - 1 downto 0);
--         new_activation_value_bank    : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
         -- Current filter convoluted
         convolution_done : out STD_LOGIC
    );
end processing_unit;  
           
architecture processing_unit_arch of processing_unit is
    component filter_manager
        generic(max_elements : positive := MAX_FILTER_ELEMENTS;
                bank_depth : positive := 2;
                mem_width  : positive := AXIS_BUS_WIDTH;
                data_width : positive := FILTER_VALUE_WIDTH);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- Filter indices from the DDR through the AXIS interface
             store_filter : in STD_LOGIC;
             new_data     : in STD_LOGIC;         
             filter_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
             -- Reads
             read_element_no : in STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             filter_stored : out STD_LOGIC;
             filters_no    : out STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);         
             filter_height : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
             filter_width  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
             filter_depth  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
             filter_output : out STD_LOGIC_VECTOR(data_width - 1 downto 0)
        );
    end component;
    
    component pair_selector
        generic(unit_no : natural := 0);
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             activation_value_element_no : in tp_match_buffer_activation;
             filter_value_element_no     : in tp_match_buffer_filter;
             request_served : in STD_LOGIC;
             request_no     : in STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             bank_no : out tp_request_set;
             -- Addresses of the request selected
             activation_value_bank    : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
             activation_value_address : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
             filter_value_element     : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
             -- One-hot encoded request served
             pair_taken : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0)
        );
    end component;
    
    component pairing_unit
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             start_convolution : in STD_LOGIC;
             -- Convolution dimensions
             activation_height          : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
             activation_width           : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
             activation_x_z_slice_size  : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);
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
    end component;
    
    component MAC_processor
        port (----------------
              ---- INPUTS ----
              ----------------              
              clk : in STD_LOGIC;
              rst : in STD_LOGIC;
              -- DSP operation
              enable : in STD_LOGIC;
              flush  : in STD_LOGIC;
              -- Operands
              filter_value     : in STD_LOGIC_VECTOR(FILTER_VALUE_WIDTH - 1 downto 0);
              activation_value : in STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
              -----------------
              ---- OUTPUTS ----
              -----------------
              enqueue_value : out STD_LOGIC;
              output        : out STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0)
        );
    end component;
    
    component MAC_output_buffer
        generic(queue_depth : positive := 2);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- Queue operations
             enqueue_value   : in STD_LOGIC;
             enqueue_address : in STD_LOGIC;
             dequeue : in STD_LOGIC;
             -- Queue data
             value_in   : in STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
             address_in : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             value_queue_full  : out STD_LOGIC;
             value_queue_empty : out STD_LOGIC;
             address_queue_empty : out STD_LOGIC;
             value_out   : out STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
             address_out : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0)
        );
    end component;
    
    component processing_unit_controller
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             start_convolution : in STD_LOGIC;
             new_MAC  : in STD_LOGIC;
             convolution_step_done : in STD_LOGIC;
             convolution_done      : in STD_LOGIC;
             MAC_buffer_empty : in STD_LOGIC;
             MAC_buffer_full  : in STD_LOGIC;  -- TO DO: stop pipeline when MAC_buffer_full and a new value is generated
             -----------------
             ---- OUTPUTS ----
             -----------------
-- Peformance monitoring
idle_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
mult_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
             MAC_enable : out STD_LOGIC;
             MAC_flush  : out STD_LOGIC;
             enqueue_address : out STD_LOGIC;
             done : out STD_LOGIC
        );
    end component;
    
    component pipeline
        generic(unit_no : natural := 0);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;        
             new_product           : in STD_LOGIC;
             write_address         : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
             convolution_step_done : in STD_LOGIC;
             convolution_done      : in STD_LOGIC;
             -----------------
             ---- OUTPUTS ----
             -----------------
             new_product_pipelined           : out STD_LOGIC;
             write_address_pipelined         : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
             convolution_step_done_pipelined : out STD_LOGIC;
             convolution_done_pipelined      : out STD_LOGIC
        );
    end component;
    
    -- Filter values manager
    signal filter_value_element_no : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    signal filter_value : STD_LOGIC_VECTOR(FILTER_VALUE_WIDTH - 1 downto 0);
    signal filters_no    : STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
    signal filter_height : STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
    signal filter_width  : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
    signal filter_depth  : STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
    signal pair_taken_position : STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    
    -- Filter indices manager    
    signal filter_indices_element_no : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_INDICES_WIDTH) - 1 downto 0);
    signal filter_indices : STD_LOGIC_VECTOR(FILTER_INDICES_WIDTH - 1 downto 0);
    
    -- Pairing
    signal filter_value_addresses     : tp_match_buffer_filter;
    signal activation_value_addresses : tp_match_buffer_activation;
    signal activation_indices_element_no : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal pair_taken: STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    signal new_activation_value_position : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    signal convolution_step_done: STD_LOGIC;
    signal convolution_done_int: STD_LOGIC;
    
    -- MAC_processor
    signal MAC_enable, MAC_flush : STD_LOGIC;    
    signal MAC_output : STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
    
    -- MAC output buffer
    signal enqueue_value, enqueue_address : STD_LOGIC;
    signal value_queue_full, value_queue_empty : STD_LOGIC;
    signal address_queue_empty : STD_LOGIC;
    signal MAC_buffer_address_out : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    
    -- Controller
    signal start_kernel_convolution: STD_LOGIC;
    signal new_section: STD_LOGIC;
    
    -- Pipeline
    signal new_product_pipelined           : STD_LOGIC;
    signal write_address_pipelined         : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    signal convolution_step_done_pipelined : STD_LOGIC;
    signal convolution_done_pipelined      : STD_LOGIC;
begin
    -- Filters manager
    filter_values_manager_I: filter_manager
        generic map(max_elements => MAX_FILTER_ELEMENTS,
                    bank_depth => FILTER_VALUES_BRAMS_PER_BANK,
                    mem_width  => AXIS_BUS_WIDTH,
                    data_width => FILTER_VALUE_WIDTH)                    
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Filter indices from the DDR through the AXIS interface
                 store_filter => store_filter_values,
                 new_data     => new_data,
                 filter_input => filter_input,
                 -- Reads
                 read_element_no => filter_value_element_no,  --filter_value_address,
                 ---- OUTPUTS ----
                 filter_stored => filter_values_stored,
                 filters_no    => filters_no,
                 filter_height => filter_height,
                 filter_width  => filter_width,
                 filter_depth  => filter_depth,
                 filter_output => filter_value
        );    
        
    filter_indices_manager_I: filter_manager
        generic map(max_elements => MAX_FILTER_ELEMENTS / FILTER_INDICES_WIDTH,
                    bank_depth => FILTER_INDICES_BRAMS_PER_BANK,
                    mem_width  => AXIS_BUS_WIDTH,
                    data_width => FILTER_INDICES_WIDTH)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Filter indices from the DDR through the AXIS interface
                 store_filter => store_filter_indices,
                 new_data     => new_data,
                 filter_input => filter_input,
                 -- Reads
                 read_element_no => filter_indices_element_no,
                 ---- OUTPUTS ----
                 filter_stored => filter_indices_stored,
                 filters_no    => open,
                 filter_height => open,
                 filter_width  => open,
                 filter_depth  => open,
                 filter_output => filter_indices
        );
    
    pairing_unit_I: pairing_unit
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 -- Convolution dimensions
                 activation_height         => activation_height,
                 activation_width          => activation_width,
                 activation_x_z_slice_size => activation_x_z_slice_size,
                 filter_height     => filter_height,
                 filter_width      => filter_width,
                 filter_depth      => filter_depth,
                 filter_no => (others => '0'),  --filter_no,
                 filters_no => filters_no,
                 -- Indices
                 indices_granted => activation_indices_granted,
                 indices_served     => activation_indices_served,
                 filter_indices     => filter_indices,
                 activation_indices => activation_indices,
                 -- Pairs buffer
                 pair_taken => pair_taken,
                 ---- OUTPUTS ----
                 -- Indices
                 request_indices            => activation_indices_request_valid,
                 activation_indices_address => activation_indices_element_no,
                 filter_indices_address     => filter_indices_element_no,
                 -- Pairs buffer
                 pairs_available      => activation_value_request_valid,
                 filter_addresses     => filter_value_addresses,
                 activation_addresses => activation_value_addresses,
                 -- Element position in the new activation
                 new_activation_value_address => new_activation_value_position,
                 convolution_step_done => convolution_step_done,
                 convolution_done      => convolution_done_int
        );
    
    pair_selector_I: pair_selector generic map(unit_no => unit_no)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 activation_value_element_no => activation_value_addresses,
                 filter_value_element_no     => filter_value_addresses,   
                 request_served => request_served,
                 request_no     => request_no,
                 ---- OUTPUTS ----
                 bank_no => activation_value_requests_bank_no,
                 -- Address of the request selected
                 activation_value_bank    => activation_value_bank,
                 activation_value_address => activation_value_address,
                 filter_value_element     => filter_value_element_no,    --filter_value_address,                     
                 -- One-hot encoded request served
                 pair_taken => pair_taken
        );
    
    MAC_processor_I: MAC_processor
        port map(---- INPUTS ----           
                 clk => clk,
                 rst => rst,
                 -- DSP operation
                 enable => MAC_enable,
                 flush  => MAC_flush,
                 -- Operands
                 filter_value     => filter_value,
                 activation_value => activation_value,
                 ---- OUTPUTS ----
                 enqueue_value => enqueue_value,
                 output => MAC_output
        );
    
    MAC_output_buffer_I: MAC_output_buffer generic map(queue_depth => 2)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Queue operations
                 enqueue_value   => enqueue_value,
                 enqueue_address => enqueue_address,
                 dequeue         => new_activation_value_written,
                 -- Queue data
                 value_in   => MAC_output,
                 address_in => write_address_pipelined,
                 ---- OUTPUTS ----
                 value_queue_full  => value_queue_full,
                 value_queue_empty => value_queue_empty,
                 address_queue_empty => address_queue_empty,
                 value_out   => new_activation_value,
                 address_out => MAC_buffer_address_out
        );
    
    new_value <= NOT(value_queue_empty);    
    new_activation_value_element_no <= MAC_buffer_address_out;

    controller: processing_unit_controller
        port map(---- INPUTS ---- 
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 new_MAC => new_product_pipelined,
                 convolution_step_done => convolution_step_done_pipelined,
                 convolution_done      => convolution_done_pipelined,
                 MAC_buffer_empty => address_queue_empty,
                 MAC_buffer_full  => value_queue_full,  -- TO DO: stop pipeline when MAC_buffer_full and a new value is generated
                 ---- OUTPUTS ----
-- Peformance monitoring
idle_count => idle_count,
mult_count => mult_count,
                 MAC_enable => MAC_enable,
                 MAC_flush  => MAC_flush,
                 enqueue_address => enqueue_address,
                 done => convolution_done
        );
    
    pipeline_I: pipeline generic map(unit_no => unit_no)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 new_product           => request_served,
                 write_address         => new_activation_value_position,
                 convolution_step_done => convolution_step_done,
                 convolution_done      => convolution_done_int,
                 ---- OUTPUTS ----
                 new_product_pipelined           => new_product_pipelined,
                 write_address_pipelined         => write_address_pipelined,
                 convolution_step_done_pipelined => convolution_step_done_pipelined,
                 convolution_done_pipelined      => convolution_done_pipelined
        );
    
    -- Outputs
    --activation_indices_request <= activation_indices_element_no(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
    activation_indices_request <= resize(activation_indices_element_no, log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS));
end processing_unit_arch;
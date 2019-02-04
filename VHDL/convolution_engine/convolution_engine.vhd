library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity convolution_engine is	
    port(----------------
         ---- INPUTS ----
         ----------------
         clk, rst : in STD_LOGIC;
         -- Data input from DDR
         new_data   : in STD_LOGIC;          
         data_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
DEBUG_read_mem      : in STD_LOGIC;
DEBUG_address_read  : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
POWER_iterations : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
idle_count_reg : out tp_performance_count;
mult_count_reg : out tp_performance_count;
DEBUG_first_done : out STD_LOGIC;
DEBUG_transfers_no : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0);
         led : out STD_LOGIC_VECTOR(8 - 1 downto 0);
         -- All the iterations done
         done : out STD_LOGIC;         
         conv_output : out STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0)
	);
end convolution_engine;

architecture convolution_engine_arch of convolution_engine is    
    ------------------------
    -- Activation indices --
    ------------------------
    component activation_indices_manager
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- Image from the DDR through the AXIS interface
             store_image : in STD_LOGIC;
             new_data    : in STD_LOGIC;         
             image_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
             -- Activation values from the MACs
             write_element         : in STD_LOGIC;
             element_address_write : in STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) - 1 downto 0);
             activation_input      : in STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
             -- Reads
             addresses_read : in tp_activation_indices_requests_served;
             layer : in STD_LOGIC;
             retrieve_activation : in STD_LOGIC;
             -----------------
             ---- OUTPUTS ----
             -----------------
DEBUG_transfers_no : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0);
             image_stored : out STD_LOGIC;
             activation_output : out tp_activation_indices_mem_output
        );
    end component;
    
    component activation_indices_arbiter
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             requests		: in tp_activation_indices_requests;
             requests_valid : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- PUs that were granted
             granted : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             served  : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             -- PU assigned to each bank
             PUs_granted : out tp_activation_indices_PUs_served
        );
    end component;
    
    component activation_indices_read_crossbar
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- From activation indices read arbiter : PU assigned to each bank
             PUs_granted           : in tp_activation_indices_PUs_served;
             -- From proccesing units
             PU_requests_addresses : in tp_activation_indices_requests;
             -- Indices from the activation indices manager
             activation_indices : in tp_activation_indices_mem_output;
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- Requests addresses to the activation indices manager
             activation_mem_indices_addresses : out tp_activation_indices_requests_served;
             -- Indices read to the PUs
             activation_indices_read : out tp_activation_indices_read
        );
    end component;
    
    -----------------------
    -- Activation values --
    -----------------------
    component activation_values_manager
        generic(banks      : positive := ACTIVATION_VALUES_BANKS;
                bank_depth : positive := ACTIVATION_VALUES_BRAMS_PER_BANK;
                data_width : positive := ACTIVATION_VALUE_WIDTH);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- Image from the DDR through the AXIS interface
             store_image : in STD_LOGIC;
             new_data    : in STD_LOGIC;         
             image_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
             -- Activation values from the MACs
             write_value      : in STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
             address_write    : in tp_activation_value_mem_address;
             activation_input : in tp_activation_value_mem_data;
             -- Reads
             address_read : in tp_activation_value_mem_address;
             layer : in STD_LOGIC;
             retrieve_activation : in STD_LOGIC;
address_retrieve : in STD_LOGIC_VECTOR(32 - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             image_stored : out STD_LOGIC;
             -- Activation dimensions
             activation_height         : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
             activation_width          : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH)  - 1 downto 0);
             activation_x_z_slice_size : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);
             -- Activation values
             activation_output : out tp_activation_value_mem_data
        );
    end component;
    
    component activation_values_read_arbiter
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             requests		: in tp_request_array;
             requests_valid : in tp_request_valid_array;
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- To pairing
             request_served_to_pairing : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             request_to_pairing		   : out tp_bank_requests_selected;
             -- To data fetcher
             request_served : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             request		: out tp_bank_requests_selected
        );
    end component;
    
    component activation_values_write_arbiter
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             requests		: in tp_activation_value_bank_requests;
             requests_valid : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- Request that could be served         
             served : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0)
        );
    end component;
    
    component activation_values_write_crossbar
        port(----------------
             ---- INPUTS ----
             ----------------
             -- From activation values write arbiter         
             bank_requests_served : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             -- From proccesing units
             bank_requests           : in tp_activation_value_bank_requests;
             bank_requests_addresses : in tp_new_activation_value_address_requests;
             requests_values         : in tp_new_activation_value_requests;
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- To activation manager
             activation_mem_write     : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
             activation_mem_addresses : out tp_activation_value_mem_address;
             activation_mem_values    : out tp_activation_value_mem_data
        );
    end component;
    
    ----------------------
    -- Processing units --
    ----------------------
    component processing_unit
        generic(unit_no : natural := 0;
                bank_depth : positive :=  8;
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
             -- Pair taken by the activation data arbiter
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
             -- ** Reads while convoluting **
             -- Indices
             activation_indices_request       : out STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
             activation_indices_request_valid : out STD_LOGIC;
             -- Values
             activation_value_requests_bank_no : out tp_request_set;
             activation_value_request_valid    : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
             activation_value_bank    : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
             activation_value_address : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);         
             -- ** Writings while convoluting **
             new_value                    : out STD_LOGIC;
             new_activation_value         : out STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
             new_activation_value_element_no : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
--             new_activation_value_address : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH) - 1 downto 0);
--             new_activation_value_bank    : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
             -- Current filter convoluted
             convolution_done : out STD_LOGIC
        );
    end component;
    
    ------------------
    -- Data fetcher --
    ------------------    
    component data_fetcher
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- From activation values read arbiter
             bank_request           : in tp_activation_value_bank_requests;
             bank_request_served    : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             bank_request_addresses : in tp_addresses_selected;
             -- From activation manager
             activation_values : in tp_activation_value_mem_data;
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- To activation memory: addresses
             activation_mem_addresses : out tp_activation_value_mem_address;
             -- To MACs: activation operand
             MAC_activation_values : out tp_MACs_activation_input
        );
    end component;
	
	------------------
    -- Control unit --
    ------------------
    component convolution_engine_controller is	
        port(----------------
             ---- INPUTS ----
             ----------------
             clk, rst : in STD_LOGIC;
             -- Data input from DDR
             new_data   : in STD_LOGIC;          
             data_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
             -- From processing units
             convolution_done : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             -- From memory managers
             image_indices_stored   : in STD_LOGIC;
             image_values_stored    : in STD_LOGIC;
             filter_indices_stored : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             filter_values_stored  : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    -- Power measurement
    iterations : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);         
             -----------------
             ---- OUTPUTS ----
             -----------------
    led : out STD_LOGIC_VECTOR(8 - 1 downto 0);
             -- To memory managers
             store_image_indices   : out STD_LOGIC;
             store_image_values    : out STD_LOGIC;
             store_filter_indices : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             store_filter_values  : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             done : out STD_LOGIC;
             -- To processing units
             compute_convolution : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0)
        );
    end component;
    
    component reg
		generic(bits       : positive := 128;
                init_value : natural := 0);
		port (----------------
			  ---- INPUTS ----
			  ----------------
              clk : in std_logic;
              rst : in std_logic;
              ld  : in std_logic;
              din : in std_logic_vector(bits - 1 downto 0);
              -----------------
              ---- OUTPUTS ----
              -----------------
              dout : out std_logic_vector(bits - 1 downto 0)
		);
	end component;
    
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
    
        
    signal layer: STD_LOGIC;    -- TEMP
    
    ------------------------
    -- Activation indices --
    ------------------------
    -- Memory
    signal retrieve_activation_indices : STD_LOGIC;
    signal image_indices_stored : STD_LOGIC;
    signal activation_indices_read_addresses : tp_activation_indices_requests_served;
    signal activation_indices : tp_activation_indices_mem_output;
    
    -- Read arbiter
    signal activation_indices_requests      : tp_activation_indices_requests;
    signal activation_indices_requests_valid : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal activation_indices_read_request_granted  : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal activation_indices_read_request_served   : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal activation_indices_read_addresses_served : tp_activation_indices_PUs_served;
    
    -- PUs-to-mem & mem-to-PUs crossbars
    signal activation_indices_read : tp_activation_indices_read;
    
    -----------------------
    -- Activation values --
    -----------------------
    -- Memory
    signal image_values_stored : STD_LOGIC;
    signal write_activation_value: STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
    signal activation_value_addresses_write : tp_activation_value_mem_address;
    signal activation_value_addresses_read : tp_activation_value_mem_address;
    signal retrieve_activation_values : STD_LOGIC;
    signal activation_height         : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
    signal activation_width          : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH)  - 1 downto 0);
    signal activation_x_z_slice_size : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);    
    signal activation_values : tp_activation_value_mem_data;
    signal new_activation_values : tp_activation_value_mem_data;    

    -- Read arbiter
	signal activation_value_read_requests       : tp_request_array;
    signal activation_value_read_requests_valid : tp_request_valid_array;
    signal activation_value_read_request_served : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal activation_value_read_request		: tp_bank_requests_selected;
    signal activation_value_read_request_served_to_pairing  : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal activation_value_read_request_to_pairing         : tp_bank_requests_selected;
    
    -- Write arbiter
    signal new_activation_value_address : tp_new_activation_value_address_requests;
signal new_activation_value_address_TEMP : tp_new_activation_value_address_requests;
    signal new_activation_value_addresses_selected : tp_activation_value_mem_address;
    signal new_activation_value_bank_selected : STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
    signal new_activation_value_write_request : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal new_activation_value_values_selected : tp_activation_value_mem_data;
    signal new_activation_value_served : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);    
    
    -- Writtings crossbar
    signal activation_mem_write : STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);    
    
    ---------------------
    -- Processing unit --
    ---------------------
    signal filter_indices_stored : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal filter_values_stored  : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal activation_value_bank    : tp_activation_value_bank_requests;
    signal activation_value_address : tp_addresses_selected;    
    signal new_activation_value : tp_new_activation_value_requests;
    type tp_activation_value_address_array is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    type tp_activation_value_bank_array is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
    signal new_activation_value_bank : tp_activation_value_bank_requests;
signal new_activation_value_bank_TEMP : tp_activation_value_bank_requests;
signal new_activation_value_element_no : tp_activation_value_elements_no;
signal new_activation_value_local_element_no : tp_activation_value_elements_no;
    signal convolution_done : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    
    ------------------
    -- Data fetcher --
    ------------------
    signal MAC_activation_value : tp_MACs_activation_input;
    
    -----------------------------------
    -- Convolution engine controller --
    -----------------------------------
    signal store_image_indices : STD_LOGIC;
    signal store_image_values  : STD_LOGIC;
    signal store_filter_indices : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal store_filter_values  : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal start_convolution : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal retrieve_activation : STD_LOGIC;

-- Performance monitoring
type tp_state is (IDLE,
                  CONVOLVING,
                  WELL);                  
signal current_state, next_state: tp_state;

signal idle_count : tp_performance_count;
signal mult_count : tp_performance_count;
signal ld_performance : STD_LOGIC;
begin
    layer <= '0';   -- TEMP
    
    ------------------------
    -- Activation indices --
    ------------------------
    -- Memory
    activation_indices_manager_I: activation_indices_manager
        port map(---- INPUTS ---- 
                 clk => clk,
                 rst => rst,
                 -- Image indices from the DDR through the AXIS interface
                 store_image => store_image_indices,
                 new_data    => new_data,
                 image_input => data_input,
                 -- Activation indices from arbiter
                 write_element         => '0',                -- TEMP
                 element_address_write => (others => '0'),    -- TEMP
                 activation_input      => (others => '0'),    -- TEMP
                 -- Reads
                 addresses_read => activation_indices_read_addresses,
                 layer => '0',                           -- TEMP
                 retrieve_activation => '0',             -- TEMP
                 ---- OUTPUTS ----
DEBUG_transfers_no => DEBUG_transfers_no,
                 image_stored => image_indices_stored,
                 activation_output => activation_indices);
   
    -- Arbiter
    activation_indices_arbiter_I: activation_indices_arbiter
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 requests       => activation_indices_requests,
                 requests_valid => activation_indices_requests_valid,
                 ---- OUTPUTS ----
                 -- PUs that were granted
                 granted => activation_indices_read_request_granted,
                 served  => activation_indices_read_request_served,                 
                 -- PU assigned to each bank
                 PUs_granted => activation_indices_read_addresses_served);
    
    -- PUs-to-mem & mem-to-PUs crossbars
    activation_indices_read_crossbar_I: activation_indices_read_crossbar
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- From activation indices read arbiter : PU assigned to each bank
                 PUs_granted => activation_indices_read_addresses_served,
                 -- From proccesing units
                 PU_requests_addresses => activation_indices_requests,
                 -- Indices from the activation indices manager
                 activation_indices => activation_indices,
                 ---- OUTPUTS ----
                 -- Requests addresses to the activation indices manager
                 activation_mem_indices_addresses => activation_indices_read_addresses,
                 -- Indices read to the PUs
                 activation_indices_read => activation_indices_read
        );

    -----------------------
    -- Activation values --
    -----------------------
    -- Memory
    activation_values_manager_I: activation_values_manager
        generic map(banks      => ACTIVATION_VALUES_BANKS,
                    bank_depth => ACTIVATION_VALUES_BRAMS_PER_BANK,
                    data_width => ACTIVATION_VALUE_WIDTH
        )
        port map(---- INPUTS ---- 
                 clk => clk,
                 rst => rst,
                 -- Image from the DDR through the AXIS interface
                 store_image => store_image_values,
                 new_data    => new_data,
                 image_input => data_input,                 
                 -- Activation values from the MACs
                 write_value   => activation_mem_write,
                 address_write => new_activation_value_addresses_selected,
                 activation_input => new_activation_value_values_selected,
                 -- Reads from data fetcher
                 address_read => activation_value_addresses_read,
                 layer => layer,
                 -- TEMP ->
retrieve_activation => DEBUG_read_mem,
address_retrieve    => DEBUG_address_read,
                 ---- OUTPUTS ----
                 image_stored => image_values_stored,
                 -- Activation dimensions
                 activation_height         => activation_height,
                 activation_width          => activation_width,
                 activation_x_z_slice_size => activation_x_z_slice_size,
                 -- Activation values                 
                 activation_output => activation_values
        );
    
    -- Reads arbiter
    activation_values_read_arbiter_I: activation_values_read_arbiter
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 requests       => activation_value_read_requests,
                 requests_valid => activation_value_read_requests_valid,
                 ---- OUTPUTS ----
                 -- To pairing
                 request_served_to_pairing => activation_value_read_request_served_to_pairing,
                 request_to_pairing        => activation_value_read_request_to_pairing,
                 -- To data fetcher & PU controller
                 request_served => activation_value_read_request_served,
                 request        => activation_value_read_request
        );

    -- Writtings arbiter
    activation_values_write_arbiter_I: activation_values_write_arbiter
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 requests		=> new_activation_value_bank_TEMP,
                 requests_valid => new_activation_value_write_request,
                 -----------------
                 ---- OUTPUTS ----
                 -----------------
                 -- Requests that could be served         
                 served  => new_activation_value_served
        );
    
    -- Writtings crossbar
    activation_values_write_crossbar_I: activation_values_write_crossbar
        port map(---- INPUTS ----
                 -- From activation values write arbiter         
                 bank_requests_served => new_activation_value_served,
                 -- From proccesing units
                 bank_requests           => new_activation_value_bank_TEMP,  --new_activation_value_bank,
                 bank_requests_addresses => new_activation_value_address_TEMP,  --bank_requests_addresses => new_activation_value_address_TEMP,
                 requests_values => new_activation_value,
                 ---- OUTPUTS ----
                 -- To activation manager
                 activation_mem_write     => activation_mem_write,
                 activation_mem_addresses => new_activation_value_addresses_selected,
                 activation_mem_values    => new_activation_value_values_selected
        );

    ----------------------
    -- Processing units --
    ----------------------
    processing_units: for i in PROCESSING_UNITS_NO - 1 downto 0 generate        
new_activation_value_element_no(i) <= std_logic_vector(to_unsigned(to_uint(new_activation_value_local_element_no(i)) + i, log_2(MAX_ACTIVATION_ELEMENTS)));
new_activation_value_bank_TEMP(i) <= new_activation_value_element_no(i)(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
new_activation_value_address_TEMP(i) <= new_activation_value_element_no(i)(ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(ACTIVATION_VALUES_BANKS) - 1 downto log_2(ACTIVATION_VALUES_BANKS));        
        processing_unit_I: processing_unit
            generic map(unit_no => i,
                        bank_depth => 2,
                        mem_width  => AXIS_BUS_WIDTH,
                        data_width => ACTIVATION_VALUE_WIDTH
            )
            port map(---- INPUTS ----
                     clk => clk,
                     rst => rst,
                     -- Filter data from the DDR through the AXIS interface
                     store_filter_indices => store_filter_indices(i),
                     store_filter_values  => store_filter_values(i),
                     new_data     => new_data,
                     filter_input => data_input,
                     -- Starts the convolution traversing all the activation
                     start_convolution => start_convolution(i),
                     -- Activation dimensions
                     activation_height         => activation_height,
                     activation_width          => activation_width,
                     activation_x_z_slice_size => activation_x_z_slice_size,                     
                     -- ** Activation data **
                     -- Request granted
                     activation_indices_granted => activation_indices_read_request_granted(i),
                     -- Request data are ready                     
                     activation_indices         => activation_indices_read(i),
                     activation_indices_served  => activation_indices_read_request_served(i),
                     activation_value => MAC_activation_value(i),
                     -- Pair taken by the activation data read arbiter
request_served => activation_value_read_request_served_to_pairing(i),
request_no     => activation_value_read_request_to_pairing(i),
--                     request_served => activation_value_read_request_served(i),
--                     request_no     => activation_value_read_request(i),
                     -- Next layer activation value written
                     new_activation_value_written => new_activation_value_served(i),
                     ---- OUTPUTS ----
-- Peformance monitoring
idle_count => idle_count(i),
mult_count => mult_count(i),
                     filter_indices_stored => filter_indices_stored(i),
                     filter_values_stored  => filter_values_stored(i),                     
                     -- Read requests on activation indices
                     activation_indices_request       => activation_indices_requests(i),
                     activation_indices_request_valid => activation_indices_requests_valid(i),
                     -- Read requests on activation values
                     activation_value_requests_bank_no => activation_value_read_requests(i),        -- To activation value read arbiter
                     activation_value_request_valid    => activation_value_read_requests_valid(i),  -- To activation value read arbiter
                     activation_value_bank    => activation_value_bank(i),
                     activation_value_address => activation_value_address(i),
--                     activation_value_address_serving    => activation_value_address_serving(i),
--                     activation_value_address_requesting => activation_value_address_requesting(i),
                     -- Writings requests on activation values
                     new_value                    => new_activation_value_write_request(i),
                     new_activation_value         => new_activation_value(i),
                     new_activation_value_element_no => new_activation_value_local_element_no(i),
--                     new_activation_value_address => new_activation_value_address(i),
--                     new_activation_value_bank    => new_activation_value_bank(i),
                     -- Current filter convoluted
                     convolution_done => convolution_done(i)
            );
    end generate;
 
    ------------------
    -- Data fetcher --
    ------------------
    data_fetcher_I: data_fetcher
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- From activation values read arbiter
                 bank_request           => activation_value_bank,
                 bank_request_served    => activation_value_read_request_served,
                 bank_request_addresses => activation_value_address,
                 -- From activation manager
                 activation_values => activation_values,
                 ---- OUTPUTS ----
                 -- To activation manager: addresses
                 activation_mem_addresses => activation_value_addresses_read,
                 -- To MACs: operands
                 MAC_activation_values => MAC_activation_value
        );
        
    ------------------
    -- Control unit --
    ------------------
    convolution_engine_controller_I: convolution_engine_controller
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Data input from DDR
                 new_data   => new_data,
                 data_input => data_input,
                 -- From processing units
                 convolution_done => convolution_done,
                 -- From memory managers
                 image_indices_stored => image_indices_stored,
                 image_values_stored  => image_values_stored,
                 filter_indices_stored => filter_indices_stored,
                 filter_values_stored  => filter_values_stored,
-- Power measurement
--iterations => POWER_iterations,
iterations => std_logic_vector(to_unsigned(5000000, AXIS_BUS_WIDTH)),
                 ---- OUTPUTS ----
led => led,
                 -- To memory managers
                 store_image_indices => store_image_indices,
                 store_image_values  => store_image_values,
                 store_filter_indices => store_filter_indices,
                 store_filter_values  => store_filter_values,
                 done => done,
                 -- To processing units
                 compute_convolution => start_convolution
        );

-- Performance monitoring
debug_performance_idle: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
    idle_reg: reg
        generic map(bits => 32,
                    init_value => 0)
        port map(clk, rst, ld_performance, idle_count(i), idle_count_reg(i));
end generate;

debug_performance_mult: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
    mult_reg: reg
        generic map(bits => 32,
                    init_value => 0)
        port map(clk, rst, ld_performance, mult_count(i), mult_count_reg(i));
end generate;

remove_FSM: process(current_state,                                          -- Default
                    start_convolution,                                               -- IDLE
                    convolution_done)
begin        
    next_state <= current_state;
    
    DEBUG_first_done <= '0';
    ld_performance <= '0';
      
    case current_state is
        when IDLE =>
            if start_convolution(0) = '1' then
                next_state <= CONVOLVING;                                
            end if;                                        
        
        when CONVOLVING =>
            if convolution_done /= std_logic_vector(to_unsigned(0, PROCESSING_UNITS_NO)) then
                DEBUG_first_done <= '1';
                ld_performance <= '1';
                
                next_state <= WELL;
            end if;

        when WELL =>
            
    end case;
end process remove_FSM;

states: process(clk)
begin              
    if rising_edge(clk) then
        if rst = '1' then
            current_state <= IDLE;
        else
            current_state <= next_state;
        end if;
    end if;
end process;


-- TEMP
conv_output <= std_logic_vector(to_unsigned(0, AXIS_BUS_WIDTH - ACTIVATION_VALUE_WIDTH)) & activation_values(to_uint(DEBUG_address_read(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0)));
	-- User logic ends
end convolution_engine_arch;

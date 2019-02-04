library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity pair_selector is
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
         -- To activation values read arbiter
         bank_no : out tp_request_set;
         -- Addresses of the request selected
         activation_value_bank    : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
         activation_value_address : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
         filter_value_element     : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
         -- One-hot encoded request served
         pair_taken : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0)
    );
end pair_selector;

architecture pair_selector_arch of pair_selector is    
    component reg
		generic(bits       : positive := 128;
                init_value : natural := 0);
		port(----------------
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
    
    constant BANK_ADDRESS_SIZE   : positive := log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH);
    constant FILTER_ADDRESS_SIZE : positive := log_2(FILTER_VALUES_BRAMS_PER_BANK) + address_width(FILTER_VALUE_WIDTH);
    signal bank_no_int : tp_request_set;
    signal full_activation_value_address : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    signal full_filter_value_address     : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    
    signal activation_value_bank_selected    : STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
    signal activation_value_address_selected : STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
    signal filter_value_element_selected     : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
begin
    ---------------------------------------
    -- To activation values read arbiter --
    ---------------------------------------
    -- Select bank_no from addresses
    requests: for i in PAIRING_BUFFER_DEPTH - 1 downto 0 generate
        -- #bank of each request passed to act value read arbiter in order to select a feasible request
        bank_no_int(i) <= activation_value_element_no(i)(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);        
        bank_no(i)     <= bank_no_int(i);
    end generate;
    
    ----------------------------------
    -- To activation values manager --
    ----------------------------------
    full_activation_value_address <= activation_value_element_no(to_uint(request_no));
    full_filter_value_address     <= filter_value_element_no(to_uint(request_no));
    
    -- Activation & filter address of the request selected
    activation_value_bank_selected    <= bank_no_int(to_uint(request_no));
    activation_value_address_selected <= full_activation_value_address(BANK_ADDRESS_SIZE + log_2(ACTIVATION_VALUES_BANKS) - 1 downto log_2(ACTIVATION_VALUES_BANKS));
    filter_value_element_selected     <= full_filter_value_address;
    
    -- Pipeline
    pipeline_arch: if unit_no /= 0 generate
        type tp_pipeline_info is array(unit_no downto 1) of STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) + ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
        signal pipeline : tp_pipeline_info;
        
        signal pipeline_input : STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) + ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    begin
        pipeline_stages: for i in unit_no downto 1 generate
            first: if i = unit_no generate
                -- Bank no + @act + @filter
                pipeline_info: reg generic map(bits => log_2(ACTIVATION_VALUES_BANKS) + ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS))
                    port map(clk, rst, '1', pipeline_input, pipeline(i));
                
                pipeline_input <= activation_value_bank_selected & activation_value_address_selected & filter_value_element_selected;
            end generate;
            
            remaining: if i /= unit_no generate
                pipeline_info: reg generic map(bits => log_2(ACTIVATION_VALUES_BANKS) + ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS))
                    port map(clk, rst, '1', pipeline(i + 1), pipeline(i));
            end generate;
        end generate;
        
        -- Outputs
        activation_value_bank    <= pipeline(1)(log_2(ACTIVATION_VALUES_BANKS) + ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS) - 1 downto ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS));
        activation_value_address <= pipeline(1)(                                 ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS) - 1 downto                                       log_2(MAX_FILTER_ELEMENTS));
        filter_value_element     <= pipeline(1)(                                                                       log_2(MAX_FILTER_ELEMENTS) - 1 downto                                                                       0);            
    end generate;    
    
    last_stage: if unit_no = 0 generate
        activation_value_bank    <= activation_value_bank_selected;
        activation_value_address <= activation_value_address_selected;
        filter_value_element     <= filter_value_element_selected;
    end generate;

    ----------------
    -- To pairing --
    ----------------
    -- Decoder for the request served
    decoder: for i in PAIRING_BUFFER_DEPTH - 1 downto 0 generate
        pair_taken(i) <= '1' when i = to_uint(request_no) AND request_served = '1' else '0';
    end generate;
end pair_selector_arch;


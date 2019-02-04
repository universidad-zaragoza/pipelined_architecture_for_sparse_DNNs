library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity data_fetcher is	
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
         -- To activation manager: addresses
         activation_mem_addresses : out tp_activation_value_mem_address;
         -- To MACs: activation operand
         MAC_activation_values : out tp_MACs_activation_input
    );
end data_fetcher;

architecture data_fetcher_arch of data_fetcher is
    component request_comparator
        generic (bank_no : integer := 0);
        port(----------------
             ---- INPUTS ----
             ----------------
             bank_requests       : in tp_activation_value_bank_requests;
             bank_request_served : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- Unit that is requesting bank 'bank_no' (one-hot encoded)
             unit_requesting : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0)
        );
    end component;
    
    component encoder
        generic (input_width : natural);
        port(----------------
             ---- INPUTS ----
             ----------------
             input : in STD_LOGIC_VECTOR(input_width - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
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
    
    type tp_unit_requesting_array is array(ACTIVATION_VALUES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0); 
    signal unit_requesting: tp_unit_requesting_array;
    
    type tp_unit_selected_array is array(ACTIVATION_VALUES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0); 
    signal unit_selected: tp_unit_selected_array;
    
    signal bank_request_reg: tp_activation_value_bank_requests;
begin	
    --------------------------------------------
    -- Muxes to address the activation memory --
    --------------------------------------------
    activation_mem_addr_muxes: for i in ACTIVATION_VALUES_BANKS - 1 downto 0 generate
        ------------------
        -- Mux selector --
        ------------------
        -- Request comparators to find which unit is requesting bank 'i'
        comparators: request_comparator generic map(i)
            port map(---- INPUTS ----
                     bank_request,
                     bank_request_served,
                     ---- OUTPUTS ----
                     unit_requesting(i)
            );
        
        -- Binary encoding of the one-hot encoded comparators output 
        encoders: encoder generic map(PROCESSING_UNITS_NO)
            port map(---- INPUTS ----
                     unit_requesting(i),
                     ---- OUTPUTS ----
                     unit_selected(i)
            );
            
        ----------------
        -- Mux inputs --
        ----------------
        activation_mem_addresses(i) <= bank_request_addresses(to_uint(unit_selected(i)));
    end generate;
    
    ----------------------------
    -- Muxes to feed the MACs --
    ----------------------------
    MACs_inputs_muxes: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        -- Mux selector is the bank_no of the request
        bank_no_regs: reg generic map(bits => log_2(ACTIVATION_VALUES_BANKS))
            port map(clk, rst, '1', bank_request(i), bank_request_reg(i));
            
        MAC_activation_values(i) <= activation_values(to_uint(bank_request_reg(i)));
    end generate;
end data_fetcher_arch;
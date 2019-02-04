library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_values_write_crossbar is	
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
end activation_values_write_crossbar;

architecture activation_values_write_crossbar_arch of activation_values_write_crossbar is
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
    
    type tp_unit_requesting_array is array(ACTIVATION_VALUES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0); 
    signal unit_requesting: tp_unit_requesting_array;
    
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
    
    type tp_unit_selected_array is array(ACTIVATION_VALUES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0); 
    signal unit_selected: tp_unit_selected_array;
begin	
    -----------------------------------------------------
    -- Muxes to address and feed the activation memory --
    -----------------------------------------------------
    activation_mem_addr_muxes: for i in ACTIVATION_VALUES_BANKS - 1 downto 0 generate
        ------------------
        -- Mux selector --
        ------------------
        -- Request comparators to find which unit is requesting bank 'i'
        comparators: request_comparator generic map(i)
            port map(---- INPUTS ----
                     bank_requests,
                     bank_requests_served,
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
            
        ------------------
        -- Write enable --
        ------------------
        activation_mem_write(i) <= '1' when unit_requesting(i) /= std_logic_vector(to_unsigned(0, PROCESSING_UNITS_NO)) else '0';
        
        -----------------------
        -- Addres mux inputs --
        -----------------------
        activation_mem_addresses(i) <= bank_requests_addresses(to_uint(unit_selected(i)));
        
        ----------------------
        -- Value mux inputs --
        ----------------------
        activation_mem_values(i) <= requests_values(to_uint(unit_selected(i)));
    end generate;    
end activation_values_write_crossbar_arch;
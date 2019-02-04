library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_indices_manager is
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
end activation_indices_manager;

architecture activation_indices_manager_arch of activation_indices_manager is
    component memory
        generic(banks      : positive := 1;
                bank_depth : positive := 2;
                data_width : positive := 32);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             addresses  : in STD_LOGIC_VECTOR((banks * (log_2(bank_depth) + address_width(data_width))) - 1 downto 0);
             data_input : in STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0);
             we         : in STD_LOGIC_VECTOR(banks - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             data_output : out STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0)
        );
    end component;
    
    component activation_indices_controller
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
             write_element    : in STD_LOGIC;
             write_address    : in STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) - 1 downto 0);
             activation_input : in STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
             -- Reads
             addresses_read : in tp_activation_indices_requests_served;
             layer : in STD_LOGIC;
             -----------------
             ---- OUTPUTS ----
             -----------------
DEBUG_transfers_no : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0);
             address_0 : out STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH)) - 1 downto 0);
             address_1 : out STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH)) - 1 downto 0);
             we_0      : out STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS - 1 downto 0);
             we_1      : out STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS - 1 downto 0);
             mem_input : out STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * ACTIVATION_INDICES_WIDTH - 1 downto 0);
             image_stored : out STD_LOGIC
        );
    end component;    
   
    -- Memories
    signal address_0 : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH)) - 1 downto 0);
    signal address_1 : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH)) - 1 downto 0);
    signal mem_input : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * ACTIVATION_INDICES_WIDTH - 1 downto 0);
    signal we_0 : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS - 1 downto 0);
    signal we_1 : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS - 1 downto 0);
    signal mem_output_0 : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * ACTIVATION_INDICES_WIDTH - 1 downto 0);
    signal mem_output_1 : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS * ACTIVATION_INDICES_WIDTH - 1 downto 0);
begin
    memory_0_I: memory
        generic map(banks      => ACTIVATION_INDICES_BANKS,
                    bank_depth => ACTIVATION_INDICES_BRAMS_PER_BANK,
                    data_width => AXIS_BUS_WIDTH)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 addresses  => address_0,
                 data_input => mem_input,
                 we => we_0,
                 ---- OUTPUTS ----
                 data_output => mem_output_0
        );        
    
    memory_1_I: memory
        generic map(banks      => ACTIVATION_INDICES_BANKS,
                    bank_depth => ACTIVATION_INDICES_BRAMS_PER_BANK,
                    data_width => AXIS_BUS_WIDTH)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 addresses  => address_1,
                 data_input => mem_input,
                 we => we_0,
                 ---- OUTPUTS ----
                 data_output => mem_output_1
        );
    
    activation_indices_controller_I: activation_indices_controller
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Image from the DDR through the AXIS interface
                 store_image => store_image,
                 new_data    => new_data,
                 image_input => image_input,
                 -- Activation values from the MACs
                 write_element => write_element,
                 write_address => element_address_write,
                 activation_input => activation_input,
                 -- Reads
                 addresses_read => addresses_read,
                 layer => layer,
                 ---- OUTPUTS ----
DEBUG_transfers_no => DEBUG_transfers_no,
                 address_0 => address_0,
                 address_1 => address_1,
                 we_0      => we_0,
                 we_1      => we_1,
                 mem_input => mem_input,
                 image_stored => image_stored
        );    

    -------------
    -- Outputs --
    -------------
    -- Type conversion
    output_conv: for i in ACTIVATION_INDICES_BANKS - 1 downto 0 generate
        activation_output(i) <= vector_slice(mem_output_0, i, ACTIVATION_INDICES_WIDTH);        
--        activation_output(i) <= vector_slice(mem_output_0, i, ACTIVATION_VALUE_WIDTH) when (layer = EVEN AND retrieve_activation = '0') OR (layer = ODD AND retrieve_activation = '1') else
--                                vector_slice(mem_output_1, i, ACTIVATION_VALUE_WIDTH);
    end generate;
end activation_indices_manager_arch;
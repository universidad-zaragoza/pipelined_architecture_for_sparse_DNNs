library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_values_manager is
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
end activation_values_manager;

architecture activation_values_manager_arch of activation_values_manager is
    component memory
        generic(banks      : positive := 2;
                bank_depth : positive := 2;
                data_width : positive := 32);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             addresses  : in STD_LOGIC_VECTOR(banks * (log_2(bank_depth) + address_width(data_width)) - 1 downto 0);
             data_input : in STD_LOGIC_VECTOR(banks * data_width - 1 downto 0);
             we         : in STD_LOGIC_VECTOR(banks - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             data_output : out STD_LOGIC_VECTOR(banks * data_width - 1 downto 0)
        );
    end component;
    
    component activation_data_controller
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
             write_element    : in STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
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
             -- Activation dimensions
             activation_height : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
             activation_width  : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
             activation_x_z_slice_size : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) + log_2(MAX_ACTIVATION_DEPTH) - 1 downto 0);
             -- Memory management
             address_0 : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS * (log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH)) - 1 downto 0);
             address_1 : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS * (log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH)) - 1 downto 0);
             we_0      : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
             we_1      : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
             mem_input : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS * ACTIVATION_VALUE_WIDTH - 1 downto 0);
             image_stored : out STD_LOGIC
        );
    end component;
    
    -- Memories
    signal address_0 : STD_LOGIC_VECTOR((banks * (log_2(bank_depth) + address_width(data_width))) - 1 downto 0);
    signal address_1 : STD_LOGIC_VECTOR((banks * (log_2(bank_depth) + address_width(data_width))) - 1 downto 0);
    signal mem_input : STD_LOGIC_VECTOR((banks * ACTIVATION_VALUE_WIDTH) - 1 downto 0);
    signal we_0 : STD_LOGIC_VECTOR(banks - 1 downto 0);
    signal we_1 : STD_LOGIC_VECTOR(banks - 1 downto 0);
    signal mem_output_0 : STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0);
    signal mem_output_1 : STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0);
begin
    memory_0_I: memory
        generic map(banks      => ACTIVATION_VALUES_BANKS,
                    bank_depth => ACTIVATION_VALUES_BRAMS_PER_BANK,
                    data_width => ACTIVATION_VALUE_WIDTH)
        port map(---- INPUTS ----
                 clk,
                 rst,
                 address_0,
                 mem_input,
                 we_0,
                 ---- OUTPUTS ----
                 mem_output_0
        );
    
    memory_1_I: memory
        generic map(banks      => ACTIVATION_VALUES_BANKS,
                    bank_depth => ACTIVATION_VALUES_BRAMS_PER_BANK,
                    data_width => ACTIVATION_VALUE_WIDTH)
        port map(---- INPUTS ----
                 clk,
                 rst,
                 address_1,
                 mem_input,
                 we_1,
                 ---- OUTPUTS ----
                 mem_output_1
        );
    
    activation_data_controller_I: activation_data_controller
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Image from the DDR through the AXIS interface
                 store_image => store_image,
                 new_data    => new_data,
                 image_input => image_input,
                 -- Activation values from the MACs
                 write_element    => write_value,
                 address_write    => address_write,
                 activation_input => activation_input,
                 -- Reads
                 address_read => address_read,
                 layer => layer,
-- Read the memory sequentially to verify results
retrieve_activation => retrieve_activation,
address_retrieve => address_retrieve,
                 ---- OUTPUTS ----
                 -- Activation dimensions
                 activation_height         => activation_height,
                 activation_width          => activation_width,
                 activation_x_z_slice_size => activation_x_z_slice_size,
                 -- Memory management
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
    act_output_conv: for i in ACTIVATION_VALUES_BANKS - 1 downto 0 generate
--activation_output(i) <= vector_slice(mem_output_0, i, ACTIVATION_VALUE_WIDTH);        
--        activation_output(i) <= vector_slice(mem_output_0, i, ACTIVATION_VALUE_WIDTH) when (layer = EVEN AND retrieve_activation = '0') OR (layer = ODD AND retrieve_activation = '1') else
--                                vector_slice(mem_output_1, i, ACTIVATION_VALUE_WIDTH);
    activation_output(i) <= vector_slice(mem_output_0, i, ACTIVATION_VALUE_WIDTH) when retrieve_activation = '0' else
                                vector_slice(mem_output_1, i, ACTIVATION_VALUE_WIDTH);
    end generate;
end activation_values_manager_arch;
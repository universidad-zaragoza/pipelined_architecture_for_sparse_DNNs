library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_data_controller is
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
         activation_height         : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
         activation_width          : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
         activation_x_z_slice_size : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0);    
         -- Memory management
         address_0 : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS * (log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH)) - 1 downto 0);
         address_1 : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS * (log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH)) - 1 downto 0);
         we_0      : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
         we_1      : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
         mem_input : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS * ACTIVATION_VALUE_WIDTH - 1 downto 0);
         image_stored : out STD_LOGIC
    );
end activation_data_controller;

architecture activation_data_controller_arch of activation_data_controller is
	component reg
        generic(bits       : natural := 128;
                init_value : natural := 0);
        port(----------------
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
    
    ------------------------
    -- Activation storage --
    ------------------------
    signal ld_activation_height, ld_activation_width: STD_LOGIC;
    signal ld_activation_x_z_slice_size : STD_LOGIC;
    signal ld_activation_transfers_no : STD_LOGIC;
    
    signal activation_transfers_no : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    
    signal rst_transfers_received, inc_transfers_received: STD_LOGIC;
    signal transfers_received: STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    
    -- FSM
    type tp_address is array(ACTIVATION_VALUES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH) - 1 downto 0);
    signal address_0_int, address_1_int: tp_address;
	type tp_state is (IDLE,
                      STORING_ACTIVATION_HEIGHT,
                      STORING_ACTIVATION_WIDTH,
                      STORING_ACTIVATION_X_Z_SLICE_SIZE,
                      STORING_IMAGE);
    signal current_state, next_state: tp_state; 
begin
    -------------------
	-- Image storing --
	-------------------
    -- Activation dimensions
	activation_height_reg: reg generic map(log_2(MAX_ACTIVATION_HEIGHT), 0)
        port map(clk, rst, ld_activation_height, image_input(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0), activation_height);
	
	activation_width_reg: reg generic map(log_2(MAX_ACTIVATION_WIDTH), 0)
        port map(clk, rst, ld_activation_width, image_input(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0), activation_width);

    activation_x_z_slice_size_reg: reg generic map(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH), 0)
        port map(clk, rst, ld_activation_x_z_slice_size, image_input(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH) - 1 downto 0), activation_x_z_slice_size);
    
	activation_transfers_no_reg: reg generic map(log_2(MAX_ACTIVATION_ELEMENTS), 0)
        port map(clk, rst, ld_activation_transfers_no, image_input(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0), activation_transfers_no);        
        
    -- Activation element received from the PS
    transfers_received_counter: counter
        generic map(log_2(MAX_ACTIVATION_ELEMENTS),
                    1)
        port map(clk, rst, rst_transfers_received, inc_transfers_received, transfers_received);                
    
    -- Activation data memory FSM
    activation_data_mem_FSM: process(current_state, address_read, activation_input,
                                     store_image, layer, write_element, address_write,
                                     new_data, transfers_received, image_input,
retrieve_activation, address_retrieve)
    begin        
        next_state <= current_state;

        ld_activation_height         <= '0';
        ld_activation_width          <= '0';
        ld_activation_x_z_slice_size <= '0';
        ld_activation_transfers_no   <= '0';
        
        rst_transfers_received <= '0';
        inc_transfers_received <= '0';
        
        for i in ACTIVATION_VALUES_BANKS - 1 downto 0 loop
            address_0_int(i) <= address_read(i);
            address_1_int(i) <= address_read(i);
            
            mem_input((i + 1) * ACTIVATION_VALUE_WIDTH - 1 downto i * ACTIVATION_VALUE_WIDTH) <= activation_input(i);
            
            we_0(i) <= '0';
            we_1(i) <= '0';
        end loop;
        
        image_stored <= '0';		  
          
        case current_state is
            when IDLE =>                                    
                if store_image = '1' then
                    ld_activation_transfers_no <= '1';
                    
                    next_state <= STORING_ACTIVATION_HEIGHT;
                elsif retrieve_activation = '1' then
                    for i in ACTIVATION_VALUES_BANKS - 1 downto 0 loop        
                        address_1_int(i) <= address_retrieve(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
                    end loop;    
                -- Even layers write in memory_1                
                elsif layer = EVEN then
                    we_1 <= write_element;
                    
                    -- Switch between read & write addresses
                    for i in ACTIVATION_VALUES_BANKS - 1 downto 0 loop
                        if write_element(i) = '1' then                              
                            address_1_int(i) <= address_write(i);
                        end if;
                    end loop;
                -- Odd layers write in memory_0
                else
                    we_0 <= write_element;
                    
                    -- Switch between read & write addresses
                    for i in ACTIVATION_VALUES_BANKS - 1 downto 0 loop
                        if write_element(i) = '1' then
                            address_0_int(i) <= address_write(i);
                        end if;
                    end loop;
                end if;
           
            when STORING_ACTIVATION_HEIGHT =>
				if new_data = '1' then
					ld_activation_height <= '1';
					
					next_state <= STORING_ACTIVATION_WIDTH;
				end if;
			
			when STORING_ACTIVATION_WIDTH =>
				if new_data = '1' then
					ld_activation_width <= '1';
					
					next_state <= STORING_ACTIVATION_X_Z_SLICE_SIZE;
				end if;
			
			when STORING_ACTIVATION_X_Z_SLICE_SIZE =>
				if new_data = '1' then
					ld_activation_x_z_slice_size <= '1';
					
					next_state <= STORING_IMAGE;
				end if;
            
            
            when STORING_IMAGE =>                    
                if new_data = '1' then
                    -- +++ Consecutive data are stored in consecutive banks +++
                    -- WEs
                    for i in AXIS_BUS_WIDTH / ACTIVATION_VALUE_WIDTH - 1 downto 0 loop
                        we_0(to_uint(transfers_received(log_2(ACTIVATION_VALUES_BANKS / (AXIS_BUS_WIDTH / ACTIVATION_VALUE_WIDTH)) - 1 downto 0) & std_logic_vector(to_unsigned(0, log_2(AXIS_BUS_WIDTH / ACTIVATION_VALUE_WIDTH)))) + i) <= '1';
                    end loop;
                    
                    -- Addresses
                    for i in ACTIVATION_VALUES_BANKS - 1 downto 0 loop
                        address_0_int(i) <= transfers_received(ACTIVATION_VALUES_BANK_ADDRESS_SIZE + log_2(ACTIVATION_VALUES_BANKS) - 1 downto log_2(ACTIVATION_VALUES_BANKS));
                    end loop;
                    
                    -- Data inputs
                    for i in (ACTIVATION_VALUES_BANKS * ACTIVATION_VALUE_WIDTH) / AXIS_BUS_WIDTH - 1 downto 0 loop
                        mem_input(((i + 1) * AXIS_BUS_WIDTH) - 1 downto i * AXIS_BUS_WIDTH) <= image_input;
                    end loop;
                    
                    -- Done
                    if transfers_received = activation_transfers_no then
                        image_stored <= '1';
                        rst_transfers_received <= '1';
                        
                        next_state <= IDLE;
                    else
                        inc_transfers_received <= '1';
                    end if;
                end if;
        end case;
    end process activation_data_mem_FSM;    
    
    process(clk)
    begin              
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= IDLE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;
    
    -------------
    -- Outputs --
    -------------
    outputs: for i in ACTIVATION_VALUES_BANKS - 1 downto 0 generate
        address_0((i + 1) * ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto i * ACTIVATION_VALUES_BANK_ADDRESS_SIZE) <= address_0_int(i);
        address_1((i + 1) * ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto i * ACTIVATION_VALUES_BANK_ADDRESS_SIZE) <= address_1_int(i);
    end generate;
end activation_data_controller_arch;


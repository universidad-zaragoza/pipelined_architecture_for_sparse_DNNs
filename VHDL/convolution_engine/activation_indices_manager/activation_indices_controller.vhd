library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_indices_controller is
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
end activation_indices_controller;

architecture activation_indices_controller_arch of activation_indices_controller is
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
    
    -- component address_translator
        -- generic(max_elements : positive := 1024;
                -- banks      : positive := 1;
                -- bank_depth : positive := 2;
                -- mem_width  : positive := 32;
                -- data_width : positive := 8);
        -- port(----------------
             -- ---- INPUTS ----
             -- ----------------
             -- input_address : in STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
             -- -----------------
             -- ---- OUTPUTS ----
             -- -----------------
             -- output_address : out STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(mem_width) - 1 downto 0);
             -- bank_no        : out STD_LOGIC_VECTOR(log_2(banks) - 1 downto 0) 
        -- );
    -- end component;
    
    
    
    -- Activation storage counter
    signal activation_transfers_no: STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0);
    
    signal rst_transfer_received, inc_transfer_received: STD_LOGIC;
    signal transfer_received: STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0);
    
    -- FSM
    type tp_address is array(ACTIVATION_INDICES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal address_0_int, address_1_int: tp_address;
	type tp_state is (IDLE, STORING_IMAGE_INDICES);
    signal current_state, next_state: tp_state;
begin
DEBUG_transfers_no <= activation_transfers_no;
    ---------------------------
	-- Image indices storage --
	---------------------------
	activation_transfers_no_reg: reg generic map(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH), 0)
        port map(clk, rst, store_image, image_input(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0), activation_transfers_no);
        
    -- Activation indices elements received from the PS
    transfer_received_counter: counter        
        generic map(log_2(MAX_ACTIVATION_ELEMENTS / AXIS_BUS_WIDTH),
                    step => 1)
        port map(clk, rst, rst_transfer_received, inc_transfer_received, transfer_received);
    
    -- ------------------------
	-- -- Address translator --
	-- ------------------------
    -- address_translator_I: address_translator
        -- generic map(max_elements => max_elements,
                    -- banks      => 1,
                    -- bank_depth => bank_depth,
                    -- data_width => data_width)
        -- port map(---- INPUTS ----
                 -- read_element_no,
                 -- ---- OUTPUTS ----
                 -- address_element_no_read,
                 -- open);

    
    -- Activation indices FSM
    activation_indices_FSM: process(current_state, addresses_read, activation_input,                -- Default
                                    store_image, image_input, write_element, layer, write_address,  -- IDLE
                                    new_data, transfer_received)                                    -- STORING_IMAGE_INDICES
    begin        
        next_state <= current_state;

        rst_transfer_received <= '0';
        inc_transfer_received <= '0';

        for i in ACTIVATION_INDICES_BANKS - 1 downto 0 loop
            address_0_int(i) <= addresses_read(i)(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto log_2(ACTIVATION_INDICES_BANKS));
            address_1_int(i) <= addresses_read(i)(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto log_2(ACTIVATION_INDICES_BANKS));
            
            mem_input((i + 1) * ACTIVATION_INDICES_WIDTH - 1 downto i * ACTIVATION_INDICES_WIDTH) <= activation_input;
            
            we_0(i) <= '0';
            we_1(i) <= '0';
        end loop;
        
        image_stored <= '0';		  
          
        case current_state is
            when IDLE =>                                    
                -- Store #transfers
                if store_image = '1' then
                    next_state <= STORING_IMAGE_INDICES;
                end if;
            
            when STORING_IMAGE_INDICES =>                    
                if new_data = '1' then
                    -- +++ Consecutive data are stored in consecutive banks +++
                    we_0(to_uint(transfer_received(log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0))) <= '1';
                    
                    for i in ACTIVATION_INDICES_BANKS - 1 downto 0 loop 
                        address_0_int(i) <= transfer_received(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto log_2(ACTIVATION_INDICES_BANKS));
                        mem_input((i + 1) * ACTIVATION_INDICES_WIDTH - 1 downto i * ACTIVATION_INDICES_WIDTH) <= image_input;
                    end loop;
                    
                    -- Done
                    if transfer_received = activation_transfers_no then
                        image_stored <= '1';
                        rst_transfer_received <= '1';
                        
                        next_state <= IDLE;
                    else
                        inc_transfer_received <= '1';
                    end if;
                end if;
        end case;
    end process activation_indices_FSM;
    
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
    outputs: for i in ACTIVATION_INDICES_BANKS - 1 downto 0 generate
        address_0((i + 1) * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH)) - 1 downto i * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH))) <= address_0_int(i);
        address_1((i + 1) * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH)) - 1 downto i * (log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH))) <= address_1_int(i);
    end generate;
end activation_indices_controller_arch;
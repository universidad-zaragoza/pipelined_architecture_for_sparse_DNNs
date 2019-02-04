library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity filter_controller is
    generic(max_elements : positive := 4096;
            bank_depth : positive := 2;
            data_width : positive := 8;
            mem_width  : positive := 32);
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
         filters_no    : out STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);         
         filter_height : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
         filter_width  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
         filter_depth  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
         address   : out STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(mem_width) - 1 downto 0);
         we        : out STD_LOGIC;
         mem_input : out STD_LOGIC_VECTOR(mem_width - 1 downto 0);
         filter_stored : out STD_LOGIC
    );
end filter_controller;

architecture filter_controller_arch of filter_controller is
    component address_translator
        generic(max_elements : positive := 1024;
                banks      : positive := 1;
                bank_depth : positive := 2;
                mem_width  : positive := 32;
                data_width : positive := 8);
        port(----------------
             ---- INPUTS ----
             ----------------
             input_address : in STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             output_address : out STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(mem_width) - 1 downto 0);
             bank_no        : out STD_LOGIC_VECTOR(log_2(banks) - 1 downto 0) 
        );
    end component;
    
    
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
    
    -- Filter storage counter
    signal rst_element_received, inc_element_received: STD_LOGIC;
    signal element_received: STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(data_width) - 1 downto 0);
    
    -- Filter dimensions
    signal ld_filter_height 	 : STD_LOGIC;
	signal ld_filter_width  	 : STD_LOGIC;
	signal ld_filter_depth		 : STD_LOGIC;
	signal ld_filter_elements_no : STD_LOGIC;
	signal filter_elements_no : STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
    
    -- Address translator
    signal address_element_no_read: STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(mem_width) - 1 downto 0);
    
    -- FSM
	type tp_state is (IDLE,
					  STORING_FILTER_HEIGHT,
					  STORING_FILTER_WIDTH,
					  STORING_FILTER_DEPTH,
					  STORING_FILTERS_ELEMENTS_NO,
					  STORING_FILTER);
    signal current_state, next_state: tp_state;
	
begin
    --------------------
	-- Filter storage --
	--------------------
    -- Filter dimensions
	filter_no_reg: reg generic map(log_2(MAX_FILTERS), 0)
        port map(clk, rst, store_filter, filter_input(log_2(MAX_FILTERS) - 1 downto 0), filters_no);
		
	filter_height_reg: reg generic map(log_2(MAX_FILTER_HEIGHT), 0)
        port map(clk, rst, ld_filter_height, filter_input(log_2(MAX_FILTER_HEIGHT) - 1 downto 0), filter_height);
	
	filter_width_reg: reg generic map(log_2(MAX_FILTER_WIDTH), 0)
        port map(clk, rst, ld_filter_width, filter_input(log_2(MAX_FILTER_WIDTH) - 1 downto 0), filter_width);
	
	filter_depth_reg: reg generic map(log_2(MAX_FILTER_DEPTH), 0)
        port map(clk, rst, ld_filter_depth, filter_input(log_2(MAX_FILTER_DEPTH) - 1 downto 0), filter_depth);
    
	filter_elements_no_reg: reg generic map(log_2(max_elements), 0)
        port map(clk, rst, ld_filter_elements_no, filter_input(log_2(max_elements) - 1 downto 0), filter_elements_no);
		
    -- Filter element received
    element_received_counter: counter
        generic map(log_2(bank_depth) + address_width(data_width),
                    AXIS_BUS_WIDTH / data_width)
        port map(clk, rst, rst_element_received, inc_element_received, element_received);
        
    
    ------------------------
	-- Address translator --
	------------------------
    address_translator_I: address_translator
        generic map(max_elements => max_elements,
                    banks      => 1,
                    bank_depth => bank_depth,
                    data_width => data_width)
        port map(---- INPUTS ----
                 read_element_no,
                 ---- OUTPUTS ----
                 address_element_no_read,
                 open);
    
    
    -------------------------------
    -- Filter indices memory FSM --
    -------------------------------
    filter_data_mem_FSM: process(current_state, address_element_no_read,
                                 new_data, store_filter,
                                 element_received, filter_elements_no)
    begin        
        next_state <= current_state;
		
		ld_filter_height <= '0';
		ld_filter_width <= '0';
		ld_filter_depth <= '0';
		ld_filter_elements_no <= '0';

        rst_element_received <= '0';
        inc_element_received <= '0';
        
        address <= address_element_no_read;
        we <= '0';
        
        filter_stored <= '0';		  
          
        case current_state is
            when IDLE =>                                    
                if store_filter = '1' then
                    next_state <= STORING_FILTER_HEIGHT;
                end if;
			
			when STORING_FILTER_HEIGHT =>
				if new_data = '1' then
					ld_filter_height <= '1';
					
					next_state <= STORING_FILTER_WIDTH;
				end if;
			
			when STORING_FILTER_WIDTH =>
				if new_data = '1' then
					ld_filter_width <= '1';
					
					next_state <= STORING_FILTER_DEPTH;
				end if;
			
			when STORING_FILTER_DEPTH =>
				if new_data = '1' then
					ld_filter_depth <= '1';
					
					next_state <= STORING_FILTERS_ELEMENTS_NO;
				end if;
			
			when STORING_FILTERS_ELEMENTS_NO =>
				if new_data = '1' then
					ld_filter_elements_no <= '1';
					rst_element_received <= '1';
					
					next_state <= STORING_FILTER;
				end if;
				
            when STORING_FILTER =>                    
                if new_data = '1' then
                    we <= '1';                    
                    address <= element_received(log_2(bank_depth) + address_width(data_width) - 1 downto log_2(AXIS_BUS_WIDTH / data_width));
                   
                    -- Done
                    if to_uint(element_received) >= to_uint(filter_elements_no) - AXIS_BUS_WIDTH / data_width then
                        filter_stored <= '1';
                        rst_element_received <= '1';
                        
                        next_state <= IDLE;
                    else
                        inc_element_received <= '1';
                    end if;
                end if;
        end case;
    end process filter_data_mem_FSM;    
    
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
    mem_input <= filter_input;
end filter_controller_arch;
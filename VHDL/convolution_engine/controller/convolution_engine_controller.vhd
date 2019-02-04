library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity convolution_engine_controller is	
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
end convolution_engine_controller;

architecture convolution_engine_controller_arch of convolution_engine_controller is
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
    
    -- Filters setup (#filters so far)
    signal ld_filters_no : STD_LOGIC;
    signal filters_no : STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
    
    -- Filter counter
    signal inc_filter_counter, rst_filter_counter : STD_LOGIC;
    signal filter_count : STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
    
    -- Pipeline counter
    signal rst_PU_pipeline, inc_PU_pipeline : STD_LOGIC;
    signal PU_pipeline : STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0);
    
    -- Convolution engine FSM
    type tp_state is (IDLE,
                      STORING_IMAGE_INDICES,
                      WAITING_FOR_IMAGE_VALUES,
                      STORING_IMAGE_VALUES,
                      WAITING_FOR_FILTER_INDICES,
                      STORING_FILTER_INDICES,
                      WAITING_FOR_FILTER_VALUES,
                      STORING_FILTER_VALUES,
                      INITIALIZING_PIPELINE,
                      COMPUTING_CONVOLUTIONS);
                      
    signal current_state, next_state: tp_state;
    signal ones : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal PU : STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0);

    ------------------------
    -- Power measurements --
    ------------------------
    -- Iterations counter
    signal rst_iterations_counter, inc_iterations_counter : STD_LOGIC;
    signal iterations_count : STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
begin
    -- #Filters
    filters_no_reg: reg generic map(bits => log_2(MAX_FILTERS), init_value => 0)
		port map(clk, rst, ld_filters_no, data_input(log_2(MAX_FILTERS) - 1 downto 0), filters_no);
    
    -- Keeps track of the #filter being stored
    filter_counter: counter generic map(bits => log_2(MAX_FILTERS))
        port map(clk, rst, rst_filter_counter, inc_filter_counter, filter_count);
    
    -- Procesing unit where to store the current filter
    PU <= filter_count(log_2(PROCESSING_UNITS_NO) - 1 downto 0);
    
    -- Initialization of the pipeline of the activation values read arbiter
    pipeline_stage: counter generic map(bits => log_2(PROCESSING_UNITS_NO))
        port map(clk, rst, rst_PU_pipeline, inc_PU_pipeline, PU_pipeline);
    
    -- Convolution engine FSM
    ones <= (others => '1');
    
    ------------------------
    -- Power measurements --
    ------------------------
    -- Iterations counter
    iterations_counter: counter generic map(bits => AXIS_BUS_WIDTH)
        port map(clk, rst, rst_iterations_counter, inc_iterations_counter, iterations_count);
    
    -- Control unit
    convolution_engine_FSM: process(current_state,                                          -- Default
                                    new_data,                                               -- IDLE
                                    image_indices_stored,                                   -- STORING_IMAGE_INDICES                                    
                                    image_values_stored,                                    -- STORING_IMAGE_VALUES
                                    PU,                                                     -- WAITING_FOR_FILTER_INDICES
                                    filter_indices_stored, filter_count, filters_no,        -- STORING_FILTER_INDICES
                                    filter_values_stored, PU_pipeline,                      -- STORING_FILTER_VALUES
                                    convolution_done, ones, iterations_count, iterations)   -- COMPUTING_CONVOLUTIONS
    begin        
        next_state <= current_state;
        
        -- Filters setup
        ld_filters_no <= '0';
        
        -- Filter counter
        inc_filter_counter <= '0';
        rst_filter_counter <= '0';
        
        -- Pipeline counter
        rst_PU_pipeline <= '0';
        inc_PU_pipeline <= '0';
        
        -- Activation storage
        store_image_indices    <= '0';
        store_image_values     <= '0';
        
        -- Filter storage
        store_filter_indices <= (others => '0');
        store_filter_values  <= (others => '0');
        
        compute_convolution <= (others => '0');
        
        done <= '0';
        
        -- Power measurement
        rst_iterations_counter <= '0';
        inc_iterations_counter <= '0';

led <= (others => '0');
		  
        case current_state is
            when IDLE =>
--led(0) <= '1';             
                done <= '1';
                
                if new_data = '1' then
                    store_image_indices <= '1';
                    next_state <= STORING_IMAGE_INDICES;                                
                end if;                                        
                
            ---------------------------------------
            -- Image to process from DDR to BRAM --
            ---------------------------------------
            when STORING_IMAGE_INDICES =>                    
led <= std_logic_vector(to_unsigned(1, 8));                
                if image_indices_stored = '1' then                    
                    next_state <= WAITING_FOR_IMAGE_VALUES;                                
                end if;
            
            when WAITING_FOR_IMAGE_VALUES =>
led <= std_logic_vector(to_unsigned(2, 8));
                if new_data = '1' then
                    store_image_values <= '1';
                    
                    next_state <= STORING_IMAGE_VALUES;                                
                end if;
                
            when STORING_IMAGE_VALUES =>
led <= std_logic_vector(to_unsigned(3, 8));
                if image_values_stored = '1' then                    
                    next_state <= WAITING_FOR_FILTER_INDICES;                                
                end if;
                
            ----------------------------------
            -- Filters set from DDR to BRAM --
            ----------------------------------
            when WAITING_FOR_FILTER_INDICES =>                    
led <= std_logic_vector(to_unsigned(4, 8));
                if new_data = '1' then
                    ld_filters_no <= '1';
                    store_filter_indices(to_uint(PU)) <= '1';                    
                    next_state <= STORING_FILTER_INDICES;                                
                end if;
                
            when STORING_FILTER_INDICES =>
led <= std_logic_vector(to_unsigned(5, 8));
                if filter_indices_stored(to_uint(PU)) = '1' then
                    -- All filter indices stored
                    if to_uint(filter_count) = to_uint(filters_no) - 1 then
                        rst_filter_counter <= '1';                        
                        next_state <= WAITING_FOR_FILTER_VALUES;
                    else
                        inc_filter_counter <= '1';
                        next_state <= WAITING_FOR_FILTER_INDICES;
                    end if;
                end if;
            
            when WAITING_FOR_FILTER_VALUES =>                    
led <= std_logic_vector(to_unsigned(6, 8));                
                if new_data = '1' then
                    store_filter_values(to_uint(PU)) <= '1';                    
                    next_state <= STORING_FILTER_VALUES;
                end if;
            
            when STORING_FILTER_VALUES =>
led <= std_logic_vector(to_unsigned(7, 8));
                if filter_values_stored(to_uint(PU)) = '1' then                    
                    -- All filter values stored
                    if to_uint(filter_count) = to_uint(filters_no) - 1 then
                        rst_filter_counter <= '1'; 

                        compute_convolution((PROCESSING_UNITS_NO - 1) - to_uint(PU_pipeline)) <= '1';
                        if (PROCESSING_UNITS_NO - 1) - to_uint(PU_pipeline) > 0 then
                            inc_PU_pipeline <= '1';
                            
                            next_state <= INITIALIZING_PIPELINE;
                        else
                            next_state <= COMPUTING_CONVOLUTIONS;
                        end if;    
                            
--                        next_state <= COMPUTING_CONVOLUTIONS;
                    else
                        inc_filter_counter <= '1';
                        next_state <= WAITING_FOR_FILTER_VALUES;
                    end if;
                end if;
                    
            ----------------
            -- Processing --
            ----------------
            when INITIALIZING_PIPELINE =>
led <= std_logic_vector(to_unsigned(8, 8));
                compute_convolution((PROCESSING_UNITS_NO - 1) - to_uint(PU_pipeline)) <= '1';
                
                if (PROCESSING_UNITS_NO - 1) - to_uint(PU_pipeline) > 0 then
                    inc_PU_pipeline <= '1';
                else
                    rst_PU_pipeline <= '1';
                    
                    next_state <= COMPUTING_CONVOLUTIONS;
                end if;
                
            when COMPUTING_CONVOLUTIONS =>
led <= std_logic_vector(to_unsigned(9, 8));
--led(1) <= '1';
                if convolution_done = ones AND iterations_count = iterations then
                    rst_iterations_counter <= '1';
                    
                    next_state <= IDLE;
                elsif convolution_done = ones then
                    inc_iterations_counter <= '1';

                    next_state <= INITIALIZING_PIPELINE;
                end if;
        end case;
    end process convolution_engine_FSM;
    

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
end convolution_engine_controller_arch;
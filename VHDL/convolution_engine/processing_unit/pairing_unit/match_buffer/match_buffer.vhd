library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity match_buffer is
    port(----------------
         ---- INPUTS ----
         ----------------
         clk : in std_logic;
         rst : in std_logic;
         -- Pair to buffer
         new_pair_ready         : in STD_LOGIC;
         filter_address         : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
         activation_address     : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
         new_activation_address : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
         last_pair_step         : in STD_LOGIC;
         last_pair              : in STD_LOGIC;
         -- Read from buffer
         pair_taken : in STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         buffer_full  : out STD_LOGIC;         
         pairs : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
         filter_addresses           : out tp_match_buffer_filter;
         activation_addresses       : out tp_match_buffer_activation;
         new_activation_address_out : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
         convolution_step_done : out STD_LOGIC;
         convolution_done      : out STD_LOGIC
    );
end match_buffer;

architecture match_buffer_arch of match_buffer is
    component reg
		generic(bits       : natural := 128;
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
	
	component D_flip_flop
		port (----------------
			  ---- INPUTS ----
			  ----------------
              clk : in std_logic;
              rst : in std_logic;
              ld  : in std_logic;
              din : in std_logic;
              -----------------
              ---- OUTPUTS ----
              -----------------
              dout : out std_logic
		);
	end component;
    
    component priority_enconder
		generic(input_width : natural := 2);
        port(----------------
             ---- INPUTS ----
             ----------------
             input : in STD_LOGIC_VECTOR(input_width - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             found    : out STD_LOGIC;
             position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
        );
	end component;
	
	component match_buffer_controller
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in std_logic;
             rst : in std_logic;
             -- Buffering the last pair
             last_pair_step : in STD_LOGIC;
             last_pair      : in STD_LOGIC;             
             last_taken : in STD_LOGIC;
             -----------------
             ---- OUTPUTS ----
             -----------------
              -- Mixed Convolutions control
			 toggle_input : out STD_LOGIC;
			 toggle_output : out STD_LOGIC;
             convolution_step_done : out STD_LOGIC;
             convolution_done      : out STD_LOGIC
        );
    end component;

   component t_flip_flop is
    	Port ( toggle : in  STD_LOGIC;
           clk : in  STD_LOGIC;
		   reset : in  STD_LOGIC;
           Dout : out  STD_LOGIC);
	end component;    
    -- Buffer
    signal ld_buffer   : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);    
    signal ld_any_buffer : STD_LOGIC;
    
    -- Pairs available
    signal rst_pairs_available : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);    
    signal pairs_available     : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    
    -- Free position selection
    signal pairs_available_masked : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    signal free_position_found, last_taken    : STD_LOGIC;
    signal free_position          : STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
	-- Mixed Convs
	signal input_conv_no, output_conv_no, ld_addr_conv_0, ld_addr_conv_1, prevent_3_convs, ld_prevent_3_convs    : STD_LOGIC;
	signal conv_no : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);	
	signal new_activation_conv_0, new_activation_conv_1: STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
	signal toggle_input, toggle_output, reset_pairs_available_reg, reset_Prevent_3_convs_reg, int_convolution_step_done, int_convolution_done : STD_LOGIC;
	signal valid_pair, valid_pair_masked : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
begin
    ------------
    -- Buffer --
    ------------
    addresses_buffer: for i in PAIRING_BUFFER_DEPTH - 1 downto 0 generate        
        ld_buffer(i) <= '1' when free_position_found = '1' AND new_pair_ready = '1' AND to_uint(free_position) = i AND prevent_3_convs = '0' else '0';
        
       -- Filter address
        filter_buffer: reg generic map(bits => log_2(MAX_FILTER_ELEMENTS))
            port map(clk, rst, ld_buffer(i), filter_address, filter_addresses(i));
        
        -- Activation address
        activation_buffer: reg generic map(bits => log_2(MAX_ACTIVATION_ELEMENTS))
            port map(clk, rst, ld_buffer(i), activation_address, activation_addresses(i));		
		
		-- The buffers support mixing two different convolutions (the one being processed and the next one) This registers indetify if the pair belongs to conv 0 or 1		
		conv_no_reg: D_flip_flop
            port map(clk => clk, rst => rst, ld => ld_buffer(i), din => input_conv_no, dout => conv_no(i));	
    
	 end generate;
    
    -- New activation address (conv 0)
    new_activation_address_conv_0: reg generic map(bits => log_2(MAX_ACTIVATION_ELEMENTS))
        port map(clk, rst, ld_addr_conv_0, new_activation_address, new_activation_conv_0);	
    -- New activation address (conv 1)
    new_activation_address_conv_1: reg generic map(bits => log_2(MAX_ACTIVATION_ELEMENTS))
        port map(clk, rst, ld_addr_conv_1, new_activation_address, new_activation_conv_1);	    
			
    -- Selects between the two possible new_activation addresses
    new_activation_address_out <= new_activation_conv_0 when output_conv_no = '0' else
                                  new_activation_conv_1;
                                  

    ---------------------
    -- Pairs available --
    ---------------------
    pairs_available_ctrl : for i in PAIRING_BUFFER_DEPTH - 1 downto 0 generate
        -- Valid pair indicates that valid information is stored (can be from the current convolution or from the next one)
        pairs_available_reg: D_flip_flop
            port map(clk, rst_pairs_available(i), ld_buffer(i), '1', valid_pair(i));        
        
        rst_pairs_available(i) <= '1' when (rst = '1') OR (pair_taken(i) = '1' AND NOT ld_buffer(i) = '1') else '0';
        
        -- Pair available indicates which pairs store valid data for the convolution being processed
        pairs_available(i) <= '1' when valid_pair(i) = '1' AND conv_no(i) = output_conv_no else '0';
    end generate;
    
    -- Two additional registers identify which one is the current convolution, and if the incoming pairs belong to the current convolution or to the next one
    -- #convolution belongs the pairs received
    t_conv_input_reg: t_flip_flop
        port map(toggle_input, clk, rst, input_conv_no);
           
    -- #convolution under processing
    processing_conv_reg: t_flip_flop
        port map(toggle_output, clk, rst, output_conv_no);
    
    ld_any_buffer <= '1' when ld_buffer /= std_logic_vector(to_unsigned(0, PAIRING_BUFFER_DEPTH)) else '0';
    ld_addr_conv_0 <= '1' when ld_any_buffer = '1' AND input_conv_no = '0' else '0';								
    ld_addr_conv_1 <= '1' when ld_any_buffer = '1' AND input_conv_no = '1' else '0';	
			 
	-- Prevent three convolutions mixed at the same time
    prevent_3_convs <= '1' when input_conv_no /= output_conv_no AND (last_pair = '1' OR last_pair_step = '1') else '0';
    
    
    --------------------------------------------------------
    -- Selection of the free position to store a new pair --
    --------------------------------------------------------    
    -- Mask current pair taken (if exists) in the valid list (used to select a free position)
    valid_pair_mask: for i in PAIRING_BUFFER_DEPTH - 1 downto 0 generate
        valid_pair_masked(i) <= valid_pair(i) AND NOT pair_taken(i);
    end generate;
    
    -- Mask current pair taken (if exists) in the avaliable list (used to identify when the last pair of the current convolution is selected)
    pairs_available_mask: for i in PAIRING_BUFFER_DEPTH - 1 downto 0 generate
        pairs_available_masked(i) <= pairs_available(i) AND NOT(pair_taken(i));
    end generate;
    
    -- Selection
    free_position_selector: priority_enconder generic map(input_width => PAIRING_BUFFER_DEPTH)
        port map (-- INPUTS --
                  input    => NOT(valid_pair_masked),
                  -- OUTPUTS --
                  found    => free_position_found,
                  position => free_position
        );

    match_buffer_controller_I: match_buffer_controller
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Buffering the last pair
                 last_pair_step => last_pair_step,
                 last_pair      => last_pair,                 
                 last_taken => last_taken,                 
                 ---- OUTPUTS ----
                 -- Mixed convolutions control
				 toggle_input  => toggle_input,
				 toggle_output => toggle_output, 
                 convolution_step_done => int_convolution_step_done,
                 convolution_done => int_convolution_done
        );
        
	last_taken <= '1' when pairs_available_masked = std_logic_vector(to_unsigned(0, PAIRING_BUFFER_DEPTH)) else '0';    
    
    -------------
    -- Outputs --
    -------------
    -- Block pipeline whether the match buffer is full or there is risk of mixing three different convolution steps
    --buffer_full <= NOT(free_position_found) OR prevent_3_convs;
buffer_full <= NOT(free_position_found);    
    
    pairs <= pairs_available;    
    convolution_step_done <= int_convolution_step_done;
    convolution_done <= int_convolution_done;
end match_buffer_arch;
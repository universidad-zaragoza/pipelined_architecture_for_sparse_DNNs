library ieee;
use ieee.std_logic_1164.ALL;
use work.types.all;

entity convolution_controller is
    port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         -- Convolution dimensions
         activation_height : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
         activation_width  : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
         filter_height     : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
         filter_width      : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
         filter_depth      : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
         -- New section received
         indices_granted   : in STD_LOGIC;         
         -----------------
         ---- OUTPUTS ----
         -----------------
         filter_inc_x : out STD_LOGIC;
         filter_inc_y : out STD_LOGIC;
         filter_inc_z : out STD_LOGIC;
         activation_inc_x : out STD_LOGIC;
         activation_inc_y : out STD_LOGIC;
         convolution_step_done : out STD_LOGIC;
         convolution_done      : out STD_LOGIC
    );
end convolution_controller;

architecture convolution_controller_arch of convolution_controller is    
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
    
    -- Convolution coordinates    
    signal rst_filter_x, inc_filter_x : STD_LOGIC;
    signal rst_filter_y, inc_filter_y : STD_LOGIC;
    signal rst_filter_z, inc_filter_z : STD_LOGIC;
    signal filter_x_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
    signal filter_y_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
    signal filter_z_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH / FILTER_INDICES_WIDTH) - 1 downto 0);
    
    signal rst_activation_base_x, inc_activation_base_x : STD_LOGIC;
    signal rst_activation_base_y, inc_activation_base_y : STD_LOGIC;
    signal activation_base_x : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
    signal activation_base_y : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
    
    signal activation_x_int : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_HEIGHT) - 1 downto 0);
    signal activation_y_int : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH) - 1 downto 0);
    
    -- Endings
    signal filter_x_done : STD_LOGIC;
    signal filter_y_done : STD_LOGIC;
    signal filter_z_done : STD_LOGIC;
    signal activation_x_done : STD_LOGIC;
    signal activation_y_done : STD_LOGIC;
begin
    -----------------------------
    -- Convolution coordinates --
    -----------------------------
    -- Filter coordinates
    filter_x_I: counter generic map(log_2(MAX_FILTER_HEIGHT), step => 1)
        port map(clk, rst, rst_filter_x, inc_filter_x, filter_x_int);        
    filter_y_I: counter generic map(log_2(MAX_FILTER_WIDTH),  step => 1)
        port map(clk, rst, rst_filter_y, inc_filter_y, filter_y_int);
    filter_z_I: counter generic map(log_2(MAX_FILTER_DEPTH / FILTER_INDICES_WIDTH),  step => 1)
        port map(clk, rst, rst_filter_z, inc_filter_z, filter_z_int);    
    
    -- Activation base coordinates
    activation_base_x_I: counter generic map(log_2(MAX_ACTIVATION_HEIGHT))
        port map(clk, rst, rst_activation_base_x, inc_activation_base_x, activation_base_x);
    activation_base_y_I: counter generic map(log_2(MAX_ACTIVATION_WIDTH))
        port map(clk, rst, rst_activation_base_y, inc_activation_base_y, activation_base_y);
    
    -- Activation coordinates
    activation_x_int <= activation_base_x + filter_x_int;
    activation_y_int <= activation_base_y + filter_y_int;
    
    -- Convolution controller
    filter_z_done <= '1' when filter_z_int = filter_depth(log_2(MAX_FILTER_DEPTH) - 1 downto log_2(FILTER_INDICES_WIDTH)) - 1 else '0';
    filter_x_done <= '1' when filter_x_int = filter_width  else '0';
    filter_y_done <= '1' when filter_y_int = filter_height else '0';
    
    activation_x_done <= '1' when activation_x_int = activation_width  else '0';
    activation_y_done <= '1' when activation_y_int = activation_height else '0';
    
    inc_filter_z <= indices_granted AND NOT filter_z_done;
    inc_filter_x <= indices_granted AND filter_z_done AND NOT filter_x_done;
    inc_filter_y <= indices_granted AND filter_z_done AND filter_x_done AND NOT filter_y_done;
    
    rst_filter_z <= indices_granted AND filter_z_done;
    rst_filter_x <= indices_granted AND filter_z_done AND filter_x_done;
    rst_filter_y <= indices_granted AND filter_z_done AND filter_x_done AND filter_y_done;

    inc_activation_base_x <= indices_granted AND filter_x_done AND filter_y_done AND filter_z_done AND NOT activation_x_done;
    inc_activation_base_y <= indices_granted AND filter_x_done AND filter_y_done AND filter_z_done AND activation_x_done AND NOT activation_y_done;
    
    rst_activation_base_x <= indices_granted AND filter_x_done AND filter_y_done AND filter_z_done AND activation_x_done;
    rst_activation_base_y <= indices_granted AND filter_x_done AND filter_y_done AND filter_z_done AND activation_x_done AND activation_y_done;

    convolution_step_done <= indices_granted AND filter_x_done AND filter_y_done AND filter_z_done;
    convolution_done      <= indices_granted AND filter_x_done AND filter_y_done AND filter_z_done AND activation_x_done AND activation_y_done;
    
    --------------    
    -- Outputs ---
    --------------
    filter_inc_x <= inc_filter_x;
    filter_inc_y <= inc_filter_y;
    filter_inc_z <= inc_filter_z;
    activation_inc_x <= inc_activation_base_x;
    activation_inc_y <= inc_activation_base_y;
end convolution_controller_arch;
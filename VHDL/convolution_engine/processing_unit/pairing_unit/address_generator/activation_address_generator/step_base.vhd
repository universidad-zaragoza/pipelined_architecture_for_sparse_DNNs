library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity step_base is
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution : in STD_LOGIC;
         -- Step when increasing x
         activation_inc_x : in STD_LOGIC;
         filter_depth     : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
         -- Step when increasing y
         activation_inc_y          : in STD_LOGIC;
         activation_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_WIDTH * MAX_ACTIVATION_DEPTH / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         activation_step_base : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0)
    );
end step_base;

architecture step_base_arch of step_base is
    component reg
		generic(bits       : natural := 128;
                init_value : natural := 0);
		port (----------------
			  ---- INPUTS ----
			  ----------------
              clk : in STD_LOGIC;
              rst : in STD_LOGIC;
              ld  : in STD_LOGIC;
              din : in STD_LOGIC_VECTOR(bits - 1 downto 0);
              -----------------
              ---- OUTPUTS ----
              -----------------
              dout : out STD_LOGIC_VECTOR(bits - 1 downto 0)
		);
	end component;
    
    -- Activation step base
    signal step_base_input : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal step_base_int   : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    
    -- Base address when increasing y
    signal step_base_y : STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
begin    
    -- Base address
    step_base_reg: reg generic map(bits => log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH))
        port map(clk, rst OR start_convolution, activation_inc_x OR activation_inc_y, step_base_input, step_base_int);
    
    step_base_input <=  resize(step_base_y + activation_x_z_slice_size, log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH)) when activation_inc_y = '1' else
                        resize(step_base_int + filter_depth, log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH));

    -- Base address when increasing y
    step_base_y_reg: reg generic map(bits => log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH))
        port map(clk, rst OR start_convolution, activation_inc_y, resize(step_base_y + activation_x_z_slice_size, log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH)), step_base_y);

    -------------
    -- Outputs --
    -------------
    activation_step_base <= step_base_int;
end step_base_arch;
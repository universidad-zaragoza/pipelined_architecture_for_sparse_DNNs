library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_values_write_arbiter is
	port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         requests		: in tp_activation_value_bank_requests;
         requests_valid : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- Request that could be served         
         served  : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0)
--         bank    : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
--         address : out STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH) - 1 downto 0)
    );
end activation_values_write_arbiter;

architecture activation_values_write_arbiter_arch of activation_values_write_arbiter is
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
    
	-- Current master counter
    signal rst_current_master : STD_LOGIC;
    signal current_master : STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0);
    
    -- Mask
    signal mask : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal requests_masked : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    
    -- Selector
    signal request_found : STD_LOGIC;
    signal request_to_serve : STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0);
begin
    -----------------------------
    -- Round-robin arbitration --
    -----------------------------
    current_master_I: counter
        generic map(bits => log_2(PROCESSING_UNITS_NO),
                    step => 1)
        port map(clk, rst, rst_current_master, '1', current_master);
    
    rst_current_master <= '1' when to_uint(current_master) = 2**log_2(PROCESSING_UNITS_NO) - 1 else '0';
    
    
    ----------
    -- Mask --
	----------
    mask_below_master: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        mask(i) <= '1' when 2**log_2(PROCESSING_UNITS_NO) - 1 - to_uint(current_master) >= i else '0';
        
        requests_masked(i) <= requests_valid(i) AND mask(i);
    end generate;
    
    --------------
    -- Selector --
    --------------
    request_selector: priority_enconder
		generic map(input_width => PROCESSING_UNITS_NO)
        port map(---- INPUTS ----
                 input => requests_masked,
                 ---- OUTPUTS ----
                 found    => request_found,
                 position => request_to_serve
        );
    
    -------------
    -- Outputs --
    -------------
    -- Processing unit whose request was served
	served_gen: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        served(i) <= '1' when request_found = '1' AND i = to_uint(request_to_serve) else '0';
    end generate;    
    
--    bank    <= requests(to_uint(request_to_serve))(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
--    address <= requests(to_uint(request_to_serve))(log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH) - 1 downto 0);
end activation_values_write_arbiter_arch;
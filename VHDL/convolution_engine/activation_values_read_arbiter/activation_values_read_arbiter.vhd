library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_values_read_arbiter is
	port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         requests		: in tp_request_array;
         requests_valid : in tp_request_valid_array;
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- To pairing
         request_served_to_pairing : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         request_to_pairing		   : out tp_bank_requests_selected;
         -- To data fetcher
         request_served : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         request		: out tp_bank_requests_selected
    );
end activation_values_read_arbiter;

architecture activation_values_read_arbiter_arch of activation_values_read_arbiter is
	component bank_assigner
        port(----------------
			 ---- INPUTS ----
             ----------------
             -- Banks available before the assignation
             free_banks_in : in STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
             -- Requests of the assigned unit
             requests		: in tp_request_set;
             requests_valid : in STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             -- Banks available after the assignation
             free_banks_out : out STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
             -- A request could be served
             request_served : out STD_LOGIC;
             request		: out STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0)
		);
	end component;
    
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

	signal master : STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0);
    
    type tp_free_banks_array is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
    signal free_banks_in, free_banks_out: tp_free_banks_array;
    
    --------------
    -- Pipeline --
    --------------
    -- {unit, stage}
    type tp_request_served_reg is array(PROCESSING_UNITS_NO - 1 downto 0, PROCESSING_UNITS_NO - 1 downto 1) of STD_LOGIC_VECTOR(1 - 1 downto 0);
    signal request_served_reg : tp_request_served_reg;
    
    type tp_request_reg is array(PROCESSING_UNITS_NO - 1 downto 0, PROCESSING_UNITS_NO - 1 downto 1) of STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    signal request_reg : tp_request_reg;
    
    signal free_banks_out_reg: tp_free_banks_array;
    
    signal request_served_int : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal request_int        : tp_bank_requests_selected;
    
    type tp_stage_info is array(PROCESSING_UNITS_NO - 1 downto 1, PROCESSING_UNITS_NO - 1 downto 1) of STD_LOGIC_VECTOR(1 + log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    signal stage_info : tp_stage_info;
begin
    bank_assigner_I: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        first: if i = PROCESSING_UNITS_NO - 1 generate
            free_banks_in(i) <= (others => '1');
        end generate;

        remaining: if i /= PROCESSING_UNITS_NO - 1 generate
            free_banks_in(i) <= free_banks_out_reg(i + 1);
        end generate;
        
        --------------
        -- Pipeline --
        --------------
        free_banks_reg: reg generic map(bits => ACTIVATION_VALUES_BANKS)
            port map(clk, rst, '1', free_banks_out(i), free_banks_out_reg(i));
                
        -- {source_stage, stage}
        stage_regs: for j in i downto 1 generate
            current_unit: if j = i generate
                stage_reg: reg generic map(bits => 1 + log_2(PAIRING_BUFFER_DEPTH))
                    port map(clk, rst, '1', request_served_int(i) & request_int(i), stage_info(i, j));
            end generate;
            
            remaining_units: if j /= i generate
                stage_reg: reg generic map(bits => 1 + log_2(PAIRING_BUFFER_DEPTH))
                    port map(clk, rst, '1', stage_info(i, j + 1), stage_info(i, j));
            end generate;

            request_served_reg(i, j) <= stage_info(i, j)(1 + log_2(PAIRING_BUFFER_DEPTH) - 1 downto log_2(PAIRING_BUFFER_DEPTH));
            request_reg(i, j)        <= stage_info(i, j)(    log_2(PAIRING_BUFFER_DEPTH) - 1 downto                           0);
        end generate;
        
        bank_assigner_I: bank_assigner
            port map(---- INPUTS ----
                     -- Banks available before the assignation
                     free_banks_in(i),
                     -- Requests of the assigned unit
                     requests(i),
                     requests_valid(i),
                     ---- OUTPUTS ----
                     -- Banks available after the assignation
                     free_banks_out(i),
                     -- A request could be served
                     request_served_int(i),
                     request_int(i));
        
        -------------
        -- Outputs --
        -------------
        -- To pairing
        request_served_to_pairing <= request_served_int;
        request_to_pairing        <= request_int;
        
        -- To data fetcher
        request_served(0) <= request_served_int(0);
        request(0)        <= request_int(0);
        
        not_last: if i /= 0 generate
            request_served(i) <= '1' when request_served_reg(i, 1) = "1" else '0';
            request(i)        <= request_reg(i, 1);
        end generate;
    end generate;
end activation_values_read_arbiter_arch;
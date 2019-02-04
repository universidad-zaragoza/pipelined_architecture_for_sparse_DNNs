library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity bank_assigner is
	port(----------------
         ---- INPUTS ----
		 ----------------
		 -- Banks available before the assignation
         free_banks_in : in STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
         -- Unit requests
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
end bank_assigner;

architecture bank_assigner_arch of bank_assigner is
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
    
    -- Request selector
	signal request_served_int : STD_LOGIC;
	signal request_int        : STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    signal request_feasible : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
	
	-- Bank availability updater
	signal mask: STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANKS - 1 downto 0);
begin
	-- Check bank availability for each request
	request_feasibility: for i in PAIRING_BUFFER_DEPTH - 1 downto 0 generate
		request_feasible(i) <= free_banks_in(to_uint(requests(i))) AND requests_valid(i);
	end generate;

	-- Select the first valid request that targets a free bank	
	priority_enconder_I: priority_enconder generic map(PAIRING_BUFFER_DEPTH)
		port map(---- INPUTS ----
				 request_feasible,
				 ---- OUTPUTS ----
				 request_served_int,
				 request_int);
    
	--------------------------------------------------
	-- Update banks available after the assignation --
	--------------------------------------------------	
	mask_I: for i in ACTIVATION_VALUES_BANKS - 1 downto 0 generate
		-- Generate the mask to mark the bank assigned as not available 
		mask(i) <= '0' when i = to_uint(requests(to_uint(request_int))) else '1';
		
		-- New banks availability
        free_banks_out(i) <= free_banks_in(i) AND mask(i) when request_served_int = '1' else
							 free_banks_in(i);
	end generate;
	
	-------------
	-- Outputs --
	-------------
    request_served <= request_served_int;
    request        <= request_int;
end bank_assigner_arch;
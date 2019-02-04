library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity bank_arbiter is
	generic(bank_no : natural := 0);
    port(----------------
         ---- INPUTS ----
         ----------------
         requests		: in tp_activation_indices_requests;
         requests_valid : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- Decoded output
         PU_served  : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         -- Encoded output
         PU_served_no : out STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0)
    );
end bank_arbiter;

architecture bank_arbiter_arch of bank_arbiter is
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
    
	-- PUs requesting this bank
    signal requestors : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    
    -- Selector
    signal served : STD_LOGIC;
    signal PU_no  : STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0);
    
signal served_int : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);    
begin
    -----------------------------
    -- PUs requesting this bank--
	-----------------------------
    PUs_requesting: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        requestors(i) <= '1' when requests_valid(i) = '1' AND to_uint(requests(i)(log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0)) = bank_no else '0';
    end generate;
    
    --------------
    -- Selector --
    --------------
    PU_selector: priority_enconder
		generic map(input_width => PROCESSING_UNITS_NO)
        port map(---- INPUTS ----
                 input => requestors,
                 ---- OUTPUTS ----
                 found    => served,
                 position => PU_no
        );
    
    -------------
    -- Outputs --
    -------------
	PU_served_gen: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        PU_served(i) <= '1' when served = '1' AND to_uint(PU_no) = i else '0';
    end generate;
    
    PU_served_no <= PU_no;
end bank_arbiter_arch;
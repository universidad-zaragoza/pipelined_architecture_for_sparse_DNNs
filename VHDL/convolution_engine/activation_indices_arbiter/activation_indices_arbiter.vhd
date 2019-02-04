library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_indices_arbiter is
	port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         requests		: in tp_activation_indices_requests;
         requests_valid : in STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- PUs that were granted
         granted : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         served  : out STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
         -- PU assigned to each bank
         PUs_granted : out tp_activation_indices_PUs_served
    );
end activation_indices_arbiter;

architecture activation_indices_arbiter_arch of activation_indices_arbiter is
    component bank_arbiter
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
    
	-- Bank arbiters
    type tp_bank_assigner_decoded_PU is array(ACTIVATION_INDICES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);
    signal PU_served : tp_bank_assigner_decoded_PU;
    
    -- PUs granted
    signal granted_int : STD_LOGIC_VECTOR(PROCESSING_UNITS_NO - 1 downto 0);    
begin
    -------------------
    -- Bank arbiters --
    -------------------
    bank_arbiters: for i in ACTIVATION_INDICES_BANKS - 1 downto 0 generate
        bank_arbiter_I: bank_arbiter generic map(bank_no => i)
            port map(---- INPUTS ----
                     requests       => requests,
                     requests_valid => requests_valid,
                     ---- OUTPUTS ----
                     -- Decoded output
                     PU_served    => PU_served(i),
                     -- Encoded output
                     PU_served_no => PUs_granted(i)
            );
    end generate;
    
    ----------------
    -- PUs granted --
    ----------------
    PUs_granted_gen: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        signal check : STD_LOGIC_VECTOR(ACTIVATION_INDICES_BANKS - 1 downto 0);
    begin
        PU_requests: for j in ACTIVATION_INDICES_BANKS - 1 downto 0 generate
            check(j) <= PU_served(j)(i);
        end generate;
        
        granted_int(i) <= '1' when check /= std_logic_vector(to_unsigned(0, ACTIVATION_INDICES_BANKS)) else '0';
    end generate;  
        
    -------------
    -- Outputs --
    -------------
    -- Point out the PU whether was served when the data has been read
    served_reg: reg generic map(bits => PROCESSING_UNITS_NO)
        port map(clk, rst, '1', granted_int, served);

    granted <= granted_int;
end activation_indices_arbiter_arch;
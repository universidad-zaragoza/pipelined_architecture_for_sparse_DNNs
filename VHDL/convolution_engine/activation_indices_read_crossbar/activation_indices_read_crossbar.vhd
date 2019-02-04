library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity activation_indices_read_crossbar is	
	port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         -- From activation indices read arbiter : PU granted by each bank
         PUs_granted           : in tp_activation_indices_PUs_served;
         -- From proccesing units
         PU_requests_addresses : in tp_activation_indices_requests;
         -- Indices from the activation indices manager
         activation_indices : in tp_activation_indices_mem_output;
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- Requests addresses to the activation indices manager
         activation_mem_indices_addresses : out tp_activation_indices_requests_served;
         -- Indices read to the PUs
         activation_indices_read : out tp_activation_indices_read
    );
end activation_indices_read_crossbar;

architecture activation_indices_read_crossbar_arch of activation_indices_read_crossbar is
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
    
    -- Addresses latches
    signal PU_requests_addresses_latched : tp_activation_indices_requests;
begin
    -----------------------------------------------------------------
    -- Muxes to address the banks of the activation indices memory --
    -----------------------------------------------------------------
    activation_indices_mem_addr_muxes: for i in ACTIVATION_INDICES_BANKS - 1 downto 0 generate
        activation_mem_indices_addresses(i) <= PU_requests_addresses(to_uint(PUs_granted(i)));
    end generate;
    
    -- ---------------------------
    -- -- Muxes to feed the PUs --
    -- ---------------------------
    -- PUs_indices_read_muxes: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        -- type tp_PU_bank_requested is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
        -- signal PU_bank_requested : tp_PU_bank_requested;
    -- begin
        -- PU_bank_requested(i) <= PU_requests_addresses(i)(log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0); 
    
        -- activation_indices_read(i) <= activation_indices(to_uint(PU_bank_requested(i)));
    -- end generate;   
    
    ---------------------------
    -- Muxes to feed the PUs --
    ---------------------------
    PUs_indices_read_muxes: for i in PROCESSING_UNITS_NO - 1 downto 0 generate
        type tp_PU_bank_requested is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
        signal PU_bank_requested : tp_PU_bank_requested;
    begin
        -- Latch addresses to correctly select bank when reading
        address_reg: reg generic map(bits => log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS))
            port map(clk, rst, '1', PU_requests_addresses(i), PU_requests_addresses_latched(i));
        
        PU_bank_requested(i) <= PU_requests_addresses_latched(i)(log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0); 
    
        activation_indices_read(i) <= activation_indices(to_uint(PU_bank_requested(i)));
    end generate;
end activation_indices_read_crossbar_arch;
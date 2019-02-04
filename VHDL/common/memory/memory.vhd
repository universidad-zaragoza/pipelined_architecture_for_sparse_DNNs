library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNIMACRO;
use UNIMACRO.vcomponents.all;
use work.types.all;


--  |---------------------------------------------------|
--  |                                                   |
--  |  |------------------|       |------------------|  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |   | BRAM_0_n |   |       |   | BRAM_m_n |   |  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |        .         |       |        .         |  |
--  |  |        .         |       |        .         |  |
--  |  |        .         | . . . |        .         |  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |   | BRAM_0_0 |   |       |   | BRAM_m_0 |   |  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |                  |       |                  |  |
--  |  |      Bank_0      |       |      Bank_m      |  |
--  |  |------------------|       |------------------|  |
--  |                                                   |
--  |                      Memory                       |
--  |                                                   |
--  |---------------------------------------------------|
-- 
-- ++ Asumptions ++
--      - Parallel reads/writes accross banks BUT NOT within banks


entity memory is
    generic(banks      : positive := 2;
            bank_depth : positive := 2;
            data_width : positive := 32);
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         addresses  : in STD_LOGIC_VECTOR(banks * (log_2(bank_depth) + address_width(data_width)) - 1 downto 0);
         data_input : in STD_LOGIC_VECTOR(banks * data_width - 1 downto 0);
         we         : in STD_LOGIC_VECTOR(banks - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         data_output : out STD_LOGIC_VECTOR(banks * data_width - 1 downto 0)
    );
end memory;

architecture memory_arch of memory is
    component blockRAM
        generic (data_width : positive := 8);             
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             address    : in STD_LOGIC_VECTOR(address_width(data_width) - 1 downto 0);
             data_input : in STD_LOGIC_VECTOR(data_width - 1 downto 0);
             we         : in STD_LOGIC;         
             -----------------
             ---- OUTPUTS ----
             -----------------
             data_output : out STD_LOGIC_VECTOR(data_width - 1 downto 0)
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

    -- Input
    type tp_memory_address is array(banks - 1 downto 0) of STD_LOGIC_VECTOR((log_2(bank_depth) + address_width(data_width)) - 1 downto 0);
    signal addresses_array: tp_memory_address;
    type tp_memory_input is array(banks - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal data_input_array: tp_memory_input;
    type tp_memory_output is array(banks - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal data_output_array: tp_memory_output;
    
    -- WEs
    type tp_we is array(banks - 1 downto 0, bank_depth - 1 downto 0) of STD_LOGIC;
    signal we_int: tp_we;
    
    -- BlockRAM input
    type tp_blockRAM_input is array(banks - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal blockRAM_input: tp_blockRAM_input;
    
    -- BlockRAM output
    type tp_blockRAM_output is array(banks - 1 downto 0, bank_depth - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal blockRAM_output: tp_blockRAM_output;
begin
    -- Type conversion
    conv: for i in banks - 1 downto 0 generate
        addresses_array(i)  <= vector_slice(addresses, i, log_2(bank_depth) + address_width(data_width));
        data_input_array(i) <= vector_slice(data_input, i, data_width);
        data_output(((i + 1) * data_width) - 1 downto i * data_width) <= data_output_array(i);
    end generate;   
    
    -- Memory 
    banks_I: for i in banks - 1 downto 0  generate
        type tp_BRAM_no is array(banks - 1 downto 0) of STD_LOGIC_VECTOR(log_2(bank_depth) - 1 downto 0);
        signal BRAM_no, BRAM_no_on_request: tp_BRAM_no;
    begin
        bank_I: for j in bank_depth - 1 downto 0 generate
            BRAM_no(i) <= addresses_array(i)((log_2(bank_depth) + address_width(data_width)) - 1 downto address_width(data_width));
            we_int(i, j) <= '1' when we(i) = '1' AND to_uint(BRAM_no(i)) = j else '0';
            
            blockRAM_I: blockRAM generic map(data_width)
                port map(---- INPUTS ---- 
                         clk,
                         rst,
                         addresses_array(i)(address_width(data_width) - 1 downto 0),
                         data_input_array(i),
                         we_int(i, j),
                         ---- OUTPUTS ----
                         blockRAM_output(i, j)
                );
        end generate;
        
        -- #BRAM latch
        BRAM_no_reg: reg generic map(bits => log_2(bank_depth))
            port map(clk, rst, '1', BRAM_no(i), BRAM_no_on_request(i));
        
        -- Data output mux
        data_output_array(i) <= blockRAM_output(i, to_uint(BRAM_no_on_request(i)));
    end generate;   
end memory_arch;
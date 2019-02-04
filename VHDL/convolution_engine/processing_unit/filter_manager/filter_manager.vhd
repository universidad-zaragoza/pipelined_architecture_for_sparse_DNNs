library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity filter_manager is
    generic(max_elements : positive := MAX_FILTER_ELEMENTS;
            bank_depth : positive := 2;
            mem_width  : positive := AXIS_BUS_WIDTH;
            data_width : positive := FILTER_VALUE_WIDTH);
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         -- Filter indices from the DDR through the AXIS interface
         store_filter : in STD_LOGIC;
         new_data     : in STD_LOGIC;         
         filter_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
         -- Reads
         read_element_no : in STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         filter_stored : out STD_LOGIC;
         filters_no    : out STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);         
         filter_height : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
         filter_width  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
         filter_depth  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
         filter_output : out STD_LOGIC_VECTOR(data_width - 1 downto 0)
    );
end filter_manager;

architecture filter_manager_arch of filter_manager is
    component memory
        generic(banks      : positive := 2;
                bank_depth : positive := 2;
                data_width : positive := 8);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             addresses  : in STD_LOGIC_VECTOR(banks * (log_2(bank_depth) + address_width(data_width)) - 1 downto 0);
             data_input : in STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0);
             we         : in STD_LOGIC_VECTOR(banks - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             data_output : out STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0)
        );
    end component;    
    
    component filter_controller
        generic(max_elements : positive := 4096;
                bank_depth : positive := 2;
                data_width : positive := 8;
                mem_width  : positive := 32);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- Filter from the DDR through the AXIS interface
             store_filter : in STD_LOGIC;
             new_data     : in STD_LOGIC;         
             filter_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
             -- Reads
             read_element_no : in STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             filters_no    : out STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
             filter_height : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
             filter_width  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
             filter_depth  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
             address   : out STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(mem_width) - 1 downto 0);
             we        : out STD_LOGIC;
             mem_input : out STD_LOGIC_VECTOR(mem_width - 1 downto 0);
             filter_stored : out STD_LOGIC
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
    
    -- Memory
    signal mem_address : STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(mem_width) - 1 downto 0);
    signal mem_input : STD_LOGIC_VECTOR(mem_width - 1 downto 0);
    signal mem_we : STD_LOGIC_VECTOR(0 downto 0);
    signal mem_output : STD_LOGIC_VECTOR(mem_width - 1 downto 0);
    
    -- Selector reg
    signal selector : STD_LOGIC_VECTOR(log_2(mem_width / data_width) - 1 downto 0);
    
    -- Controller
    signal we : STD_LOGIC;
begin
    memory_I: memory
        generic map(1,
                    bank_depth,
                    mem_width)
        port map(---- INPUTS ----
                 clk,
                 rst,
                 mem_address,
                 mem_input,
                 mem_we,
                 ---- OUTPUTS ----
                 mem_output
        );
    mem_we <= "0" when we = '0' else "1";

    filter_controller_I: filter_controller
        generic map(max_elements => max_elements,
                    bank_depth => bank_depth,
                    data_width => data_width,
                    mem_width  => mem_width)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 -- Filter from the DDR through the AXIS interface
                 store_filter => store_filter,
                 new_data     => new_data,
                 filter_input => filter_input,
                 -- Reads
                 read_element_no => read_element_no,
                 ---- OUTPUTS ----
                 filters_no    => filters_no,
                 filter_height => filter_height,
                 filter_width  => filter_width,
                 filter_depth  => filter_depth,
                 address   => mem_address,
                 we        => we,
                 mem_input => mem_input,
                 filter_stored => filter_stored
        );

    -------------
    -- Outputs --
    -------------
    selector_reg: reg
		generic map(bits => log_2(mem_width / data_width),
                    init_value => 0)
		port map(clk, rst, '1', read_element_no(log_2(mem_width / data_width) - 1 downto 0), selector);
    
    equal: if mem_width = data_width generate
        filter_output <= mem_output;
    end generate;
    
    not_equal: if mem_width /= data_width generate
        type tp_mem_output is array(mem_width / data_width - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
        signal mem_output_array : tp_mem_output;
    begin
        array_gen: for j in mem_width / data_width - 1 downto 0 generate
            mem_output_array(j) <= vector_slice(mem_output, j, data_width);
        end generate;
        
--        selector <= read_element_no(log_2(mem_width / data_width) - 1 downto 0);
        filter_output <= mem_output_array(mem_width / data_width - 1 - to_uint(selector));
--        filter_output <= mem_output((to_uint(mem_width / data_width - selector + 1) + 1) * data_width - 1 downto to_uint(mem_width / data_width - selector + 1) * data_width);
    end generate;
end filter_manager_arch;
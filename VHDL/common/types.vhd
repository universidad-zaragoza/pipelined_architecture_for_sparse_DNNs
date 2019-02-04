library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";
use ieee.math_real."floor";

package types is
    -- Signals size
    function log_2(n: natural) return natural;
    
    -- Type conversion
    function to_uint(vector: STD_LOGIC_VECTOR) return integer;   
    function vector_slice(vector : STD_LOGIC_VECTOR; element : natural; element_size : positive) return STD_LOGIC_VECTOR;
    
    -- BlockRAMs
    function address_width(data_width: positive) return positive;    
    function we_width(data_width: positive) return positive;
        
    --------------------
    -- Net parameters --
    -------------------- 
    constant DATA_WIDTH : positive := 32;   
    -- Filters
    constant MAX_FILTERS : positive := 2**4;
    constant MAX_FILTER_HEIGHT : positive := 2**4;
    constant MAX_FILTER_WIDTH  : positive := MAX_FILTER_HEIGHT;
    constant MAX_FILTER_DEPTH  : positive := 2**10;
    constant MAX_FILTER_ELEMENTS : positive := 2**11;
    
    -- Activations
    constant MAX_ACTIVATION_HEIGHT : positive := 2**8;
    constant MAX_ACTIVATION_WIDTH  : positive := MAX_ACTIVATION_HEIGHT;
    constant MAX_ACTIVATION_DEPTH  : positive := MAX_FILTER_DEPTH;
    constant MAX_ACTIVATION_ELEMENTS : positive := 2**17;
    
    constant EVEN : STD_LOGIC := '0';
    constant ODD  : STD_LOGIC := '1';
    
    ---------------------
    -- PS/PL Interface --
    ---------------------
    constant AXIS_BUS_WIDTH : positive := 32;    
    
    ----------------------
	-- Processing units --
	----------------------
    constant PROCESSING_UNITS_NO : positive := 8;
    constant ACCUMULATOR_SIZE_FACTOR : positive := 4;

----------------------------
-- Performance monitoring --
----------------------------
type tp_performance_count is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(32 - 1 downto 0);
    
    --------------
    -- Pairing --
    --------------
	constant PAIRING_BUFFER_DEPTH : positive := 4;
    constant SECTION_WIDTH : positive := 32;

    type tp_match_buffer_filter     is array(PAIRING_BUFFER_DEPTH - 1 downto 0) of STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    type tp_match_buffer_activation is array(PAIRING_BUFFER_DEPTH - 1 downto 0) of STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    
    --------------------------------
    -- Activation indices manager --
    --------------------------------    
    constant ACTIVATION_INDICES_WIDTH          : positive := 32;    
    --constant ACTIVATION_INDICES_BANKS          : positive := PROCESSING_UNITS_NO / 4;
    constant ACTIVATION_INDICES_BANKS          : positive := 8;    
    constant ACTIVATION_INDICES_BRAMS_PER_BANK : positive := positive(ceil(real(MAX_ACTIVATION_ELEMENTS) / real(2**address_width(ACTIVATION_INDICES_WIDTH) * ACTIVATION_INDICES_WIDTH * ACTIVATION_INDICES_BANKS)));
    constant MAX_ACTIVATION_INDICES_ELEMENTS   : positive := MAX_ACTIVATION_ELEMENTS / SECTION_WIDTH;

    type tp_activation_indices_requests_served is array(ACTIVATION_INDICES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
    type tp_activation_indices_PUs_served is array(ACTIVATION_INDICES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(PROCESSING_UNITS_NO) - 1 downto 0);
    type tp_PU_requests_addresses is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
    type tp_activation_indices_mem_output is array(ACTIVATION_INDICES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
    type tp_activation_indices_read is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
    type tp_activation_indices_addresses_requests is array(ACTIVATION_INDICES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
    
    -------------------------------
    -- Activation values manager --
    -------------------------------
    constant ACTIVATION_VALUE_WIDTH           : positive := DATA_WIDTH;
    constant ACTIVATION_VALUES_BANKS          : positive := 2 * PROCESSING_UNITS_NO;
    constant ACTIVATION_VALUES_BRAMS_PER_BANK : positive := positive(ceil(real(MAX_ACTIVATION_ELEMENTS / (2**address_width(ACTIVATION_VALUE_WIDTH) * ACTIVATION_VALUES_BANKS))));
    constant ACTIVATION_VALUES_BANK_ADDRESS_SIZE : positive := log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH);    
    
	type tp_activation_value_mem_address is array(ACTIVATION_VALUES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
    type tp_activation_value_mem_data is array(ACTIVATION_VALUES_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
    
    ---------------------------
    -- Filter indices memory --
    ---------------------------
    constant MAX_FILTER_INDICES_ELEMENTS : positive := MAX_FILTER_ELEMENTS / SECTION_WIDTH;
    constant FILTER_INDICES_BRAMS_PER_BANK : positive := 1;  --1;    -- TO AVOID SIM WARNINGS
    constant FILTER_INDICES_WIDTH : positive := AXIS_BUS_WIDTH;
    
    --------------------------
    -- Filter values memory --
    --------------------------    
    constant FILTER_VALUE_WIDTH : positive := ACTIVATION_VALUE_WIDTH;    
    constant FILTER_VALUES_BRAMS_PER_BANK : positive := positive(ceil(real(2 * MAX_FILTER_ELEMENTS) / real(2**address_width(FILTER_VALUE_WIDTH) * 1)));
    
    
    type tp_filter_mem_output is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(FILTER_VALUE_WIDTH - 1 downto 0);
    
    
    
    
type tp_new_activation_value_requests is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);    
--------
-- PU --
--------
type tp_activation_value_elements_no is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
    
    -----------------------------------
	-- Activation value read arbiter --
	-----------------------------------
	type tp_request_set is array(PAIRING_BUFFER_DEPTH - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);	
	type tp_request_array is array(PROCESSING_UNITS_NO - 1 downto 0) of tp_request_set;
	type tp_request_valid_array is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
	type tp_bank_requests_selected is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
	
	------------------------------------
	-- Activation value write arbiter --
	------------------------------------
--	type tp_new_activation_value_address_array is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
    type tp_activation_value_bank_requests is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);
	
	-------------------------------------
	-- Activation indices read arbiter --
	-------------------------------------
    type tp_activation_indices_requests is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_BRAMS_PER_BANK) + address_width(ACTIVATION_INDICES_WIDTH) + log_2(ACTIVATION_INDICES_BANKS) - 1 downto 0);
    
    -------------------------------------
    -- Activation values write arbiter --
    -------------------------------------
    type tp_new_activation_value_address_requests is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BRAMS_PER_BANK) + address_width(ACTIVATION_VALUE_WIDTH) - 1 downto 0);
    
    ------------------
    -- Data fetcher --
    ------------------    
    type tp_bank_selected      is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACTIVATION_VALUES_BANKS) - 1 downto 0);    
    type tp_addresses_selected is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_VALUES_BANK_ADDRESS_SIZE - 1 downto 0);
    
    ----------
    -- MACs --
    ----------
    type tp_MACs_filter_input is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(FILTER_VALUE_WIDTH - 1 downto 0);
    type tp_MACs_activation_input is array(PROCESSING_UNITS_NO - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
    
    -- Resize std_logic_vector
    function resize(v : std_logic_vector; i : integer) return std_logic_vector;
    
    -- Add two std_logic_vector loosing carry
    function add(a, b : std_logic_vector) return std_logic_vector;
    
    -- Add two std_logic_vector adding one bit to output size
    function c_add(a, b : std_logic_vector) return std_logic_vector;
    
    -- Add two std_logic_vector loosing carry
    function "+"(a, b : std_logic_vector) return std_logic_vector;
    
    -- Add std_logic_vector and natural loosing carry
    function "+"(v : std_logic_vector; n : natural) return std_logic_vector;
    
    -- Substract two std_logic_vector
    function "-"(v1, v2 : std_logic_vector) return std_logic_vector;
    
    -- Substract natural from std_logic_vector
    function "-"(v : std_logic_vector; n : natural) return std_logic_vector;
    
    -- Substract std_logic_vector from natural
    function "-"(n : natural; v : std_logic_vector) return std_logic_vector;
    
    -- Multiply two std_logic_vector loosing carry
    function "*"(a, b : std_logic_vector) return std_logic_vector;
    
    -- Divide std_logic_vector by positive
    function "/"(v : std_logic_vector; p : positive) return std_logic_vector;
    
    -- Comparison < for std_logic_vector
    function "<"(v1, v2 : std_logic_vector) return boolean;
    
    -- Comparison <= for std_logic_vector
    function "<="(v1, v2 : std_logic_vector) return boolean;
    
    -- Comparison >= for std_logic_vector
    function ">="(v1, v2 : std_logic_vector) return boolean;
    
    -- Comparison > for std_logic_vector
    function ">"(v1, v2 : std_logic_vector) return boolean;
    
    -- Return std_logic_vector prepared to get the 'range atribute
    -- interpreted as the element of size 'size' in the 'position' position
    function get_range(position, size : natural) return std_logic_vector;
end package;
    
package body types is
    -- Signals size
    function log_2(n: natural) return natural is
    begin
        return integer(ceil(log2(real(n))));
    end function;
    
    -- Type conversion
    function to_uint(vector: STD_LOGIC_VECTOR) return integer is
    begin
        return to_integer(unsigned(vector));
    end function;    
    
    
    function vector_slice(vector : STD_LOGIC_VECTOR; element : natural; element_size : positive) return STD_LOGIC_VECTOR is
    begin
        return vector((element + 1) * element_size - 1 downto element * element_size);
    end function;
    
    --------------
    -- BlockRAM --
    --------------
    ---------------------------------------------------------------------
    --  READ_WIDTH | BRAM_SIZE | READ Depth  | ADDR Width |            --
    -- WRITE_WIDTH |           | WRITE Depth |            |  WE Width  --
    -- ============|===========|=============|============|============--
    --    19-36    |  "18Kb"   |      512    |    9-bit   |    4-bit   --
    --    10-18    |  "18Kb"   |     1024    |   10-bit   |    2-bit   --
    --     5-9     |  "18Kb"   |     2048    |   11-bit   |    1-bit   --
    --     3-4     |  "18Kb"   |     4096    |   12-bit   |    1-bit   --
    --       2     |  "18Kb"   |     8192    |   13-bit   |    1-bit   --
    --       1     |  "18Kb"   |    16384    |   14-bit   |    1-bit   --
    ---------------------------------------------------------------------
    
    function address_width(data_width: positive) return positive is
    begin
        assert data_width >= 1 AND data_width <= 36 report "BlockRAM data width not supported" severity FAILURE;
        
        if    data_width  =  1 then
            return 14;
        elsif data_width  =  2 then
            return 13;
        elsif data_width >=  3 AND data_width <=  4 then
            return 12;
        elsif data_width >=  5 AND data_width <=  9 then
            return 11;
        elsif data_width >= 10 AND data_width <= 18 then
            return 10;
        elsif data_width >= 19 AND data_width <= 36 then
            return  9;
        end if;
    end function;
    
    function we_width(data_width: positive) return positive is
    begin        
        assert data_width >= 1 AND data_width <= 36 report "BlockRAM data width not supported" severity FAILURE;
        
        if    data_width >=  1 AND data_width <=  9 then
            return 1;        
        elsif data_width >= 10 AND data_width <= 18 then
            return 2;
        elsif data_width >= 19 AND data_width <= 36 then
            return 4;
        end if;
    end function;   
    
    -- Resize std_logic_vector
    function resize(v : std_logic_vector;
                    i : integer) return std_logic_vector is
    begin
        return std_logic_vector(resize(unsigned(v), i));
    end function;
    
    -- Add two std_logic_vector loosing carry
    function add(a, b : std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(a) + unsigned(b));
    end function;
    
    -- Add two std_logic_vector adding one bit to output size
    function c_add(a, b : std_logic_vector) return std_logic_vector is
    begin
        if a'length > b'length then
            return std_logic_vector(resize(unsigned(a), a'length + 1)
                    + resize(unsigned(b), a'length + 1));
        else
            return std_logic_vector(resize(unsigned(a), b'length + 1)
                    + resize(unsigned(b), b'length + 1));
        end if;
    end function;
    
    -- Add two std_logic_vector loosing carry
    function "+"(a, b : std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(a) + unsigned(b));
    end function;
    
    -- Add std_logic_vector and natural loosing carry
    function "+"(v : std_logic_vector; n : natural) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(v) + n);
    end function;
    
    -- Substract two std_logic_vector
    function "-"(v1, v2 : std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(v1) - unsigned(v2));
    end function;
    
    -- Substract natural from std_logic_vector
    function "-"(v : std_logic_vector; n : natural) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(v) - n);
    end function;
    
    -- Substract std_logic_vector from natural
    function "-"(n : natural; v : std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(n - unsigned(v));
    end function;
    
    -- Multiply two std_logic_vector loosing carry
    function "*"(a, b : std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(a) * unsigned(b));
    end function;
    
    -- Divide std_logic_vector by positive
    function "/"(v : std_logic_vector; p : positive) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(v) / p);
    end function;
    
    -- Comparison < for std_logic_vector
    function "<"(v1, v2 : std_logic_vector) return boolean is
    begin
        return unsigned(v1) < unsigned(v2);
    end function;
    
    -- Comparison <= for std_logic_vector
    function "<="(v1, v2 : std_logic_vector) return boolean is
    begin
        return unsigned(v1) <= unsigned(v2);
    end function;
    
    -- Comparison >= for std_logic_vector
    function ">="(v1, v2 : std_logic_vector) return boolean is
    begin
        return unsigned(v1) >= unsigned(v2);
    end function;
    
    -- Comparison > for std_logic_vector
    function ">"(v1, v2 : std_logic_vector) return boolean is
    begin
        return unsigned(v1) > unsigned(v2);
    end function;
    
    -- Return std_logic_vector prepared to get the 'range atribute
    -- interpreted as the element of size 'size' in the 'position' position
    function get_range(position, size : natural) return std_logic_vector is
        variable v : std_logic_vector((position * size) + size - 1
                                      downto position * size);
    begin
        return v;
    end function;
end types;
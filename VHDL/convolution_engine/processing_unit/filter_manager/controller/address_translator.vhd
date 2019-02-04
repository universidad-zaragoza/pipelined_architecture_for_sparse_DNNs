library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity address_translator is
    generic(max_elements : positive := 1024;
            banks      : positive := 1;
            bank_depth : positive := 2;
            mem_width  : positive := 32;
            data_width : positive := 8);
    port(----------------
         ---- INPUTS ----
         ----------------
         input_address : in STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         output_address : out STD_LOGIC_VECTOR(log_2(bank_depth) + address_width(mem_width) - 1 downto 0);
         bank_no        : out STD_LOGIC_VECTOR(log_2(banks) - 1 downto 0) 
    );
end address_translator;

architecture address_translator_arch of address_translator is
begin   
    -- Discard log_2(banks) and log_2(mem_width / data_width) LSb
    output_address(log_2(bank_depth) + address_width(mem_width) - 1 downto 0) <= resize(input_address(log_2(max_elements) - 1 downto log_2(banks) + log_2(mem_width / data_width)), log_2(bank_depth) + address_width(mem_width));
        
    bank_no <= input_address(log_2(banks) + log_2(mem_width / data_width) - 1 downto log_2(mem_width / data_width));
end address_translator_arch;
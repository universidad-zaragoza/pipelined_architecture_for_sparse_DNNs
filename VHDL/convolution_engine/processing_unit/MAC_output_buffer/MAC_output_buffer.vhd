library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity MAC_output_buffer is
    generic(queue_depth : positive := 2);
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         -- Queue operations
         enqueue_value   : in STD_LOGIC;
         enqueue_address : in STD_LOGIC;
         dequeue : in STD_LOGIC;
         -- Queue data
         value_in   : in STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
         address_in : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         value_queue_full  : out STD_LOGIC;
         value_queue_empty : out STD_LOGIC;
         address_queue_empty : out STD_LOGIC;
         value_out   : out STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
         address_out : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS) - 1 downto 0)
    );
end MAC_output_buffer;

architecture MAC_output_buffer_arch of MAC_output_buffer is
    component address_translator
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
    end component;
    
    component queue
        generic(element_width : positive := 8;
                queue_depth   : positive := 2);
        port(----------------
             ---- INPUTS ----
             ---------------- 
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             -- Queue operations
             enqueue : in STD_LOGIC;
             dequeue : in STD_LOGIC;
             -- Queue data
             data_in : in STD_LOGIC_VECTOR(element_width - 1 downto 0);
             -----------------
             ---- OUTPUTS ----
             -----------------
             full  : out STD_LOGIC;
             empty : out STD_LOGIC;
             data_out : out STD_LOGIC_VECTOR(element_width - 1 downto 0)
        );
    end component;
begin
    -- Values
    value_queue: queue
        generic map(element_width => ACTIVATION_VALUE_WIDTH,
                    queue_depth   => queue_depth)
        port map(---- INPUTS ---- 
                 clk => clk,
                 rst => rst,
                 -- Queue operations
                 enqueue => enqueue_value,
                 dequeue => dequeue,
                 -- Queue data
                 data_in => value_in,
                 ---- OUTPUTS ----
                 full  => value_queue_full,
                 empty => value_queue_empty,
                 data_out => value_out
        );
    
    -- Addresses
    address_queue: queue
        generic map(element_width => log_2(MAX_ACTIVATION_ELEMENTS),
                    queue_depth   => queue_depth)
        port map(---- INPUTS ---- 
                 clk => clk,
                 rst => rst,
                 -- Queue operations
                 enqueue => enqueue_address,
                 dequeue => dequeue,
                 -- Queue data
                 data_in => address_in,
                 ---- OUTPUTS ----
                 full  => open,
                 empty => address_queue_empty,
                 data_out => address_out
        );
end MAC_output_buffer_arch;
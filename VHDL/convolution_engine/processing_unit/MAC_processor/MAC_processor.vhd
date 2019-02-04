library IEEE;
use IEEE.std_logic_1164.all;
use work.types.all;

entity MAC_processor is
    port (----------------
          ---- INPUTS ----
          ----------------              
          clk : in STD_LOGIC;
          rst : in STD_LOGIC;
          -- MAC operation
          enable : in STD_LOGIC;
          flush  : in STD_LOGIC;
          -- Operands
          filter_value     : in STD_LOGIC_VECTOR(FILTER_VALUE_WIDTH - 1 downto 0);
          activation_value : in STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0);
          -----------------
          ---- OUTPUTS ----
          -----------------
          enqueue_value : out STD_LOGIC;
          output        : out STD_LOGIC_VECTOR(ACTIVATION_VALUE_WIDTH - 1 downto 0)
    );
end MAC_processor;

architecture MAC_processor_arch of MAC_processor is
    component MAC
        generic (operand_width : positive := 8);
        port (----------------
              ---- INPUTS ----
              ----------------              
              clk : in STD_LOGIC;
              rst : in STD_LOGIC;
              enable : in STD_LOGIC;
              flush  : in STD_LOGIC;
              input_A : in STD_LOGIC_VECTOR(operand_width - 1 downto 0);
              input_B : in STD_LOGIC_VECTOR(operand_width - 1 downto 0);
              -----------------
              ---- OUTPUTS ----
              -----------------
              enqueue_value : out STD_LOGIC;
              output        : out STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * operand_width - 1 downto 0)
        );
    end component;
    
    component scaler
        generic (input_width  : positive := 16;
                 output_width : positive := 8);
        port (----------------
              ---- INPUTS ----
              ----------------
              input : in STD_LOGIC_VECTOR(input_width - 1 downto 0);          
              -----------------
              ---- OUTPUTS ----
              -----------------
              output : out STD_LOGIC_VECTOR(output_width - 1 downto 0)
        );
    end component;
    
    signal MAC_output: STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * ACTIVATION_VALUE_WIDTH - 1 downto 0);
    signal MAC_output_ReLU: STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * ACTIVATION_VALUE_WIDTH - 1 downto 0);
begin
    MAC_I: MAC
        generic map(operand_width => ACTIVATION_VALUE_WIDTH)
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 enable => enable,
                 flush  => flush,
                 input_A => filter_value,
                 input_B => activation_value,
                 ---- OUTPUTS ----
                 enqueue_value => enqueue_value,
                 output        => MAC_output
        );
        
   -- ReLU
   MAC_output_ReLU <= MAC_output when MAC_output(ACCUMULATOR_SIZE_FACTOR * ACTIVATION_VALUE_WIDTH - 1) = '0' else (others => '0');
   
   -- -- Resize MAC output from (2 * operand_width)b to (operand_width)b    
   -- scaler_I: scaler
       -- generic map(input_width  => ACCUMULATOR_SIZE_FACTOR * ACTIVATION_VALUE_WIDTH,
                   -- output_width => ACTIVATION_VALUE_WIDTH)
       -- port map(---- INPUTS ----
                -- MAC_output_ReLU,
                -- ---- OUTPUTS ----
                -- output
       -- );
output <= MAC_output_ReLU(ACTIVATION_VALUE_WIDTH - 1 downto 0);
-- JUST FOR DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
-- output <= MAC_output(ACTIVATION_VALUE_WIDTH - 1 downto 0);
end MAC_processor_arch;
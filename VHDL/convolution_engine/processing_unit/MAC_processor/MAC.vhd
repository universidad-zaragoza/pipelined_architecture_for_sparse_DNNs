library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.numeric_std.all;
--use IEEE.std_logic_unsigned.all;
use work.types.all;

entity MAC is
    generic (operand_width : positive := 32);
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
    
    attribute use_dsp : string;
    attribute use_dsp of MAC : entity is "no";
end MAC;

architecture MAC_arch of MAC is
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
    
    -- 1st stage: multiply
    signal multiplication : STD_LOGIC_VECTOR(2 * operand_width - 1 downto 0);
    signal control        : STD_LOGIC_VECTOR(1 + 1 - 1 downto 0);
    
    -- 2nd stage: accumulate
    signal accumulation : STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * operand_width - 1 downto 0);
    signal accumulator_input : STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * operand_width - 1 downto 0);
    
    signal enable_pipelined : STD_LOGIC;
    signal flush_pipelined  : STD_LOGIC;
    
    signal flush_pipelined_latch_input : STD_LOGIC_VECTOR(1 - 1 downto 0);
    signal flush_pipelined_latch       : STD_LOGIC_VECTOR(1 - 1 downto 0);
    
    -- MAC FSM
    type tp_state is (FIRST_MAC,
                      REMAINING_MACS);
    signal current_state, next_state: tp_state;
begin
    -- 1st stage: multiply
    mult_reg: reg generic map(bits => 2 * operand_width, init_value => 0)
        port map(clk, rst, enable, input_A * input_B, multiplication);
    
    control_reg: reg generic map(bits => 1 + 1)
        port map(clk, rst, '1', enable & flush, control);

    enable_pipelined <= control(1);
    flush_pipelined  <= control(0);
    
    -- 2nd stage: accumulate
    accum_reg: reg generic map(bits => ACCUMULATOR_SIZE_FACTOR * operand_width, init_value => 0)        
        port map(clk, rst, enable_pipelined, accumulator_input, accumulation);
    
    -- MAC FSM
    MAC_FSM : process(current_state, multiplication, accumulation,  -- Default
                      enable_pipelined,                             -- FIRST_MAC
                      flush_pipelined)                              -- REMAINING_MACS
    begin
        next_state <= current_state;
        
        accumulator_input <= resize(multiplication + accumulation, ACCUMULATOR_SIZE_FACTOR * operand_width);
        
        case current_state is
            when FIRST_MAC =>
                if enable_pipelined = '1' then
                    accumulator_input <= resize(multiplication, ACCUMULATOR_SIZE_FACTOR * operand_width);
                    
                    next_state <= REMAINING_MACS;
                end if;
            
            when REMAINING_MACS =>
                if flush_pipelined = '1' then
                    next_state <= FIRST_MAC;
                end if;
        end case;        
    end process MAC_FSM;
    
    states: process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                current_state <= FIRST_MAC;
            else
                current_state <= next_state;
            end if;
        end if;
    end process states;
    
    flush_latch: reg generic map(bits => 1)
        port map(clk, rst, '1', flush_pipelined_latch_input, flush_pipelined_latch);
    
    flush_pipelined_latch_input <= "1" when flush_pipelined = '1' else "0";
    
    -- Outputs
    enqueue_value <= '1' when flush_pipelined_latch = "1" else '0';
    output        <= accumulation;
end MAC_arch;

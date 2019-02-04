library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity MAC_and_buffer_controller is
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         new_MAC  : in STD_LOGIC;
         convolution_step_done : in STD_LOGIC;
         convolution_done      : in STD_LOGIC;
         MAC_buffer_full: in STD_LOGIC;  -- TO DO: stop pipeline when MAC_buffer_full and a new value is generated
         -----------------
         ---- OUTPUTS ----
         -----------------
-- Peformance monitoring
idle_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
mult_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
         MAC_enable : out STD_LOGIC;
         MAC_flush  : out STD_LOGIC;
         enqueue_address : out STD_LOGIC
    );
end MAC_and_buffer_controller;

architecture MAC_and_buffer_controller_arch of MAC_and_buffer_controller is
component counter
    generic(bits : positive := 2;
            step : positive := 1);
        port(----------------
             ---- INPUTS ----
             ----------------
             clk : in STD_LOGIC;
             rst : in STD_LOGIC;
             rst_2 : in STD_LOGIC;
             inc   : in STD_LOGIC;
             -----------------
             ---- OUTPUTS ----
             -----------------
             count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
    );
end component;

    -- MAC_and_buffer_controller FSM
    type tp_state is (INIT, -- Peformance monitoring
                      IDLE,
                      MULTIPLYING,
                      FLUSH_AND_MULTIPLY,
                      FLUSH);
    signal current_state, next_state: tp_state;

signal rst_performance_counter : STD_LOGIC;
signal inc_idle_counter, inc_mult_counter : STD_LOGIC;    
-- signal idle_count : STD_LOGIC_VECTOR(32 - 1 downto 0);
-- signal mult_count : STD_LOGIC_VECTOR(32 - 1 downto 0);

begin
-- Peformance monitoring
idle_counter: counter generic map(bits =>32, step => 1)
    port map(clk, rst, rst_performance_counter, inc_idle_counter, idle_count);

mult_counter: counter generic map(bits =>32, step => 1)
    port map(clk, rst, rst_performance_counter, inc_mult_counter, mult_count);    
-- Peformance monitoring
    
    -- MAC_and_buffer_controller FSM        
    MAC_and_buffer_controller_FSM: process(current_state,                                      -- Default
                                           convolution_done, convolution_step_done, new_MAC)   -- IDLE
    begin        
        next_state <= current_state;
        
        MAC_enable <= '0';
        MAC_flush  <= '0';
        
        enqueue_address <= '0';

        rst_performance_counter <= '0'; -- Peformance monitoring
        inc_idle_counter <= '0';        -- Peformance monitoring
        inc_mult_counter <= '0';        -- Peformance monitoring

        case current_state is
            -- Remove if not performance monitoring 
            when INIT =>    
                if new_MAC = '1' then
                    rst_performance_counter <= '1';
                    next_state <= MULTIPLYING;
                end if;
    
            when IDLE =>
                inc_idle_counter <= '1';    -- Peformance monitoring

                if (convolution_done = '1' OR convolution_step_done = '1') AND new_MAC = '1' then
                    enqueue_address <= '1';
                    next_state <= FLUSH_AND_MULTIPLY;
                elsif convolution_done = '1' OR convolution_step_done = '1' then
                    enqueue_address <= '1';
                    next_state <= FLUSH;
                elsif new_MAC = '1' then
                    next_state <= MULTIPLYING;
                end if;
           
            when MULTIPLYING =>
                inc_mult_counter <= '1';    -- Peformance monitoring
                MAC_enable <= '1';

                if (convolution_done = '1' OR convolution_step_done = '1') AND new_MAC = '1' then
                    enqueue_address <= '1';
                    next_state <= FLUSH_AND_MULTIPLY;
                elsif convolution_done = '1' OR convolution_step_done = '1' then
                    enqueue_address <= '1';
                    next_state <= FLUSH;
                elsif new_MAC = '0' then
                    next_state <= IDLE;
                end if;
            
            when FLUSH_AND_MULTIPLY =>
                inc_mult_counter <= '1';    -- Peformance monitoring
                MAC_enable <= '1';
                MAC_flush <= '1';
                
                if new_MAC = '1' then
                    next_state <= MULTIPLYING;
                else
                    next_state <= IDLE;
                end if;
            
            when FLUSH =>
                inc_idle_counter <= '1';    -- Peformance monitoring                
                MAC_flush <= '1';
                
                if new_MAC = '1' then
                    next_state <= MULTIPLYING;
                else
                    next_state <= IDLE;
                end if;
        end case;
    end process MAC_and_buffer_controller_FSM;    

    states: process(clk)
    begin              
        if rising_edge(clk) then
            if rst = '1' then
--                current_state <= IDLE;
                current_state <= INIT;  -- Peformance monitoring
            else
                current_state <= next_state;
            end if;
        end if;
    end process;
end MAC_and_buffer_controller_arch;
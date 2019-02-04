library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity match_buffer_controller is
    port(----------------
         ---- INPUTS ----
         ----------------
         clk : in std_logic;
         rst : in std_logic;
         -- Buffering the last pair
         last_pair_step : in STD_LOGIC;
         last_pair      : in STD_LOGIC;         
         last_taken : in STD_LOGIC;
         -----------------
         ---- OUTPUTS ----
         -----------------
         -- Mixed Convolutions control
		 toggle_input  : out STD_LOGIC;
		 toggle_output : out STD_LOGIC;
         convolution_step_done : out STD_LOGIC;
         convolution_done      : out STD_LOGIC
    );
end match_buffer_controller;

architecture match_buffer_controller_arch of match_buffer_controller is
    -- Convolution controller FSM
    type tp_state is (LAST_PAIR_NOT_BUFFERED,
                      FLUSHING_BUFFER_STEP,
                      FLUSHING_BUFFER);
    signal current_state, next_state: tp_state;
begin
    -- Match buffer FSM
    match_buffer_FSM : process(current_state,               -- Default
                               last_pair, last_pair_step,   -- LAST_PAIR_NOT_BUFFERED
                               last_taken)                  -- FLUSHING_BUFFER_STEP
    begin
        next_state <= current_state;

        convolution_step_done <= '0';
        convolution_done      <= '0';
        toggle_input		  <= '0';
        toggle_output		  <= '0';
        
        case current_state is
            when LAST_PAIR_NOT_BUFFERED =>
                if last_pair = '1' then
                    toggle_input <= '1';
                    
                    next_state <= FLUSHING_BUFFER;                    
                elsif last_pair_step = '1' then
                    toggle_input <= '1';
                    
                    next_state <= FLUSHING_BUFFER_STEP;
                end if;
                
            -- Match buffer stored the last pair of a convolution step. Wait until that pair, and any possible previous pair are taken
            when FLUSHING_BUFFER_STEP =>                
                if last_taken = '1' then
                    convolution_step_done <= '1';
                    toggle_output <= '1';
                    
                    next_state <= LAST_PAIR_NOT_BUFFERED;
                    
                end if;                
            
            -- Match buffer stored the last pair of the last convolution step. Wait until that pair, and any possible previous pair are taken
            when FLUSHING_BUFFER =>                
                if last_taken = '1' then
                    convolution_done <= '1';
                    toggle_output <= '1';
                    
                    next_state <= LAST_PAIR_NOT_BUFFERED;                    
                end if;
        end case;        
    end process match_buffer_FSM;
    
    states: process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                current_state <= LAST_PAIR_NOT_BUFFERED;
            else
                current_state <= next_state;
            end if;
        end if;
    end process states;
end match_buffer_controller_arch;
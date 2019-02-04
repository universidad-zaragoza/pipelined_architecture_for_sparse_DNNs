library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity done_controller is
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution : in STD_LOGIC;
         convolution_done  : in STD_LOGIC;
         MAC_buffer_empty  : in STD_LOGIC;
         -----------------
         ---- OUTPUTS ----
         -----------------
         done : out STD_LOGIC
    );
end done_controller;

architecture done_controller_arch of done_controller is
    -- Done controller FSM  
    type tp_state is (IDLE,
                      CONVOLVING,
                      FLUSHING_MAC_BUFFER);
    signal current_state, next_state: tp_state;
begin    
    -- Done controller FSM        
    done_controller_FSM: process(current_state,     -- Default
                                 start_convolution, -- IDLE
                                 convolution_done,  -- CONVOLVING
                                 MAC_buffer_empty)  -- FLUSHING_MAC_BUFFER
    begin        
        next_state <= current_state;
        
        done <= '0';

        case current_state is
            when IDLE =>
                done <= '1';
                
                if start_convolution = '1' then
                    next_state <= CONVOLVING;
                end if;
           
            when CONVOLVING =>
                if convolution_done = '1' then
                    next_state <= FLUSHING_MAC_BUFFER;
                end if;
            
            when FLUSHING_MAC_BUFFER =>
                if MAC_buffer_empty = '1' then
                    next_state <= IDLE;
                end if;
        end case;
    end process done_controller_FSM;    

    states: process(clk)
    begin              
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= IDLE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;
end done_controller_arch;
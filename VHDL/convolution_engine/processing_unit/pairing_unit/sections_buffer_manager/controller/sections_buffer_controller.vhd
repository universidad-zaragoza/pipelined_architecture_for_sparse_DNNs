library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity sections_buffer_controller is
    port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution : in STD_LOGIC;
         request_indices_int : in STD_LOGIC_VECTOR(2 - 1 downto 0);
         convolution_done    : in STD_LOGIC;
         -----------------
         ---- OUTPUTS ----
         -----------------
         request_indices : out STD_LOGIC
    );
end sections_buffer_controller;

architecture sections_buffer_controller_arch of sections_buffer_controller is
    -- Sections buffer FSM
    type tp_state is (IDLE,
                      CONVOLVING);
    signal current_state, next_state: tp_state;
begin
    -- Sections buffer FSM
    sections_buffer_FSM : process(current_state,                            -- Default
                                  start_convolution, request_indices_int,   -- IDLE
                                  convolution_done)                         -- CONVOLVING
    begin
        next_state <= current_state;
        
        request_indices <= '0';
        
        case current_state is
            when IDLE =>
                if start_convolution = '1' then
                    request_indices <= request_indices_int(0) OR request_indices_int(1); 
                    
                    next_state <= CONVOLVING;
                end if;
            
            when CONVOLVING =>
                request_indices <= request_indices_int(0) OR request_indices_int(1); 
                
                if convolution_done = '1' then
                    next_state <= IDLE;
                end if;
        end case;        
    end process sections_buffer_FSM;
    
    states: process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                current_state <= IDLE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process states;    
end sections_buffer_controller_arch;
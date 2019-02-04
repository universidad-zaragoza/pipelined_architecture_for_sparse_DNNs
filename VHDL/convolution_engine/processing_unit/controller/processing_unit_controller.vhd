library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity processing_unit_controller is
    port(----------------
         ---- INPUTS ----
         ---------------- 
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution : in STD_LOGIC;
         new_MAC  : in STD_LOGIC;
         convolution_step_done : in STD_LOGIC;
         convolution_done      : in STD_LOGIC;
         MAC_buffer_empty : in STD_LOGIC;
         MAC_buffer_full  : in STD_LOGIC;  -- TO DO: stop pipeline when MAC_buffer_full and a new value is generated
         -----------------
         ---- OUTPUTS ----
         -----------------
-- Peformance monitoring
idle_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
mult_count : out STD_LOGIC_VECTOR(32 - 1 downto 0);
         MAC_enable : out STD_LOGIC;
         MAC_flush  : out STD_LOGIC;
         enqueue_address : out STD_LOGIC;
         done : out STD_LOGIC
    );
end processing_unit_controller;

architecture processing_unit_controller_arch of processing_unit_controller is
    component MAC_and_buffer_controller
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
    end component;
    
    component done_controller
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
    end component;
begin
    MAC_and_buffer_controller_I: MAC_and_buffer_controller
        port map(---- INPUTS ----              
                 clk => clk,
                 rst => rst,
                 new_MAC => new_MAC,
                 convolution_step_done => convolution_step_done,
                 convolution_done      => convolution_done,
                 MAC_buffer_full       => MAC_buffer_full,
                 -----------------
                 ---- OUTPUTS ----
                 -----------------
-- Peformance monitoring
idle_count => idle_count,
mult_count => mult_count,
                 MAC_enable => MAC_enable,
                 MAC_flush  => MAC_flush,
                 enqueue_address => enqueue_address
        );
    
    done_controller_I: done_controller
        port map(---- INPUTS ----              
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 convolution_done  => convolution_done,
                 MAC_buffer_empty  => MAC_buffer_empty,
                 ---- OUTPUTS ----
                 done => done
        );
end processing_unit_controller_arch;


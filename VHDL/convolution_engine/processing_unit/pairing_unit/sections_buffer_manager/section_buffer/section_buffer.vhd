library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity sections_buffer is
    port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution : in STD_LOGIC;
         indices_granted : in STD_LOGIC;         
         filter_indices     : in STD_LOGIC_VECTOR(FILTER_INDICES_WIDTH - 1 downto 0);
         activation_indices : in STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
         buffer_processed : in STD_LOGIC;
         -- Convolution control info         
         convolution_step_done_in : in STD_LOGIC;
         convolution_done_in      : in STD_LOGIC;
         -- Activation base address
         activation_address_in : in STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
         -----------------
         ---- OUTPUTS ----
         -----------------
         request_indices : out STD_LOGIC;
         section_available  : out STD_LOGIC;
         filter_buffer     : out STD_LOGIC_VECTOR(FILTER_INDICES_WIDTH - 1 downto 0);
         activation_buffer : out STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
         -- Convolution control info         
         convolution_step_done : out STD_LOGIC;
         convolution_done      : out STD_LOGIC;
         -- Activation base address
         activation_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0)
    );
end sections_buffer;

architecture sections_buffer_arch of sections_buffer is
    component reg
		generic(bits       : natural := 128;
                init_value : natural := 0);
		port (----------------
			  ---- INPUTS ----
			  ----------------
              clk : in STD_LOGIC;
              rst : in STD_LOGIC;
              ld  : in STD_LOGIC;
              din : in STD_LOGIC_VECTOR(bits - 1 downto 0);
              -----------------
              ---- OUTPUTS ----
              -----------------
              dout : out STD_LOGIC_VECTOR(bits - 1 downto 0)
		);
	end component;
    
    -- Sections buffer
    signal ld_control, ld_sections : STD_LOGIC;
    signal control_in, control : STD_LOGIC_VECTOR((1 + 1) - 1 downto 0);
    
    -- Sections buffer FSM
    type tp_state is (UNLOADED,
                      LOADING_SECTION,
                      LOADED);
    signal current_state, next_state: tp_state;
begin
    ---------------------
    -- Sections buffer --
    ---------------------
    -- Sections
    filter_section_buffer_reg : reg generic map(bits => FILTER_INDICES_WIDTH)
        port map(clk, rst, ld_sections, filter_indices, filter_buffer);
    
    activation_section_buffer_reg : reg generic map(bits => ACTIVATION_INDICES_WIDTH)
        port map(clk, rst, ld_sections, activation_indices, activation_buffer);
    
    -- Control
    control_buffer_reg : reg generic map(bits => 1 + 1)
        port map(clk, rst, ld_control, control_in, control);

    control_in <= convolution_step_done_in & convolution_done_in;
    
    -- Activation base address
    activation_base_address_reg : reg generic map(bits => log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH))
        port map(clk, rst, ld_control, activation_address_in, activation_address);
    
    -- Sections buffer FSM
    sections_buffer_FSM : process(current_state,    -- Default                                  
                                  indices_granted,  -- UNLOADED
                                  buffer_processed) -- LOADED
    begin
        next_state <= current_state;
        
        request_indices <= '0';
        
        ld_control  <= '0';
        ld_sections <= '0';
        
        section_available <= '0';
        
        case current_state is
            when UNLOADED =>
                request_indices <= '1';
                
                if indices_granted = '1' then
                    ld_control <= '1';
                    
                    next_state <= LOADING_SECTION;
                end if;
            
            when LOADING_SECTION =>                
                ld_sections <= '1';
                section_available <= '1';
                
                next_state <= LOADED;  
            
            when LOADED =>
                if buffer_processed = '1' then
                    request_indices <= '1';
                    
                    if indices_granted = '1' then
                        ld_control <= '1';
                        
                        next_state <= LOADING_SECTION;
                    else
                        next_state <= UNLOADED;
                    end if;
                else
                    section_available <= '1';                    
                end if;
        end case;        
    end process sections_buffer_FSM;
    
    states: process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                current_state <= UNLOADED;
            else
                current_state <= next_state;
            end if;
        end if;
    end process states;
    
    -- Outputs
    -- Convolution control info
    convolution_step_done <= control(1);
    convolution_done      <= control(0);
end sections_buffer_arch;
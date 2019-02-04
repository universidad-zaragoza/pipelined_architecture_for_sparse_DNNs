library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity sections_buffer_manager is
    port(----------------
         ---- INPUTS ----
         ----------------
         clk : in STD_LOGIC;
         rst : in STD_LOGIC;
         start_convolution : in STD_LOGIC;
         indices_granted : in STD_LOGIC;
         indices_served     : in STD_LOGIC;
         filter_indices     : in STD_LOGIC_VECTOR(FILTER_INDICES_WIDTH - 1 downto 0);
         activation_indices : in STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
         section_processed     : in STD_LOGIC;
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
         filter_section     : out STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
         activation_section : out STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
         indices_buffer_processed : out STD_LOGIC;
         -- Convolution control info         
         convolution_step_done : out STD_LOGIC;
         convolution_done      : out STD_LOGIC;
         -- Activation base address
         activation_address : out STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / SECTION_WIDTH) - 1 downto 0)
    );
end sections_buffer_manager;

architecture sections_buffer_manager_arch of sections_buffer_manager is
    component sections_buffer
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
    end component;
    
    component sections_buffer_controller
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
    end component;
    
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
    
    -- Sections buffers
    signal indices_granted_int, indices_served_int : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal buffer_processed_int : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal request_indices_int : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal section_available_int : STD_LOGIC_VECTOR(2 - 1 downto 0);
    type tp_buffer_array is array(2 - 1 downto 0) of STD_LOGIC_VECTOR(ACTIVATION_INDICES_WIDTH - 1 downto 0);
    signal filter_buffer     : tp_buffer_array;
    signal activation_buffer : tp_buffer_array;    
    
    signal convolution_step_done_int : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal convolution_done_int      : STD_LOGIC_VECTOR(2 - 1 downto 0);
    
    type tp_activation_address_array is array(2 - 1 downto 0) of STD_LOGIC_VECTOR(log_2(MAX_ACTIVATION_ELEMENTS / ACTIVATION_INDICES_WIDTH) - 1 downto 0);
    signal activation_address_int : tp_activation_address_array;
    
    -- Sections buffer FSM
    signal current_buffer_cs, current_buffer_ns : STD_LOGIC_VECTOR(1 - 1 downto 0);
    signal buffer_to_be_granted_cs, buffer_to_be_granted_ns : STD_LOGIC_VECTOR(1 - 1 downto 0);

signal debug_start_cs : STD_LOGIC;
signal debug_section_halts : STD_LOGIC_VECTOR(20 - 1 downto 0);
signal inc_debug_section_halts : STD_LOGIC;
begin
    buffer_larger_than_section: if ACTIVATION_INDICES_WIDTH > SECTION_WIDTH generate
        signal rst_current_section, inc_current_section : STD_LOGIC;
        signal current_section : STD_LOGIC_VECTOR(log_2(ACTIVATION_INDICES_WIDTH / SECTION_WIDTH) - 1 downto 0);
    begin
        ----------------------
        -- Sections buffers --
        ----------------------
        sections_buffers_I: for i in 2 - 1 downto 0 generate
            sections_buffer_I: sections_buffer
                port map(---- INPUTS ----
                         clk => clk,
                         rst => rst,
                         start_convolution => start_convolution,
                         indices_granted => indices_granted_int(i),                         
                         filter_indices     => filter_indices,
                         activation_indices => activation_indices,
                         buffer_processed => buffer_processed_int(i),                         
                         convolution_step_done_in => convolution_step_done_in,
                         convolution_done_in      => convolution_done_in,
                         activation_address_in    => activation_address_in,
                         ---- OUTPUTS ----
                         request_indices => request_indices_int(i),
                         section_available  => section_available_int(i),
                         filter_buffer     => filter_buffer(i),
                         activation_buffer => activation_buffer(i),
                         convolution_step_done => convolution_step_done_int(i),
                         convolution_done      => convolution_done_int(i),
                         activation_address    => activation_address_int(i)
                );

                indices_granted_int(i) <= '1' when indices_granted   = '1'              AND
                                                   to_uint(buffer_to_be_granted_cs) = i else
                                          '0';
                
                buffer_processed_int(i)  <= '1' when section_processed = '1'                                                  AND
                                                     to_uint(current_section)  = ACTIVATION_INDICES_WIDTH / SECTION_WIDTH - 1 AND
                                                     to_uint(current_buffer_cs) = i else
                                            '0';
        end generate;
        
        --------------------
        -- Buffer control --
        --------------------
        -- Control of which buffer is being processed
        current_buffer_ns <= NOT(current_buffer_cs) when section_processed = '1'                                                 AND
                                                         to_uint(current_section) = ACTIVATION_INDICES_WIDTH / SECTION_WIDTH - 1 else
                             current_buffer_cs;
        
        ---------------------
        -- Section control --
        ---------------------
        section_counter: counter generic map(bits => log_2(ACTIVATION_INDICES_WIDTH / SECTION_WIDTH))
            port map(clk, rst, rst_current_section, inc_current_section, current_section);

        rst_current_section <= '1' when section_processed = '1' AND to_uint(current_section)  = ACTIVATION_INDICES_WIDTH / SECTION_WIDTH - 1 else '0';
        inc_current_section <= '1' when section_processed = '1' AND to_uint(current_section) /= ACTIVATION_INDICES_WIDTH / SECTION_WIDTH - 1 else '0';
        
        -- Outputs
        filter_section     <= vector_slice(    filter_buffer(to_uint(current_buffer_cs)), (ACTIVATION_INDICES_WIDTH / SECTION_WIDTH - 1) - to_uint(current_section), SECTION_WIDTH);
        activation_section <= vector_slice(activation_buffer(to_uint(current_buffer_cs)), (ACTIVATION_INDICES_WIDTH / SECTION_WIDTH - 1) - to_uint(current_section), SECTION_WIDTH);
        
        indices_buffer_processed <= buffer_processed_int(0) OR buffer_processed_int(1);
        
        activation_address <= std_logic_vector(to_unsigned(to_uint(activation_address_int(to_uint(current_buffer_cs)) & current_section),
                                                           log_2(MAX_ACTIVATION_ELEMENTS / SECTION_WIDTH)));
    end generate;
    
    buffer_equal_to_section: if ACTIVATION_INDICES_WIDTH = SECTION_WIDTH generate
    begin
        ----------------------
        -- Sections buffers --
        ----------------------
        sections_buffers_I: for i in 2 - 1 downto 0 generate
            sections_buffer_I: sections_buffer
                port map(---- INPUTS ----
                         clk => clk,
                         rst => rst,
                         start_convolution => start_convolution,
                         indices_granted => indices_granted_int(i),
                         filter_indices     => filter_indices,
                         activation_indices => activation_indices,
                         buffer_processed => buffer_processed_int(i),                         
                         convolution_step_done_in => convolution_step_done_in,
                         convolution_done_in      => convolution_done_in,
                         activation_address_in    => activation_address_in,
                         ---- OUTPUTS ----
                         request_indices => request_indices_int(i),
                         section_available  => section_available_int(i),
                         filter_buffer     => filter_buffer(i),
                         activation_buffer => activation_buffer(i),
                         convolution_step_done => convolution_step_done_int(i),
                         convolution_done      => convolution_done_int(i),
                         activation_address    => activation_address_int(i)
                );

                indices_granted_int(i) <= '1' when indices_granted   = '1'              AND
                                                   to_uint(buffer_to_be_granted_cs) = i else
                                          '0';
                
                buffer_processed_int(i)  <= '1' when section_processed = '1'        AND
                                                     to_uint(current_buffer_cs) = i else
                                            '0';
        end generate;
        
        --------------------
        -- Buffer control --
        --------------------
        -- Control of which buffer is being processed
        current_buffer_ns <= NOT(current_buffer_cs) when section_processed = '1' else current_buffer_cs;        
        
        ---------------------
        -- Section control --
        ---------------------
        -- Outputs
        filter_section     <= filter_buffer(to_uint(current_buffer_cs));
        activation_section <= activation_buffer(to_uint(current_buffer_cs));
        
        indices_buffer_processed <= buffer_processed_int(0) OR buffer_processed_int(1);
        
        activation_address <= activation_address_int(to_uint(current_buffer_cs));
    end generate;    
    
    ---------------------------
    -- Common for both cases --
    ---------------------------
    -- Control of which buffer is being granted with a new section
    buffer_to_be_granted_ns <= NOT(buffer_to_be_granted_cs) when indices_granted = '1' else buffer_to_be_granted_cs;
    
    -- A section is inmediately available to be processed by the matching unit
    section_available <= section_available_int(0) OR section_available_int(1);    
    
    control_regs: process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                current_buffer_cs <= "0";
                buffer_to_be_granted_cs <= "0";
            else
                current_buffer_cs <= current_buffer_ns;
                buffer_to_be_granted_cs <= buffer_to_be_granted_ns;
            end if;
        end if;
    end process control_regs;
    
    --------------------------------
    -- Sections buffer controller --
    --------------------------------
    sections_buffer_controller_I: sections_buffer_controller
        port map(---- INPUTS ----
                 clk => clk,
                 rst => rst,
                 start_convolution => start_convolution,
                 request_indices_int => request_indices_int,
                 convolution_done    => convolution_done_in,
                 ---- OUTPUTS ----
                 request_indices => request_indices
        );
    
    -------------
    -- Outputs --
    -------------
    convolution_step_done <= convolution_step_done_int(to_uint(current_buffer_cs));
    convolution_done      <= convolution_done_int(to_uint(current_buffer_cs));

-- DEBUG
debug: process(clk)
begin              
    if clk'event AND clk = '1' then
        if rst = '1' then
            debug_start_cs <= '0';
        elsif start_convolution = '1' then
            debug_start_cs <= '1';
        end if;
    end if;
end process debug;

debug_section_halts_counter: counter generic map(bits => 20)
    port map(clk, rst, '0', inc_debug_section_halts, debug_section_halts);

inc_debug_section_halts <= debug_start_cs AND NOT(section_available_int(0) OR section_available_int(1));
    
end sections_buffer_manager_arch;
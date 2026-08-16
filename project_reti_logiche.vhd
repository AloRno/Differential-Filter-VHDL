
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity project_reti_logiche is
    port(
        i_clk : in std_logic;
         i_rst : in std_logic;
         i_start : in std_logic;
         i_add : in std_logic_vector(15 downto 0);
         o_done : out std_logic;
         o_mem_addr : out std_logic_vector(15 downto 0);
         i_mem_data : in std_logic_vector(7 downto 0);
         o_mem_data : out std_logic_vector(7 downto 0);
         o_mem_we : out std_logic;
         o_mem_en : out std_logic
    );
end project_reti_logiche;

architecture main_arch  of project_reti_logiche is
    type state_type is (S0,S1,S2,S3,S4,S5,S6,S7,S8,S9,DONE);
    signal next_state, current_state : state_type;
    signal k : std_logic_vector(15 downto 0);
    signal elementi_filtrati : std_logic_vector(15 downto 0);
    signal tipo_filtro : std_logic;
    signal elaborazione_fatta : std_logic;
    signal memory_address : std_logic_vector(15 downto 0);
    signal input_start : std_logic_vector(15 downto 0); --Salva da dove partire a prendere input
    signal write_address : std_logic_vector(15 downto 0); --Indrizzo di memoria in cui scrivere il risultato
    type array_7x8 is array(0 to 6) of std_logic_vector(7 downto 0);
    signal costanti : array_7x8;
    signal input : array_7x8;
    signal index_costanti : integer range 0 to 6;
    signal index_input : integer range 0 to 6;

begin
    state_reg : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            current_state <= S0;
        elsif rising_edge(i_clk) then
            current_state <= next_state;
        end if;
    end process;
    
    funzione_stato_prossimo : process(current_state, i_start, memory_address, elaborazione_fatta) --Specifica della funzione di stato prossimo
    begin
        o_done <= '0';
        o_mem_en <= '1';
        o_mem_we <= '0';
        o_mem_addr <= (others => '-');       
        case current_state is            
            when S0 =>
                if i_start = '1' then
                    o_mem_en <= '1'; 
                    o_mem_addr <= std_logic_vector(unsigned(i_add));
                    next_state <= S1;
                else
                    o_mem_en <= '0';
                    o_mem_addr <= (others => '-');
                    next_state <= S0;
                end if;
                
             when S1 => --Lettura K1
                o_mem_addr <= std_logic_vector(unsigned(i_add) + 1);
                next_state <= S2;
                
             when S2 => --lettura K2
                o_mem_addr <= std_logic_vector(unsigned(i_add) + 2);
                next_state <= S3;
                
             when S3 => --Lettura Tipo di Filtro
                next_state <= S4;
                
             when S4 => --Setup memoria per leggere coefficienti
                o_mem_addr <= memory_address;
                next_state <= S5;
                
             when S5 => --Lettura Costanti
                if index_costanti >= 6 then --Rileva quando la lettura delle costanti sta terminando
                    o_mem_addr <= memory_address;
                    next_state <= S6;
                else 
                    o_mem_addr <= std_logic_vector(unsigned(memory_address) + 1);
                    next_state <= S5;
                end if;  
                
             when S6 => --Lettura Input
                o_mem_addr <= memory_address;
                if index_input = 6 then
                    next_state <= S7;
                else    
                    next_state <= S6;
                end if;
                    
              when S7 => --Elaborazione filtro
                o_mem_addr <= write_address;
                if elaborazione_fatta = '1' then                                       
                    o_mem_we <= '1'; 
                    next_state <= S8;
                else
                    o_mem_we <= '0';
                    next_state <= S7;
                end if;
                
                
             when S8 => --Scrittura Risultato
                next_state <= S9; 
                
             when S9 => --Setup memoria per nuovo ciclo di lettura/Rilevamento Done
                if unsigned(elementi_filtrati) = unsigned(k) then
                    o_done <= '1';
                    next_state <= DONE;
                else
                    o_done <= '0';
                    o_mem_addr <= memory_address; -- input_start + 1 (dove input_start è "determinato" in S5 per la prima volta e in S8 per le successive riletture)
                    next_state <= S6;
                end if; 
                
             when DONE => --Stato in cui il segnale di Done è alto
                if i_start = '0' then
                    o_done <= '0';
                    next_state <= S0;
                else
                    o_done <= '1';
                    next_state <= DONE;
                end if;
                
                
                            
        end case;
    end process;
    
    gestione_stati : process(i_clk)
    begin
        if rising_edge(i_clk) then
            case current_state is
                when S0 => --RST
                    index_costanti <= 0;
                    index_input <= 0;
                    elementi_filtrati <= std_logic_vector(to_unsigned(0, 16));
                
                when S1 =>
                    k(15 downto 8) <= i_mem_data;
                    
                when S2 =>
                    k(7 downto 0) <= i_mem_data;
                    
                when S3 =>
                    write_address <= std_logic_vector(unsigned(i_add) + 17 + unsigned(k));
                    tipo_filtro <= i_mem_data(0);
                    if i_mem_data(0) = '0' then
                        memory_address <= std_logic_vector(unsigned(i_add) + 3);
                    else
                        memory_address <= std_logic_vector(unsigned(i_add) + 10);
                    end if;
                    
                 when S5 => 
                    costanti(index_costanti) <= i_mem_data;
                    index_costanti <= index_costanti + 1;
                    if index_costanti = 5 then --Per capire, quando index_costanti = 4 viene deciso l'indirizzo da cui poi prenderà il dato quando index_costnati = 6, quindi quando inex_costanti = 5 possiamo determinare da dove iniziare a prendere l'input risparmando uno stato di setup
                        if tipo_filtro = '0' then --In base al filtro individuato cambia la strategia con cui bisogna prendere l'input
                            memory_address <= std_logic_vector(unsigned(i_add) + 15);
                            input_start <= std_logic_vector(unsigned(i_add) + 16); --Necessario per letture successive dell'input
                        else    
                            memory_address <= std_logic_vector(unsigned(i_add) + 14);
                            input_start <= std_logic_vector(unsigned(i_add) + 15); --Necessario Per letture successive dell'input
                        end if;
                    else
                        memory_address <= std_logic_vector(unsigned(memory_address) + 1);                        
                    end if;
                    
                 when S6 =>
                    if memory_address < std_logic_vector(unsigned(i_add) + 18) or memory_address > std_logic_vector(unsigned(i_add) + 17 + unsigned(k)) then --memory_address a questo punto è di uno più avanti rispetto all'indizirro su cui è settata la RAM
                        input(index_input) <= std_logic_vector(to_signed(0, 8));
                    else
                        input(index_input) <= i_mem_data;
                    end if;
                    index_input <= index_input + 1;
                    memory_address <= std_logic_vector(unsigned(memory_address) + 1);
                    
                 when S7 =>
                    index_input <= 0;
                    memory_address <= std_logic_vector(unsigned(input_start));
                    
                 when S8 =>
                    elementi_filtrati <= std_logic_vector(unsigned(elementi_filtrati) + 1);
                    input_start <= std_logic_vector(unsigned(input_start) + 1);
                    write_address <= std_logic_vector(unsigned(write_address) + 1);
                    
                 when S9 =>
                    memory_address <= std_logic_vector(unsigned(memory_address) + 1);
                    
                                                        
                when others => --S4
            end case;
        end if;       
    end process;
    
    filtro : process(i_clk)
        variable tmp1,tmp2,tmp3,tmp4,tmp5, tmp6, tmp7 : signed(15 downto 0);
        variable da_shiftare, shiftato : signed(17 downto 0);
    begin
        if rising_edge(i_clk) then           
            case current_state is
                when S7 =>
                    if tipo_filtro = '0' then
                        tmp1 := (signed(costanti(1)) * signed(input(0)));
                        tmp2 := (signed(costanti(2)) * signed(input(1)));
                        tmp3 := (signed(costanti(3)) * signed(input(2)));
                        tmp4 := (signed(costanti(4)) * signed(input(3)));
                        tmp5 := (signed(costanti(5)) * signed(input(4)));
                        da_shiftare := signed(resize(tmp1, 18)) + signed(resize(tmp2, 18)) + signed(resize(tmp3, 18)) + signed(resize(tmp4, 18)) + signed(resize(tmp5, 18));
                        if da_shiftare >= 0 then
                            shiftato := signed(shift_right(da_shiftare, 4)) + signed(shift_right(da_shiftare, 6)) + signed(shift_right(da_shiftare, 8)) + signed(shift_right(da_shiftare, 10));
                        else
                            shiftato := signed(shift_right(da_shiftare, 4) + 1) + signed(shift_right(da_shiftare, 6) + 1) + signed(shift_right(da_shiftare, 8) + 1) + signed(shift_right(da_shiftare, 10) + 1);
                        end if;
                    else
                        tmp1 := (signed(costanti(0)) * signed(input(0)));
                        tmp2 := (signed(costanti(1)) * signed(input(1)));
                        tmp3 := (signed(costanti(2)) * signed(input(2)));
                        tmp4 := (signed(costanti(3)) * signed(input(3)));
                        tmp5 := (signed(costanti(4)) * signed(input(4)));
                        tmp6 := (signed(costanti(5)) * signed(input(5)));
                        tmp7 := (signed(costanti(6)) * signed(input(6)));
                        da_shiftare := signed(resize(tmp1, 18)) + signed(resize(tmp2, 18)) + signed(resize(tmp3, 18)) + signed(resize(tmp4, 18)) + signed(resize(tmp5, 18)) + signed(resize(tmp6, 18)) + signed(resize(tmp7, 18));
                        if da_shiftare >= 0 then
                            shiftato := signed(shift_right(da_shiftare, 6)) + signed(shift_right(da_shiftare, 10));
                        else
                            shiftato := signed(shift_right(da_shiftare, 6) + 1) + signed(shift_right(da_shiftare, 10) + 1);
                        end if;
                    end if; -- fine (if tipo_filtro = '0')
                    if shiftato < -128 then
                        o_mem_data <= std_logic_vector(to_signed(-128, 8));
                    elsif shiftato > 127 then
                        o_mem_data <= std_logic_vector(to_signed(127, 8));
                    else
                        o_mem_data <= std_logic_vector(shiftato(7 downto 0));
                    end if;  
                    elaborazione_fatta <= '1';
                    
                when others =>
                    elaborazione_fatta <= '0';                   
            end case;                    
        end if;
    end process;

end main_arch;

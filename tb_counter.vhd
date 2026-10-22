library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_counter is
end entity;

architecture sim of tb_counter is 
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal enable : std_logic :='0';
    signal count : std_logic_vector(3 downto 0);
begin
    -- DUT
    dut : entity work.counter
       port map (
        clk => clk,
        reset => reset,
        enable => enable,
        count => count
       );
    
       -- clock for 10ns period
    clk <= not clk after 5 ns;
  
    -- Stimulus + check
    stim : process
    begin
        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        reset <='0';
        wait until rising_edge(clk);
        assert count = "0000" report "after reset count should be 0" severity error;

        -- count for 5 cycles
        enable <= '1';
        for i in 1 to 5 loop
            wait until rising_edge(clk);
            report "Count (binary) = " & to_string(count);
            --report "Count = " & integer'image(to_integer(count));
        end loop ;
        enable <= '0';
        wait until rising_edge(clk);
        assert count = "0101" report "count should be 5" severity error ;


        -- hold : enable =0 must not change
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert count = "0101" report "count should hold at 5" severity error;

        report "TEST FINISHED";
        std.env.finish;
    end process;
end architecture;

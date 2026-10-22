library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    port(
        clk : in std_logic;
        reset : in std_logic;
        enable : in std_logic;
        count : out std_logic_vector(3 downto 0 )
    );
end entity;

architecture rtl of counter is 
    signal cnt : unsigned (3 downto 0) := (others => '0');
begin
    process(clk)
    begin
      if rising_edge(clk)then
        if reset = '1' then
            cnt <= (others => '0');
        elsif enable = '1' then
            cnt <= cnt+1;
        end if;
      end if;
    end process;

    count <= std_logic_vector(cnt);
end architecture;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axi_counter is
end entity;

architecture sim of tb_axi_counter is

    -- ===== Clock and reset =====
    signal clk     : std_logic := '0';
    signal resetn  : std_logic := '0';

    -- ===== AXI wires (connected to the DUT) =====
    signal awaddr  : std_logic_vector(2 downto 0)  := (others => '0');
    signal awvalid : std_logic := '0';
    signal awready : std_logic;
    signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal wvalid  : std_logic := '0';
    signal wready  : std_logic;
    signal bresp   : std_logic_vector(1 downto 0);
    signal bvalid  : std_logic;
    signal bready  : std_logic := '0';
    signal araddr  : std_logic_vector(2 downto 0)  := (others => '0');
    signal arvalid : std_logic := '0';
    signal arready : std_logic;
    signal rdata   : std_logic_vector(31 downto 0);
    signal rresp   : std_logic_vector(1 downto 0);
    signal rvalid  : std_logic;
    signal rready  : std_logic := '0';

    -- ===== Register addresses =====
    constant CTRL  : std_logic_vector(2 downto 0) := "000";   -- 0x0
    constant COUNT : std_logic_vector(2 downto 0) := "100";   -- 0x4

begin

    -- ===== 1. The DUT =====
    dut : entity work.axi_counter
        port map (
            S_AXI_ACLK    => clk,
            S_AXI_ARESETN => resetn,
            S_AXI_AWADDR  => awaddr,
            S_AXI_AWVALID => awvalid,
            S_AXI_AWREADY => awready,
            S_AXI_WDATA   => wdata,
            S_AXI_WVALID  => wvalid,
            S_AXI_WREADY  => wready,
            S_AXI_BRESP   => bresp,
            S_AXI_BVALID  => bvalid,
            S_AXI_BREADY  => bready,
            S_AXI_ARADDR  => araddr,
            S_AXI_ARVALID => arvalid,
            S_AXI_ARREADY => arready,
            S_AXI_RDATA   => rdata,
            S_AXI_RRESP   => rresp,
            S_AXI_RVALID  => rvalid,
            S_AXI_RREADY  => rready
        );

    -- ===== 2. Clock: 10 ns period (100 MHz) =====
    clk <= not clk after 5 ns;

    -- ===== 3. The "CPU": stimulus + checks =====
    stim : process

        variable errors : integer := 0;
        variable data   : std_logic_vector(31 downto 0);
        variable count1 : integer;
        variable count2 : integer;

        -- ---------- CPU write: send address + data, wait for response ----------
        procedure axi_write(addr  : std_logic_vector(2 downto 0);
                            value : std_logic_vector(31 downto 0)) is
        begin
            awaddr  <= addr;
            wdata   <= value;
            awvalid <= '1';
            wvalid  <= '1';
            bready  <= '1';
            loop                                    -- wait for the IP to say READY
                wait until rising_edge(clk);
                exit when awready = '1';
            end loop;
            awvalid <= '0';
            wvalid  <= '0';
            loop                                    -- wait for "write done"
                wait until rising_edge(clk);
                exit when bvalid = '1';
            end loop;
            bready <= '0';
        end procedure;

        -- ---------- CPU read: send address, wait for data ----------
        procedure axi_read(addr  : std_logic_vector(2 downto 0);
                           value : out std_logic_vector(31 downto 0)) is
        begin
            araddr  <= addr;
            arvalid <= '1';
            rready  <= '1';
            loop                                    -- wait for the IP to say READY
                wait until rising_edge(clk);
                exit when arready = '1';
            end loop;
            arvalid <= '0';
            loop                                    -- wait for the data
                wait until rising_edge(clk);
                exit when rvalid = '1';
            end loop;
            value  := rdata;
            rready <= '0';
        end procedure;

        -- ---------- Check: print PASS or FAIL ----------
        procedure check(name : string; ok : boolean) is
        begin
            if ok then
                report "PASS: " & name;
            else
                report "FAIL: " & name severity error;
                errors := errors + 1;
            end if;
        end procedure;

    begin
        -- Reset for 2 clock cycles
        resetn <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        resetn <= '1';
        wait until rising_edge(clk);

        -- Test 1: values after reset
        axi_read(COUNT, data);
        check("COUNT is 0 after reset", data = x"00000000");
        axi_read(CTRL, data);
        check("CTRL is 0 after reset", data = x"00000000");

        -- Test 2: start the counter
        axi_write(CTRL, x"00000001");
        axi_read(CTRL, data);
        check("CTRL reads back 1", data = x"00000001");

        -- Test 3: the counter is counting
        axi_read(COUNT, data);
        count1 := to_integer(unsigned(data));
        wait for 100 ns;
        axi_read(COUNT, data);
        count2 := to_integer(unsigned(data));
        report "  COUNT went from " & integer'image(count1) & " to " & integer'image(count2);
        check("COUNT increases while enabled", count2 > count1);

        -- Test 4: stop the counter
        axi_write(CTRL, x"00000000");
        axi_read(COUNT, data);
        count1 := to_integer(unsigned(data));
        wait for 100 ns;
        axi_read(COUNT, data);
        count2 := to_integer(unsigned(data));
        report "  COUNT stopped at " & integer'image(count1);
        check("COUNT holds when stopped", count2 = count1);

        -- Test 5: COUNT is read-only
        axi_write(COUNT, x"12345678");
        axi_read(COUNT, data);
        check("write to COUNT is ignored", to_integer(unsigned(data)) = count1);

        -- Test 6: only bit 0 of CTRL is stored
        axi_write(CTRL, x"FFFFFFFE");
        axi_read(CTRL, data);
        check("CTRL keeps only bit 0 (wrote FFFFFFFE)", data = x"00000000");

        -- Summary
        if errors = 0 then
            report "===== ALL TESTS PASSED =====";
        else
            report "===== " & integer'image(errors) & " TEST(S) FAILED =====" severity error;
        end if;
        std.env.finish;
    end process;

end architecture;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_counter is
    port (
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;
        -- write address + write data (CPU -> IP)
        S_AXI_AWADDR  : in  std_logic_vector(2 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;
        S_AXI_WDATA   : in  std_logic_vector(31 downto 0);
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;
        -- write response (IP -> CPU)
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;
        -- read address (CPU -> IP)
        S_AXI_ARADDR  : in  std_logic_vector(2 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;
        -- read data (IP -> CPU)
        S_AXI_RDATA   : out std_logic_vector(31 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic
    );
end entity;

architecture rtl of axi_counter is
    signal enable  : std_logic;                -- register 0x0: CTRL (bit 0)
    signal cnt     : unsigned(31 downto 0);    -- register 0x4: COUNT (read-only)
    signal wready  : std_logic;
    signal bvalid  : std_logic;
    signal arready : std_logic;
    signal rvalid  : std_logic;
    signal rdata   : std_logic_vector(31 downto 0);
begin

    -- 1. The counter (same as Step 1)
    counter_proc : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                cnt <= (others => '0');
            elsif enable = '1' then
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    -- 2. AXI write: the CPU writes the CTRL register
    write_proc : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                wready <= '0';
                bvalid <= '0';
                enable <= '0';
            else
                wready <= '0';                                   -- default: not ready
                if S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and wready = '0' and bvalid = '0' then
                    wready <= '1';                               -- accept address + data
                    if S_AXI_AWADDR(2) = '0' then                -- address 0x0 = CTRL
                        enable <= S_AXI_WDATA(0);
                    end if;                                      -- 0x4 = COUNT: read-only, ignored
                end if;

                if wready = '1' then
                    bvalid <= '1';                               -- send "write done"
                elsif S_AXI_BREADY = '1' then
                    bvalid <= '0';                               -- CPU accepted it
                end if;
            end if;
        end if;
    end process;

    -- 3. AXI read: the CPU reads CTRL or COUNT
    read_proc : process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                arready <= '0';
                rvalid  <= '0';
                rdata   <= (others => '0');
            else
                arready <= '0';                                  -- default: not ready
                if S_AXI_ARVALID = '1' and arready = '0' and rvalid = '0' then
                    arready <= '1';                              -- accept address
                    if S_AXI_ARADDR(2) = '0' then
                        rdata <= (0 => enable, others => '0');   -- 0x0: CTRL
                    else
                        rdata <= std_logic_vector(cnt);          -- 0x4: COUNT
                    end if;
                end if;

                if arready = '1' then
                    rvalid <= '1';                               -- send the data
                elsif S_AXI_RREADY = '1' then
                    rvalid <= '0';                               -- CPU took it
                end if;
            end if;
        end if;
    end process;

    -- 4. Connect to the output pins
    S_AXI_AWREADY <= wready;
    S_AXI_WREADY  <= wready;
    S_AXI_BVALID  <= bvalid;
    S_AXI_BRESP   <= "00";          -- OKAY
    S_AXI_ARREADY <= arready;
    S_AXI_RVALID  <= rvalid;
    S_AXI_RDATA   <= rdata;
    S_AXI_RRESP   <= "00";          -- OKAY

end architecture;
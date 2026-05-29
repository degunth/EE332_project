library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity led_status_driver is
    Port (
        clk       : in  std_logic;                    -- 100 MHz system clock
        rst       : in  std_logic;                    -- active-high reset
        fsm_state : in  std_logic_vector(2 downto 0); -- state from vending_fsm
        led       : out std_logic_vector(15 downto 0) -- active-high LEDs
    );
end led_status_driver;

architecture Behavioral of led_status_driver is

    signal flash_cnt     : unsigned(24 downto 0) := (others => '0');
    signal shift_cnt     : unsigned(22 downto 0) := (others => '0');
    signal flash_2hz_flag : std_logic := '0';
    signal shift_reg      : std_logic_vector(15 downto 0) := x"0001";

begin

    -- Clock dividers for blinking and running-light effects
    process(clk, rst)
    begin
        if rst = '1' then
            flash_cnt      <= (others => '0');
            shift_cnt      <= (others => '0');
            flash_2hz_flag <= '0';
            shift_reg      <= x"0001";
        elsif rising_edge(clk) then
            -- 2 Hz blink flag: toggle every 25,000,000 cycles at 100 MHz
            if flash_cnt = to_unsigned(25000000, flash_cnt'length) then
                flash_cnt      <= (others => '0');
                flash_2hz_flag <= not flash_2hz_flag;
            else
                flash_cnt <= flash_cnt + 1;
            end if;

            -- Success state: running light shifts every 5,000,000 cycles, about 20 Hz
            if fsm_state = "010" then
                if shift_cnt = to_unsigned(5000000, shift_cnt'length) then
                    shift_cnt <= (others => '0');
                    shift_reg <= shift_reg(14 downto 0) & shift_reg(15);
                else
                    shift_cnt <= shift_cnt + 1;
                end if;
            else
                shift_reg <= x"0001";
                shift_cnt <= (others => '0');
            end if;
        end if;
    end process;

    -- LED output according to FSM state protocol
    process(fsm_state, shift_reg, flash_2hz_flag)
    begin
        case fsm_state is
            when "000" | "001" =>
                -- IDLE / COMPARE: LEDs off
                led <= x"0000";

            when "010" =>
                -- Transaction success: running light
                led <= shift_reg;

            when "011" =>
                -- Low balance: all LEDs blink at 2 Hz
                if flash_2hz_flag = '1' then
                    led <= x"FFFF";
                else
                    led <= x"0000";
                end if;

            when "100" =>
                -- Out of stock: odd/even alternating alert
                if flash_2hz_flag = '1' then
                    led <= x"AAAA";
                else
                    led <= x"5555";
                end if;

            when others =>
                led <= x"0000";
        end case;
    end process;

end Behavioral;

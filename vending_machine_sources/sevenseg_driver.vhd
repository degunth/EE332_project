library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sevenseg_driver is
    Port (
        clk          : in  std_logic;                     -- 100 MHz system clock
        rst          : in  std_logic;                     -- active-high reset
        user_balance : in  std_logic_vector(7 downto 0);  -- balance from payment_controller
        fsm_state    : in  std_logic_vector(2 downto 0);  -- state from vending_fsm
        seg          : out std_logic_vector(7 downto 0);  -- DP,G,F,E,D,C,B,A, active low
        an           : out std_logic_vector(7 downto 0)   -- AN0~AN7, active low
    );
end sevenseg_driver;

architecture Behavioral of sevenseg_driver is

    -- Dynamic scan divider: use refresh_cnt(16 downto 14) as 8-way selector
    signal refresh_cnt : unsigned(16 downto 0) := (others => '0');
    signal scan_sel    : std_logic_vector(2 downto 0);

    -- 2 Hz blinking flag for low-balance warning
    signal flash_cnt  : unsigned(24 downto 0) := (others => '0');
    signal flash_flag : std_logic := '1';

    -- Binary-to-decimal digits for user_balance
    signal balance_int : integer range 0 to 255;
    signal digit_hun   : integer range 0 to 9;
    signal digit_ten   : integer range 0 to 9;
    signal digit_one   : integer range 0 to 9;

    -- 0~9: number, 12: r, 14: E, 15: blank
    signal current_digit : integer range 0 to 15;

begin

    -- Binary to BCD-like decimal digit extraction
    balance_int <= to_integer(unsigned(user_balance));
    digit_hun   <= balance_int / 100;
    digit_ten   <= (balance_int mod 100) / 10;
    digit_one   <= balance_int mod 10;

    -- Scan divider and flash divider
    process(clk, rst)
    begin
        if rst = '1' then
            refresh_cnt <= (others => '0');
            flash_cnt   <= (others => '0');
            flash_flag  <= '1';
        elsif rising_edge(clk) then
            refresh_cnt <= refresh_cnt + 1;

            -- 100 MHz / 25,000,000 toggles at 4 Hz, giving a 2 Hz full blink period
            if flash_cnt = to_unsigned(25000000, flash_cnt'length) then
                flash_cnt  <= (others => '0');
                flash_flag <= not flash_flag;
            else
                flash_cnt <= flash_cnt + 1;
            end if;
        end if;
    end process;

    scan_sel <= std_logic_vector(refresh_cnt(16 downto 14));

    -- Digit selection and state-specific display behavior
    process(scan_sel, digit_hun, digit_ten, digit_one, fsm_state, flash_flag)
    begin
        -- In low-balance state, blink all digits off for half of the time
        if fsm_state = "011" and flash_flag = '0' then
            an <= "11111111";
            current_digit <= 15;
        else
            an <= "11111111";
            current_digit <= 15;

            case scan_sel is
                when "000" => -- AN0: ones digit
                    an(0) <= '0';
                    current_digit <= digit_one;

                when "001" => -- AN1: tens digit, blank leading zero
                    an(1) <= '0';
                    if digit_hun = 0 and digit_ten = 0 then
                        current_digit <= 15;
                    else
                        current_digit <= digit_ten;
                    end if;

                when "010" => -- AN2: hundreds digit, blank leading zero
                    an(2) <= '0';
                    if digit_hun = 0 then
                        current_digit <= 15;
                    else
                        current_digit <= digit_hun;
                    end if;

                -- In out-of-stock state, show Err on the left side: AN7='E', AN6='r', AN5='r'
                when "101" =>
                    an(5) <= '0';
                    if fsm_state = "100" then
                        current_digit <= 12; -- r
                    else
                        current_digit <= 15;
                    end if;

                when "110" =>
                    an(6) <= '0';
                    if fsm_state = "100" then
                        current_digit <= 12; -- r
                    else
                        current_digit <= 15;
                    end if;

                when "111" =>
                    an(7) <= '0';
                    if fsm_state = "100" then
                        current_digit <= 14; -- E
                    else
                        current_digit <= 15;
                    end if;

                when others =>
                    an <= "11111111";
                    current_digit <= 15;
            end case;
        end if;
    end process;

    -- Seven-segment decoder for common-anode, active-low segments
    -- Segment order: DP, G, F, E, D, C, B, A
    process(current_digit)
    begin
        case current_digit is
            when 0  => seg <= "11000000"; -- 0
            when 1  => seg <= "11111001"; -- 1
            when 2  => seg <= "10100100"; -- 2
            when 3  => seg <= "10110000"; -- 3
            when 4  => seg <= "10011001"; -- 4
            when 5  => seg <= "10010010"; -- 5
            when 6  => seg <= "10000010"; -- 6
            when 7  => seg <= "11111000"; -- 7
            when 8  => seg <= "10000000"; -- 8
            when 9  => seg <= "10010000"; -- 9
            when 12 => seg <= "10101111"; -- r
            when 14 => seg <= "10000110"; -- E
            when 15 => seg <= "11111111"; -- blank
            when others => seg <= "11111111";
        end case;
    end process;

end Behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port (
        CLK100MHZ     : in  std_logic;
        product_id    : in  std_logic_vector(3 downto 0); -- Product selection index SW(3:0)
        product_price : in  std_logic_vector(7 downto 0); -- Selected product price
        product_stock : in  std_logic_vector(7 downto 0); -- Selected product stock
        user_balance  : in  std_logic_vector(7 downto 0); -- Current user balance
        fsm_state     : in  std_logic_vector(2 downto 0); -- State code from FSM
        VGA_R         : out std_logic_vector(3 downto 0);
        VGA_G         : out std_logic_vector(3 downto 0);
        VGA_B         : out std_logic_vector(3 downto 0);
        VGA_HS        : out std_logic;
        VGA_VS        : out std_logic
    );
end vga_controller;

architecture Behavioral of vga_controller is

    -- 640 x 480 @ 60 Hz VGA timing constants
    constant H_VISIBLE : integer := 640;
    constant H_FRONT   : integer := 16;
    constant H_SYNC    : integer := 96;
    constant H_BACK    : integer := 48;
    constant H_TOTAL   : integer := 800;

    constant V_VISIBLE : integer := 480;
    constant V_FRONT   : integer := 10;
    constant V_SYNC    : integer := 2;
    constant V_BACK    : integer := 33;
    constant V_TOTAL   : integer := 525;

    -- 5x7 Pixel Font ROM: support 0-9, B, A, L, P, R, C, S, T, K, :, space, U, E, O, W, N, Y, M
    type font_matrix is array(0 to 27, 0 to 6) of std_logic_vector(4 downto 0);
    constant FONT_ROM : font_matrix := (
        0  => ("11111", "10001", "10001", "10001", "10001", "10001", "11111"), -- 0
        1  => ("00100", "01100", "00100", "00100", "00100", "00100", "01110"), -- 1
        2  => ("11111", "00001", "00001", "11111", "10000", "10000", "11111"), -- 2
        3  => ("11111", "00001", "00001", "11111", "00001", "00001", "11111"), -- 3
        4  => ("10001", "10001", "10001", "11111", "00001", "00001", "00001"), -- 4
        5  => ("11111", "10000", "10000", "11111", "00001", "00001", "11111"), -- 5
        6  => ("11111", "10000", "10000", "11111", "10001", "10001", "11111"), -- 6
        7  => ("11111", "00001", "00001", "00010", "00100", "00100", "00100"), -- 7
        8  => ("11111", "10001", "10001", "11111", "10001", "10001", "11111"), -- 8
        9  => ("11111", "10001", "10001", "11111", "00001", "00001", "11111"), -- 9 (Fixed from '3' typo!)
        10 => ("11110", "10001", "10001", "11110", "10001", "10001", "11110"), -- B
        11 => ("01110", "10001", "10001", "11111", "10001", "10001", "10001"), -- A
        12 => ("10000", "10000", "10000", "10000", "10000", "10000", "11111"), -- L
        13 => ("11110", "10001", "10001", "11110", "10000", "10000", "10000"), -- P
        14 => ("11110", "10001", "10001", "11110", "10100", "10010", "10001"), -- R
        15 => ("01111", "10000", "10000", "10000", "10000", "10000", "01111"), -- C
        16 => ("01111", "10000", "10000", "01111", "00001", "00001", "11110"), -- S
        17 => ("11111", "00100", "00100", "00100", "00100", "00100", "00100"), -- T
        18 => ("10001", "10010", "10100", "11000", "10100", "10010", "10001"), -- K
        19 => ("00000", "01100", "01100", "00000", "01100", "01100", "00000"), -- :
        20 => ("00000", "00000", "00000", "00000", "00000", "00000", "00000"), -- space
        21 => ("10001", "10001", "10001", "10001", "10001", "10001", "01110"), -- U
        22 => ("11111", "10000", "10000", "11110", "10000", "10000", "11111"), -- E
        23 => ("01110", "10001", "10001", "10001", "10001", "10001", "01110"), -- O
        24 => ("10001", "10001", "10001", "10101", "10101", "10101", "01010"), -- W
        25 => ("10001", "11001", "10101", "10101", "10011", "10011", "10001"), -- N
        26 => ("10001", "10001", "01010", "00100", "00100", "00100", "00100"), -- Y
        27 => ("10001", "11011", "10101", "10101", "10001", "10001", "10001")  -- M
    );

    -- 25 MHz pixel enable from 100 MHz clock
    signal clk_div : unsigned(1 downto 0) := (others => '0');
    signal pix_ce  : std_logic := '0';

    signal h_cnt : integer range 0 to H_TOTAL - 1 := 0;
    signal v_cnt : integer range 0 to V_TOTAL - 1 := 0;

    signal video_on : std_logic;

    signal r_reg : std_logic_vector(3 downto 0) := (others => '0');
    signal g_reg : std_logic_vector(3 downto 0) := (others => '0');
    signal b_reg : std_logic_vector(3 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- Pixel clock enable: 100 MHz / 4 = 25 MHz
    --------------------------------------------------------------------
    process(CLK100MHZ)
    begin
        if rising_edge(CLK100MHZ) then
            clk_div <= clk_div + 1;
            if clk_div = "11" then
                pix_ce <= '1';
            else
                pix_ce <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- VGA horizontal and vertical counters
    --------------------------------------------------------------------
    process(CLK100MHZ)
    begin
        if rising_edge(CLK100MHZ) then
            if pix_ce = '1' then
                if h_cnt = H_TOTAL - 1 then
                    h_cnt <= 0;
                    if v_cnt = V_TOTAL - 1 then
                        v_cnt <= 0;
                    else
                        v_cnt <= v_cnt + 1;
                    end if;
                else
                    h_cnt <= h_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- VGA sync signals
    --------------------------------------------------------------------
    VGA_HS <= '0' when (h_cnt >= H_VISIBLE + H_FRONT and
                        h_cnt <  H_VISIBLE + H_FRONT + H_SYNC) else '1';

    VGA_VS <= '0' when (v_cnt >= V_VISIBLE + V_FRONT and
                        v_cnt <  V_VISIBLE + V_FRONT + V_SYNC) else '1';

    video_on <= '1' when (h_cnt < H_VISIBLE and v_cnt < V_VISIBLE) else '0';

    --------------------------------------------------------------------
    -- UI renderer
    --------------------------------------------------------------------
    process(h_cnt, v_cnt, video_on, product_id, user_balance, product_stock, product_price, fsm_state)
        variable selected_id : integer;
        variable card_x      : integer;
        variable card_y      : integer;
        variable col         : integer;
        variable row         : integer;
        variable local_x     : integer;
        variable local_y     : integer;
        variable inside_card : boolean;
        variable on_border   : boolean;

        -- Local variables for BCD decoding
        variable bal_val     : integer;
        variable bal_hun     : integer;
        variable bal_ten     : integer;
        variable bal_one     : integer;

        variable stock_val   : integer;
        variable stock_ten   : integer;
        variable stock_one   : integer;

        variable price_val   : integer;
        variable price_ten   : integer;
        variable price_one   : integer;

        -- Helper variables for pixel-font rendering
        variable char_col    : integer;
        variable char_idx    : integer;
    begin

        -- Extract decimal digits from input vectors
        bal_val   := to_integer(unsigned(user_balance));
        bal_hun   := bal_val / 100;
        bal_ten   := (bal_val mod 100) / 10;
        bal_one   := bal_val mod 10;

        stock_val := to_integer(unsigned(product_stock));
        stock_ten := stock_val / 10;
        stock_one := stock_val mod 10;

        price_val := to_integer(unsigned(product_price));
        price_ten := price_val / 10;
        price_one := price_val mod 10;

        -- Map selection product_id directly to integer
        selected_id := to_integer(unsigned(product_id));

        ----------------------------------------------------------------
        -- Default background
        ----------------------------------------------------------------
        r_reg <= "0001";
        g_reg <= "0001";
        b_reg <= "0011";

        if video_on = '0' then
            r_reg <= "0000";
            g_reg <= "0000";
            b_reg <= "0000";
        else

            ------------------------------------------------------------
            -- Top title bar
            ------------------------------------------------------------
            if v_cnt >= 20 and v_cnt < 55 then
                r_reg <= "0010";
                g_reg <= "0010";
                b_reg <= "0110";
            end if;

            ------------------------------------------------------------
            -- Bottom information bar
            ------------------------------------------------------------
            if v_cnt >= 400 and v_cnt < 455 then
                r_reg <= "0011";
                g_reg <= "0011";
                b_reg <= "0011";
            end if;

            ------------------------------------------------------------
            -- Draw 16 product cards: 4 columns x 4 rows
            ------------------------------------------------------------
            for i in 0 to 15 loop
                col := i mod 4;
                row := i / 4;

                card_x := 60 + col * 145;
                card_y := 70 + row * 80;

                inside_card := (h_cnt >= card_x and h_cnt < card_x + 110 and
                                v_cnt >= card_y and v_cnt < card_y + 65);

                on_border := inside_card and
                             (h_cnt < card_x + 3 or h_cnt >= card_x + 107 or
                              v_cnt < card_y + 3 or v_cnt >= card_y + 62);

                if inside_card then
                    local_x := h_cnt - card_x;
                    local_y := v_cnt - card_y;

                    -- Card background
                    r_reg <= "1100";
                    g_reg <= "1100";
                    b_reg <= "1100";

                    -- Product 0 & 8: Water (0: Blue Bottle, 8: Green Bottle)
                    if i = 0 or i = 8 then
                        if local_x >= 42 and local_x < 68 and local_y >= 18 and local_y < 55 then
                            if i = 0 then
                                r_reg <= "0010"; g_reg <= "0110"; b_reg <= "1111"; -- Blue
                            else
                                r_reg <= "0010"; g_reg <= "1100"; b_reg <= "0010"; -- Green
                            end if;
                        end if;
                        if local_x >= 48 and local_x < 62 and local_y >= 10 and local_y < 18 then
                            if i = 0 then
                                r_reg <= "0011"; g_reg <= "1000"; b_reg <= "1111";
                            else
                                r_reg <= "0011"; g_reg <= "1110"; b_reg <= "0011";
                            end if;
                        end if;
                        if local_x >= 45 and local_x < 65 and local_y >= 6 and local_y < 10 then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                        if local_x >= 45 and local_x < 65 and local_y >= 32 and local_y < 40 then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                    end if;

                    -- Product 1 & 9: Cola (1: Red Can, 9: Orange/Yellow Soda Can)
                    if i = 1 or i = 9 then
                        if local_x >= 35 and local_x < 75 and local_y >= 12 and local_y < 55 then
                            if i = 1 then
                                r_reg <= "1111"; g_reg <= "0001"; b_reg <= "0001"; -- Red
                            else
                                r_reg <= "1111"; g_reg <= "1000"; b_reg <= "0000"; -- Orange
                            end if;
                        end if;
                        if local_x >= 35 and local_x < 75 and ((local_y >= 12 and local_y < 17) or (local_y >= 50 and local_y < 55)) then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                        if local_x >= 39 and local_x < 71 and local_y >= 28 and local_y < 35 then
                            if i = 1 then
                                r_reg <= "0100"; g_reg <= "0000"; b_reg <= "0000";
                            else
                                r_reg <= "0110"; g_reg <= "0011"; b_reg <= "0000";
                            end if;
                        end if;
                    end if;

                    -- Product 2 & 10: Coffee Cup (2: Brown Cup, 10: Blue Cup)
                    if i = 2 or i = 10 then
                        if local_x >= 35 and local_x < 72 and local_y >= 24 and local_y < 55 then
                            if i = 2 then
                                r_reg <= "0110"; g_reg <= "0011"; b_reg <= "0001"; -- Brown
                            else
                                r_reg <= "0001"; g_reg <= "0011"; b_reg <= "1001"; -- Blue
                            end if;
                        end if;
                        if local_x >= 30 and local_x < 77 and local_y >= 18 and local_y < 26 then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                        if local_x >= 35 and local_x < 72 and local_y >= 20 and local_y < 24 then
                            if i = 2 then
                                r_reg <= "0100"; g_reg <= "0010"; b_reg <= "0000";
                            else
                                r_reg <= "0000"; g_reg <= "0001"; b_reg <= "0101";
                            end if;
                        end if;
                        if local_x >= 72 and local_x < 85 and local_y >= 28 and local_y < 46 then
                            if i = 2 then
                                r_reg <= "0110"; g_reg <= "0011"; b_reg <= "0001";
                            else
                                r_reg <= "0001"; g_reg <= "0011"; b_reg <= "1001";
                            end if;
                        end if;
                        if local_x >= 76 and local_x < 81 and local_y >= 32 and local_y < 42 then
                            r_reg <= "1100"; g_reg <= "1100"; b_reg <= "1100"; -- Matches background
                        end if;
                    end if;

                    -- Product 3 & 11: Cake Block (3: Yellow Bread, 11: Green Matcha Cake)
                    if i = 3 or i = 11 then
                        if local_x >= 25 and local_x < 85 and local_y >= 28 and local_y < 55 then
                            if i = 3 then
                                r_reg <= "1111"; g_reg <= "1100"; b_reg <= "0010"; -- Yellow
                            else
                                r_reg <= "0010"; g_reg <= "1100"; b_reg <= "0010"; -- Matcha Green
                            end if;
                        end if;
                        if local_x >= 35 and local_x < 75 and local_y >= 16 and local_y < 28 then
                            if i = 3 then
                                r_reg <= "1111"; g_reg <= "1010"; b_reg <= "0010";
                            else
                                r_reg <= "0100"; g_reg <= "1110"; b_reg <= "0100";
                            end if;
                        end if;
                        if (local_x >= 38 and local_x < 45 and local_y >= 36 and local_y < 42) or
                           (local_x >= 58 and local_x < 65 and local_y >= 36 and local_y < 42) then
                            if i = 3 then
                                r_reg <= "1000"; g_reg <= "0100"; b_reg <= "0000";
                            else
                                r_reg <= "0001"; g_reg <= "0110"; b_reg <= "0001";
                            end if;
                        end if;
                    end if;

                    -- Product 4 & 12: Chips Bag (4: Purple Bag, 12: Red Bag)
                    if i = 4 or i = 12 then
                        if local_x >= 30 and local_x < 80 and local_y >= 12 and local_y < 56 then
                            if i = 4 then
                                r_reg <= "1000"; g_reg <= "0010"; b_reg <= "1111"; -- Purple
                            else
                                r_reg <= "1111"; g_reg <= "0001"; b_reg <= "0001"; -- Red
                            end if;
                        end if;
                        if local_x >= 38 and local_x < 72 and local_y >= 26 and local_y < 42 then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "0010"; -- Yellow Label
                        end if;
                        if local_x >= 30 and local_x < 80 and ((local_y >= 12 and local_y < 17) or (local_y >= 50 and local_y < 56)) then
                            if i = 4 then
                                r_reg <= "0101"; g_reg <= "0000"; b_reg <= "1010";
                            else
                                r_reg <= "1000"; g_reg <= "0000"; b_reg <= "0000";
                            end if;
                        end if;
                    end if;

                    -- Product 5 & 13: Milk Carton (5: White/Blue Carton, 13: Yellow Banana Milk Carton)
                    if i = 5 or i = 13 then
                        if local_x >= 35 and local_x < 75 and local_y >= 20 and local_y < 56 then
                            if i = 5 then
                                r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111"; -- White
                            else
                                r_reg <= "1111"; g_reg <= "1111"; b_reg <= "0110"; -- Yellow
                            end if;
                        end if;
                        if local_x >= 40 and local_x < 70 and local_y >= 10 and local_y < 20 then
                            if i = 5 then
                                r_reg <= "0010"; g_reg <= "0110"; b_reg <= "1111"; -- Blue
                            else
                                r_reg <= "1111"; g_reg <= "1010"; b_reg <= "0000"; -- Banana Yellow
                            end if;
                        end if;
                        if local_x >= 42 and local_x < 68 and local_y >= 34 and local_y < 43 then
                            if i = 5 then
                                r_reg <= "0010"; g_reg <= "0110"; b_reg <= "1111";
                            else
                                r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                            end if;
                        end if;
                        if local_x >= 68 and local_x < 75 and local_y >= 20 and local_y < 56 then
                            if i = 5 then
                                r_reg <= "1010"; g_reg <= "1010"; b_reg <= "1010";
                            else
                                r_reg <= "1100"; g_reg <= "1100"; b_reg <= "0100";
                            end if;
                        end if;
                    end if;

                    -- Product 6 & 14: Candy (6: Green Candy, 14: Pink Candy)
                    if i = 6 or i = 14 then
                        if local_x >= 38 and local_x < 72 and local_y >= 24 and local_y < 44 then
                            if i = 6 then
                                r_reg <= "0010"; g_reg <= "1111"; b_reg <= "0010"; -- Green
                            else
                                r_reg <= "1111"; g_reg <= "0100"; b_reg <= "1000"; -- Pink
                            end if;
                        end if;
                        if local_x >= 20 and local_x < 38 and local_y >= 29 and local_y < 39 then
                            if i = 6 then
                                r_reg <= "0001"; g_reg <= "1000"; b_reg <= "0001";
                            else
                                r_reg <= "1010"; g_reg <= "0010"; b_reg <= "0101";
                            end if;
                        end if;
                        if local_x >= 72 and local_x < 90 and local_y >= 29 and local_y < 39 then
                            if i = 6 then
                                r_reg <= "0001"; g_reg <= "1000"; b_reg <= "0001";
                            else
                                r_reg <= "1010"; g_reg <= "0010"; b_reg <= "0101";
                            end if;
                        end if;
                        if local_x >= 45 and local_x < 65 and local_y >= 29 and local_y < 33 then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                    end if;

                    -- Product 7 & 15: Orange Juice Bottle (7: Orange Bottle, 15: Purple Grape Bottle)
                    if i = 7 or i = 15 then
                        if local_x >= 40 and local_x < 70 and local_y >= 18 and local_y < 55 then
                            if i = 7 then
                                r_reg <= "1111"; g_reg <= "1000"; b_reg <= "0000"; -- Orange
                            else
                                r_reg <= "1000"; g_reg <= "0001"; b_reg <= "1111"; -- Purple Grape
                            end if;
                        end if;
                        if local_x >= 47 and local_x < 63 and local_y >= 10 and local_y < 18 then
                            if i = 7 then
                                r_reg <= "1111"; g_reg <= "1010"; b_reg <= "0010";
                            else
                                r_reg <= "1011"; g_reg <= "0011"; b_reg <= "1111";
                            end if;
                        end if;
                        if local_x >= 45 and local_x < 65 and local_y >= 6 and local_y < 10 then
                            r_reg <= "0010"; g_reg <= "1111"; b_reg <= "0010"; -- Green Cap
                        end if;
                        if local_x >= 44 and local_x < 66 and local_y >= 32 and local_y < 40 then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                    end if;

                    -- Normal border: black
                    if on_border then
                        r_reg <= "0000"; g_reg <= "0000"; b_reg <= "0000";
                    end if;

                    -- Selected product border: red
                    if i = selected_id and on_border then
                        r_reg <= "1111"; g_reg <= "0000"; b_reg <= "0000";
                    end if;
                end if;
            end loop;

            ------------------------------------------------------------
            -- Bottom information text rendering (using 5x7 Pixel Font)
            ------------------------------------------------------------
            if v_cnt >= 415 and v_cnt < 436 then
                
                -- 1. Balance Display (BAL: XXX) starting at h_cnt = 50
                if h_cnt >= 50 and h_cnt < 218 then
                    char_col := (h_cnt - 50) / 21;
                    local_x  := ((h_cnt - 50) mod 21) / 3;
                    local_y  := (v_cnt - 415) / 3;
                    
                    if local_x < 5 and local_y < 7 then
                        case char_col is
                            when 0 => char_idx := 10; -- B
                            when 1 => char_idx := 11; -- A
                            when 2 => char_idx := 12; -- L
                            when 3 => char_idx := 19; -- :
                            when 4 => char_idx := 20; -- space
                            when 5 => char_idx := bal_hun;
                            when 6 => char_idx := bal_ten;
                            when 7 => char_idx := bal_one;
                            when others => char_idx := 20;
                        end case;
                        
                        if FONT_ROM(char_idx, local_y)(4 - local_x) = '1' then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                    end if;

                -- 2. Price Display (PRC: XX) starting at h_cnt = 250
                elsif h_cnt >= 250 and h_cnt < 397 then
                    char_col := (h_cnt - 250) / 21;
                    local_x  := ((h_cnt - 250) mod 21) / 3;
                    local_y  := (v_cnt - 415) / 3;
                    
                    if local_x < 5 and local_y < 7 then
                        case char_col is
                            when 0 => char_idx := 13; -- P
                            when 1 => char_idx := 14; -- R
                            when 2 => char_idx := 15; -- C
                            when 3 => char_idx := 19; -- :
                            when 4 => char_idx := 20; -- space
                            when 5 => char_idx := price_ten;
                            when 6 => char_idx := price_one;
                            when others => char_idx := 20;
                        end case;
                        
                        if FONT_ROM(char_idx, local_y)(4 - local_x) = '1' then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                    end if;

                -- 3. Stock Display (STK: XX) starting at h_cnt = 430
                elsif h_cnt >= 430 and h_cnt < 577 then
                    char_col := (h_cnt - 430) / 21;
                    local_x  := ((h_cnt - 430) mod 21) / 3;
                    local_y  := (v_cnt - 415) / 3;
                    
                    if local_x < 5 and local_y < 7 then
                        case char_col is
                            when 0 => char_idx := 16; -- S
                            when 1 => char_idx := 17; -- T
                            when 2 => char_idx := 18; -- K
                            when 3 => char_idx := 19; -- :
                            when 4 => char_idx := 20; -- space
                            when 5 => char_idx := stock_ten;
                            when 6 => char_idx := stock_one;
                            when others => char_idx := 20;
                        end case;
                        
                        if FONT_ROM(char_idx, local_y)(4 - local_x) = '1' then
                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                        end if;
                    end if;
                end if;
            end if;

            ------------------------------------------------------------
            -- Pop-up Warning Box Rendering (Overlays screen in central area)
            ------------------------------------------------------------
            if (fsm_state = "010" or fsm_state = "011" or fsm_state = "100") then
                if h_cnt >= 170 and h_cnt < 470 and v_cnt >= 190 and v_cnt < 290 then
                    -- Draw 3px white border around pop-up
                    if h_cnt < 173 or h_cnt >= 467 or v_cnt < 193 or v_cnt >= 287 then
                        r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                    else
                        -- Draw solid box backgrounds
                        if fsm_state = "010" then     -- Success state: Green
                            r_reg <= "0000"; g_reg <= "1000"; b_reg <= "0000";
                        elsif fsm_state = "011" then  -- Low Balance error: Red
                            r_reg <= "1000"; g_reg <= "0000"; b_reg <= "0000";
                        else                          -- Out of Stock error: Yellow
                            r_reg <= "1000"; g_reg <= "0110"; b_reg <= "0000";
                        end if;
                        
                        -- Draw Centered Pixel text inside the box
                        if v_cnt >= 225 and v_cnt < 246 then
                            if fsm_state = "010" then -- "SUCCESS" starting at X=247
                                if h_cnt >= 247 and h_cnt < 394 then
                                    char_col := (h_cnt - 247) / 21;
                                    local_x  := ((h_cnt - 247) mod 21) / 3;
                                    local_y  := (v_cnt - 225) / 3;
                                    if local_x < 5 and local_y < 7 then
                                        case char_col is
                                            when 0 => char_idx := 16; -- S
                                            when 1 => char_idx := 21; -- U
                                            when 2 => char_idx := 15; -- C
                                            when 3 => char_idx := 15; -- C
                                            when 4 => char_idx := 22; -- E
                                            when 5 => char_idx := 16; -- S
                                            when 6 => char_idx := 16; -- S
                                            when others => char_idx := 20;
                                        end case;
                                        if FONT_ROM(char_idx, local_y)(4 - local_x) = '1' then
                                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                                        end if;
                                    end if;
                                end if;
                            
                            elsif fsm_state = "011" then -- "LOW BAL" starting at X=247
                                if h_cnt >= 247 and h_cnt < 394 then
                                    char_col := (h_cnt - 247) / 21;
                                    local_x  := ((h_cnt - 247) mod 21) / 3;
                                    local_y  := (v_cnt - 225) / 3;
                                    if local_x < 5 and local_y < 7 then
                                        case char_col is
                                            when 0 => char_idx := 12; -- L
                                            when 1 => char_idx := 23; -- O
                                            when 2 => char_idx := 24; -- W
                                            when 3 => char_idx := 20; -- space
                                            when 4 => char_idx := 10; -- B
                                            when 5 => char_idx := 11; -- A
                                            when 6 => char_idx := 12; -- L
                                            when others => char_idx := 20;
                                        end case;
                                        if FONT_ROM(char_idx, local_y)(4 - local_x) = '1' then
                                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                                        end if;
                                    end if;
                                end if;

                            elsif fsm_state = "100" then -- "NO STOCK" starting at X=236
                                if h_cnt >= 236 and h_cnt < 404 then
                                    char_col := (h_cnt - 236) / 21;
                                    local_x  := ((h_cnt - 236) mod 21) / 3;
                                    local_y  := (v_cnt - 225) / 3;
                                    if local_x < 5 and local_y < 7 then
                                        case char_col is
                                            when 0 => char_idx := 25; -- N
                                            when 1 => char_idx := 23; -- O
                                            when 2 => char_idx := 20; -- space
                                            when 3 => char_idx := 16; -- S
                                            when 4 => char_idx := 17; -- T
                                            when 5 => char_idx := 23; -- O
                                            when 6 => char_idx := 15; -- C
                                            when 7 => char_idx := 18; -- K
                                            when others => char_idx := 20;
                                        end case;
                                        if FONT_ROM(char_idx, local_y)(4 - local_x) = '1' then
                                            r_reg <= "1111"; g_reg <= "1111"; b_reg <= "1111";
                                        end if;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end if;

        end if;
    end process;

    VGA_R <= r_reg;
    VGA_G <= g_reg;
    VGA_B <= b_reg;

end Behavioral;

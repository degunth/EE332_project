library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_vending_demo_top is
    Port (
        CLK100MHZ : in  STD_LOGIC;

        -- SW(0) -> Product 1
        -- SW(1) -> Product 2
        -- ...
        -- SW(7) -> Product 8
        SW        : in  STD_LOGIC_VECTOR(7 downto 0);

        -- New dynamic inputs for Vending Machine FSM and Payment calculations
        user_balance  : in  STD_LOGIC_VECTOR(7 downto 0);
        product_stock : in  STD_LOGIC_VECTOR(7 downto 0);
        product_price : in  STD_LOGIC_VECTOR(7 downto 0);

        VGA_R     : out STD_LOGIC_VECTOR(3 downto 0);
        VGA_G     : out STD_LOGIC_VECTOR(3 downto 0);
        VGA_B     : out STD_LOGIC_VECTOR(3 downto 0);
        VGA_HS    : out STD_LOGIC;
        VGA_VS    : out STD_LOGIC
    );
end vga_vending_demo_top;

architecture Behavioral of vga_vending_demo_top is

    -- 640 x 480 @ 60 Hz VGA timing
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

    -- 5x7 Pixel Font ROM: support 0-9, B, A, L, P, R, C, S, T, K, :, space
    type font_matrix is array(0 to 20, 0 to 6) of std_logic_vector(4 downto 0);
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
        9  => ("11111", "00001", "00001", "11111", "00001", "00001", "11111"), -- 9
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
        20 => ("00000", "00000", "00000", "00000", "00000", "00000", "00000")  -- space
    );

    -- Generate approximate 25 MHz pixel enable from 100 MHz clock
    signal clk_div : unsigned(1 downto 0) := (others => '0');
    signal pix_ce  : STD_LOGIC := '0';

    signal h_cnt : integer range 0 to H_TOTAL - 1 := 0;
    signal v_cnt : integer range 0 to V_TOTAL - 1 := 0;

    signal video_on : STD_LOGIC;

    signal r_reg : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal g_reg : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal b_reg : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

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
    -- VGA sync signals, active low
    --------------------------------------------------------------------
    VGA_HS <= '0' when (h_cnt >= H_VISIBLE + H_FRONT and
                        h_cnt <  H_VISIBLE + H_FRONT + H_SYNC) else '1';

    VGA_VS <= '0' when (v_cnt >= V_VISIBLE + V_FRONT and
                        v_cnt <  V_VISIBLE + V_FRONT + V_SYNC) else '1';

    video_on <= '1' when (h_cnt < H_VISIBLE and v_cnt < V_VISIBLE) else '0';

    --------------------------------------------------------------------
    -- UI renderer
    -- Draw 8 vending-machine product cards and simple pixel icons
    --------------------------------------------------------------------
    process(h_cnt, v_cnt, video_on, SW, user_balance, product_stock, product_price)
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

        ----------------------------------------------------------------
        -- One-switch-one-product selection logic
        -- Priority rule:
        -- if multiple switches are on, the lower-index switch has priority.
        -- SW(0) selects Product 1, SW(1) selects Product 2, ..., SW(7) selects Product 8.
        ----------------------------------------------------------------
        if SW(0) = '1' then
            selected_id := 0;
        elsif SW(1) = '1' then
            selected_id := 1;
        elsif SW(2) = '1' then
            selected_id := 2;
        elsif SW(3) = '1' then
            selected_id := 3;
        elsif SW(4) = '1' then
            selected_id := 4;
        elsif SW(5) = '1' then
            selected_id := 5;
        elsif SW(6) = '1' then
            selected_id := 6;
        elsif SW(7) = '1' then
            selected_id := 7;
        else
            selected_id := 0;
        end if;

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
            -- Draw 8 product cards: 4 columns x 2 rows
            ------------------------------------------------------------
            for i in 0 to 7 loop

                col := i mod 4;
                row := i / 4;

                card_x := 60 + col * 145;
                card_y := 90 + row * 135;

                inside_card := (h_cnt >= card_x and h_cnt < card_x + 110 and
                                v_cnt >= card_y and v_cnt < card_y + 90);

                on_border := inside_card and
                             (h_cnt < card_x + 4 or h_cnt >= card_x + 106 or
                              v_cnt < card_y + 4 or v_cnt >= card_y + 86);

                if inside_card then

                    local_x := h_cnt - card_x;
                    local_y := v_cnt - card_y;

                    ----------------------------------------------------
                    -- Card background
                    ----------------------------------------------------
                    r_reg <= "1100";
                    g_reg <= "1100";
                    b_reg <= "1100";

                    ----------------------------------------------------
                    -- Product 1: Water, blue bottle
                    ----------------------------------------------------
                    if i = 0 then
                        -- bottle body
                        if local_x >= 42 and local_x < 68 and
                           local_y >= 25 and local_y < 75 then
                            r_reg <= "0010";
                            g_reg <= "0110";
                            b_reg <= "1111";
                        end if;

                        -- bottle neck
                        if local_x >= 48 and local_x < 62 and
                           local_y >= 15 and local_y < 25 then
                            r_reg <= "0011";
                            g_reg <= "1000";
                            b_reg <= "1111";
                        end if;

                        -- bottle cap
                        if local_x >= 45 and local_x < 65 and
                           local_y >= 10 and local_y < 15 then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
                        end if;

                        -- label
                        if local_x >= 45 and local_x < 65 and
                           local_y >= 45 and local_y < 55 then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Product 2: Cola, red can
                    ----------------------------------------------------
                    if i = 1 then
                        -- can body
                        if local_x >= 35 and local_x < 75 and
                           local_y >= 18 and local_y < 75 then
                            r_reg <= "1111";
                            g_reg <= "0001";
                            b_reg <= "0001";
                        end if;

                        -- top and bottom metal edges
                        if local_x >= 35 and local_x < 75 and
                           ((local_y >= 18 and local_y < 25) or
                            (local_y >= 68 and local_y < 75)) then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
                        end if;

                        -- dark middle stripe
                        if local_x >= 39 and local_x < 71 and
                           local_y >= 42 and local_y < 50 then
                            r_reg <= "0100";
                            g_reg <= "0000";
                            b_reg <= "0000";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Product 3: Coffee, brown cup
                    ----------------------------------------------------
                    if i = 2 then
                        -- cup body
                        if local_x >= 35 and local_x < 72 and
                           local_y >= 35 and local_y < 75 then
                            r_reg <= "0110";
                            g_reg <= "0011";
                            b_reg <= "0001";
                        end if;

                        -- cup top
                        if local_x >= 30 and local_x < 77 and
                           local_y >= 28 and local_y < 38 then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
                        end if;

                        -- coffee surface
                        if local_x >= 35 and local_x < 72 and
                           local_y >= 30 and local_y < 36 then
                            r_reg <= "0100";
                            g_reg <= "0010";
                            b_reg <= "0000";
                        end if;

                        -- handle
                        if local_x >= 72 and local_x < 88 and
                           local_y >= 42 and local_y < 62 then
                            r_reg <= "0110";
                            g_reg <= "0011";
                            b_reg <= "0001";
                        end if;

                        if local_x >= 76 and local_x < 84 and
                           local_y >= 46 and local_y < 58 then
                            r_reg <= "1100";
                            g_reg <= "1100";
                            b_reg <= "1100";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Product 4: Bread, yellow bread block
                    ----------------------------------------------------
                    if i = 3 then
                        -- bread main body
                        if local_x >= 25 and local_x < 85 and
                           local_y >= 38 and local_y < 75 then
                            r_reg <= "1111";
                            g_reg <= "1100";
                            b_reg <= "0010";
                        end if;

                        -- bread top
                        if local_x >= 35 and local_x < 75 and
                           local_y >= 25 and local_y < 45 then
                            r_reg <= "1111";
                            g_reg <= "1010";
                            b_reg <= "0010";
                        end if;

                        -- small crust marks
                        if (local_x >= 38 and local_x < 45 and local_y >= 50 and local_y < 58) or
                           (local_x >= 58 and local_x < 65 and local_y >= 50 and local_y < 58) then
                            r_reg <= "1000";
                            g_reg <= "0100";
                            b_reg <= "0000";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Product 5: Chips, purple bag
                    ----------------------------------------------------
                    if i = 4 then
                        -- bag body
                        if local_x >= 30 and local_x < 80 and
                           local_y >= 18 and local_y < 78 then
                            r_reg <= "1000";
                            g_reg <= "0010";
                            b_reg <= "1111";
                        end if;

                        -- yellow label
                        if local_x >= 38 and local_x < 72 and
                           local_y >= 38 and local_y < 58 then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "0010";
                        end if;

                        -- crimped top and bottom
                        if local_x >= 30 and local_x < 80 and
                           ((local_y >= 18 and local_y < 25) or
                            (local_y >= 70 and local_y < 78)) then
                            r_reg <= "0101";
                            g_reg <= "0000";
                            b_reg <= "1010";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Product 6: Milk, white carton
                    ----------------------------------------------------
                    if i = 5 then
                        -- carton body
                        if local_x >= 35 and local_x < 75 and
                           local_y >= 28 and local_y < 78 then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
                        end if;

                        -- blue top
                        if local_x >= 40 and local_x < 70 and
                           local_y >= 15 and local_y < 30 then
                            r_reg <= "0010";
                            g_reg <= "0110";
                            b_reg <= "1111";
                        end if;

                        -- milk label
                        if local_x >= 42 and local_x < 68 and
                           local_y >= 48 and local_y < 60 then
                            r_reg <= "0010";
                            g_reg <= "0110";
                            b_reg <= "1111";
                        end if;

                        -- carton side shadow
                        if local_x >= 68 and local_x < 75 and
                           local_y >= 30 and local_y < 78 then
                            r_reg <= "1010";
                            g_reg <= "1010";
                            b_reg <= "1010";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Product 7: Candy, green candy
                    ----------------------------------------------------
                    if i = 6 then
                        -- candy center
                        if local_x >= 38 and local_x < 72 and
                           local_y >= 35 and local_y < 62 then
                            r_reg <= "0010";
                            g_reg <= "1111";
                            b_reg <= "0010";
                        end if;

                        -- left wrapper
                        if local_x >= 20 and local_x < 38 and
                           local_y >= 42 and local_y < 55 then
                            r_reg <= "0001";
                            g_reg <= "1000";
                            b_reg <= "0001";
                        end if;

                        -- right wrapper
                        if local_x >= 72 and local_x < 90 and
                           local_y >= 42 and local_y < 55 then
                            r_reg <= "0001";
                            g_reg <= "1000";
                            b_reg <= "0001";
                        end if;

                        -- highlight stripe
                        if local_x >= 45 and local_x < 65 and
                           local_y >= 42 and local_y < 48 then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Product 8: Juice, orange bottle
                    ----------------------------------------------------
                    if i = 7 then
                        -- juice bottle body
                        if local_x >= 40 and local_x < 70 and
                           local_y >= 25 and local_y < 75 then
                            r_reg <= "1111";
                            g_reg <= "1000";
                            b_reg <= "0000";
                        end if;

                        -- bottle neck
                        if local_x >= 47 and local_x < 63 and
                           local_y >= 14 and local_y < 25 then
                            r_reg <= "1111";
                            g_reg <= "1010";
                            b_reg <= "0010";
                        end if;

                        -- cap
                        if local_x >= 45 and local_x < 65 and
                           local_y >= 9 and local_y < 14 then
                            r_reg <= "0010";
                            g_reg <= "1111";
                            b_reg <= "0010";
                        end if;

                        -- label
                        if local_x >= 44 and local_x < 66 and
                           local_y >= 45 and local_y < 56 then
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
                        end if;
                    end if;

                    ----------------------------------------------------
                    -- Normal border: black
                    ----------------------------------------------------
                    if on_border then
                        r_reg <= "0000";
                        g_reg <= "0000";
                        b_reg <= "0000";
                    end if;

                    ----------------------------------------------------
                    -- Selected product border: white
                    ----------------------------------------------------
                    if i = selected_id and on_border then
                        r_reg <= "1111";
                        g_reg <= "1111";
                        b_reg <= "1111";
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
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
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
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
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
                            r_reg <= "1111";
                            g_reg <= "1111";
                            b_reg <= "1111";
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
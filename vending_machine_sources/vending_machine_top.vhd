library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vending_machine_top is
    Port (
        CLK100MHZ  : in  std_logic;
        CPU_RESETN : in  std_logic;  -- active-low reset button

        SW   : in  std_logic_vector(15 downto 0);

        BTNU : in  std_logic;        -- +10
        BTND : in  std_logic;        -- +5
        BTNL : in  std_logic;        -- +1
        BTNR : in  std_logic;        -- +20
        BTNC : in  std_logic;        -- confirm

        LED  : out std_logic_vector(15 downto 0);

        -- seg order follows sevenseg_driver: DP,G,F,E,D,C,B,A, active low
        SEG  : out std_logic_vector(7 downto 0);
        AN   : out std_logic_vector(7 downto 0);

        VGA_R  : out std_logic_vector(3 downto 0);
        VGA_G  : out std_logic_vector(3 downto 0);
        VGA_B  : out std_logic_vector(3 downto 0);
        VGA_HS : out std_logic;
        VGA_VS : out std_logic
    );
end vending_machine_top;

architecture Structural of vending_machine_top is

    -- Power-on reset generator. This ensures modules with registers, especially stock_regs,
    -- are initialized automatically after FPGA configuration.
    signal por_cnt  : unsigned(20 downto 0) := (others => '0');
    signal por_done : std_logic := '0';
    signal rst      : std_logic := '1';

    -- Product selection and global control
    signal product_id : std_logic_vector(3 downto 0);
    signal cancel_sw  : std_logic;

    -- Debounced one-clock pulses from D module
    signal coin_1        : std_logic;
    signal coin_5        : std_logic;
    signal coin_10       : std_logic;
    signal coin_20       : std_logic;
    signal confirm_press : std_logic;

    -- Filtered pulses to block recharge/confirm during replenishment mode
    signal coin_1_filtered        : std_logic;
    signal coin_5_filtered        : std_logic;
    signal coin_10_filtered       : std_logic;
    signal coin_20_filtered       : std_logic;
    signal confirm_press_filtered : std_logic;

    -- Stock and price signals from B module
    signal product_price : std_logic_vector(7 downto 0);
    signal product_stock : std_logic_vector(7 downto 0);

    -- Payment and FSM signals from C module
    signal user_balance   : std_logic_vector(7 downto 0);
    signal deduct_pulse   : std_logic;
    signal dispense_pulse : std_logic;
    signal fsm_state      : std_logic_vector(2 downto 0);

begin

    --------------------------------------------------------------------
    -- Global mapping
    -- SW[3:0] selects product ID 0~15.
    -- SW[15] is cancel/refund/reset-balance switch.
    --------------------------------------------------------------------
    product_id <= SW(3 downto 0);
    cancel_sw  <= SW(15);

    --------------------------------------------------------------------
    -- Replenish Mode Signal Filtering
    -- When SW(14) is active (replenish_mode = '1'), we block recharges
    -- and confirms from reaching the Payment Controller and FSM.
    --------------------------------------------------------------------
    coin_1_filtered        <= coin_1        and (not SW(14));
    coin_5_filtered        <= coin_5        and (not SW(14));
    coin_10_filtered       <= coin_10       and (not SW(14));
    coin_20_filtered       <= coin_20       and (not SW(14));
    confirm_press_filtered <= confirm_press and (not SW(14));

    --------------------------------------------------------------------
    -- Power-on reset: hold rst high for about 20 ms after configuration,
    -- or whenever CPU_RESETN is pressed low.
    --------------------------------------------------------------------
    process(CLK100MHZ)
    begin
        if rising_edge(CLK100MHZ) then
            if CPU_RESETN = '0' then
                por_cnt  <= (others => '0');
                por_done <= '0';
            elsif por_done = '0' then
                if por_cnt = to_unsigned(2000000, por_cnt'length) then
                    por_done <= '1';
                else
                    por_cnt <= por_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    rst <= (not CPU_RESETN) or (not por_done);

    --------------------------------------------------------------------
    -- D: Button debounce module
    --------------------------------------------------------------------
    U_DEBOUNCE : entity work.button_debounce
        port map (
            clk           => CLK100MHZ,
            btn_u         => BTNU,
            btn_d         => BTND,
            btn_l         => BTNL,
            btn_r         => BTNR,
            btn_c         => BTNC,
            coin_10       => coin_10,
            coin_5        => coin_5,
            coin_1        => coin_1,
            coin_20       => coin_20,
            confirm_press => confirm_press
        );

    --------------------------------------------------------------------
    -- B: Product price and stock controller
    --------------------------------------------------------------------
    U_STOCK : entity work.product_stock_controller
        port map (
            clk               => CLK100MHZ,
            rst               => rst,
            product_id        => product_id,
            dispense_pulse    => dispense_pulse,
            replenish_mode    => SW(14),
            replenish_trigger => coin_10, -- BTNU
            product_price     => product_price,
            product_stock     => product_stock
        );

    --------------------------------------------------------------------
    -- C: Payment controller
    --------------------------------------------------------------------
    U_PAYMENT : entity work.payment_controller
        port map (
            clk           => CLK100MHZ,
            rst           => rst,
            cancel_sw     => cancel_sw,
            coin_1        => coin_1_filtered,
            coin_5        => coin_5_filtered,
            coin_10       => coin_10_filtered,
            coin_20       => coin_20_filtered,
            product_price => product_price,
            deduct_pulse  => deduct_pulse,
            user_balance  => user_balance
        );

    --------------------------------------------------------------------
    -- C: Vending machine FSM
    -- Important: drive it with real 100 MHz clock, so set CLK_FREQ_HZ accordingly.
    --------------------------------------------------------------------
    U_FSM : entity work.vending_fsm
        generic map (
            CLK_FREQ_HZ => 100000000
        )
        port map (
            clk            => CLK100MHZ,
            rst            => rst,
            cancel_sw      => cancel_sw,
            confirm_press  => confirm_press_filtered,
            user_balance   => user_balance,
            product_price  => product_price,
            product_stock  => product_stock,
            deduct_pulse   => deduct_pulse,
            dispense_pulse => dispense_pulse,
            fsm_state      => fsm_state
        );

    --------------------------------------------------------------------
    -- D: Seven-segment driver
    --------------------------------------------------------------------
    U_SEVENSEG : entity work.sevenseg_driver
        port map (
            clk          => CLK100MHZ,
            rst          => rst,
            user_balance => user_balance,
            fsm_state    => fsm_state,
            seg          => SEG,
            an           => AN
        );

    --------------------------------------------------------------------
    -- D: LED status driver
    --------------------------------------------------------------------
    U_LED : entity work.led_status_driver
        port map (
            clk       => CLK100MHZ,
            rst       => rst,
            fsm_state => fsm_state,
            led       => LED
        );

    --------------------------------------------------------------------
    -- A: Integrated VGA UI controller
    --------------------------------------------------------------------
    U_VGA : entity work.vga_controller
        port map (
            CLK100MHZ     => CLK100MHZ,
            product_id    => product_id,
            product_price => product_price,
            product_stock => product_stock,
            user_balance  => user_balance,
            fsm_state     => fsm_state,
            VGA_R         => VGA_R,
            VGA_G         => VGA_G,
            VGA_B         => VGA_B,
            VGA_HS        => VGA_HS,
            VGA_VS        => VGA_VS
        );

end Structural;

----------------------------------------------------------------------------------
-- Company: Southern University of Science and Technology (SUSTech)
-- Course: EE332 Digital System Design
-- Module Name: tb_payment_controller - Behavioral
-- Description: Testbench for payment_controller.
--              Verifies balance load, recharge, overflow block, and deduct logic.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_payment_controller is
end tb_payment_controller;

architecture Behavioral of tb_payment_controller is

    -- Component declaration for the Unit Under Test (UUT)
    component payment_controller
        Port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            cancel_sw       : in  std_logic;
            coin_1          : in  std_logic;
            coin_5          : in  std_logic;
            coin_10         : in  std_logic;
            coin_20         : in  std_logic;
            product_price   : in  std_logic_vector(7 downto 0);
            deduct_pulse    : in  std_logic;
            user_balance    : out std_logic_vector(7 downto 0)
        );
    end component;

    -- Stimulus signals
    signal clk             : std_logic := '0';
    signal rst             : std_logic := '0';
    signal cancel_sw       : std_logic := '0';
    signal coin_1          : std_logic := '0';
    signal coin_5          : std_logic := '0';
    signal coin_10         : std_logic := '0';
    signal coin_20         : std_logic := '0';
    signal product_price   : std_logic_vector(7 downto 0) := (others => '0');
    signal deduct_pulse    : std_logic := '0';

    -- Output signals
    signal user_balance    : std_logic_vector(7 downto 0);

    -- Clock period definitions (100MHz clock)
    constant clk_period : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: payment_controller
        Port map (
            clk           => clk,
            rst           => rst,
            cancel_sw     => cancel_sw,
            coin_1        => coin_1,
            coin_5        => coin_5,
            coin_10       => coin_10,
            coin_20       => coin_20,
            product_price => product_price,
            deduct_pulse  => deduct_pulse,
            user_balance  => user_balance
        );

    -- Clock process definitions
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- 1. Power-on reset test
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 20 ns;
        assert (user_balance = std_logic_vector(to_unsigned(50, 8)))
            report "Error: Initial balance is not 50!" severity error;

        -- 2. Single recharge test: +1
        wait until rising_edge(clk);
        coin_1 <= '1';
        wait until rising_edge(clk);
        coin_1 <= '0';
        wait for 20 ns;
        assert (user_balance = std_logic_vector(to_unsigned(51, 8)))
            report "Error: +1 recharge failed!" severity error;

        -- 3. Consecutive recharges: +5, +10, +20
        wait until rising_edge(clk);
        coin_5 <= '1';
        wait until rising_edge(clk);
        coin_5 <= '0';
        wait for 20 ns;
        
        wait until rising_edge(clk);
        coin_10 <= '1';
        wait until rising_edge(clk);
        coin_10 <= '0';
        wait for 20 ns;
        
        wait until rising_edge(clk);
        coin_20 <= '1';
        wait until rising_edge(clk);
        coin_20 <= '0';
        wait for 20 ns;
        
        -- Current balance: 51 + 5 + 10 + 20 = 86
        assert (user_balance = std_logic_vector(to_unsigned(86, 8)))
            report "Error: Consecutive recharge values are incorrect!" severity error;

        -- 4. Deduction test: Set price to 26 and trigger deduct pulse
        product_price <= std_logic_vector(to_unsigned(26, 8));
        wait until rising_edge(clk);
        deduct_pulse <= '1';
        wait until rising_edge(clk);
        deduct_pulse <= '0';
        wait for 20 ns;
        -- Current balance: 86 - 26 = 60
        assert (user_balance = std_logic_vector(to_unsigned(60, 8)))
            report "Error: Price subtraction failed!" severity error;

        -- 5. Overflow block test: add large sums to test the 250 limit
        for i in 1 to 10 loop
            wait until rising_edge(clk);
            coin_20 <= '1';
            wait until rising_edge(clk);
            coin_20 <= '0';
            wait for 10 ns;
        end loop;
        
        -- 60 + 20 * 10 = 260, should be clamped at 250
        assert (user_balance = std_logic_vector(to_unsigned(250, 8)))
            report "Error: Overflow guard failed to clamp balance at 250!" severity error;

        -- 6. Cancel and Refund test: trigger SW[15]
        wait until rising_edge(clk);
        cancel_sw <= '1';
        wait until rising_edge(clk);
        cancel_sw <= '0';
        wait for 20 ns;
        assert (user_balance = std_logic_vector(to_unsigned(50, 8)))
            report "Error: SW15 refund reset back to 50 failed!" severity error;

        -- Test complete, suspend simulation
        report "====== SUCCESS: payment_controller simulation verified successfully! ======" severity note;
        wait;
    end process;

end Behavioral;

----------------------------------------------------------------------------------
-- Company: Southern University of Science and Technology (SUSTech)
-- Course: EE332 Digital System Design
-- Module Name: tb_vending_fsm - Behavioral
-- Description: Testbench for vending_fsm.
--              Verifies transaction success, low balance block, stock shortage block, 
--              and reset/cancellation paths.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_vending_fsm is
end tb_vending_fsm;

architecture Behavioral of tb_vending_fsm is

    -- Component declaration for the Unit Under Test (UUT)
    component vending_fsm
        Generic (
            CLK_FREQ_HZ : integer := 1000
        );
        Port (
            clk             : in  std_logic;
            rst             : in  std_logic;
            cancel_sw       : in  std_logic;
            confirm_press   : in  std_logic;
            user_balance    : in  std_logic_vector(7 downto 0);
            product_price   : in  std_logic_vector(7 downto 0);
            product_stock   : in  std_logic_vector(7 downto 0);
            deduct_pulse    : out std_logic;
            dispense_pulse  : out std_logic;
            fsm_state       : out std_logic_vector(2 downto 0)
        );
    end component;

    -- Stimulus signals
    signal clk             : std_logic := '0';
    signal rst             : std_logic := '0';
    signal cancel_sw       : std_logic := '0';
    signal confirm_press   : std_logic := '0';
    signal user_balance    : std_logic_vector(7 downto 0) := (others => '0');
    signal product_price   : std_logic_vector(7 downto 0) := (others => '0');
    signal product_stock   : std_logic_vector(7 downto 0) := (others => '0');

    -- Output signals
    signal deduct_pulse    : std_logic;
    signal dispense_pulse  : std_logic;
    signal fsm_state       : std_logic_vector(2 downto 0);

    -- Clock definitions (100MHz clock)
    constant clk_period : time := 10 ns;
    
    -- Optimize simulation speed by overriding clock frequency generic to 100Hz
    constant SIM_CLK_FREQ : integer := 100;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: vending_fsm
        generic map (
            CLK_FREQ_HZ => SIM_CLK_FREQ
        )
        Port map (
            clk           => clk,
            rst           => rst,
            cancel_sw     => cancel_sw,
            confirm_press => confirm_press,
            user_balance  => user_balance,
            product_price => product_price,
            product_stock => product_stock,
            deduct_pulse  => deduct_pulse,
            dispense_pulse=> dispense_pulse,
            fsm_state     => fsm_state
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
        assert (fsm_state = "000") report "Error: Failed to reset to ST_IDLE!" severity error;

        --------------------------------------------------------------------------------
        -- Scenario 1: Transaction Success (Balance 60, Price 20, Stock 5)
        --------------------------------------------------------------------------------
        report ">>> SCENARIO 1: Verifying successful purchase transaction...";
        user_balance  <= std_logic_vector(to_unsigned(60, 8));
        product_price <= std_logic_vector(to_unsigned(20, 8));
        product_stock <= std_logic_vector(to_unsigned(5,  8));
        wait for 20 ns;
        
        -- Trigger confirm press
        wait until rising_edge(clk);
        confirm_press <= '1';
        wait until rising_edge(clk);
        confirm_press <= '0';
        
        -- In next cycle, state should enter ST_COMPARE, emit pulses, then go to SUCCESS
        wait until rising_edge(clk);
        assert (deduct_pulse = '1' and dispense_pulse = '1')
            report "Error: deduct_pulse or dispense_pulse failed to assert on transaction success!" severity error;
            
        -- Next cycle: pulses should immediately drop to '0' to avoid double-spend
        wait until rising_edge(clk);
        assert (deduct_pulse = '0' and dispense_pulse = '0')
            report "Error: pulses held active for multiple cycles! Risk of double-spend!" severity error;
        assert (fsm_state = "010")
            report "Error: Failed to enter ST_SUCCESS state!" severity error;
            
        -- Stay for 3 seconds (300 clock cycles = 3000ns) then self-return to IDLE
        wait for 3200 ns;
        assert (fsm_state = "000")
            report "Error: Failed to auto-return to IDLE from ST_SUCCESS!" severity error;

        --------------------------------------------------------------------------------
        -- Scenario 2: Low Balance Error (Balance 15, Price 25, Stock 5)
        --------------------------------------------------------------------------------
        report ">>> SCENARIO 2: Verifying low balance handling...";
        user_balance  <= std_logic_vector(to_unsigned(15, 8));
        product_price <= std_logic_vector(to_unsigned(25, 8));
        product_stock <= std_logic_vector(to_unsigned(5,  8));
        wait for 20 ns;
        
        -- Trigger confirm press
        wait until rising_edge(clk);
        confirm_press <= '1';
        wait until rising_edge(clk);
        confirm_press <= '0';
        
        -- Compare and jump to ST_ERR_LOW_BAL
        wait for 20 ns;
        assert (deduct_pulse = '0' and dispense_pulse = '0')
            report "Error: Erroneous payment occurred during low balance!" severity error;
        assert (fsm_state = "011") -- ST_ERR_LOW_BAL is "011"
            report "Error: Failed to enter low balance error state!" severity error;
            
        -- Stay 3 seconds then return to IDLE
        wait for 3200 ns;
        assert (fsm_state = "000")
            report "Error: Failed to auto-return to IDLE from low balance error!" severity error;

        --------------------------------------------------------------------------------
        -- Scenario 3: Out of Stock Error (Balance 80, Price 20, Stock 0)
        --------------------------------------------------------------------------------
        report ">>> SCENARIO 3: Verifying stock shortage handling...";
        user_balance  <= std_logic_vector(to_unsigned(80, 8));
        product_price <= std_logic_vector(to_unsigned(20, 8));
        product_stock <= std_logic_vector(to_unsigned(0,  8));
        wait for 20 ns;
        
        -- Trigger confirm press
        wait until rising_edge(clk);
        confirm_press <= '1';
        wait until rising_edge(clk);
        confirm_press <= '0';
        
        -- Compare and jump to ST_ERR_OUT_OF_STOCK
        wait for 20 ns;
        assert (deduct_pulse = '0' and dispense_pulse = '0')
            report "Error: Erroneous payment occurred during stock shortage!" severity error;
        assert (fsm_state = "100") -- ST_ERR_OUT_OF_STOCK is "100"
            report "Error: Failed to enter out of stock error state!" severity error;
            
        -- Stay 3 seconds then return to IDLE
        wait for 3200 ns;
        assert (fsm_state = "000")
            report "Error: Failed to auto-return to IDLE from stock shortage error!" severity error;

        --------------------------------------------------------------------------------
        -- Scenario 4: Mid-stay Cancel SW Reset
        --------------------------------------------------------------------------------
        report ">>> SCENARIO 4: Verifying mid-state cancel switch reset...";
        user_balance  <= std_logic_vector(to_unsigned(60, 8));
        product_price <= std_logic_vector(to_unsigned(20, 8));
        product_stock <= std_logic_vector(to_unsigned(5,  8));
        wait for 20 ns;
        
        -- Trigger confirm
        wait until rising_edge(clk);
        confirm_press <= '1';
        wait until rising_edge(clk);
        confirm_press <= '0';
        
        -- Enter SUCCESS
        wait for 40 ns;
        assert (fsm_state = "010") report "Error: Setup for cancel test failed!" severity error;
        
        -- Trigger cancel switch SW[15]
        wait until rising_edge(clk);
        cancel_sw <= '1';
        wait until rising_edge(clk);
        cancel_sw <= '0';
        wait for 10 ns;
        
        -- Verify instant return to IDLE without waiting 3s
        assert (fsm_state = "000")
            report "Error: SW15 failed to instantly force reset FSM back to IDLE!" severity error;

        -- End simulation
        report "====== SUCCESS: vending_fsm simulation verified successfully! ======" severity note;
        wait;
    end process;

end Behavioral;

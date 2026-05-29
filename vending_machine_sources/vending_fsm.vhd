----------------------------------------------------------------------------------
-- Company: Southern University of Science and Technology (SUSTech)
-- Course: EE332 Digital System Design
-- Module Name: vending_fsm - Behavioral
-- Description: Core Finite State Machine (FSM) for Vending Machine.
--              1. Logic path states: Idle/Select -> Compare -> Success / Error -> Idle
--              2. Verifies enough balance and active stock quantity.
--              3. Triggers exactly single-cycle deduct_pulse and dispense_pulse upon success.
--              4. Broadcasts current state codes to VGA display and LED/seven-segment.
--              5. Stays in Success/Error state for 3 seconds before self-returning.
--              6. SW[15] cancel_sw triggers instant return to Idle state.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vending_fsm is
    Generic (
        CLK_FREQ_HZ : integer := 1000                        -- Clock frequency driving FSM (default 1kHz)
    );
    Port (
        clk             : in  std_logic;                     -- System clock
        rst             : in  std_logic;                     -- Global reset (active high)
        cancel_sw       : in  std_logic;                     -- Cancel switch (SW[15])
        confirm_press   : in  std_logic;                     -- Debounced purchase confirm pulse (BTNC)
        user_balance    : in  std_logic_vector(7 downto 0);  -- Current balance vector from payment_controller
        product_price   : in  std_logic_vector(7 downto 0);  -- Product price from product_stock_controller
        product_stock   : in  std_logic_vector(7 downto 0);  -- Product stock from product_stock_controller
        deduct_pulse    : out std_logic;                     -- Single-cycle balance deduction pulse
        dispense_pulse  : out std_logic;                     -- Single-cycle stock decrement pulse
        fsm_state       : out std_logic_vector(2 downto 0)   -- FSM state broadcast signals
    );
end vending_fsm;

architecture Behavioral of vending_fsm is

    -- FSM state declarations
    type state_type is (ST_IDLE, ST_COMPARE, ST_SUCCESS, ST_ERR_LOW_BAL, ST_ERR_OUT_OF_STOCK);
    signal current_state, next_state : state_type := ST_IDLE;

    -- 3-second delay timer register
    signal timer_reg : integer range 0 to 3 * CLK_FREQ_HZ := 0;
    constant DELAY_3S : integer := 3 * CLK_FREQ_HZ;

begin

    -- State Transitions and Output Pulse Logic
    process(clk)
    begin
        if rising_edge(clk) then
            -- Active-high reset or cancel switch triggers instant reset
            if (rst = '1') or (cancel_sw = '1') then
                current_state <= ST_IDLE;
                timer_reg <= 0;
                deduct_pulse <= '0';
                dispense_pulse <= '0';
            else
                -- Default single-cycle pulse assignments
                deduct_pulse <= '0';
                dispense_pulse <= '0';

                case current_state is
                    -- 1. Idle state: wait for confirm pulse
                    when ST_IDLE =>
                        timer_reg <= 0;
                        if confirm_press = '1' then
                            current_state <= ST_COMPARE;
                        end if;

                    -- 2. Bill comparison and validation state
                    when ST_COMPARE =>
                        if (unsigned(user_balance) >= unsigned(product_price)) and (unsigned(product_stock) > 0) then
                            current_state <= ST_SUCCESS;
                            deduct_pulse <= '1';       -- Emit deduct pulse
                            dispense_pulse <= '1';     -- Emit dispense pulse
                            timer_reg <= 0;
                        elsif (unsigned(user_balance) < unsigned(product_price)) then
                            current_state <= ST_ERR_LOW_BAL;
                            timer_reg <= 0;
                        else
                            current_state <= ST_ERR_OUT_OF_STOCK;
                            timer_reg <= 0;
                        end if;

                    -- 3. Success state: wait 3 seconds
                    when ST_SUCCESS =>
                        if timer_reg < DELAY_3S then
                            timer_reg <= timer_reg + 1;
                        else
                            current_state <= ST_IDLE;
                            timer_reg <= 0;
                        end if;

                    -- 4. Low balance error state: wait 3 seconds
                    when ST_ERR_LOW_BAL =>
                        if timer_reg < DELAY_3S then
                            timer_reg <= timer_reg + 1;
                        else
                            current_state <= ST_IDLE;
                            timer_reg <= 0;
                        end if;

                    -- 5. Out of stock error state: wait 3 seconds
                    when ST_ERR_OUT_OF_STOCK =>
                        if timer_reg < DELAY_3S then
                            timer_reg <= timer_reg + 1;
                        else
                            current_state <= ST_IDLE;
                            timer_reg <= 0;
                        end if;

                    when others =>
                        current_state <= ST_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- Output state encoding Combinational logic
    process(current_state)
    begin
        case current_state is
            when ST_IDLE =>
                fsm_state <= "000";
            when ST_COMPARE =>
                fsm_state <= "001";
            when ST_SUCCESS =>
                fsm_state <= "010";
            when ST_ERR_LOW_BAL =>
                fsm_state <= "011";
            when ST_ERR_OUT_OF_STOCK =>
                fsm_state <= "100";
            when others =>
                fsm_state <= "000";
        end case;
    end process;

end Behavioral;

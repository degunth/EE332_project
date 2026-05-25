----------------------------------------------------------------------------------
-- Company: Southern University of Science and Technology (SUSTech)
-- Course: EE332 Digital System Design
-- Module Name: payment_controller - Behavioral
-- Description: Core payment calculation module for Vending Machine.
--              1. Initial balance is preset to 50.
--              2. Receives debounced button pulses to accumulate balance (+1, +5, +10, +20).
--              3. Protects against overflow with a maximum limit of 250.
--              4. Receives deduct_pulse from FSM to subtract the product price.
--              5. cancel_sw (SW[15]) triggers refund and resets balance back to 50.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity payment_controller is
    Port (
        clk             : in  std_logic;                     -- System clock
        rst             : in  std_logic;                     -- Global reset (active high)
        cancel_sw       : in  std_logic;                     -- Cancel switch (SW[15])
        coin_1          : in  std_logic;                     -- +1 pulse (BTNL)
        coin_5          : in  std_logic;                     -- +5 pulse (BTND)
        coin_10         : in  std_logic;                     -- +10 pulse (BTNU)
        coin_20         : in  std_logic;                     -- +20 pulse (BTNR)
        product_price   : in  std_logic_vector(7 downto 0);  -- Selected product price
        deduct_pulse    : in  std_logic;                     -- Deduct trigger pulse from FSM
        user_balance    : out std_logic_vector(7 downto 0)   -- Current account balance output
    );
end payment_controller;

architecture Behavioral of payment_controller is
    -- Internal balance register initialized to 50
    signal balance : unsigned(7 downto 0) := to_unsigned(50, 8);
    
    -- Upper limit to prevent overflow
    constant MAX_LIMIT : unsigned(7 downto 0) := to_unsigned(250, 8);
begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Reset or Cancel SW active: force balance back to 50
            if (rst = '1') or (cancel_sw = '1') then
                balance <= to_unsigned(50, 8);
                
            -- Deduct balance upon deduct_pulse from FSM
            elsif deduct_pulse = '1' then
                if balance >= unsigned(product_price) then
                    balance <= balance - unsigned(product_price);
                end if;
                
            -- Recharge accumulation with overflow guard
            else
                if coin_1 = '1' then
                    if (balance + 1) <= MAX_LIMIT then
                        balance <= balance + 1;
                    end if;
                elsif coin_5 = '1' then
                    if (balance + 5) <= MAX_LIMIT then
                        balance <= balance + 5;
                    end if;
                elsif coin_10 = '1' then
                    if (balance + 10) <= MAX_LIMIT then
                        balance <= balance + 10;
                    end if;
                elsif coin_20 = '1' then
                    if (balance + 20) <= MAX_LIMIT then
                        balance <= balance + 20;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Output conversion
    user_balance <= std_logic_vector(balance);

end Behavioral;

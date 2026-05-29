library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity product_stock_controller is
    Port (
        clk               : in  std_logic;
        rst               : in  std_logic;
        product_id        : in  std_logic_vector(3 downto 0);
        dispense_pulse    : in  std_logic;
        replenish_mode    : in  std_logic; -- SW[14]
        replenish_trigger : in  std_logic; -- Debounced pulse (BTNU)
        product_price     : out std_logic_vector(7 downto 0);
        product_stock     : out std_logic_vector(7 downto 0)
    );
end product_stock_controller;

architecture Behavioral of product_stock_controller is

    type stock_reg_array is array(0 to 15) of std_logic_vector(7 downto 0);
    signal stock_regs : stock_reg_array;

begin

    -- 商品价格只读ROM
    process(product_id)
    begin
        case product_id is
            when "0000" => product_price <= std_logic_vector(to_unsigned(2, 8));
            when "0001" => product_price <= std_logic_vector(to_unsigned(3, 8));
            when "0010" => product_price <= std_logic_vector(to_unsigned(5, 8));
            when "0011" => product_price <= std_logic_vector(to_unsigned(6, 8));
            when "0100" => product_price <= std_logic_vector(to_unsigned(8, 8));
            when "0101" => product_price <= std_logic_vector(to_unsigned(10, 8));
            when "0110" => product_price <= std_logic_vector(to_unsigned(12, 8));
            when "0111" => product_price <= std_logic_vector(to_unsigned(15, 8));
            when "1000" => product_price <= std_logic_vector(to_unsigned(18, 8));
            when "1001" => product_price <= std_logic_vector(to_unsigned(20, 8));
            when "1010" => product_price <= std_logic_vector(to_unsigned(25, 8));
            when "1011" => product_price <= std_logic_vector(to_unsigned(30, 8));
            when "1100" => product_price <= std_logic_vector(to_unsigned(35, 8));
            when "1101" => product_price <= std_logic_vector(to_unsigned(40, 8));
            when "1110" => product_price <= std_logic_vector(to_unsigned(45, 8));
            when "1111" => product_price <= std_logic_vector(to_unsigned(50, 8));
            when others => product_price <= (others => '0');
        end case;
    end process;

    -- 库存寄存器时序逻辑
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for i in 0 to 15 loop
                    stock_regs(i) <= std_logic_vector(to_unsigned(5, 8));
                end loop;
            else
                -- 正常销售模式下的出货扣减
                if dispense_pulse = '1' then
                    if unsigned(stock_regs(to_integer(unsigned(product_id)))) > 0 then
                        stock_regs(to_integer(unsigned(product_id))) <= 
                            std_logic_vector(unsigned(stock_regs(to_integer(unsigned(product_id)))) - 1);
                    end if;
                -- 管理员补货模式下的库存增加 (每次按键库存+1，上限10件)
                elsif replenish_mode = '1' and replenish_trigger = '1' then
                    if unsigned(stock_regs(to_integer(unsigned(product_id)))) < 10 then
                        stock_regs(to_integer(unsigned(product_id))) <= 
                            std_logic_vector(unsigned(stock_regs(to_integer(unsigned(product_id)))) + 1);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- 当前商品库存输出
    product_stock <= stock_regs(to_integer(unsigned(product_id)));

end Behavioral;

# 自动售货机商品库存控制器与UI布局系统

## VHDL Stock Controller \&amp; UI Layout Specification

本目录为自动售货机项目**成员 B 负责模块**的正式技术文档与代码库，完全对齐团队整体架构、接口规范与时序协议，支持成员 A 顶层无缝集成、成员 C 逻辑直接对接。

---

## 一、模块功能架构

本模块包含两个独立子系统，无耦合依赖：

1. **`product\_stock\_controller\.vhd`**（商品库存控制器）

    - 内置 16 通道商品价格只读 ROM，支持`SW\[3:0\]`选择 16 种商品，并行输出对应单价

    - 16 组独立 8 位库存寄存器，上电 / 复位默认初始库存为 5 件

    - 硬件级安全防护：库存为 0 时自动拦截扣减，杜绝负数溢出

    - 捕获 C 模块`dispense\_pulse`单周期脉冲，自动对选中商品执行库存减 1

2. **1024×600 VGA 界面坐标规范**

    - 标准化像素坐标规划，完全适配 VGA 可视区时序

    - 包含商品网格、选中光标、状态弹窗、信息面板的完整坐标映射

    - 与 C 模块`fsm\_state`状态码完全联动，成员 A 可直接套用渲染

---

## 二、接口引脚规范

所有端口与 C/D 模块风格、位宽、类型完全统一，支持 “连线即通”：

```vhdl
entity product_stock_controller is
    Port (
        clk             : in  std_logic;                     -- 系统主时钟 100MHz 全局统一
        rst             : in  std_logic;                     -- 全局同步复位 高电平有效
        product_id      : in  std_logic_vector(3 downto 0);  -- 商品ID 接开发板 SW[3:0]
        dispense_pulse  : in  std_logic;                     -- 出货单脉冲 来自C模块vending_fsm
        product_price   : out std_logic_vector(7 downto 0);  -- 商品单价 输出至C模块
        product_stock   : out std_logic_vector(7 downto 0)   -- 商品库存 输出至C模块
    );
end product_stock_controller;
```

---

## 三、联调对接协议

### 1\. 对接成员 C（核心控制模块）

- **脉冲时序**：完全适配 C 模块输出的**10ns 单周期高电平脉冲**，时钟上升沿触发，无漏触发、无重复扣减

- **数据输出**：`product\_price`/`product\_stock`为纯组合逻辑输出，无时延，C 模块可直接采样

- **安全互锁**：C 模块先判断库存 \&gt; 0 再发脉冲，本模块二次校验库存 \&gt; 0 才执行扣减，双重防护杜绝溢出

### 2\. 对接成员 A（顶层集成与 VGA 渲染）

- **顶层接线**：`clk`/`rst`接全局时钟复位，`product\_id`直连`SW\[3:0\]`，输出仅需连接至 C 模块对应端口

- **UI 规范**：所有坐标基于 1024×600 VGA 可视区（左上角为原点`\(0,0\)`），无需额外偏移

- **状态联动**：弹窗显示 / 隐藏直接绑定 C 模块`fsm\_state`，无需额外逻辑

---

## 四、1024×600 VGA 界面坐标规范

### 1\. 固定元素坐标表

|界面元素|起始坐标 \(x,y\)|尺寸 \(宽 × 高\)|渲染要求|
|---|---|---|---|
|顶部标题栏|`\(48, 24\)`|`928 × 56`|深蓝色背景，白色标题文字|
|商品网格基准|`\(64, 112\)`|单块`184×80`，块间距 24px|4 行 4 列共 16 个商品块，白背景灰边框|
|右侧余额面板|`\(720, 112\)`|`240 × 96`|浅灰背景，显示当前账户余额|
|右侧操作提示|`\(720, 232\)`|`240 × 240`|白背景，显示按键操作说明|
|底部状态栏|`\(48, 520\)`|`928 × 48`|浅灰背景，显示系统实时状态|
|中央状态弹窗|`\(312, 200\)`|`400 × 200`|层级最高，默认隐藏|

### 2\. 弹窗状态联动规则

|C 模块 fsm\_state|弹窗内容|背景色|
|---|---|---|
|`010`（交易成功）|交易成功，正在出货|绿色|
|`011`（余额不足）|余额不足，请充值|红色|
|`100`（商品缺货）|商品已售罄|黄色|

### 3\. 商品 ID ↔ 光标坐标映射

|商品 ID|光标起始坐标|商品 ID|光标起始坐标|
|---|---|---|---|
|`0000`|`\(62, 110\)`|`1000`|`\(62, 314\)`|
|`0001`|`\(270, 110\)`|`1001`|`\(270, 314\)`|
|`0010`|`\(478, 110\)`|`1010`|`\(478, 314\)`|
|`0011`|`\(686, 110\)`|`1011`|`\(686, 314\)`|
|`0100`|`\(62, 212\)`|`1100`|`\(62, 416\)`|
|`0101`|`\(270, 212\)`|`1101`|`\(270, 416\)`|
|`0110`|`\(478, 212\)`|`1110`|`\(478, 416\)`|
|`0111`|`\(686, 212\)`|`1111`|`\(686, 416\)`|

---

## 五、仿真验证说明
![产品库存控制器](https://raw.githubusercontent.com/degunth/EE332_project/main/product_stock_controller_1.jpg)

![产品库存控制器2](https://raw.githubusercontent.com/degunth/EE332_project/main/product_stock_controller_2.png)

1. **复位验证**：复位后所有商品库存默认输出`x\&\#34;05\&\#34;`，价格输出对应 ID 正确值

2. **扣减验证**：单脉冲触发一次，库存自动减 1，无多扣漏扣

3. **防溢出验证**：库存为 0 后，脉冲不再触发扣减，无负数溢出

4. **独立性验证**：不同商品 ID 的库存寄存器独立，扣减互不干扰

---

## 六、核心源代码

### product\_stock\_controller\.vhd

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity product_stock_controller is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        product_id      : in  std_logic_vector(3 downto 0);
        dispense_pulse  : in  std_logic;
        product_price   : out std_logic_vector(7 downto 0);
        product_stock   : out std_logic_vector(7 downto 0)
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
                if dispense_pulse = '1' then
                    if unsigned(stock_regs(to_integer(unsigned(product_id)))) > 0 then
                        stock_regs(to_integer(unsigned(product_id))) <= 
                            std_logic_vector(unsigned(stock_regs(to_integer(unsigned(product_id)))) - 1);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- 当前商品库存输出
    product_stock <= stock_regs(to_integer(unsigned(product_id)));

end Behavioral;
```

### tb\_product\_stock\_controller\.vhd

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_product_stock_controller is
end tb_product_stock_controller;

architecture behavior of tb_product_stock_controller is

    component product_stock_controller
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        product_id      : in  std_logic_vector(3 downto 0);
        dispense_pulse  : in  std_logic;
        product_price   : out std_logic_vector(7 downto 0);
        product_stock   : out std_logic_vector(7 downto 0)
    );
    end component;

    signal clk             : std_logic := '0';
    signal rst             : std_logic := '0';
    signal product_id      : std_logic_vector(3 downto 0) := (others => '0');
    signal dispense_pulse  : std_logic := '0';
    signal product_price   : std_logic_vector(7 downto 0);
    signal product_stock   : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    uut: product_stock_controller PORT MAP (
        clk => clk,
        rst => rst,
        product_id => product_id,
        dispense_pulse => dispense_pulse,
        product_price => product_price,
        product_stock => product_stock
    );

    clk_process :process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
    begin
        wait for 100 ns;
        rst <= '1'; wait for 20 ns;
        rst <= '0'; wait for 20 ns;

        product_id <= "0000"; wait for 20 ns;
        product_id <= "0001"; wait for 20 ns;
        product_id <= "0010"; wait for 20 ns;
        product_id <= "1111"; wait for 20 ns;
        product_id <= "0000"; wait for 20 ns;

        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;
        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;
        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;

        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;
        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;
        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;
        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;

        product_id <= "0001"; wait for 20 ns;
        dispense_pulse <= '1'; wait for 10 ns;
        dispense_pulse <= '0'; wait for 30 ns;
        product_id <= "0000"; wait for 20 ns;

        wait;
    end process;

end behavior;
```


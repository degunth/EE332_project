library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_debounce is
    Port (
        clk : in std_logic;

        -- 5 physical buttons on the FPGA board
        btn_u : in std_logic;
        btn_d : in std_logic;
        btn_l : in std_logic;
        btn_r : in std_logic;
        btn_c : in std_logic;

        -- One-clock-cycle debounced pulses for the control/payment modules
        coin_10       : out std_logic; -- Up button:    +10
        coin_5        : out std_logic; -- Down button:  +5
        coin_1        : out std_logic; -- Left button:  +1
        coin_20       : out std_logic; -- Right button: +20
        confirm_press : out std_logic  -- Center button: confirm transaction
    );
end button_debounce;

architecture Behavioral of button_debounce is

    -- Internal vector mapping: 4=U, 3=D, 2=L, 1=R, 0=C
    signal btn_in_vec  : std_logic_vector(4 downto 0);
    signal btn_out_vec : std_logic_vector(4 downto 0) := (others => '0');

    -- Synchronizer, debounce counter and edge detector registers
    type sync_array is array(0 to 4) of std_logic_vector(1 downto 0);
    signal btn_sync : sync_array := (others => "00");

    type counter_array is array(0 to 4) of unsigned(20 downto 0);
    signal counter : counter_array := (others => (others => '0'));

    signal btn_stable : std_logic_vector(4 downto 0) := (others => '0');
    signal btn_prev   : std_logic_vector(4 downto 0) := (others => '0');

    constant DEBOUNCE_COUNT : unsigned(20 downto 0) := to_unsigned(2000000, 21); -- 20 ms @ 100 MHz

begin

    btn_in_vec <= btn_u & btn_d & btn_l & btn_r & btn_c;

    coin_10       <= btn_out_vec(4);
    coin_5        <= btn_out_vec(3);
    coin_1        <= btn_out_vec(2);
    coin_20       <= btn_out_vec(1);
    confirm_press <= btn_out_vec(0);

    gen_debounce : for i in 0 to 4 generate

        -- 1. Two-stage synchronizer to reduce metastability
        process(clk)
        begin
            if rising_edge(clk) then
                btn_sync(i) <= btn_sync(i)(0) & btn_in_vec(i);
            end if;
        end process;

        -- 2. 20 ms debounce filter
        process(clk)
        begin
            if rising_edge(clk) then
                if btn_sync(i)(1) /= btn_stable(i) then
                    if counter(i) = DEBOUNCE_COUNT then
                        btn_stable(i) <= btn_sync(i)(1);
                        counter(i) <= (others => '0');
                    else
                        counter(i) <= counter(i) + 1;
                    end if;
                else
                    counter(i) <= (others => '0');
                end if;
            end if;
        end process;

        -- 3. Rising-edge detector: generate one-clock pulse
        process(clk)
        begin
            if rising_edge(clk) then
                btn_prev(i) <= btn_stable(i);

                if btn_prev(i) = '0' and btn_stable(i) = '1' then
                    btn_out_vec(i) <= '1';
                else
                    btn_out_vec(i) <= '0';
                end if;
            end if;
        end process;

    end generate;

end Behavioral;

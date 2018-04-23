---- Nixie.vhd
 --
 -- Author: L. Sartory
 -- Creation: 29.03.2018
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------

package nixie_types is
	type digit_array is array(natural range <>) of std_logic_vector(9 downto 0);
end package;

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.nixie_types.all;

--------------------------------------------------

entity Nixie is
	port
	(
		CLK          : in  std_logic;

		DIGIT        : out digit_array(6 downto 1) := (others => (others => 'Z'));
		NIXIE_ENABLE : out std_logic := 'Z';

		GPS_PPS      : in  std_logic;
		GPS_RX       : in  std_logic;
		GPS_TX       : out std_logic := 'Z';

		SWITCH       : in  std_logic_vector(2 downto 1)
	);
end Nixie;

architecture Nixie_Arch of Nixie is
	signal clk_1Hz : std_logic := '0';
	signal shift_register : std_logic_vector(9 downto 0) := "0000000001";
begin

	cs: entity work.ClockScaler
		generic map (
			INPUT_FREQUENCY         => 16.384000,
			OUTPUT_FREQUENCY        => 0.000001,
			CLOCKS_ARE_SYNCHRONIZED => true
		)
		port map (
			INPUT_CLK  => CLK,
			TARGET_CLK => CLK,
			OUTPUT_CLK => clk_1Hz
		);

	process (clk_1Hz)
	begin
		if rising_edge(clk_1Hz) then
			shift_register <= shift_register(shift_register'high - 1 downto shift_register'low) & '0';
			if shift_register(shift_register'high) = '1' then
				shift_register <= (shift_register'low => '1', others => '0');
			end if;
		end if;
	end process;

	digit_gen : for i in DIGIT'high downto DIGIT'low generate
		DIGIT(i) <= shift_register;
	end generate;
	NIXIE_ENABLE <= '1';

end architecture;

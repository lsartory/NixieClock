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
use ieee.numeric_std.all;
use work.nixie_types.all;

--------------------------------------------------

entity Nixie is
	port
	(
		CLK          : in  std_logic;

		DIGIT        : out digit_array(6 downto 1) := (others => (others => 'Z'));
		NIXIE_ENABLE : out std_logic := 'Z';

		GPS_1PPS     : in  std_logic;
		GPS_DATA_IN  : in  std_logic;
--		GPS_DATA_OUT : out std_logic := 'Z';

		SWITCH       : in  std_logic_vector(2 downto 1)
	);
end Nixie;

architecture Nixie_Arch of Nixie is

	signal switch_filtered : std_logic_vector(SWITCH'high downto SWITCH'low) := (others => '0');

	signal pulse_1Hz : std_logic := '0';

	signal seconds : unsigned(5 downto 0) := (others => '0');
	signal minutes : unsigned(5 downto 0) := (others => '0');
	signal hours   : unsigned(4 downto 0) := (others => '0');

	signal seconds_high : unsigned(3 downto 0) := (others => '0');
	signal seconds_low  : unsigned(3 downto 0) := (others => '0');
	signal minutes_high : unsigned(3 downto 0) := (others => '0');
	signal minutes_low  : unsigned(3 downto 0) := (others => '0');
	signal hours_high   : unsigned(3 downto 0) := (others => '0');
	signal hours_low    : unsigned(3 downto 0) := (others => '0');

begin

	-- Push-button filters
	dif : for i in SWITCH'high downto SWITCH'low generate
	begin
		filter : entity work.DigitalInputFilter
			port map (
				CLK               => CLK,
				DIGITAL_INPUT_IN  => SWITCH(i),
				DIGITAL_INPUT_OUT => switch_filtered(i)
			);
	end generate;

	-- 1 Hz time base
	cs : entity work.ClockScaler
		generic map (
			INPUT_FREQUENCY  => 16.384000,
			OUTPUT_FREQUENCY =>  0.000001
		)
		port map (
			INPUT_CLK    => CLK,
			OUTPUT_PULSE => pulse_1Hz
		);

	-- Timekeeping process
--	process (CLK)
--	begin
--		if rising_edge(CLK) then
--			if pulse_1Hz = '1' then
--				if seconds < 59 then
--					seconds <= seconds + 1;
--				else
--					seconds <= (others => '0');
--					if minutes < 59 then
--						minutes <= minutes + 1;
--					else
--						minutes <= (others => '0');
--						if hours < 23 then
--							hours <= hours + 1;
--						else
--							hours <= (others => '0');
--						end if;
--					end if;
--				end if;
--			end if;
--		end if;
--	end process;

	-- GPS interface
	gps : entity work.GPSInterface
		port map (
			CLK         => CLK,
			CLRn        => not switch_filtered(1),

			GPS_DATA_IN => GPS_DATA_IN,
			GPS_1PPS    => GPS_1PPS,

--			READY       : out std_logic;
			HOURS       => hours,
			MINUTES     => minutes,
			SECONDS     => seconds
--			UPDATED     : out std_logic
		);
	
	-- Digit splitters
	seconds_split : entity work.DigitSplitter port map (CLK, seconds, seconds_high, seconds_low);
	minutes_split : entity work.DigitSplitter port map (CLK, minutes, minutes_high, minutes_low);
	hours_split   : entity work.DigitSplitter port map (CLK, hours,   hours_high,   hours_low);

	-- Digit decoders
	digit_1 : entity work.Digit port map (CLK, seconds_low,  '1', DIGIT(1));
	digit_2 : entity work.Digit port map (CLK, seconds_high, '1', DIGIT(2));
	digit_3 : entity work.Digit port map (CLK, minutes_low,  '1', DIGIT(3));
	digit_4 : entity work.Digit port map (CLK, minutes_high, '1', DIGIT(4));
	digit_5 : entity work.Digit port map (CLK, hours_low,    '1', DIGIT(5));
	digit_6 : entity work.Digit port map (CLK, hours_high,   '1', DIGIT(6));
	NIXIE_ENABLE <= '1';

end architecture;

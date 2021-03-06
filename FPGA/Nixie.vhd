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
	signal clrn            : std_logic := '0';

	signal pulse_1Hz  : std_logic := '0';
	signal pulse_1kHz : std_logic := '0';

	signal seconds : unsigned(5 downto 0) := (others => '0');
	signal minutes : unsigned(5 downto 0) := (others => '0');
	signal hours   : unsigned(4 downto 0) := (others => '0');

--	signal gps_ready   : std_logic := '0';
	signal gps_seconds : unsigned(5 downto 0) := (others => '0');
	signal gps_minutes : unsigned(5 downto 0) := (others => '0');
	signal gps_hours   : unsigned(4 downto 0) := (others => '0');
	signal gps_updated : std_logic := '0';

	signal seconds_high : unsigned(3 downto 0) := (others => '0');
	signal seconds_low  : unsigned(3 downto 0) := (others => '0');
	signal minutes_high : unsigned(3 downto 0) := (others => '0');
	signal minutes_low  : unsigned(3 downto 0) := (others => '0');
	signal hours_high   : unsigned(3 downto 0) := (others => '0');
	signal hours_low    : unsigned(3 downto 0) := (others => '0');

	signal brightness : unsigned(2 downto 0) := (0 => '0', others => '1');

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
	clrn <= not switch_filtered(2);

	-- 1 Hz time base
	cs : entity work.ClockScaler
		generic map (
			INPUT_FREQUENCY  => 16.384000,
			OUTPUT_FREQUENCY =>  0.000001
		)
		port map (
			INPUT_CLK    => CLK,
			CLRn         => clrn and not gps_updated,
			OUTPUT_PULSE => pulse_1Hz
		);

	-- Timekeeping process
	process (CLK)
	begin
		if rising_edge(CLK) then
			if pulse_1Hz = '1' then
				if seconds < 59 then
					seconds <= seconds + 1;
				else
					seconds <= (others => '0');
					if minutes < 59 then
						minutes <= minutes + 1;
					else
						minutes <= (others => '0');
						if hours < 23 then
							hours <= hours + 1;
						else
							hours <= (others => '0');
						end if;
					end if;
				end if;
			end if;

			if gps_updated = '1' then
				seconds <= gps_seconds;
				minutes <= gps_minutes;
				hours   <= gps_hours;
			end if;

			if clrn = '0' then
				seconds <= (others => '0');
				minutes <= (others => '0');
				hours   <= (others => '0');
			end if;
		end if;
	end process;

	-- GPS interface
	gps : entity work.GPSInterface
		port map (
			CLK         => CLK,
			CLRn        => clrn,

			GPS_DATA_IN => GPS_DATA_IN,
			GPS_1PPS    => GPS_1PPS,

--			READY       => gps_ready,
			HOURS       => gps_hours,
			MINUTES     => gps_minutes,
			SECONDS     => gps_seconds,
			UPDATED     => gps_updated
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

	-- Dimming
	cs2 : entity work.ClockScaler
	generic map (
		INPUT_FREQUENCY  => 16.384000,
		OUTPUT_FREQUENCY =>  0.001000
	)
	port map (
		INPUT_CLK    => CLK,
		CLRn         => clrn,
		OUTPUT_PULSE => pulse_1kHz
	);
	process (CLK)
		variable switch_prev : std_logic := '0';
		variable counter     : unsigned(brightness'high downto brightness'low) := (others => '0');
	begin
		if rising_edge(CLK) then
			if pulse_1kHz = '1' then
				NIXIE_ENABLE <= '0';
				if counter < brightness then
					NIXIE_ENABLE <= '1';
				end if;
				counter := counter + 1;
			end if;

			if clrn = '0' then
				brightness   <= (brightness'low => '0', others => '1');
				NIXIE_ENABLE <= '1';
			elsif switch_prev = '0' and switch_filtered(1) = '1' then
				brightness <= brightness - 1;
			end if;

			switch_prev := switch_filtered(1);
		end if;
	end process;

end architecture;

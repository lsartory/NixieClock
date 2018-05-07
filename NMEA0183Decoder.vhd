---- NMEA0183Decoder.vhd
 --
 -- Author: L. Sartory
 -- Creation: 30.04.2018
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity NMEA0183Decoder is
	port (
		CLK        : in  std_logic;
		CLRn       : in  std_logic;
		ENA        : in  std_logic;
		NMEA_DATA  : in  character;

		HOURS      : out unsigned;
		MINUTES    : out unsigned;
		SECONDS    : out unsigned;
		UPDATED    : out std_logic
	);
end entity NMEA0183Decoder;

--------------------------------------------------

architecture NMEA0183Decoder_arch of NMEA0183Decoder is
	type state_t is (
		idle,
		id,
		time,
		valid,
		latitude,
		latitude_ns,
		longitude,
		longitude_we,
		ground_speed,
		track_angle,
		date,
		magnetic_variation,
		magnetic_variation_we,
		checksum,
		done,
		unknown
	);
	signal state : state_t := idle;

	signal local_checksum  : unsigned(7 downto 0) := (others => '0');
	signal remote_checksum : unsigned(7 downto 0) := (others => '0');

	type   str_t is array(4 downto 0) of character;
	signal str : str_t                := (others => '0');
	signal ptr : unsigned(3 downto 0) := (others => '0');

	signal ts_year   : unsigned(6 downto 0) := (others => '0');
	signal ts_month  : unsigned(3 downto 0) := (others => '0');
	signal ts_day    : unsigned(4 downto 0) := (others => '0');
	signal ts_hour   : unsigned(4 downto 0) := (others => '0');
	signal ts_minute : unsigned(5 downto 0) := (others => '0');
	signal ts_second : unsigned(5 downto 0) := (others => '0');
	signal ts_valid  : std_logic := '0';

	-- Constant multiplication functions
	function mult_10(X : unsigned) return unsigned is
	begin
		return (X(X'high - 3 downto X'low) & "000") + (X(X'high - 1 downto X'low) & "0");
	end function;
	function mult_16(X : unsigned) return unsigned is
	begin
		return (X(X'high - 4 downto X'low) & "0000");
	end function;
begin

	-- NMEA message decoding process
	process (CLK)
		variable bcd_digit : unsigned(3 downto 0);
	begin
		if rising_edge(CLK) then
			if CLRn = '0' then
				state <= idle;

			-- If a character was received (ENA) and its value is valid, process it
			elsif ENA = '1' and to_unsigned(character'pos(NMEA_DATA), 8)(7) = '0' then
				-- Convert an hexadecimal character into an integer
				if to_unsigned(character'pos(NMEA_DATA), 7)(6) = '0' then
					bcd_digit := to_unsigned(character'pos(NMEA_DATA), bcd_digit'length);
				else
					bcd_digit := to_unsigned(character'pos(NMEA_DATA) - 55, bcd_digit'length);
				end if;

				-- Compute the checksum
				if state /= idle and state /= checksum and state /= done and NMEA_DATA /= '*' then
					local_checksum <= local_checksum xor to_unsigned(character'pos(NMEA_DATA), local_checksum'length);
				end if;

				-- Reset the update pulse
				UPDATED <= '0';

				if NMEA_DATA = '$' then
					-- Message start
					ts_year         <= (others => '0');
					ts_month        <= (others => '0');
					ts_day          <= (others => '0');
					ts_hour         <= (others => '0');
					ts_minute       <= (others => '0');
					ts_second       <= (others => '0');
					ts_valid        <= '0';
					local_checksum  <= (others => '0');
					remote_checksum <= (others => '0');
					ptr             <= (others => '0');
					state           <= id;
				elsif NMEA_DATA = ',' then
					-- Field separator
					case state is
						when idle => null;
						when id =>
							if str(4) = 'G' and str(3) = 'P' and str(2) = 'R' and str(1) = 'M' and str(0) = 'C' then
								state <= time;
							else
								state <= idle;
							end if;
						when time               => state <= valid;
						when valid              => state <= latitude;
						when latitude           => state <= latitude_ns;
						when latitude_ns        => state <= longitude;
						when longitude          => state <= longitude_we;
						when longitude_we       => state <= ground_speed;
						when ground_speed       => state <= track_angle;
						when track_angle        => state <= date;
						when date               => state <= magnetic_variation;
						when magnetic_variation => state <= magnetic_variation_we;
						when others             => state <= unknown;
					end case;
				elsif NMEA_DATA = '*' and state /= idle then
					-- Checksum marker
					ptr   <= (others => '0');
					state <= checksum;
				elsif (NMEA_DATA = cr or NMEA_DATA = lf) and state /= idle then
					-- Message end
					state <= done;
				end if;

				if state = id then
					-- Decode the message ID
					for i in str'high downto str'low + 1 loop
						str(i) <= str(i - 1);
					end loop;
					str(str'low) <= NMEA_DATA;
				elsif state = time and ptr < 6 then
					-- Decode the time, field by field
					if ptr < 2 then
						ts_hour   <= mult_10(ts_hour)   + bcd_digit;
					elsif ptr < 4 then
						ts_minute <= mult_10(ts_minute) + bcd_digit;
					else
						ts_second <= mult_10(ts_second) + bcd_digit;
					end if;
					ptr <= ptr + 1;
				elsif state = valid and NMEA_DATA = 'A' then
					-- Check if the status flag is active
					ts_valid <= '1';
				elsif state = date and ptr < 12 then
					-- Decode the date, field by field
					if ptr < 8 then
						ts_day   <= mult_10(ts_day)   + bcd_digit;
					elsif ptr < 10 then
						ts_month <= mult_10(ts_month) + bcd_digit;
					else
						ts_year  <= mult_10(ts_year)  + bcd_digit;
					end if;
					ptr <= ptr + 1;
				elsif state = checksum and ptr < 2 then
					-- Decode the checksum
					remote_checksum <= mult_16(remote_checksum) + bcd_digit;
					ptr <= ptr + 1;
				elsif state = done and local_checksum = remote_checksum and ts_valid = '1' then
					-- If everything is fine, update the output
					HOURS   <= ts_hour;
					MINUTES <= ts_minute;
					SECONDS <= ts_second;
					UPDATED <= '1';
				end if;
			end if;
		end if;
	end process;

end NMEA0183Decoder_arch;

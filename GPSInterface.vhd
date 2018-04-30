---- GPSInterface.vhd
 --
 -- Author: L. Sartory
 -- Creation: 30.04.2018
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

-- A2235-A serial interface

entity GPSInterface is
	generic
	(
		CLK_FREQ    : natural := 16384000;
		BAUD_RATE   : natural := 4800
	);
	port (
		CLK         : in  std_logic;
		CLRn        : in  std_logic;

		GPS_DATA_IN : in  std_logic;
		GPS_1PPS    : in  std_logic;
		
		READY       : out std_logic;
		HOURS       : out unsigned;
		MINUTES     : out unsigned;
		SECONDS     : out unsigned;
		UPDATED     : out std_logic
	);
end GPSInterface;

--------------------------------------------------

architecture GPSInterface_arch of GPSInterface is

	signal timestamp : unsigned(31 downto 0);

	-- Synchronized signals
	signal gps_data_in_sync : std_logic := '0';
	signal gps_1pps_sync    : std_logic := '0';

	-- State machine declarations
	type state_t is (idle, start_delay, start, data, data_delay, stop);
	signal state : state_t := idle;

	-- Delay counter declaration
	signal delay_counter : natural range (CLK_FREQ / BAUD_RATE) downto 0;

	-- Shift register declarations
	signal shift_reg : std_logic_vector(7 downto 0);
	signal shift_cnt : unsigned(2 downto 0);
	signal recv_done : std_logic;

begin

	-- Synchronization
	sync : entity work.VectorCDC
		port map (
			TARGET_CLK => CLK,
			INPUT(1)   => GPS_DATA_IN,
			INPUT(0)   => GPS_1PPS,
			OUTPUT(1)  => gps_data_in_sync,
			OUTPUT(0)  => gps_1pps_sync
		);

	-- Serial interface decoding process
	process (CLK)
	begin
		if rising_edge(CLK) then
			-- Decrement the delay counter
			if delay_counter = 0 then
				delay_counter <= delay_counter'high;
			else
				delay_counter <= delay_counter - 1;
			end if;

			-- UART state machine
			case state is
				when idle =>
					-- Wait for the start bit to start decoding a character
					delay_counter <= delay_counter'high / 2;
					recv_done <= '0';
					shift_cnt <= (others => '1');
					if gps_data_in_sync = '0' then
						state <= start_delay;
					end if;

				when start_delay =>
					-- Skip a half bit to ensure proper decoding
					if delay_counter = 0 then
						state <= start;
					end if;

				when start =>
					-- Skip the start bit
					if delay_counter = 0 then
						state <= data;
					end if;

				when data =>
					-- Receive one bit
					delay_counter <= delay_counter'high;
					shift_reg <= gps_data_in_sync & shift_reg(shift_reg'high downto shift_reg'low + 1);
					if shift_cnt > 0 then
						shift_cnt <= shift_cnt - 1;
						state     <= data_delay;
					else
						recv_done <= '1';
						state     <= stop;
					end if;

				when data_delay =>
					-- Wait for the next bit
					if delay_counter = 0 then
						state <= data;
					end if;

				when stop =>
					-- Skip the stop bit
					if delay_counter = 0 and gps_data_in_sync = '1' then
						state <= idle;
					end if;
			end case;

			-- Reset the end of character pulse
			if recv_done = '1' then
				recv_done <= '0';
			end if;

			-- Go back to the idle state in case of reset
			if CLRn = '0' then
				state <= idle;
			end if;
		end if;
	end process;

	-- 1PPS detection process
	process (CLK)
	begin
		if rising_edge(CLK) then
			if CLRn = '0' then
				READY <= '0';
			elsif gps_1pps_sync = '1' then
				READY <= '1';
			end if;
		end if;
	end process;

	-- NMEA 0183 decoder
	nd: entity work.NMEA0183Decoder
		port map(
			CLK        => CLK,
			CLRn       => CLRn,
			ENA        => recv_done,
			NMEA_DATA  => character'val(to_integer(unsigned(shift_reg))),

			HOURS      => HOURS,
			MINUTEs    => MINUTES,
			SECONDS    => SECONDS,
			UPDATED    => UPDATED
		);

end GPSInterface_arch;

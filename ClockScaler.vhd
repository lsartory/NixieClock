---- ClockScaler.vhd
 --
 -- Author: L. Sartory
 -- Creation: 25.08.2016
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--------------------------------------------------

entity ClockScaler is
	generic (
		INPUT_FREQUENCY         : real;
		OUTPUT_FREQUENCY        : real;
		CLOCKS_ARE_SYNCHRONIZED : boolean := false
	);
	port (
		INPUT_CLK    : in  std_logic;
		TARGET_CLK   : in  std_logic;
		OUTPUT_CLK   : out std_logic;
		OUTPUT_PULSE : out std_logic
	);
end ClockScaler;

--------------------------------------------------

architecture ClockScaler_arch of ClockScaler is
	signal counter     : unsigned(63 downto 0) := (others => '0');
	signal output_sync : std_logic;

	function real_to_unsigned(x : real; size : natural) return unsigned is
		variable tmp    : real := round(x);
		variable result : unsigned(size - 1 downto 0) := (others => '0');
	begin
		for i in result'high downto result'low loop
			if tmp > (2.0 ** i) then
				result(i) := '1';
				tmp := tmp - (2.0 ** i);
			end if;
		end loop;
		return result;
	end;
begin

	-- Scale the input clock to match the requested output frequency
	process (INPUT_CLK)
	begin
		if rising_edge(INPUT_CLK) then
			counter <= counter + real_to_unsigned((OUTPUT_FREQUENCY / INPUT_FREQUENCY) * (2.0 ** counter'length), counter'length);
		end if;
	end process;

	-- Transfer the signal into the target clock domain, if required
	cdc_gen_1 : if not CLOCKS_ARE_SYNCHRONIZED generate
	begin
		cdc : work.VectorCDC
			port map (
				TARGET_CLK => TARGET_CLK,
				INPUT(0)   => counter(counter'high),
				OUTPUT(0)  => output_sync
			);
	end generate;
	cdc_gen_2 : if CLOCKS_ARE_SYNCHRONIZED generate
	begin
		output_sync <= counter(counter'high);
	end generate;
	OUTPUT_CLK <= output_sync;

	-- Generate a pulse in the target clock domain when a rising edge is detected
	process (TARGET_CLK)
		variable output_sync_prev : std_logic := '0';
	begin
		if rising_edge(TARGET_CLK) then
			OUTPUT_PULSE <= '0';
			if output_sync = '1' and output_sync_prev = '0' then
				OUTPUT_PULSE <= '1';
			end if;
			output_sync_prev := output_sync;
		end if;
	end process;

end ClockScaler_arch;

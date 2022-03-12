---- DigitalInputFilter.vhd
 --
 -- Author: L. Sartory
 -- Creation: 30.04.2018
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity DigitalInputFilter is
	generic (
		FILTER_DURATION   : natural := 100000
	);
	port (
		CLK               : in  std_logic;
		DIGITAL_INPUT_IN  : in  std_logic;
		DIGITAL_INPUT_OUT : out std_logic
	);
end entity DigitalInputFilter;

--------------------------------------------------

architecture DigitalInputFilter_arch of DigitalInputFilter is

	-- Input signals
	signal synchronized_input : std_logic := '0';
	signal filtered_input     : std_logic := '0';

	-- Filter register
	signal filter_counter : unsigned(31 downto 0) := (others => '0');

begin

	-- Input synchronization
	input_cdc : entity work.VectorCDC
		port map (
			TARGET_CLK => CLK,
			INPUT(0)   => not DIGITAL_INPUT_IN,
			OUTPUT(0)  => synchronized_input
		);

	-- Filter process
	process (CLK)
	begin
		if rising_edge(CLK) then
			if synchronized_input = filtered_input then
				filter_counter <= to_unsigned(FILTER_DURATION, filter_counter'length);
			elsif filter_counter /= 0 then
				filter_counter <= filter_counter - 1;
			else
				filtered_input <= synchronized_input;
			end if;
		end if;
	end process;
	DIGITAL_INPUT_OUT <= filtered_input;

end DigitalInputFilter_arch;

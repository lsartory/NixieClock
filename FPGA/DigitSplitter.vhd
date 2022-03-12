---- DigitSplitter.vhd
 --
 -- Author: L. Sartory
 -- Creation: 24.04.2018
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lpm;
use lpm.lpm_components.all;

--------------------------------------------------

entity DigitSplitter is
	port
	(
		CLK         : in  std_logic;
		INPUT       : in  unsigned;
		OUTPUT_HIGH : out unsigned;
		OUTPUT_LOW  : out unsigned
	);
end DigitSplitter;

architecture DigitSplitter_Arch of DigitSplitter is
	signal output_high_tmp : std_logic_vector(INPUT'high downto INPUT'low) := (others => '0');
begin

	splitter : lpm_divide
		generic map (
			lpm_type            => "LPM_DIVIDE",
			lpm_hint            => "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE",
			lpm_nrepresentation => "UNSIGNED",
			lpm_drepresentation => "UNSIGNED",
			lpm_widthn          => INPUT'length,
			lpm_widthd          => OUTPUT_LOW'length,
			lpm_pipeline        => 1
		)
		port map (
			clock            => CLK,
			numer            => std_logic_vector(INPUT),
			denom            => std_logic_vector(to_unsigned(10, OUTPUT_LOW'length)),
			quotient         => output_high_tmp,
			unsigned(remain) => OUTPUT_LOW
		);
	OUTPUT_HIGH <= unsigned(output_high_tmp(OUTPUT_HIGH'high downto OUTPUT_HIGH'low));

end architecture;

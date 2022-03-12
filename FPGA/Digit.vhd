---- Digit.vhd
 --
 -- Author: L. Sartory
 -- Creation: 24.04.2018
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity Digit is
	port
	(
		CLK    : in  std_logic;
		VALUE  : in  unsigned;
		ENABLE : in  std_logic;
		DIGIT  : out std_logic_vector
	);
end Digit;

architecture Digit_Arch of Digit is
begin

	process (CLK)
	begin
		if rising_edge(CLK) then
			DIGIT <= (others => 'Z');
			if ENABLE = '1' then
				DIGIT(to_integer(VALUE)) <= '1';
			end if;
		end if;
	end process;

end architecture;

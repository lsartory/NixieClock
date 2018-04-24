#### Nixie.sdc
 ##
 ## Author: L. Sartory
 ## Creation: 09.04.2018
####


# Clock definitions
create_clock -name "CLK"     -period       6.104 {CLK}
create_clock -name "clk_1Hz" -period 1000000.000 {ClockScaler:cs|counter[63]}
derive_clock_uncertainty

# Asynchronous inputs false paths
set_false_path -from {SWITCH[*]}

#### Nixie.sdc
 ##
 ## Author: L. Sartory
 ## Creation: 09.04.2018
####


# Clock definitions
create_clock -name "CLK" -period 6.104 [get_ports {CLK}]
derive_clock_uncertainty

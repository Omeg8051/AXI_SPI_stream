default: compile execute display


compile:
	iverilog test.v
execute:
	vvp a.out

display:
	gtkwave *.vcd
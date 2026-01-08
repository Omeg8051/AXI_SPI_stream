`timescale 1ns / 1ps
`include "./src/spi_front.v"
`include "./src/spi_host.v"
module test_bench;


    
reg clk;
reg rst_n;

/*
reg spi_begin;
wire spi_busy;
reg spi_wide;

wire spi_clk;
wire spi_mosi;

reg [31:0]mosi_data;
wire [31:0]miso_data;

spi_front dut(
    .spi_clk_in(clk),
    .rst_n(rst_n),
    .spi_clk_o(spi_clk),
    .spi_mosi_o(spi_mosi),
    .spi_miso_i(~spi_mosi),
    .data_mosi(mosi_data),
    .data_miso(miso_data),

    .spi_begin(spi_begin),
    .spi_wide(spi_wide),
    .spi_busy(spi_busy)
);
*/

reg aact;
reg act;
reg [7:0]reg_addr;
reg [31:0]axi_wdata;
reg [31:0]axis_wdata;
reg s_axis_tlast;
wire [31:0]reg_rd;

wire spi_clk;
wire spi_mosi;

wire spi_int;

wire axi_awready;
wire axi_arready;

wire axi_wready;
wire axi_rvalid;

wire axis_rlast;
wire [31:0]axis_rdata;
wire s_axis_ready;
wire m_axis_valid;
wire m_axis_last;

wire axi_bvalid;

spi_host dut (
    //spi interface
	.spi_clk_o(spi_clk),
	.spi_mosi_o(spi_mosi),
	.spi_miso_i(~spi_mosi),

	// Ports of Axi Slave Bus Interface S_AXI
	.s_axi_aclk(clk),
	.s_axi_aresetn(rst_n),


	.s_axi_awaddr(reg_addr),
	.s_axi_awvalid(aact),
	.s_axi_awready(axi_awready),

	.s_axi_wdata(axi_wdata),
	.s_axi_wvalid(act),
	.s_axi_wready(axi_wready),
	
	//.s_axi_bresp(),
	.s_axi_bvalid(axi_bvalid),
	.s_axi_bready(1'b1),


	.s_axi_araddr(reg_addr),
	.s_axi_arvalid(aact),
	.s_axi_arready(axi_arready),
	
	.s_axi_rdata(reg_rd),
	//.s_axi_rresp(),
	.s_axi_rvalid(axi_rvalid),
	.s_axi_rready(act),


	// Ports of Axi Slave Bus Interface S_AXIS
	.s_axis_tready(s_axis_ready),
	.s_axis_tdata(axis_wdata),
	.s_axis_tlast(s_axis_tlast),
	.s_axis_tvalid(1'b1),

	// Ports of Axi Master Bus Interface S_AXIS
	.m_axis_tready(1'b1),
	.m_axis_tdata(axis_rdata),
	.m_axis_tlast(m_axis_last),
	.m_axis_tvalid(m_axis_valid)
);




localparam CLK_PERIOD = 2;
always #(CLK_PERIOD/2) clk=~clk;

initial begin
    $dumpfile("tb_dut.vcd");
    $dumpvars(0, test_bench);
    
    $dumpvars(0, dut);
end

/*
always @(posedge axis_rdy ) begin
    if(axis_valid)axis_data <= axis_data + 32'h01010101;
end
*/
initial begin

    clk = 1'b0;
    rst_n = 1'b1;


    act <= 1'b0;
    aact <= 1'b0;
    s_axis_tlast <= 1'b0;
    reg_addr <= 8'b0;
    axi_wdata <= 32'h0;
    axis_wdata <= 32'h0;
/*    spi_begin = 1'b0;
    mosi_data = 32'hA5;
    spi_wide = 1'b0;
    #5 rst_n = 1'b0;
    #10 rst_n = 1'b1;
    #10 spi_begin = 1'b1;
    #4 spi_begin = 1'b0;
    #20 mosi_data = 32'h3C;
    #50 spi_begin = 1'b1;
    #4 spi_begin = 1'b0;
    #20 mosi_data = 32'h53525150;
    spi_wide = 1'b1;
    #100 spi_begin = 1'b1;
    
    axis_data = 32'h63626160;
    axis_valid = 1'b0;
    reg_wr = 8'hA0;
    act = 4'h0; rw_sel <= 1'b0;
    #1 clk = 1'b0;
    #3 rst_n = 1'bx;
    */
    #5 rst_n = 1'b0;
    #10 rst_n = 1'b1;

    //write to pscl_reg
    #20 reg_addr = 8'h18;
    aact <= 1'b1;
    #2 aact <= 1'b0;
    #2 axi_wdata = 32'h2;
    act <= 1'b1;
    #2 act <= 1'b0;
    

    //write to data access
    #20 reg_addr = 8'h04;
    aact <= 1'b1;
    #2 aact <= 1'b0;
    #2 axi_wdata = 32'h67676767;
    act <= 1'b1;
    #2 act <= 1'b0;
    
    //write to data access
    #50 axi_wdata = 32'h67676767;
    act <= 1'b1;
    #2 act <= 1'b0;
    
    //write to data access cont
    #50 axi_wdata = 32'h67676767;
    act <= 1'b1;
    #100 act <= 1'b0;
    
    //write to byte order
    #50 reg_addr = 8'h14;
    aact <= 1'b1;
    #2 aact <= 1'b0;
    #2 axi_wdata = 32'h17;
    act <= 1'b1;
    #2 act <= 1'b0;
    
    //write to burst len
    #50 reg_addr = 8'h1C;
    axis_wdata <= 32'h53525150;
    aact <= 1'b1;
    #2 aact <= 1'b0;
    #2 axi_wdata = 32'h4;
    act <= 1'b1;
    #2 act <= 1'b0;


    
    #600 $finish(2);
end


endmodule
`default_nettype wire

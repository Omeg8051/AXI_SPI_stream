//Host write and read simultaniously
//Each byte write will present the corresponding byte read from previous transfer
//Support both AXI MM and AXI STREAM interface


// MM interface:
// <reg>:	W/R	name			description

// reg0:	RO	op_status		bit0: spi_busy status
// reg1:	WR	mosi_miso_fifo	write to write 1 byte to spi bus. Read to retrieve the byte from previous transfer
// reg2:	WO	chip_sel_w1c	write 1 to clear corresponding chip select bit
// reg3:	RW	chip_sel_reg	write to enable chip select. the bits that are 1s are selected
// reg4:	WO	chip_sel_w1s	write 1 to set corresponding chip select bit

//control status
// reg5:	RW	host_ctrl		control the host: {stream_dir[15], reserved}	stream_dir == 0:mm2s; 1:s2mm
// reg6:	RW	spi clk pscl	SPI clock prescaler select(0 to turn off clock, 1 to 16 to select corresponding bit from internal prescaler counter)
// reg7:	WO	spi burst transfer word count(4 byte)

module spi_host #
	(
		// Users to add parameters here
		parameter C_S_AXIS_TDATA_WIDTH = 32,

		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		parameter integer C_S_AXI_ADDR_WIDTH	= 8,
		//parameter integer REG_DATA_WIDTH	= 32,
		parameter integer SPI_CS_WIDTH	= 16
	) (
	//spi interface
	input spi_clk_i,
	output spi_clk_o,
	output spi_clk_t,
	input spi_mosi_i,
	output spi_mosi_o,
	output spi_mosi_t,
	input spi_miso_i,
	output spi_miso_o,
	output spi_miso_t,

	input [SPI_CS_WIDTH - 1:0]spi_cs_i,
	output [SPI_CS_WIDTH - 1:0]spi_cs_o,
	output [SPI_CS_WIDTH - 1:0]spi_cs_t,

	// Ports of Axi Slave Bus Interface S_AXI
	input  s_axi_aclk,
	input  s_axi_aresetn,


	input [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
	input  s_axi_awvalid,
	output  s_axi_awready,

	input [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
	input  s_axi_wvalid,
	output  s_axi_wready,
	
	output [1 : 0] s_axi_bresp,
	output  s_axi_bvalid,
	input  s_axi_bready,


	input [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
	input  s_axi_arvalid,
	output  s_axi_arready,
	
	output [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
	output [1 : 0] s_axi_rresp,
	output  s_axi_rvalid,
	input  s_axi_rready,


	// Ports of Axi Slave Bus Interface S_AXIS
	output  s_axis_tready,
	input [C_S_AXIS_TDATA_WIDTH-1 : 0] s_axis_tdata,
	input  s_axis_tlast,
	input  s_axis_tvalid,

	// Ports of Axi Master Bus Interface S_AXIS
	input  m_axis_tready,
	output [C_S_AXIS_TDATA_WIDTH-1 : 0] m_axis_tdata,
	output  m_axis_tlast,
	output  m_axis_tvalid

);

localparam integer OP_STATUS_ADDR = 0;
localparam integer DATA_ACCESS_ADDR = 4;
localparam integer SPI_CS_W1C_ADDR = 8;
localparam integer SPI_CHIP_SEL_ADDR = 12;
localparam integer SPI_CS_W1S_ADDR = 16;
localparam integer SPI_CTL_ADDR = 20;
localparam integer SPI_CLK_SPCL_ADDR = 24;
localparam integer SPI_BURST_CNT_ADDR = 28;

wire rst_n;
assign rst_n = s_axi_aresetn;
/**
*8==================================================================================D
*8==================================================================================D
*8===================                                             ==================D
*8=================              AXI MM ADDRESS CONTROL             ================D
*8===================                                             ==================D
*8==================================================================================D
*8==================================================================================D
*/

reg [C_S_AXI_ADDR_WIDTH-1:0]awaddr_r;
wire aw_success;
assign aw_success = s_axi_awvalid & s_axi_awready;
reg [C_S_AXI_ADDR_WIDTH-1:0]araddr_r;
wire ar_success;
assign ar_success = s_axi_arvalid & s_axi_arready;
wire spi_state_is_idle;
assign spi_state_is_idle = (spi_control_state == AXI_SPI_STATE_IDLE);

always @(posedge s_axi_aclk or negedge rst_n ) begin
	if(~rst_n)begin
		awaddr_r <= 0;
	end else if(spi_state_is_idle && aw_success) begin
		awaddr_r <= s_axi_awaddr;
	end else begin
		awaddr_r <= awaddr_r;
	end
end


always @(posedge s_axi_aclk or negedge rst_n ) begin
	if(~rst_n)begin
		araddr_r <= 0;
	end else if(ar_success) begin
		araddr_r <= s_axi_araddr;
	end else begin
		araddr_r <= araddr_r;
	end
end
wire [C_S_AXI_ADDR_WIDTH-1:0]awaddr_active;
assign awaddr_active = aw_success ? s_axi_awaddr : awaddr_r;
wire [C_S_AXI_ADDR_WIDTH-1:0]araddr_active;
assign araddr_active = ar_success ? s_axi_araddr : araddr_r;
/**
*8==================================================================================D
*8==================================================================================D
*8==================                                              ==================D
*8================     AXI MM INTERFACE FSM AND CHANNEL SIGNALS     ================D
*8==================                                              ==================D
*8==================================================================================D
*8==================================================================================D
*/

reg [1:0] axi_mm_if_state ;

//axi mm output signals:

reg ar_ready;
wire r_valid;
assign r_valid = ~ar_ready;
assign s_axi_arready = ar_ready;
assign s_axi_rvalid = r_valid & spi_state_is_idle;

always @(posedge s_axi_aclk or negedge rst_n) begin
	if(~rst_n)begin
		ar_ready <= 1'b1;
	end else if(s_axi_arready && s_axi_arvalid) begin
		ar_ready <= 1'b0;
	end else if(s_axi_rready && s_axi_rvalid) begin
		ar_ready <= 1'b1;
	end
end
assign s_axi_rresp = 2'b0;

assign s_axi_awready = spi_state_is_idle;
assign s_axi_wready = spi_state_is_idle;
assign w_ready = spi_state_is_idle;
assign s_axi_bresp = 2'b0;

reg b_valid;
assign s_axi_bvalid = b_valid;

//b channel fsm
assign s_axi_bvalid = b_valid;
always @(posedge s_axi_aclk or negedge rst_n) begin
	if(~rst_n)begin
		b_valid <= 1'b0;
	end else if(s_axi_wready && s_axi_wvalid && ~b_valid) begin
		b_valid <= 1'b1;
	end else if(s_axi_bready && b_valid) begin
		b_valid <= 1'b0;
	end
end

wire w_success;
assign w_success = s_axi_wvalid & s_axi_wready;
wire r_success;
assign r_success = s_axi_rvalid & s_axi_rready;

/**
*8==================================================================================D
*8==================================================================================D
*8===================                                             ==================D
*8=================            SPI FRONT TRIGGER CONTROL            ================D
*8===================                                             ==================D
*8==================================================================================D
*8==================================================================================D
*/

localparam AXI_SPI_STATE_IDLE = 5;
localparam AXI_SPI_STATE_MM_ARMED = 0;
localparam AXI_SPI_STATE_MM_ACTIVE = 1;
localparam AXI_SPI_STATE_S_ARMED = 2;
localparam AXI_SPI_STATE_S_ACTIVE = 3;
//state encode{idle,is_stream,SPI_active}

reg [2:0]spi_control_state ;
//trigger source FSM
	wire spi_mode_stream;
reg [31:0]spi_tx_data;
reg [31:0]spi_strm_b_len;
	wire spi_strm_b_len_nz;
	assign spi_strm_b_len_nz = |spi_strm_b_len;

//spi front end control signals
reg spi_front_begin;
	wire spi_front_wide;
	assign spi_front_wide = spi_control_state[1];
	wire spi_front_busy;

//AXI STREAM respond signal
reg s_axis_tready_r;
reg s_axis_tlast_r;
reg m_axis_tvalid_r;
reg m_axis_tlast_r;

assign s_axis_tready = s_axis_tready_r;
assign m_axis_tvalid = m_axis_tvalid_r;
assign m_axis_tlast = m_axis_tlast_r;

always @(posedge s_axi_aclk or negedge rst_n) begin
	if(~rst_n)begin
		s_axis_tlast_r <= 1'b0;
	end else if (s_axis_tvalid && s_axis_tready) begin
		s_axis_tlast_r <= s_axis_tlast;
	end
end

always @(posedge s_axi_aclk or negedge rst_n) begin
	if(~rst_n)begin
		spi_control_state <= AXI_SPI_STATE_IDLE;
		spi_tx_data <= 32'h0;
		spi_strm_b_len <= 32'h0;
		spi_front_begin <= 1'b0;
		//stream info control
		s_axis_tready_r <= 1'b0;
		m_axis_tvalid_r <= 1'b0;
		m_axis_tlast_r <= 1'b0;
	end else begin
		case (spi_control_state)
			AXI_SPI_STATE_IDLE : begin
				if (w_success && awaddr_active == DATA_ACCESS_ADDR) begin
					//write to data access addr
					//mm byte transfer mode
					//set spi front begin
					//clear spi front wide
					spi_control_state <= AXI_SPI_STATE_MM_ARMED;
					spi_tx_data <= s_axi_wdata;
					spi_front_begin <= 1'b1;
				end else if (w_success && awaddr_active == SPI_BURST_CNT_ADDR) begin
					//write to burst_length addr
					//stream word transfer mode
					//set spi front wide
					//set spi front begin to {s2mm} : need to kick start the first SPI action for s2mm.
					spi_control_state <= AXI_SPI_STATE_S_ARMED;
					spi_strm_b_len <= s_axi_wdata;
					spi_front_begin <= spi_strm_s2mm;
					//stream info control
					//set axis_tready
					//clear axis_tvalid
					//clear axis_tlast
					s_axis_tready_r <= 1'b1;
					m_axis_tvalid_r <= 1'b0;
					m_axis_tlast_r <= 1'b0;
					
				end else begin
					//M_AXIS and S_AXIS do not overlap in reg control. can do in parallel
					if(s_axis_tvalid & s_axis_tready) begin
						//mm2s transaction success
						//clear axis_tready
						s_axis_tready_r <= 1'b0;
					end
					if(m_axis_tvalid & m_axis_tready)begin
						//s2mm transaction success
						m_axis_tvalid_r <= 1'b0; 
						m_axis_tlast_r <= 1'b0;
					end
				end
			end
			AXI_SPI_STATE_MM_ARMED : begin
				if (spi_front_busy) begin
					//spi front begin to work
					//clear spi front begin
					spi_control_state <= AXI_SPI_STATE_MM_ACTIVE;
					spi_front_begin <= 1'b0;
				end
			end
			AXI_SPI_STATE_MM_ACTIVE : begin
				if (~spi_front_busy) begin
					//spi front finished
					spi_control_state <= AXI_SPI_STATE_IDLE;
				end
			end
			AXI_SPI_STATE_S_ARMED : begin
				if (spi_front_busy) begin
					//spi front begin to work
					spi_control_state <= AXI_SPI_STATE_S_ACTIVE;
					//clear spi front begin
					//decrement burst len
					spi_strm_b_len <= spi_strm_b_len - 32'b1;
					spi_front_begin <= 1'b0;
					
				end else if(s_axis_tvalid & s_axis_tready) begin
					//mm2s transaction success
					//set spi front begin
					//clear axis_tready
					//capture data
					spi_front_begin <= 1'b1;
					//spi_tx_data <= {s_axis_tdata[7:0],s_axis_tdata[15:8],s_axis_tdata[23:16],s_axis_tdata[31:24]};
					spi_tx_data <= stream_word_odrered;
					
					//stream info control
					//clear axis_tready
					s_axis_tready_r <= 1'b0;
					m_axis_tvalid_r <= 1'b0;

				end else if(m_axis_tvalid & m_axis_tready)begin
					//s2mm transaction success
					//set spi front begin
					spi_front_begin <= 1'b1;
					//read success;
					s_axis_tready_r <= 1'b0;
					m_axis_tvalid_r <= 1'b0;

				end
			end
			AXI_SPI_STATE_S_ACTIVE : begin
				if (~spi_front_busy && spi_strm_b_len_nz) begin
					if(s_axis_tlast_r && ~spi_strm_s2mm) begin
						//spi front finished and no more data to send
						spi_control_state <= AXI_SPI_STATE_IDLE;
						spi_strm_b_len <= 32'h0;
						//keep spi front begin cleared
						//set axis_tvalid to siginify data ready
						s_axis_tready_r <= 1'b1;
						m_axis_tvalid_r <= spi_strm_s2mm;
						m_axis_tlast_r <= spi_strm_s2mm;
					end else begin
						//spi front finished and still have data to send
						spi_control_state <= AXI_SPI_STATE_S_ARMED;
						//set axis_tready to get next data
						//set axis_tvalid to siginify data ready
						s_axis_tready_r <= 1'b1;
						m_axis_tvalid_r <= spi_strm_s2mm;
					end
					
				end else if (~spi_front_busy && ~spi_strm_b_len_nz) begin

					//spi front finished and no more data to send
					spi_control_state <= AXI_SPI_STATE_IDLE;
					spi_strm_b_len <= 32'h0;
					//keep spi front begin cleared
					//set axis_tvalid to siginify data ready
					s_axis_tready_r <= 1'b1;
					m_axis_tvalid_r <= spi_strm_s2mm;
					m_axis_tlast_r <= spi_strm_s2mm;
					
				end
			end 
			default: begin
				//undefined behave like reset
				spi_control_state <= AXI_SPI_STATE_IDLE;
				spi_tx_data <= 32'h0;
				spi_strm_b_len <= 32'h0;
				spi_front_begin <= 1'b0;
				s_axis_tready_r <= 1'b0;
				m_axis_tvalid_r <= 1'b0;
				m_axis_tlast_r <= 1'b0;
			end
		endcase
	end
end

/**
*8==================================================================================D
*8==================================================================================D
*8======================                                       =====================D
*8====================              SPI IP CONTROL               ===================D
*8======================                                       =====================D
*8==================================================================================D
*8==================================================================================D
*/

reg [15:0]spi_ctl_reg;//

//[15]:		spi stream data dir: 0:mm2s; 1:s2mm
//[14:0]:	reserved


	//user write control_b into reg
	always @(posedge s_axi_aclk or negedge rst_n) begin
		if(~rst_n)begin
			spi_ctl_reg <= 0;
		end else if(w_success && awaddr_active == SPI_CTL_ADDR && spi_state_is_idle)begin
			spi_ctl_reg <= s_axi_wdata[15:0];
		end else begin
			spi_ctl_reg <= spi_ctl_reg;
		end
		
	end

wire spi_strm_s2mm;
assign spi_strm_s2mm = spi_ctl_reg[15];

wire [4:0]stream_byte_order;
assign stream_byte_order = spi_ctl_reg[4:0];

/**
*8==================================================================================D
*8==================================================================================D
*8===================                                             ==================D
*8=================             STREAM BYTR REORDERING              ================D
*8===================                                             ==================D
*8==================================================================================D
*8==================================================================================D
*/
//HI ADDRESS {B3,B2,B1,B0} LO ADDRESS
//STREAM_BYTE_ORDER_0123 means SPI transfer B0 first, B1 second, B2 third, B3 last.
localparam STREAM_BYTE_ORDER_0123 = 5'd0;
localparam STREAM_BYTE_ORDER_0132 = 5'd1;
localparam STREAM_BYTE_ORDER_0213 = 5'd2;
localparam STREAM_BYTE_ORDER_0231 = 5'd3;
localparam STREAM_BYTE_ORDER_0312 = 5'd4;
localparam STREAM_BYTE_ORDER_0321 = 5'd5;
localparam STREAM_BYTE_ORDER_1023 = 5'd6;
localparam STREAM_BYTE_ORDER_1032 = 5'd7;
localparam STREAM_BYTE_ORDER_1203 = 5'd8;
localparam STREAM_BYTE_ORDER_1230 = 5'd9;
localparam STREAM_BYTE_ORDER_1302 = 5'd10;
localparam STREAM_BYTE_ORDER_1320 = 5'd11;
localparam STREAM_BYTE_ORDER_2013 = 5'd12;
localparam STREAM_BYTE_ORDER_2031 = 5'd13;
localparam STREAM_BYTE_ORDER_2103 = 5'd14;
localparam STREAM_BYTE_ORDER_2130 = 5'd15;
localparam STREAM_BYTE_ORDER_2301 = 5'd16;
localparam STREAM_BYTE_ORDER_2310 = 5'd17;
localparam STREAM_BYTE_ORDER_3012 = 5'd18;
localparam STREAM_BYTE_ORDER_3021 = 5'd19;
localparam STREAM_BYTE_ORDER_3102 = 5'd20;
localparam STREAM_BYTE_ORDER_3120 = 5'd21;
localparam STREAM_BYTE_ORDER_3201 = 5'd22;
localparam STREAM_BYTE_ORDER_3210 = 5'd23;

reg [31:0] stream_word_odrered;

always @ (*)begin
	case (stream_byte_order)
		STREAM_BYTE_ORDER_0123 : stream_word_odrered = {s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[31:24]};
		STREAM_BYTE_ORDER_0132 : stream_word_odrered = {s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[31:24], s_axis_tdata[23:16]};
		STREAM_BYTE_ORDER_0213 : stream_word_odrered = {s_axis_tdata[7:0], s_axis_tdata[23:16], s_axis_tdata[15:8], s_axis_tdata[31:24]};
		STREAM_BYTE_ORDER_0231 : stream_word_odrered = {s_axis_tdata[7:0], s_axis_tdata[23:16], s_axis_tdata[31:24], s_axis_tdata[15:8]};
		STREAM_BYTE_ORDER_0312 : stream_word_odrered = {s_axis_tdata[7:0], s_axis_tdata[31:24], s_axis_tdata[15:8], s_axis_tdata[23:16]};
		STREAM_BYTE_ORDER_0321 : stream_word_odrered = {s_axis_tdata[7:0], s_axis_tdata[31:24], s_axis_tdata[23:16], s_axis_tdata[15:8]};
		STREAM_BYTE_ORDER_1023 : stream_word_odrered = {s_axis_tdata[15:8], s_axis_tdata[7:0], s_axis_tdata[23:16], s_axis_tdata[31:24]};
		STREAM_BYTE_ORDER_1032 : stream_word_odrered = {s_axis_tdata[15:8], s_axis_tdata[7:0], s_axis_tdata[31:24], s_axis_tdata[23:16]};
		STREAM_BYTE_ORDER_1203 : stream_word_odrered = {s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[7:0], s_axis_tdata[31:24]};
		STREAM_BYTE_ORDER_1230 : stream_word_odrered = {s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[31:24], s_axis_tdata[7:0]};
		STREAM_BYTE_ORDER_1302 : stream_word_odrered = {s_axis_tdata[15:8], s_axis_tdata[31:24], s_axis_tdata[7:0], s_axis_tdata[23:16]};
		STREAM_BYTE_ORDER_1320 : stream_word_odrered = {s_axis_tdata[15:8], s_axis_tdata[31:24], s_axis_tdata[23:16], s_axis_tdata[7:0]};
		STREAM_BYTE_ORDER_2013 : stream_word_odrered = {s_axis_tdata[23:16], s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[31:24]};
		STREAM_BYTE_ORDER_2031 : stream_word_odrered = {s_axis_tdata[23:16], s_axis_tdata[7:0], s_axis_tdata[31:24], s_axis_tdata[15:8]};
		STREAM_BYTE_ORDER_2103 : stream_word_odrered = {s_axis_tdata[23:16], s_axis_tdata[15:8], s_axis_tdata[7:0], s_axis_tdata[31:24]};
		STREAM_BYTE_ORDER_2130 : stream_word_odrered = {s_axis_tdata[23:16], s_axis_tdata[15:8], s_axis_tdata[31:24], s_axis_tdata[7:0]};
		STREAM_BYTE_ORDER_2301 : stream_word_odrered = {s_axis_tdata[23:16], s_axis_tdata[31:24], s_axis_tdata[7:0], s_axis_tdata[15:8]};
		STREAM_BYTE_ORDER_2310 : stream_word_odrered = {s_axis_tdata[23:16], s_axis_tdata[31:24], s_axis_tdata[15:8], s_axis_tdata[7:0]};
		STREAM_BYTE_ORDER_3012 : stream_word_odrered = {s_axis_tdata[31:24], s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[23:16]};
		STREAM_BYTE_ORDER_3021 : stream_word_odrered = {s_axis_tdata[31:24], s_axis_tdata[7:0], s_axis_tdata[23:16], s_axis_tdata[15:8]};
		STREAM_BYTE_ORDER_3102 : stream_word_odrered = {s_axis_tdata[31:24], s_axis_tdata[15:8], s_axis_tdata[7:0], s_axis_tdata[23:16]};
		STREAM_BYTE_ORDER_3120 : stream_word_odrered = {s_axis_tdata[31:24], s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[7:0]};
		STREAM_BYTE_ORDER_3201 : stream_word_odrered = {s_axis_tdata[31:24], s_axis_tdata[23:16], s_axis_tdata[7:0], s_axis_tdata[15:8]};
		STREAM_BYTE_ORDER_3210 : stream_word_odrered = {s_axis_tdata[31:24], s_axis_tdata[23:16], s_axis_tdata[15:8], s_axis_tdata[7:0]};
		default: stream_word_odrered = {s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[31:24]};
	endcase
end


/**
*8==================================================================================D
*8==================================================================================D
*8===================                                             ==================D
*8=================              SPI CLOCK GENERATION               ================D
*8===================                                             ==================D
*8==================================================================================D
*8==================================================================================D
*/

	reg [15:0]spi_clk_pscl;
	reg [3:0]spi_clk_pscl_sel;
	reg spi_clk_gen;
	
	
	//user write control_b into reg
	always @(posedge s_axi_aclk or negedge rst_n) begin
		if(~rst_n)begin
			spi_clk_pscl_sel <= 1;
		end else if(w_success && awaddr_active == SPI_CLK_SPCL_ADDR && spi_state_is_idle)begin
			spi_clk_pscl_sel <= s_axi_wdata[3:0];
		end else begin
			spi_clk_pscl_sel <= spi_clk_pscl_sel;
		end
		
	end

	always @(*)begin
		case(spi_clk_pscl_sel)
		4'h0: spi_clk_gen = 1'b0;
		4'h1: spi_clk_gen = spi_clk_pscl[0];
		4'h2: spi_clk_gen = spi_clk_pscl[1];
		4'h3: spi_clk_gen = spi_clk_pscl[2];
		4'h4: spi_clk_gen = spi_clk_pscl[3];
		4'h5: spi_clk_gen = spi_clk_pscl[4];
		4'h6: spi_clk_gen = spi_clk_pscl[5];
		4'h7: spi_clk_gen = spi_clk_pscl[6];
		4'h8: spi_clk_gen = spi_clk_pscl[7];
		4'h9: spi_clk_gen = spi_clk_pscl[8];
		4'hA: spi_clk_gen = spi_clk_pscl[9];
		4'hB: spi_clk_gen = spi_clk_pscl[10];
		4'hC: spi_clk_gen = spi_clk_pscl[11];
		4'hD: spi_clk_gen = spi_clk_pscl[12];
		4'hE: spi_clk_gen = spi_clk_pscl[13];
		4'hF: spi_clk_gen = spi_clk_pscl[14];
		default: spi_clk_gen = spi_clk_pscl[15];
		endcase

	end

	always @(posedge s_axi_aclk or negedge rst_n) begin
		if(~rst_n)begin
			spi_clk_pscl <= 16'b0;
		end else begin
			spi_clk_pscl <= spi_clk_pscl + 1;
		end
		
	end

/**
*8==================================================================================D
*8==================================================================================D
*8===================                                             ==================D
*8=================              SPI CHIP SELECT BLOCK              ================D
*8===================                                             ==================D
*8==================================================================================D
*8==================================================================================D
*/


	reg [SPI_CS_WIDTH-1:0]chip_sel_r;

	//user write control_b into reg
	always @(posedge s_axi_aclk or negedge rst_n) begin
		if(~rst_n)begin
			chip_sel_r <= 16'hFFFF;
		end else if(w_success && awaddr_active == SPI_CHIP_SEL_ADDR && spi_state_is_idle)begin
			chip_sel_r <= s_axi_wdata[SPI_CS_WIDTH-1:0];
		end else if(w_success && awaddr_active == SPI_CS_W1C_ADDR && spi_state_is_idle)begin
			chip_sel_r <= chip_sel_r & ~s_axi_wdata[SPI_CS_WIDTH-1:0];
		end else if(w_success && awaddr_active == SPI_CS_W1S_ADDR && spi_state_is_idle)begin
			chip_sel_r <= chip_sel_r | s_axi_wdata[SPI_CS_WIDTH-1:0];
		end else begin
			chip_sel_r <= chip_sel_r;
		end
		
	end
	assign spi_cs_o = chip_sel_r;


/**
*8==================================================================================D
*8==================================================================================D
*8===================                                             ==================D
*8=================             SPI FRONT BUS TRANCEIVER            ================D
*8===================                                             ==================D
*8==================================================================================D
*8==================================================================================D
*/

wire [31:0]spi_front_tx_data;

assign spi_front_tx_data = spi_tx_data | {32{spi_strm_s2mm}};

wire [31:0]spi_front_rx_data;
assign m_axis_tdata = {spi_front_rx_data[7:0],spi_front_rx_data[15:8],spi_front_rx_data[23:16],spi_front_rx_data[31:24]};

//following are in trigger section
//wire spi_front_begin;
//wire spi_front_wide;
//wire spi_front_busy;

spi_front front(
    .spi_clk_in(spi_clk_gen),
    .rst_n(rst_n),


    .spi_clk_o(spi_clk_o),
    .spi_mosi_o(spi_mosi_o),
    .spi_miso_i(spi_miso_i),


    .data_mosi(spi_front_tx_data),
    .data_miso(spi_front_rx_data),

    .spi_begin(spi_front_begin),
    .spi_wide(spi_front_wide),
    .spi_busy(spi_front_busy)
);

/**
*8==================================================================================D
*8==================================================================================D
*8======================                                       =====================D
*8====================    PROPER TRI STATE EXTRA PORT ASSIGN     ===================D
*8======================                                       =====================D
*8==================================================================================D
*8==================================================================================D
*/

assign spi_clk_t = 1'b0;//always output
assign spi_mosi_t = 1'b0;//always output
assign spi_miso_t = 1'b1;//why? it is always input
assign spi_miso_o = 1'b1;//always input
assign spi_cs_t = 16'b0;//always output

/**
*8==================================================================================D
*8==================================================================================D
*8======================                                       =====================D
*8====================    TO SYSTEM MM INTERFACE OUTPUT DRIVE    ===================D
*8======================                                       =====================D
*8==================================================================================D
*8==================================================================================D
*/
reg [C_S_AXI_DATA_WIDTH-1:0]s_axi_rdata_r;
assign s_axi_rdata = s_axi_rdata_r;
	always @(*) begin
		case (araddr_active)
			DATA_ACCESS_ADDR : s_axi_rdata_r = spi_front_rx_data ; 	//read current transmitting byte *mosi_fifo_pop_ptr
			SPI_CHIP_SEL_ADDR : s_axi_rdata_r = {16'h0,chip_sel_r} ;		//read chip sel reg
			OP_STATUS_ADDR : s_axi_rdata_r = {31'h000,spi_front_busy} ;	//read status reg
			SPI_CLK_SPCL_ADDR : s_axi_rdata_r = {20'h000,spi_clk_pscl_sel}; //read clk prescaler select
			SPI_CTL_ADDR : s_axi_rdata_r = {16'h000,spi_ctl_reg}; //read spi control reg
			default: s_axi_rdata_r = 32'h67676767;
		endcase
	end


endmodule
module spi_front (
    input spi_clk_in,
    input rst_n,

    //spi interface
    output spi_clk_o,
    output spi_clk_t,
    output spi_mosi_o,
    output spi_mosi_t,
    input spi_miso_i,

    //data interface
    input [31:0] data_mosi,
    output [31:0] data_miso,

    //control interface
    input spi_begin,
    input spi_wide,
    output spi_busy

);


localparam SPI_STATE_IDLE = 0;
localparam SPI_STATE_ACTIVE = 1;

reg spi_state;
reg [4:0] spi_bit_ptr;
reg spi_clk_gate;
reg spi_busy_r;
reg [31:0]spi_tx_data;

assign spi_busy = spi_busy_r;
assign spi_clk_o = spi_clk_in & spi_clk_gate;


always @(negedge spi_clk_in or negedge rst_n) begin
    if(~rst_n) begin
        spi_state <= SPI_STATE_IDLE;
        spi_bit_ptr <= 3'b0;
        spi_clk_gate <= 1'b0;
        spi_busy_r <= 1'b0;
        spi_tx_data <= 8'b0;
        spi_rx_data_r <= 32'b0;
    end else begin
        case (spi_state)
            SPI_STATE_IDLE:begin
                if(spi_begin)begin
                    spi_state <= SPI_STATE_ACTIVE;
                    spi_bit_ptr <= {{2{spi_wide}},3'h7};
                    spi_clk_gate <= 1'b1;
                    spi_busy_r <= 1'b1;
                    spi_tx_data <= data_mosi;
                end
            end
            SPI_STATE_ACTIVE:begin
                if(~|spi_bit_ptr)begin
                    spi_state <= SPI_STATE_IDLE;
                    spi_bit_ptr <= 3'h0;
                    spi_clk_gate <= 1'b0;
                    spi_busy_r <= 1'b0;
                    spi_rx_data_r <= spi_rx_data;
                end else begin
                    spi_bit_ptr <= spi_bit_ptr - 3'b1;
                    
                end
            end
            default: begin
                spi_state <= SPI_STATE_IDLE;
                spi_bit_ptr <= 3'b0;
                spi_clk_gate <= 1'b0;
                spi_busy_r <= 1'b0; 
            end

        endcase
    end
end

reg spi_mosi_r;
assign spi_mosi_o = spi_mosi_r;
always @(*) begin
    case (spi_bit_ptr)
        5'd1: spi_mosi_r = spi_tx_data[1];
        5'd2: spi_mosi_r = spi_tx_data[2];
        5'd3: spi_mosi_r = spi_tx_data[3];
        5'd4: spi_mosi_r = spi_tx_data[4];
        5'd5: spi_mosi_r = spi_tx_data[5];
        5'd6: spi_mosi_r = spi_tx_data[6];
        5'd7: spi_mosi_r = spi_tx_data[7];
        5'd8: spi_mosi_r = spi_tx_data[8];
        5'd9: spi_mosi_r = spi_tx_data[9];
        5'd10: spi_mosi_r = spi_tx_data[10];
        5'd11: spi_mosi_r = spi_tx_data[11];
        5'd12: spi_mosi_r = spi_tx_data[12];
        5'd13: spi_mosi_r = spi_tx_data[13];
        5'd14: spi_mosi_r = spi_tx_data[14];
        5'd15: spi_mosi_r = spi_tx_data[15];
        5'd16: spi_mosi_r = spi_tx_data[16];
        5'd17: spi_mosi_r = spi_tx_data[17];
        5'd18: spi_mosi_r = spi_tx_data[18];
        5'd19: spi_mosi_r = spi_tx_data[19];
        5'd20: spi_mosi_r = spi_tx_data[20];
        5'd21: spi_mosi_r = spi_tx_data[21];
        5'd22: spi_mosi_r = spi_tx_data[22];
        5'd23: spi_mosi_r = spi_tx_data[23];
        5'd24: spi_mosi_r = spi_tx_data[24];
        5'd25: spi_mosi_r = spi_tx_data[25];
        5'd26: spi_mosi_r = spi_tx_data[26];
        5'd27: spi_mosi_r = spi_tx_data[27];
        5'd28: spi_mosi_r = spi_tx_data[28];
        5'd29: spi_mosi_r = spi_tx_data[29];
        5'd30: spi_mosi_r = spi_tx_data[30];
        5'd31: spi_mosi_r = spi_tx_data[31];
        default: spi_mosi_r = spi_tx_data[0];
    endcase
end

reg [31:0]spi_rx_data;
reg [31:0]spi_rx_data_r;
assign data_miso = spi_rx_data_r;
always @(posedge spi_clk_in or negedge rst_n) begin
    if(~rst_n) begin
        spi_rx_data <= 8'b0;
    end else if(spi_busy_r) begin
        spi_rx_data <= {spi_rx_data[30:0],spi_miso_i};
    end else begin
        spi_rx_data <= spi_rx_data;
    end
end


endmodule
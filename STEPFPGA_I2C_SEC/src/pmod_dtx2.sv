module pmod_dtx2 #(
    parameter CLK_IN = 80_000_000,
    parameter PSEL_FREQ = 1_000,
    parameter COMMON_ANODE = 1
) (
    input  wire clk,
    input  wire rst_n,
    input  wire [6:0] seg_1_in,
    input  wire [6:0] seg_2_in,
    output wire [6:0] seg_out,
    output wire seg_sel 
);

    localparam PSEL_DELAY = CLK_IN / PSEL_FREQ;
    logic [31:0] c_counter;
    logic p_sel;
    logic [6:0] seg_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_counter <= 0;
            p_sel <= 1'b0;
        end else begin
            if (c_counter >= PSEL_DELAY) begin
                c_counter <= 0;
                p_sel <= ~p_sel;
            end else begin
                c_counter <= c_counter + 1;
            end
        end
    end

    assign seg_buf = (p_sel) ? seg_2_in : seg_1_in ;
    assign seg_out = (COMMON_ANODE) ? ~seg_buf : seg_buf ;
    assign seg_sel = p_sel;

endmodule
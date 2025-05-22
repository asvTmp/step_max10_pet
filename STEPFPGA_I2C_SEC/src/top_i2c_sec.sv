import seven_seg_pkg::*;

module top_i2c_sec ( 
    input wire clk_12MHZ, //clk_in = 12mhz 
    input wire [4:1] KEY_BUTTON,
    input wire [4:1] DIP_SW,

    output wire RGB_LED_1_R,
    output wire RGB_LED_1_G,
    output wire RGB_LED_1_B,

    output wire RGB_LED_2_R,
    output wire RGB_LED_2_G,
    output wire RGB_LED_2_B,

    output wire SEG_A1,
    output wire SEG_B1,
    output wire SEG_C1,
    output wire SEG_D1,
    output wire SEG_E1,
    output wire SEG_F1,
    output wire SEG_G1,
    output wire SEG_DP1,
    output wire SEG_DIG1,

    output wire SEG_A2,
    output wire SEG_B2,
    output wire SEG_C2,
    output wire SEG_D2,
    output wire SEG_E2,
    output wire SEG_F2,
    output wire SEG_G2,
    output wire SEG_DP2,
    output wire SEG_DIG2,

    output wire GPIO4,
    output wire GPIO5,
    output wire GPIO6,
    output wire GPIO7,
    output wire GPIO8,
    output wire GPIO9,
    output wire GPIO20,
    output wire GPIO21,

    output wire [8:1] LED 
); 

    localparam CLK_IN_FREQ = 12_000_000;
    localparam CLK_FREQ = 84_000_000;

    logic [7:0]leds;
    logic rst_n;
    logic clk;
    logic [3:0] dips_in;
    logic lock;
    logic pulse_1us;
    logic pulse_1ms;
    logic pulse_1s;
    logic [7:0] sec_count;
    logic [1:0] min_count;
    logic [7:0] seg_value;
    logic [7:0] snake_reg;
    logic [2:0] rgb_cnt_1;
    logic [2:0] rgb_cnt_2;

    logic [6:0] seg_out_1;
    logic [6:0] seg_out_2;
    logic seg_1_dp;
    logic seg_2_dp;
    logic seg_1_dig;
    logic seg_2_dig;
    logic [6:0] seg_out;

    logic [3:0] hundreds;
    logic [3:0] tens;
    logic [3:0] ones;
    logic [7:0] sec_hex;
    logic [7:0] sec_bcd;

    logic hex_on;
    logic sel_rgb;
    logic [2:0] rgb_key;

    logic [31:0] c_counter;
    logic p_sel;

    logic PMOD_DTx2_A;
    logic PMOD_DTx2_B;
    logic PMOD_DTx2_C;
    logic PMOD_DTx2_D;
    logic PMOD_DTx2_E;
    logic PMOD_DTx2_F;
    logic PMOD_DTx2_G;

    assign rst_n = KEY_BUTTON[1];
    assign hex_on = ~KEY_BUTTON[2];

    assign sel_rgb = DIP_SW[1];
    assign rgb_key = DIP_SW[4:2];

    /* parameterized module instance */

    alt_pll_stepfpga	alt_pll_stepfpga_inst (
	    .inclk0     ( clk_12MHZ ),
	    .c0         ( clk ),
	    .locked     ( lock )
	);

    pulses_gen #(
        .CLK_IN_HZ(CLK_FREQ),
        .PULSE_1_CLK(1_000_000),
        .PULSE_1_CNT(1000),
        .PULSE_2_CNT(1000)
    ) inst_pulses_gen (
        .rst_n(rst_n),
        .clk(clk),
        .pulse_1(pulse_1us),
        .pulse_2(pulse_1ms),
        .pulse_3(pulse_1s) 
    );

    assign sec_hex = sec_count;
    assign {hundreds, tens, ones} = hex8_to_bcd_opt(sec_hex);
    assign sec_bcd = {tens, ones};
    assign seg_value = (hex_on) ? sec_hex : sec_bcd;

    assign seg_out_1 = seven_seg_decode(seg_value[7:4], 1'b0);
    assign seg_out_2 = seven_seg_decode(seg_value[3:0], 1'b0);

    assign {seg_1_dp, seg_2_dp} = min_count[1:0];

    assign rgb_cnt_2 = (sel_rgb) ? rgb_key : sec_hex[5:3];
    assign rgb_cnt_1 = (sel_rgb) ? rgb_key : sec_hex[2:0];

    assign LED[8:1] = ~snake_reg[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_counter <= 0;
        end else begin
            c_counter <= c_counter + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snake_reg <= 8'h1;
        end else begin
            if (pulse_1s) begin
                snake_reg[7:0] <= {snake_reg[6:0], snake_reg[7]};
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_count <= 'h0;
            min_count <= 0;
        end else begin
            if (pulse_1s) begin
                // sec_count <= (sec_count==59) ? 0 : sec_count + 1;
                if (sec_count == 'd59) begin
                    sec_count <= 0;
                    min_count <= min_count + 1;
                end else begin
                    sec_count <= sec_count + 1;
                end
            end
        end
    end

    assign RGB_LED_1_R = rgb_cnt_1[2];
    assign RGB_LED_1_G = rgb_cnt_1[1];
    assign RGB_LED_1_B = rgb_cnt_1[0];

    assign RGB_LED_2_R = rgb_cnt_2[2];
    assign RGB_LED_2_G = rgb_cnt_2[1];
    assign RGB_LED_2_B = rgb_cnt_2[0];

    assign seg_1_dig = 1'b0;
    assign seg_2_dig = 1'b0;

    always_comb begin
        SEG_A1      = seg_out_1[6];
        SEG_B1      = seg_out_1[5];
        SEG_C1      = seg_out_1[4];
        SEG_D1      = seg_out_1[3];
        SEG_E1      = seg_out_1[2];
        SEG_F1      = seg_out_1[1];
        SEG_G1      = seg_out_1[0];
        SEG_DP1     = seg_1_dp;
        SEG_DIG1    = seg_1_dig;

        SEG_A2      = seg_out_2[6];
        SEG_B2      = seg_out_2[5];
        SEG_C2      = seg_out_2[4];
        SEG_D2      = seg_out_2[3];
        SEG_E2      = seg_out_2[2];
        SEG_F2      = seg_out_2[1];
        SEG_G2      = seg_out_2[0];
        SEG_DP2     = seg_2_dp;
        SEG_DIG2    = seg_2_dig;
    end

    pmod_dtx2 #(
        .CLK_IN(CLK_FREQ),
        .PSEL_FREQ(1_000),
        .COMMON_ANODE(1'b1)
    ) inst_pmod(
        .clk(clk),
        .rst_n(rst_n),
        .seg_1_in(seg_out_1),
        .seg_2_in(seg_out_2),
        .seg_out(seg_out),
        .seg_sel(p_sel) 
    );

    assign PMOD_DTx2_A      = seg_out[6];
    assign PMOD_DTx2_B      = seg_out[5];
    assign PMOD_DTx2_C      = seg_out[4];
    assign PMOD_DTx2_D      = seg_out[3];
    assign PMOD_DTx2_E      = seg_out[2];
    assign PMOD_DTx2_F      = seg_out[1];
    assign PMOD_DTx2_G      = seg_out[0];

    assign GPIO4    = PMOD_DTx2_C;
    assign GPIO5    = PMOD_DTx2_B;
    assign GPIO6    = PMOD_DTx2_D;
    assign GPIO7    = PMOD_DTx2_E;
    assign GPIO8    = PMOD_DTx2_G;
    assign GPIO9    = PMOD_DTx2_F;
    assign GPIO20   = PMOD_DTx2_A;
    assign GPIO21   = p_sel;

endmodule

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
    logic pulse_10ms;
    logic pulse_1s;
    logic [7:0] sec_count;
    logic [1:0] min_count;
    logic [7:0] seg_value;
    logic [7:0] snake_reg;
    logic [2:0] rgb_cnt_1;
    logic [2:0] rgb_cnt_2;

    logic [9:0] ms_count;
    logic [9:0] tms_count;

    logic [6:0] seg_out_1;
    logic [6:0] seg_out_2;
    logic [6:0] mseg_out_1;
    logic [6:0] mseg_out_2;
    logic seg_1_dp;
    logic seg_2_dp;
    logic seg_1_dig;
    logic seg_2_dig;
    logic [6:0] seg_out;

    logic [3:0] thundreds;
    logic [3:0] ttens;
    logic [3:0] tones;
    logic [7:0] msec_hex;
    logic [7:0] msec_bcd;
    logic [7:0] mseg_value;

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

    logic lock_btn;
    logic pause_btn;

    logic [6:0] seg_out_1_r;
    logic [6:0] seg_out_2_r;
    logic [6:0] mseg_out_1_r;
    logic [6:0] mseg_out_2_r;

    assign rst_n = KEY_BUTTON[1];
    assign hex_on = ~KEY_BUTTON[2];
    assign lock_btn = KEY_BUTTON[3];
    assign pause_btn = KEY_BUTTON[4];

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

    assign msec_hex = tms_count;
    assign {thundreds, ttens, tones} = hex8_to_bcd_opt(msec_hex);
    assign msec_bcd = {ttens, tones};
    assign mseg_value = (hex_on) ? msec_hex : msec_bcd;

    assign mseg_out_1 = seven_seg_decode(mseg_value[7:4], 1'b0);
    assign mseg_out_2 = seven_seg_decode(mseg_value[3:0], 1'b0);

    assign sec_hex = sec_count;
    assign {hundreds, tens, ones} = hex8_to_bcd_opt(sec_hex);
    assign sec_bcd = {tens, ones};
    assign seg_value = (hex_on) ? sec_hex : sec_bcd;

    assign seg_out_1 = seven_seg_decode(seg_value[7:4], 1'b0);
    assign seg_out_2 = seven_seg_decode(seg_value[3:0], 1'b0);

    // assign {seg_1_dp, seg_2_dp} = min_count[1:0];
    // assign {seg_1_dp, seg_2_dp} = sec_hex[1:0];
    assign seg_1_dp = sec_hex[0];
    assign seg_2_dp = ~sec_hex[0];

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

    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //     end else begin
    //         if (pulse_1s) begin
    //         end
    //     end
    // end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_count <= 'h0;
            ms_count <= 'd0;
            min_count <= 0;
            pulse_10ms <= 1'b0;
            snake_reg <= 8'h1;
        end else begin
            if (pulse_1ms & pause_btn) begin
                if (ms_count == 9) begin
                    ms_count <= 0;
                    pulse_10ms <= 1'b1;
                end else begin
                    ms_count <= ms_count + 1;
                    pulse_10ms <= 1'b0;
                end
            end else begin
                pulse_10ms <= 1'b0;
            end
            if (pulse_10ms) begin
                if (tms_count == 'd99) begin
                    tms_count <= 'd0;
                    if (sec_count == 'd59) begin
                        sec_count <= 0;
                        min_count <= min_count + 1;
                    end else begin
                        sec_count <= sec_count + 1;
                    end
                    snake_reg[7:0] <= {snake_reg[6:0], snake_reg[7]};
                end else begin
                    tms_count <= tms_count + 1;
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mseg_out_1_r <= 0;
            mseg_out_2_r <= 0;
            seg_out_1_r <= 0;
            seg_out_2_r <= 0;
        end else begin
            if (lock_btn) begin
                mseg_out_1_r <= mseg_out_1;
                mseg_out_2_r <= mseg_out_2;
                seg_out_1_r <= seg_out_1;
                seg_out_2_r <= seg_out_2;
            end
        end
    end


    always_comb begin
        SEG_A1      = mseg_out_1_r[6];
        SEG_B1      = mseg_out_1_r[5];
        SEG_C1      = mseg_out_1_r[4];
        SEG_D1      = mseg_out_1_r[3];
        SEG_E1      = mseg_out_1_r[2];
        SEG_F1      = mseg_out_1_r[1];
        SEG_G1      = mseg_out_1_r[0];
        SEG_DP1     = seg_1_dp;
        SEG_DIG1    = seg_1_dig;

        SEG_A2      = mseg_out_2_r[6];
        SEG_B2      = mseg_out_2_r[5];
        SEG_C2      = mseg_out_2_r[4];
        SEG_D2      = mseg_out_2_r[3];
        SEG_E2      = mseg_out_2_r[2];
        SEG_F2      = mseg_out_2_r[1];
        SEG_G2      = mseg_out_2_r[0];
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
        .seg_1_in(seg_out_1_r),
        .seg_2_in(seg_out_2_r),
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

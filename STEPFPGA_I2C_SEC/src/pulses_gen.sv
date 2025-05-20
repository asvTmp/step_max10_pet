module pulses_gen #(
    parameter CLK_IN_HZ = 100_000_000,
    parameter PULSE_1_CLK = 1_000_000,
    parameter PULSE_0_CNT = CLK_IN_HZ / PULSE_1_CLK,
    parameter PULSE_1_CNT = 1000,
    parameter PULSE_2_CNT = 1000
) (
    input wire rst_n,
    input wire clk,
    output wire pulse_1,
    output wire pulse_2,
    output wire pulse_3
);

    logic [31:0] div_counter;
    logic pulse_1r;
    logic pulse_2r;
    logic pulse_3r;
    logic [31:0] cnt_pulse1;
    logic [31:0] cnt_pulse2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_counter <= 32'h0;
            pulse_1r <= 1'b0;
        end else begin
            if (div_counter >= PULSE_0_CNT) begin
                div_counter <= 32'h0;
                pulse_1r <= 1'b1;
            end else begin
                div_counter <= div_counter + 1;
                pulse_1r <= 1'b0;
            end
        end
    end    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse_2r <= 1'b0;
            pulse_3r <= 1'b0;
            cnt_pulse1 <= 'h0;
            cnt_pulse2 <= 'h0;
        end else begin

            if (pulse_1r) begin
                if (cnt_pulse1 >= PULSE_1_CNT) begin
                    cnt_pulse1 <= 'h0;
                    pulse_2r <= 1'b1;
                end else begin
                    cnt_pulse1 <= cnt_pulse1 + 1;
                    pulse_2r <= 1'b0;
                end
            end else begin
                pulse_2r <= 1'b0;
            end

            if (pulse_2r) begin
                if (cnt_pulse2 >= PULSE_2_CNT) begin
                    cnt_pulse2 <= 'h0;
                    pulse_3r <= 1'b1;
                end else begin
                    cnt_pulse2 <= cnt_pulse2 + 1;
                    pulse_3r <= 1'b0;
                end
            end else begin
                pulse_3r <= 1'b0;
            end

        end
    end    

    assign pulse_1 = pulse_1r;
    assign pulse_2 = pulse_2r;
    assign pulse_3 = pulse_3r;
  
endmodule
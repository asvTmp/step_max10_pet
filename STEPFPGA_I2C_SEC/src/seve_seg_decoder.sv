module seven_seg_decoder #(
    parameter COMMON_ANODE = 1  // 1 - общий анод (активный 0), 0 - общий катод (активный 1)
) (
    input [3:0] bin_input,     // 4-битный вход (0x0-0xF)
    output reg [6:0] seg_out   // Выход на сегменты [a, b, c, d, e, f, g]
);

// Логика преобразования двоичного кода в сегменты
always @(*) begin
    case (bin_input)
        // Цифры 0-9
        4'h0: seg_out = COMMON_ANODE ? 7'b0000001 : 7'b1111110; // 0
        4'h1: seg_out = COMMON_ANODE ? 7'b1001111 : 7'b0110000; // 1
        4'h2: seg_out = COMMON_ANODE ? 7'b0010010 : 7'b1101101; // 2
        4'h3: seg_out = COMMON_ANODE ? 7'b0000110 : 7'b1111001; // 3
        4'h4: seg_out = COMMON_ANODE ? 7'b1001100 : 7'b0110011; // 4
        4'h5: seg_out = COMMON_ANODE ? 7'b0100100 : 7'b1011011; // 5
        4'h6: seg_out = COMMON_ANODE ? 7'b0100000 : 7'b1011111; // 6
        4'h7: seg_out = COMMON_ANODE ? 7'b0001111 : 7'b1110000; // 7
        4'h8: seg_out = COMMON_ANODE ? 7'b0000000 : 7'b1111111; // 8
        4'h9: seg_out = COMMON_ANODE ? 7'b0000100 : 7'b1111011; // 9
        
        // Буквы A-F (для шестнадцатеричного отображения)
        4'hA: seg_out = COMMON_ANODE ? 7'b0001000 : 7'b1110111; // A
        4'hB: seg_out = COMMON_ANODE ? 7'b1100000 : 7'b0011111; // b
        4'hC: seg_out = COMMON_ANODE ? 7'b0110001 : 7'b1001110; // C
        4'hD: seg_out = COMMON_ANODE ? 7'b1000010 : 7'b0111101; // d
        4'hE: seg_out = COMMON_ANODE ? 7'b0110000 : 7'b1001111; // E
        4'hF: seg_out = COMMON_ANODE ? 7'b0111000 : 7'b1000111; // F
        
        // По умолчанию - все сегменты выключены
        default: seg_out = COMMON_ANODE ? 7'b1111111 : 7'b0000000;
    endcase
end

endmodule
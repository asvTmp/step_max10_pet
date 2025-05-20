// Пакет с функцией декодирования
package seven_seg_pkg;
    
    // Функция декодирования 4-битного значения в 7-сегментный код
    function automatic logic [6:0] seven_seg_decode(
        input logic [3:0] bin_input,
        input logic common_anode = 1
    );
        case (bin_input)
            // Цифры 0-9
            4'h0: seven_seg_decode = common_anode ? 7'b0000001 : 7'b1111110; // 0
            4'h1: seven_seg_decode = common_anode ? 7'b1001111 : 7'b0110000; // 1
            4'h2: seven_seg_decode = common_anode ? 7'b0010010 : 7'b1101101; // 2
            4'h3: seven_seg_decode = common_anode ? 7'b0000110 : 7'b1111001; // 3
            4'h4: seven_seg_decode = common_anode ? 7'b1001100 : 7'b0110011; // 4
            4'h5: seven_seg_decode = common_anode ? 7'b0100100 : 7'b1011011; // 5
            4'h6: seven_seg_decode = common_anode ? 7'b0100000 : 7'b1011111; // 6
            4'h7: seven_seg_decode = common_anode ? 7'b0001111 : 7'b1110000; // 7
            4'h8: seven_seg_decode = common_anode ? 7'b0000000 : 7'b1111111; // 8
            4'h9: seven_seg_decode = common_anode ? 7'b0000100 : 7'b1111011; // 9
            
            // Буквы A-F (hex)
            4'hA: seven_seg_decode = common_anode ? 7'b0001000 : 7'b1110111; // A
            4'hB: seven_seg_decode = common_anode ? 7'b1100000 : 7'b0011111; // b
            4'hC: seven_seg_decode = common_anode ? 7'b0110001 : 7'b1001110; // C
            4'hD: seven_seg_decode = common_anode ? 7'b1000010 : 7'b0111101; // d
            4'hE: seven_seg_decode = common_anode ? 7'b0110000 : 7'b1001111; // E
            4'hF: seven_seg_decode = common_anode ? 7'b0111000 : 7'b1000111; // F
            
            // По умолчанию - все сегменты выключены
            default: seven_seg_decode = common_anode ? 7'b1111111 : 7'b0000000;
        endcase
    endfunction
    
    // Расширенная функция с точкой
    function automatic logic [7:0] seven_seg_decode_dp(
        input logic [3:0] bin_input,
        input logic dp,
        input logic common_anode = 1
    );
        seven_seg_decode_dp[6:0] = seven_seg_decode(bin_input, common_anode);
        seven_seg_decode_dp[7] = common_anode ? ~dp : dp;
    endfunction


    function automatic logic [11:0] hex8_to_bcd_opt(input logic [7:0] hex_value);
        logic [3:0] hundreds = 0;
        logic [3:0] tens = 0;
        logic [3:0] ones = 0;
        logic [7:0] temp = hex_value;
        
        // Вычисление сотен
        if (temp >= 200) begin
            hundreds = 2;
            temp = temp - 200;
        end
        else if (temp >= 100) begin
            hundreds = 1;
            temp = temp - 100;
        end
        
        // Вычисление десятков и единиц
        if (temp >= 90) begin
            tens = 9;
            ones = temp - 90;
        end
        else if (temp >= 80) begin
            tens = 8;
            ones = temp - 80;
        end
        else if (temp >= 70) begin
            tens = 7;
            ones = temp - 70;
        end
        else if (temp >= 60) begin
            tens = 6;
            ones = temp - 60;
        end
        else if (temp >= 50) begin
            tens = 5;
            ones = temp - 50;
        end
        else if (temp >= 40) begin
            tens = 4;
            ones = temp - 40;
        end
        else if (temp >= 30) begin
            tens = 3;
            ones = temp - 30;
        end
        else if (temp >= 20) begin
            tens = 2;
            ones = temp - 20;
        end
        else if (temp >= 10) begin
            tens = 1;
            ones = temp - 10;
        end
        else begin
            ones = temp;
        end
        
        return {hundreds, tens, ones};
    endfunction

endpackage

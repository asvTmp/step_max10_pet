module uart_tx #(
    parameter CLK_FREQ = 84_000_000,  // Внешняя частота (84 МГц)
    parameter BAUD_RATE = 9600        // Скорость передачи (9600 бод)
) (
    input wire clk,       // Тактовый сигнал (84 МГц)
    input wire rst_n,      // Сброс (активный 0)
    input wire [7:0] data, // Данные для передачи
    input wire start,      // Сигнал начала передачи
    output reg tx,         // Выходная линия UART
    output wire busy       // Флаг занятости передатчика
);

// Расчет делителя для получения заданной скорости передачи
localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
localparam BIT_COUNTER_WIDTH = $clog2(BIT_PERIOD);
localparam BIT_HALF_PERIOD = BIT_PERIOD / 2;

// Состояния конечного автомата
typedef enum {
    IDLE,       // Ожидание данных
    START_BIT,  // Старт-бит
    DATA_BITS,  // Передача битов данных
    STOP_BIT    // Стоп-бит
} state_t;

reg [2:0] state = IDLE;
reg [2:0] next_state;

reg [BIT_COUNTER_WIDTH-1:0] bit_timer = 0;
reg [2:0] bit_index = 0;
reg [7:0] tx_data = 0;

// Выходной сигнал busy
assign busy = (state != IDLE);

// Логика перехода между состояниями
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = START_BIT;
            end
        end
        START_BIT: begin
            if (bit_timer == BIT_PERIOD - 1) begin
                next_state = DATA_BITS;
            end
        end
        DATA_BITS: begin
            if (bit_timer == BIT_PERIOD - 1 && bit_index == 7) begin
                next_state = STOP_BIT;
            end
        end
        STOP_BIT: begin
            if (bit_timer == BIT_PERIOD - 1) begin
                next_state = IDLE;
            end
        end
    endcase
end

// Счетчик времени для каждого бита
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_timer <= 0;
        state <= IDLE;
        tx <= 1'b1; // В неактивном состоянии линия в 1
    end else begin
        state <= next_state;
        
        if (state != next_state) begin
            bit_timer <= 0;
        end else if (state != IDLE) begin
            if (bit_timer < BIT_PERIOD - 1) begin
                bit_timer <= bit_timer + 1;
            end else begin
                bit_timer <= 0;
            end
        end
        
        // Логика управления передачей
        case (state)
            IDLE: begin
                tx <= 1'b1;
                if (start) begin
                    tx_data <= data;
                end
            end
            START_BIT: begin
                tx <= 1'b0; // Старт-бит (0)
            end
            DATA_BITS: begin
                tx <= tx_data[bit_index];
                if (bit_timer == BIT_PERIOD - 1) begin
                    if (bit_index < 7) begin
                        bit_index <= bit_index + 1;
                    end else begin
                        bit_index <= 0;
                    end
                end
            end
            STOP_BIT: begin
                tx <= 1'b1; // Стоп-бит (1)
            end
        endcase
    end
end

endmodule
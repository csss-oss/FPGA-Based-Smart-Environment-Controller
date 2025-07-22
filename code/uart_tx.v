`timescale 1ns / 1ps

module uart_tx (
    input               clk,         // 시스템 클럭 (100 MHz)
    input               reset,       // 리셋 (active-high)
    input       [7:0]   i_data,      // 송신할 8비트 데이터
    input               i_start,     // 1클럭짜리 송신 시작 신호
    output  reg         o_tx_serial, // UART TX 핀
    output              o_busy       // 송신 중일 때 '1'
);

    
    parameter CLKS_PER_BIT = 10417;

    // FSM 상태
    localparam IDLE      = 3'b000,
               START_BIT = 3'b001,
               DATA_BITS = 3'b010,
               STOP_BIT  = 3'b100;

    reg [2:0]  state;
    reg [15:0] clk_counter; // 비트 타이밍 카운터
    reg [2:0]  bit_index;   // 데이터 비트 인덱스 (0~7)
    reg [7:0]  tx_data;     // 송신할 데이터를 저장할 레지스터

    assign o_busy = (state != IDLE);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            clk_counter   <= 0;
            bit_index     <= 0;
            o_tx_serial   <= 1'b1; // UART는 평소에 HIGH
            tx_data       <= 0;
        end else begin
            case (state)
                IDLE: begin
                    o_tx_serial <= 1'b1;
                    if (i_start) begin
                        tx_data     <= i_data;
                        clk_counter <= 0;
                        state       <= START_BIT;
                    end
                end

                START_BIT: begin
                    o_tx_serial <= 1'b0; // 시작 비트 (LOW)
                    if (clk_counter < CLKS_PER_BIT - 1) begin
                        clk_counter <= clk_counter + 1;
                    end else begin
                        clk_counter <= 0;
                        bit_index   <= 0;
                        state       <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    o_tx_serial <= tx_data[bit_index];
                    if (clk_counter < CLKS_PER_BIT - 1) begin
                        clk_counter <= clk_counter + 1;
                    end else begin
                        clk_counter <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    o_tx_serial <= 1'b1; // 정지 비트 (HIGH)
                    if (clk_counter < CLKS_PER_BIT - 1) begin
                        clk_counter <= clk_counter + 1;
                    end else begin
                        clk_counter <= 0;
                        state       <= IDLE;
                    end
                end

                default:
                    state <= IDLE;
            endcase
        end
    end

endmodule
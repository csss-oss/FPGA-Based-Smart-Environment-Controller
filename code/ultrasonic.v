`timescale 1ns / 1ps

module ultrasonic2(
    input                 clk,        // 100 MHz
    input                 reset,      // active-high
    input                 echo,       // HC-SR04 echo
    input       [1:0]     i_state,
    output reg            danger_flag, // 5cm이하 check
    output reg            trig,       // HC-SR04 trig
    output reg  [7:0]     distance,   // cm 단위
    output reg            done        // 1-clk 펄스
);

    // FSM 상태
    parameter IDLE         = 3'd0,
              TRIG_HIGH    = 3'd1,
              WAIT_ECHO    = 3'd2,
              MEASURING    = 3'd3,
              DONE_STATE   = 3'd4;

    reg [2:0]  state;
    reg [31:0] trig_cnt, echo_cnt, timeout_cnt, delay_cnt;
    reg        echo_d;

  

    // 타이밍 상수 (100 MHz 기준)
    parameter TRIG_CLKS    = 1_000;     // 10 µs
    parameter TIMEOUT_CLKS = 3_000_000; // 30 ms
    localparam AIR_HANDLE  = 2'b10;
    parameter DELAY_1000MS_CLKS = 100_000_000;
    
   


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <=  IDLE;
            trig        <= 1'b0;
            distance    <= 8'd0;
            done        <= 1'b0;
            trig_cnt    <= 0;
            echo_cnt    <= 0;
            timeout_cnt <= 0;
            echo_d      <= 1'b0;
            delay_cnt   <= 0;
        end else begin
            echo_d  <= echo;
            done    <= 1'b0; // done 신호는 한 클럭 동안만 유지

            case (state)
                // --- 수정: 불필요한 cycle_cnt 로직 제거로 IDLE 상태 단순화 ---
                IDLE: begin
                    trig <= 1'b0;
                        if(delay_cnt >=DELAY_1000MS_CLKS )begin
                        trig        <= 1'b1;
                        trig_cnt    <= 0;
                        delay_cnt    <= 0;
                        timeout_cnt <= 0;
                        state       <= TRIG_HIGH;
                        end
                        else delay_cnt <= delay_cnt + 1;
                    
                end
       
                TRIG_HIGH: begin
                     if (trig_cnt < TRIG_CLKS) begin//1000클럭(10us동안)트리거신호 high
                        trig     <= 1'b1;
                        trig_cnt <= trig_cnt + 1;
                    end else begin
                        trig  <= 1'b0;
                        state <= WAIT_ECHO;
                    end
                end

                WAIT_ECHO: begin
                    if (echo && !echo_d) begin
                        echo_cnt    <= 0;
                        timeout_cnt <= 0;
                        state       <= MEASURING;
                    end
                    // 타임아웃
                    else if (timeout_cnt < TIMEOUT_CLKS) begin
                        timeout_cnt <= timeout_cnt + 1;
                    end else begin
                        state <= IDLE;
                    end
                end

                // --- 수정: MEASURING 상태의 로직 구조 변경 및 계산식 수정 ---
                MEASURING: begin
                    if (echo) begin
                        echo_cnt    <= echo_cnt + 1;
                        timeout_cnt <= 0;
                    end
                    // falling edge: 측정 완료
                    else if (!echo && echo_d && (i_state == AIR_HANDLE) ) begin
                        distance <= echo_cnt / 5800;  // cm 환산
                        done     <= 1'b1;

                        // 5cm 이하인지 비교
                        if (echo_cnt <= 5 * 5800)
                            danger_flag <= 1'b1;
                        else
                            danger_flag <= 1'b0;

                        state    <= DONE_STATE;
                    end
                    // 타임아웃
                    else if (timeout_cnt < TIMEOUT_CLKS) begin
                        timeout_cnt <= timeout_cnt + 1;
                    end else begin
                        state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
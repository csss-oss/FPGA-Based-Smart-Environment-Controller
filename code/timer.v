`timescale 1ns / 1ps

module timer(
    input clk,
    input reset,
    input [1:0] state,
    input [1:0] watch_state,
    input [2:0] oven_state,
    input [1:0] prev_watch_state,
    input [4:0] rise_button,
    output [13:0] watch_seg_data,
    output [13:0] oven_seg_data,
    output reg stop_flag_reg
    );

    //------ state encoding ------
    // 상위 모드
    localparam STOPWATCH   = 2'b00,
               MICROWAVE   = 2'b01,
               AIR_HANDLE  = 2'b10;

    // 시계 sub-FSM
    localparam UP_COUNTER   = 2'b00, 
               DOWN_COUNTER = 2'b01, 
               WATCH_STOP   = 2'b10, 
               WATCH        = 2'b11; 

    // 전자레인지 sub-FSM
    localparam IDLE        = 3'b000,
               READY       = 3'b001,
               COOK        = 3'b010,
               PAUSE       = 3'b011,
               COOK_END    = 3'b100; 


    // 공용 timer
    localparam integer TICKS_100  = 7'd100;     // 100 * 10ms = 1s
    localparam integer MAX_SEC    = 6'd59;




    // stopwatch timer
    localparam integer TICKS_60S = 14'd6000;
    localparam integer TICKS_30S = 14'd3000;

    reg [19:0] watch_counter;
    reg [13:0] ms10_counter;

    //30초 동안 stop이 되있을 경우
    reg [13:0] stop_tick_counter;

    // WATCH(분/초)용
    reg [6:0]  watch_10ms_cnt;  // 0..99 (10ms 틱 세기)
    reg [5:0]  watch_sec;       // 0..59
    reg [7:0]  watch_min;       // 0..255

    // 시계/초/분 데이터 선택용
    wire [13:0] watch_display;
    // 3분 45초 -> 345
    assign watch_display = watch_min * 14'd100 + watch_sec;





    // 전자레인지 timer
    localparam integer MIN_SEC    = 6'd0;

    // oven(분/초)
    reg [19:0] oven_counter;
    reg [6:0]  oven_10ms_cnt;  // 0..99 (10ms 틱 세기)
    reg [5:0]  oven_sec;       // 0..59
    reg [7:0]  oven_min;       // 0..255

    // 시계/초/분 데이터 선택용
    wire [13:0] oven_display;

    // 3분 45초 -> 345
    assign oven_display = oven_min * 14'd100 + oven_sec;

    // microwave
    always @(posedge clk or posedge reset) begin
        if(reset)
        begin
            oven_counter <= 0;
            oven_sec <= 0;
            oven_min <= 0;
            oven_10ms_cnt <= 0;

            watch_counter      <= 0;
            ms10_counter <= 0;
            stop_flag_reg <= 0;
            stop_tick_counter <= 0;
            watch_sec <= 0;
            watch_min <= 0;
            watch_10ms_cnt <= 0;
        end
        else
        begin
            if(state == MICROWAVE)
            begin
                 case(oven_state)
                    IDLE,READY:begin // READY , IDLE
                        if(rise_button[0]) // U->시간증가 버튼 (30초 단위로 증가)
                        begin
                            if(oven_sec + 30 >= MAX_SEC)
                            begin
                                oven_sec <= (oven_sec + 30) - 60;
                                oven_min <= oven_min + 1;
                            end
                            else
                            begin
                                oven_sec <= oven_sec + 30;
                            end
                        end
                        else if(rise_button[4]) // D->시간감소 버튼 (30초 단위로 감소)
                        begin
                            if (oven_min == 0 && oven_sec <= 30) //시간 감소 불가
                            begin
                                oven_min <= 0;
                                oven_sec <= 0;
                            end
                            else // 시간 감소 가능
                            begin
                                if(oven_sec < 30)
                                    begin
                                        oven_sec <= 60 - (30 - oven_sec);
                                        oven_min <= oven_min - 1;
                                    end
                                else
                                    begin
                                        oven_sec <= oven_sec - 30;
                                    end
                            end
                        end
                        else
                        begin
                            oven_min <= oven_min;
                            oven_sec <= oven_sec;
                        end
                    end
                    COOK:begin // COOK
                        if (oven_counter == 20'd1_000_000-1) begin  // 10ms
                                oven_counter      <= 0;
                                if (oven_10ms_cnt == TICKS_100-1) begin
                                    oven_10ms_cnt <= 0;
                                    // 1초 경과 → 초/분 업데이트
                                    if (oven_sec == 0) begin // 0초 도달시 SEC를 59로, MIN을 MIN - 1
                                        oven_sec <= MAX_SEC;
                                        oven_min <= oven_min - 1;
                                    end else begin
                                        oven_sec <= oven_sec - 1;
                                    end
                                end else begin
                                    oven_10ms_cnt <= oven_10ms_cnt + 1;
                                end
                            end else begin
                                oven_counter <= oven_counter + 1;
                            end
                    end
                    PAUSE:begin // PAUSE
                        oven_min <= oven_min;
                        oven_sec <= oven_sec;
                    end
                    COOK_END:begin // END
                        oven_min <= 0;
                        oven_sec <= 0;
                    end
                    default:begin
                        oven_min <= oven_min;
                        oven_sec <= oven_sec;
                    end
                endcase
            end
            else if (state == STOPWATCH) begin
                case (watch_state)
                    UP_COUNTER: begin
                        // STOP 플래그·카운터 클리어
                        stop_flag_reg     <= 0;
                        stop_tick_counter <= 0;

                        if (watch_counter == 20'd1_000_000-1) begin  // 10ms
                            watch_counter      <= 0;
                            if (ms10_counter == TICKS_60S-1)
                                ms10_counter <= 0;
                            else
                                ms10_counter <= ms10_counter + 1;

                            if (watch_10ms_cnt == TICKS_100-1) begin
                                watch_10ms_cnt <= 0;
                                // 1초 경과 → 초/분 업데이트
                                if (watch_sec == MAX_SEC) begin
                                    watch_sec <= 0;
                                    watch_min <= watch_min + 1;
                                end else begin
                                    watch_sec <= watch_sec + 1;
                                end
                            end else begin
                                watch_10ms_cnt <= watch_10ms_cnt + 1;
                            end
                        end else begin
                            watch_counter <= watch_counter + 1;
                        end
                    end

                    DOWN_COUNTER: begin
                        // STOP 플래그·카운터 클리어
                        stop_flag_reg     <= 0;
                        stop_tick_counter <= 0;

                        if (watch_counter == 20'd1_000_000-1) begin  // 10ms
                            watch_counter      <= 0;
                            if (ms10_counter == 0)
                                ms10_counter <= TICKS_60S-1;
                            else
                                ms10_counter <= ms10_counter - 1;

                            if (watch_10ms_cnt == TICKS_100-1) begin
                                watch_10ms_cnt <= 0;
                                // 1초 경과 → 초/분 업데이트
                                if (watch_sec == MAX_SEC) begin
                                    watch_sec <= 0;
                                    watch_min <= watch_min + 1;
                                end else begin
                                    watch_sec <= watch_sec + 1;
                                end
                            end else begin
                                watch_10ms_cnt <= watch_10ms_cnt + 1;
                            end
                        end else begin
                            watch_counter <= watch_counter + 1;
                        end
                    end

                    WATCH_STOP: begin
                        // ms10_counter는 그대로 유지
                        ms10_counter <= ms10_counter;
                        watch_sec <= watch_sec;
                        // 10 ms 분주
                        if (watch_counter == 20'd1_000_000-1) begin
                            watch_counter <= 0;
                            // 플래그가 아직 세워지지 않았다면
                            if (!stop_flag_reg) begin
                                if (stop_tick_counter == TICKS_30S-1) begin
                                    stop_flag_reg <= 1;       // 30s 경과 플래그
                                end else begin
                                    stop_tick_counter <= stop_tick_counter + 1;
                                end
                            end
                        end else begin
                            watch_counter <= watch_counter + 1;
                        end
                    end

                    WATCH: begin
                        // STOP 플래그 초기화
                        stop_flag_reg     <= 0;
                        stop_tick_counter <= 0;

                        // 10ms 분주
                        if (watch_counter == 20'd1_000_000-1) begin
                            watch_counter <= 0;
                            // 10ms 틱 세기
                            if (watch_10ms_cnt == TICKS_100-1) begin
                                watch_10ms_cnt <= 0;
                                // 1초 경과 → 초/분 업데이트
                                if (watch_sec == MAX_SEC) begin
                                    watch_sec <= 0;
                                    watch_min <= watch_min + 1;
                                end else begin
                                    watch_sec <= watch_sec + 1;
                                end
                            end else begin
                                watch_10ms_cnt <= watch_10ms_cnt + 1;
                            end
                        end else begin
                            watch_counter <= watch_counter + 1;
                        end
                    end
                    default: begin
                        watch_counter      <= watch_counter;
                        ms10_counter <= ms10_counter;
                        stop_flag_reg <= 0;
                    end
                endcase
            end
        end
    end

    assign oven_seg_data = oven_display;
    assign watch_seg_data = (watch_state == WATCH_STOP) ? (prev_watch_state == WATCH ? watch_display : ms10_counter) : (watch_state == WATCH ? watch_display : ms10_counter);
endmodule

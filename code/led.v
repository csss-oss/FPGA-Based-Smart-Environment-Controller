`timescale 1ns / 1ps

module led(
    input reset,
    input clk,
    input [2:0] state,
    input [1:0] watch_state,
    input [2:0] oven_state,
    input [1:0] air_state,
    input danger_flag,
    input [13:0] watch_seg_data,
    input [7:0] set_tem,
    input [1:0] door_history,
    output reg [15:0] led
    );

    //------ state encoding ------
    // 상위 모드
    localparam STOPWATCH   = 2'b00,
               MICROWAVE   = 2'b01,
               AIR_HANDLE  = 2'b10;

    // 전자레인지 sub-FSM
    localparam IDLE        = 3'b000,
               READY       = 3'b001,
               COOK        = 3'b010,
               PAUSE       = 3'b011,
               COOK_END    = 3'b100;

    // 공조기 sub-FSM
    localparam AIR_MANUAL  = 2'b00,
               AIR_AUTO    = 2'b01,
               STOPPED     = 2'b10,
               SET_TEM     = 2'b11;

    localparam END_TOGGLE_REPEAT = 3;
    localparam END_TOGGLE_ON_CYCLES = 25_000_000; // 0.25초
    localparam END_TOGGLE_OFF_CYCLES = 75_000_000; // 0.75초
    localparam END_TOGGLE_TOTAL_CYCLES = 100_000_000; // 1초

    reg [1:0] end_toggle_count;
    reg [26:0] end_toggle_timer;
    reg end_toggle_on;

    wire toggle_enable = (state == MICROWAVE && oven_state == COOK_END) || (state == AIR_HANDLE && danger_flag);


    reg [8:0] cook_pattern; // 9비트(led[13:5])
    reg [22:0] shift_counter; // 느린 속도용 카운터

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            end_toggle_count <= 0;
            end_toggle_timer <= 0;
            end_toggle_on <= 0;
        end
        else if (toggle_enable) begin
            if (end_toggle_count < END_TOGGLE_REPEAT) begin
                // on/off 주기 제어
                if (end_toggle_timer < END_TOGGLE_ON_CYCLES)
                    end_toggle_on <= 1;
                else
                    end_toggle_on <= 0;
                // 타이머 카운트 및 리셋
                if (end_toggle_timer == END_TOGGLE_TOTAL_CYCLES-1) begin
                    end_toggle_timer <= 0;
                    if(danger_flag)
                        end_toggle_count <= 0;
                    else
                        end_toggle_count <= end_toggle_count + 1;
                end else begin
                    end_toggle_timer <= end_toggle_timer + 1;
                end
            end else begin
                // 반복회수 초과 시 off 유지
                end_toggle_on <= 0;
            end
        end else begin
            // enable 꺼지면 초기화
            end_toggle_count <= 0;
            end_toggle_timer <= 0;
            end_toggle_on    <= 0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            led <= 0;
            cook_pattern <= 9'b0000_0001;
            shift_counter <= 0;
        end else begin
            case (state)
                STOPWATCH: begin // 시간을 led에 표시
                    led[13:0] <= watch_seg_data;
                end
                MICROWAVE: begin
                    case(oven_state)
                        IDLE: led[4:0] <= 5'b00001; // IDLE
                        READY: led[4:0] <= 5'b00010; // READY
                        COOK: begin // COOK
                            // Shift 속도 조절 (약 0.1초마다 한 칸씩 이동)
                            if(shift_counter == 23'd4_999_999) begin // (100MHz라면 0.05초, 조절 가능)
                                shift_counter <= 0;
                                // 왼쪽 끝까지 가면 다시 처음으로
                                if(cook_pattern == 9'b1000_0000_0)
                                    cook_pattern <= 9'b0000_0001;
                                else
                                    cook_pattern <= cook_pattern << 1;
                            end else begin
                                shift_counter <= shift_counter + 1;
                            end
                            led[13:5] <= cook_pattern;
                            led[4:0]  <= 5'b00100; // COOK 표시(유지)
                        end
                        PAUSE: led[4:0] <= 5'b01000; // PAUSE
                        COOK_END: begin
                            if(end_toggle_on)
                            begin
                                led[13:5] <= 9'b111111111;
                            end
                            else
                            begin
                                led[13:5] <= 9'b000000000;
                            end
                                led[4:0] <= 5'b10000; // COOK_END
                        end
                        default: led[4:0] <= 5'b00000;
                    endcase
                    // 도어 상태 표시 (항상)
                    led[15:14] <= door_history;
                end
                AIR_HANDLE: begin
                    if (danger_flag) begin
                        led <= end_toggle_on ? 16'hFFFF : 16'h0000;
                    end else begin
                        // danger_flag 꺼졌을 때 기본 LED 동작
                        case (air_state)
                            AIR_MANUAL: led <= {set_tem, 8'hFF};
                            AIR_AUTO:   led <= 16'hFF00;
                            SET_TEM:    led <= 16'h0F0F;
                            default:    led <= 16'h0000;
                        endcase
                    end
                end
            endcase
        end
    end
endmodule

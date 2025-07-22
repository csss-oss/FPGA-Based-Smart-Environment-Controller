`timescale 1ns / 1ps

module fsm(
    input              clk,
    input              reset,
    // 모드 전환용
    input              mode_change_sw,
    input      [4:0]   rise_button,   // U C L R D

    // 전자레인지용
    input      [13:0]  set_time,
    input      [1:0]   door_history,  // {이전,현재} or {open,close} 방식
    input              end_event,

    // 공조기용
    input              danger_flag,

    // 출력
    output reg [1:0]   state,
    output reg [1:0]   watch_state,
    output reg [2:0]   oven_state,
    output reg [1:0]   air_state,
    output reg [1:0]   prev_watch_state,
    output reg [1:0]   prev_air_state
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

    // 공조기 sub-FSM
    localparam AIR_MANUAL  = 2'b00,
               AIR_AUTO    = 2'b01,
               STOPPED     = 2'b10,
               SET_TEM     = 2'b11;

    //------ next-state signals ------
    reg [1:0]  next_state;
    reg [1:0]  next_watch_state;
    reg [2:0]  next_oven_state;
    reg [1:0]  next_air_state;

    //----------------------------------------------------------------------  
    // 1) 동기식 상태 레지스터 업데이트
    //----------------------------------------------------------------------  
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= STOPWATCH;
            watch_state  <= UP_COUNTER;
            oven_state   <= IDLE;
            air_state    <= AIR_MANUAL;
        end else begin
            state        <= next_state;
            watch_state  <= next_watch_state;
            oven_state   <= next_oven_state;
            air_state    <= next_air_state;
        end
    end

    //----------------------------------------------------------------------  
    // 2) 상위 모드 FSM (combinational)
    //----------------------------------------------------------------------  
    always @(*) begin
        next_state = state;
        case (state)
            STOPWATCH:   if (mode_change_sw && rise_button[2]) next_state = MICROWAVE;
            MICROWAVE:   if (mode_change_sw && rise_button[2]) next_state = AIR_HANDLE;
            AIR_HANDLE:  if (mode_change_sw && rise_button[2]) next_state = STOPWATCH;
            default:     next_state = STOPWATCH;
        endcase
    end

    //----------------------------------------------------------------------  
    // 3) 시계 FSM (combinational)
    //    — 모드가 STOPWATCH 아닐 때는 항상 IDLE 유지 (초기화 효과)
    //----------------------------------------------------------------------
    // U C L R D
    always @(*) begin
        if(state != STOPWATCH)
            next_watch_state = UP_COUNTER;
        else begin
            next_watch_state = watch_state;
            case (watch_state)
                UP_COUNTER: if(rise_button[2]) next_watch_state = DOWN_COUNTER; // L
                            else if(rise_button[1]) next_watch_state = WATCH_STOP; // C
                            else if(rise_button[0]) next_watch_state = WATCH; // U
                DOWN_COUNTER: if(rise_button[2]) next_watch_state = UP_COUNTER; // L
                              else if(rise_button[1]) next_watch_state = WATCH_STOP; // C
                              else if(rise_button[0]) next_watch_state = WATCH; // U
                WATCH_STOP: if(rise_button[1]) next_watch_state = prev_watch_state;
                WATCH: if(rise_button[0]) next_watch_state = UP_COUNTER;
                       else if(rise_button[1]) next_watch_state = WATCH_STOP; // C
                default: next_watch_state = UP_COUNTER;
            endcase
        end
    end

    //----------------------------------------------------------------------  
    // 4) 전자레인지 FSM (combinational)
    //    — 모드가 MICROWAVE 아닐 때는 항상 IDLE 유지 (초기화 효과)
    //----------------------------------------------------------------------  
    always @(*) begin
        // 모드 진입 시 초기화
        if (state != MICROWAVE)
            next_oven_state = IDLE;
        else begin
            next_oven_state = oven_state;
            case (oven_state)
                IDLE:     if (set_time != 0 && door_history == 2'b10) next_oven_state = READY;
                READY:    if (rise_button[2])                        next_oven_state = COOK;
                          else if (door_history[0])                   next_oven_state = IDLE;
                COOK:     if (rise_button[3] || door_history[0])     next_oven_state = PAUSE;
                          else if (set_time == 0)                    next_oven_state = COOK_END;
                PAUSE:    if (rise_button[2] && !door_history[0])     next_oven_state = COOK;
                          else if (rise_button[3])                   next_oven_state = IDLE;
                COOK_END: if (end_event)                             next_oven_state = IDLE;
                default:   next_oven_state = IDLE;
            endcase
        end
    end

    //----------------------------------------------------------------------  
    // 5) 공조기 FSM (combinational)
    //    — 모드가 AIR_HANDLE 아닐 때는 항상 AIR_MANUAL 유지
    //----------------------------------------------------------------------  
    always @(*) begin
        if (state != AIR_HANDLE)
            next_air_state = AIR_MANUAL;
        else begin
            next_air_state = air_state;
            case (air_state)
                AIR_MANUAL: begin
                    if      (rise_button[1])  next_air_state = AIR_AUTO;
                    else if (rise_button[2])  next_air_state = SET_TEM;
                    else if (danger_flag)     next_air_state = STOPPED;
                end
                AIR_AUTO:   begin
                    if      (rise_button[1])  next_air_state = AIR_MANUAL;
                    else if (danger_flag)     next_air_state = STOPPED;
                end
                STOPPED:    begin
                    if (!danger_flag)
                        next_air_state = prev_air_state;
                end
                SET_TEM: begin
                    if      (rise_button[2])  next_air_state = AIR_MANUAL;
                end
                default:    next_air_state = AIR_MANUAL;
            endcase
        end
    end

    //----------------------------------------------------------------------  
    // 6) prev_watch_state, prev_air_state 업데이트 (synchronous)
    //    — WATCH_STOP,STOPPED 상태로 들어갈 때 직전 모드를 저장
    //----------------------------------------------------------------------  
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_air_state <= AIR_MANUAL;
            prev_watch_state <= UP_COUNTER;
        end
        else if (state == AIR_HANDLE) begin
            // 상태 변화가 일어났을 때만 갱신, STOPPED 진입 전의 모드 기억
            if (air_state != next_air_state && air_state != STOPPED)
                prev_air_state <= air_state;
        end
        else if (state == STOPWATCH) begin
            if (watch_state != next_watch_state && watch_state != WATCH_STOP)
                prev_watch_state <= watch_state;
        end
    end

endmodule
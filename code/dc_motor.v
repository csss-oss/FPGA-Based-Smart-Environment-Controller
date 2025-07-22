`timescale 1ns / 1ps

module dc_motor(
    input  wire       clk,
    input  wire       reset,
    input  wire [1:0] state,         // FSM 상태
    input  wire [2:0] oven_state,
    input  wire [1:0] air_state,
    input  wire       danger_flag,   // 위험 시 모터 정지용
    input  wire [7:0] tem_reg,       // 현재 온도
    input  wire [7:0] set_tem,       // 설정 온도
    output wire       in1,           // 항상 HIGH
    output wire       in2,           // 항상 LOW
    output wire       dc             // PWM 출력
);
 
    localparam [7:0] BASE_TEMP = 8'd24;

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


    assign in1 = 1'b1;
    assign in2 = 1'b0;

    reg [3:0] r_counter;       // 0..9로 10단계 분주
    reg       pwm_enable_reg;  // PWM 사용 여부
    reg [3:0] DUTY;            // 듀티값 0..9

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_counter <= 4'd0;
        end else if (r_counter == 4'd9) begin
            r_counter <= 4'd0;
        end else begin
            r_counter <= r_counter + 1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            DUTY           <= 4'd0;
            pwm_enable_reg <= 1'b0;
        end else begin
            case (state)
                // 전자레인지 모드: 고정 듀티 5
                MICROWAVE: begin
                    if(oven_state == COOK) begin
                        DUTY           <= 4'd5;
                        pwm_enable_reg <= 1'b1;
                    end else begin
                        DUTY           <= 4'd0;
                        pwm_enable_reg <= 1'b0;
                    end
                end
                AIR_HANDLE: begin
                    if(air_state == AIR_AUTO) begin
                        pwm_enable_reg <= 1'b1;
                        if      (tem_reg > BASE_TEMP + 5) DUTY <= 4'd9;  // 너무 높으면 빠르게
                        else if (tem_reg < BASE_TEMP - 5) DUTY <= 4'd2;  // 너무 낮으면 천천히
                        else                               DUTY <= 4'd5;  // 정상 범위
                    end
                    else if (air_state == AIR_MANUAL) begin
                        pwm_enable_reg <= 1'b1;
                        if      (tem_reg > set_tem + 5) DUTY <= 4'd9;
                        else if (tem_reg < set_tem - 5) DUTY <= 4'd2;
                        else                             DUTY <= 4'd5;
                    end
                    else if (air_state == SET_TEM) begin
                        pwm_enable_reg <= 1'b1;
                        DUTY <= DUTY;
                    end
                end
                // 그 외(정지 등)
                default: begin
                    pwm_enable_reg <= 1'b0;
                    DUTY           <= 4'd0;
                end
            endcase
        end
    end
 
    assign dc = (pwm_enable_reg && !danger_flag) 
                ? (r_counter < DUTY) 
                : 1'b0;

endmodule

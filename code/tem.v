`timescale 1ns / 1ps

module tem(
    input clk,
    input reset,
    input [4:0] rise_button,
    input [7:0] tem_reg,
    input [1:0] air_state,
    output reg [7:0] set_tem
);

//------ state encoding ------

    // 공조기 sub-FSM
    localparam AIR_MANUAL  = 2'b00,
               AIR_AUTO    = 2'b01,
               STOPPED     = 2'b10,
               SET_TEM     = 2'b11;


// 이전 air_state 저장용
reg [1:0] prev_air_state;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        set_tem         <= tem_reg;
        prev_air_state  <= AIR_MANUAL;
    end else begin
        // 1) 상태 기록
        prev_air_state <= air_state;
        // 2) SET_TEM 상태일 때만 동작
        if (air_state == SET_TEM) begin
            // 2-1) 입장 시: tem_reg 로 한 번만 로드
            if (prev_air_state != SET_TEM) begin
                set_tem <= tem_reg;
            end
            // 2-2) 이미 SET_TEM 상태: 버튼에 따라 증감 (예시)
            else begin
                if (rise_button[0]) set_tem <= set_tem + 1; // + 버튼
                else if (rise_button[4]) set_tem <= set_tem - 1; // – 버튼
            end
        end
        // 3) SET_TEM 아닌 상태: set_tem 유지 또는 초기화 (원하는 동작으로)
        else begin
            // 예: SET_TEM을 빠져나가면 set_tem 고정
            set_tem <= set_tem;
        end
    end
end
endmodule

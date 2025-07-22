`timescale 1ns / 1ps

module button(
    input reset,
    input clk,
    input btnU,
    input btnC,
    input btnL,
    input btnR,
    input btnD,
    output [4:0] rise_button
    );

    reg prev_U,prev_C,prev_L,prev_R,prev_D;
    wire press_U,press_C,press_L,press_R,press_D;

    button_debounce u_btnU( .i_clk(clk), .i_reset(rst), .i_btn(btnU), .o_btn(press_U)); // 시간증가
    button_debounce u_btnC( .i_clk(clk), .i_reset(rst), .i_btn(btnC), .o_btn(press_C)); // 문열기/닫기
    button_debounce u_btnL( .i_clk(clk), .i_reset(rst), .i_btn(btnL), .o_btn(press_L)); // 시작
    button_debounce u_btnR( .i_clk(clk), .i_reset(rst), .i_btn(btnR), .o_btn(press_R)); // 취소/정지
    button_debounce u_btnD( .i_clk(clk), .i_reset(rst), .i_btn(btnD), .o_btn(press_D)); // 시간감소


    always @(posedge clk or posedge reset) begin
        if(reset) begin
            prev_U <= 0;
            prev_C <= 0;
            prev_L <= 0;
            prev_R <= 0;
            prev_D <= 0;
        end
        else begin
            prev_U <= press_U;
            prev_C <= press_C;
            prev_L <= press_L;
            prev_R <= press_R;
            prev_D <= press_D;
        end
    end

    assign rise_button[0] = press_U & ~prev_U;
    assign rise_button[1] = press_C & ~prev_C;
    assign rise_button[2] = press_L & ~prev_L;
    assign rise_button[3] = press_R & ~prev_R;
    assign rise_button[4] = press_D & ~prev_D;
endmodule

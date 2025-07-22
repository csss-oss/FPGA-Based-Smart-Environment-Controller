`timescale 1ns / 1ps

module button_debounce #(parameter DEBOUNCE_LIMIT = 20'd999_999) (
    input      i_clk,
    input      i_reset,
    input      i_btn,
    output    reg  o_btn 
);
    reg [19:0] count;
    reg btn_state;
    reg btn_clean;

    always @(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin
            count <= 0;
            btn_state <= 0;
            o_btn <= 0;
        end else if (i_btn == btn_state) begin
            count <= 0;
        end else begin
            if (count < DEBOUNCE_LIMIT)
                count <= count + 1;
            else begin
                btn_state <= i_btn;
                o_btn <= i_btn;
                count <= 0;  // 리셋하면 다음 변경을 다시 감지할 수 있음
            end
        end
    end
    
endmodule
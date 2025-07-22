`timescale 1ns / 1ps

module fnd(
    input clk,
    input reset,
    input [13:0] oven_seg_data,
    input [13:0] watch_seg_data,
    input [13:0] tem_hum_seg_data,
    input [13:0] set_tem_seg_data,
    input [1:0] state,
    input [1:0] air_state,
    output [7:0] seg_data,
    output [3:0] an    // 자릿수 선택 
    );

    wire [1:0] w_sel;
    wire [3:0] w_d1, w_d10, w_d100, w_d1000;

    wire [13:0] input_data;

    // 상위 모드
    localparam STOPWATCH   = 2'b00,
               MICROWAVE   = 2'b01,
               AIR_HANDLE  = 2'b10;

    // 공조기 sub-FSM
    localparam AIR_MANUAL  = 2'b00,
               AIR_AUTO    = 2'b01,
               STOPPED     = 2'b10,
               SET_TEM     = 2'b11;

    assign input_data = (state == STOPWATCH) ? watch_seg_data : (state == MICROWAVE) ? oven_seg_data : (air_state == SET_TEM) ? set_tem_seg_data : tem_hum_seg_data;

    fnd_digit_select u_fnd_digit_select(
        .clk(clk),
        .reset(reset),
        .sel(w_sel)   // 00 01 10 11
    );

    bin2bcd u_bin2bcd(
        .in_data(input_data),
        .d1(w_d1),
        .d10(w_d10),  
        .d100(w_d100),  
        .d1000(w_d1000)
    );

    fnd_display u_fnd_display(
        .digit_sel(w_sel),
        .d1(w_d1),
        .d10(w_d10),  
        .d100(w_d100),  
        .d1000(w_d1000),
        .an(an),
        .seg(seg_data)
    );
endmodule

module fnd_digit_select (
    input clk,
    input reset,
    output reg [1:0] sel   // 00 01 10 11
);

    reg [16:0]  r_1ms_counter=0;
    reg [1:0] r_digit_sel=0;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_1ms_counter <=0;
            r_digit_sel <= 0;
            sel <= 0;
        end else begin
            if (r_1ms_counter == 100_000-1) begin  // 1ms
                r_1ms_counter <= 0;
                r_digit_sel <= r_digit_sel + 1; 
                sel <= r_digit_sel;
            end else begin
                r_1ms_counter <= r_1ms_counter + 1; 
            end 
        end
    end
endmodule

module bin2bcd(
    input [13:0]  in_data,
    output [3:0]  d1,
    output [3:0]  d10,  
    output [3:0]  d100,  
    output [3:0]  d1000
);

    assign d1 = in_data % 10;
    assign d10 = (in_data / 10) % 10;
    assign d100 = (in_data / 100) % 10;
    assign d1000 = (in_data / 1000) % 10;
endmodule 

module fnd_display(
    input  wire [1:0] digit_sel,
    input  wire [3:0] d1, d10, d100, d1000,
    output reg  [3:0] an,
    output reg  [7:0] seg
);
    reg [3:0] bcd_data;
    always @(*) begin
        case (digit_sel)
            2'd0: begin bcd_data = d1;   an = 4'b1110; end
            2'd1: begin bcd_data = d10;  an = 4'b1101; end
            2'd2: begin bcd_data = d100; an = 4'b1011; end
            2'd3: begin bcd_data = d1000;an = 4'b0111; end
            default: begin bcd_data=4'd0; an=4'b1111; end
        endcase
        case (bcd_data)
            4'd0: seg=8'b11000000;
            4'd1: seg=8'b11111001;
            4'd2: seg=8'b10100100;
            4'd3: seg=8'b10110000;
            4'd4: seg=8'b10011001;
            4'd5: seg=8'b10010010;
            4'd6: seg=8'b10000010;
            4'd7: seg=8'b11111000;
            4'd8: seg=8'b10000000;
            4'd9: seg=8'b10010000;
            default: seg=8'b11111111;
        endcase
    end
endmodule
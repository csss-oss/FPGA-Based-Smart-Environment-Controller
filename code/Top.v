`timescale 1ns / 1ps

module Top(
    input clk,
    input reset,
    input btnU,
    input btnC,
    input btnL,
    input btnR,
    input btnD,
    input mode_change_sw,
    input echo,
    input RsRx,
    inout dht11_data,
    output trig,
    output RsTx,
    output [7:0] seg,
    output [3:0] an,
    output servo,
    output buzzer,
    output in1,
    output in2,
    output dc,
    output [15:0] led
    );

    // fsm
    wire [1:0] state;
    wire [1:0] watch_state;
    wire [2:0] oven_state;
    wire [1:0] air_state;
    wire [1:0] prev_watch_state;
    wire [1:0] prev_air_state;

    //uart
    wire danger_flag;
    wire [7:0] tem_reg, hum_reg;
    wire [13:0] tem_hum_seg_data;

    assign tem_hum_seg_data = tem_reg * 8'd100 + hum_reg;

    // button
    wire [4:0] rise_button; // U C L R D

    //tem
    wire [7:0] set_tem;
    wire [13:0] set_tem_seg_data;

    assign set_tem_seg_data = set_tem;

    //timer
    wire [13:0] watch_seg_data;
    wire [13:0] oven_seg_data;
    wire stop_flag_reg;

    //motor
    wire [1:0] door_history;

    //event
    wire end_event;


    fsm u_fsm(.clk(clk), .reset(reset), .mode_change_sw(mode_change_sw), .rise_button(rise_button), .set_time(oven_seg_data), .door_history(door_history), .end_event(end_event), .danger_flag(danger_flag), .state(state), .watch_state(watch_state), .oven_state(oven_state), .air_state(air_state), .prev_air_state(prev_air_state), .prev_watch_state(prev_watch_state));
    button u_button( .reset(reset), .clk(clk), .btnU(btnU), .btnC(btnC), .btnL(btnL), .btnR(btnR), .btnD(btnD), .rise_button(rise_button));
    uart u_uart(.clk(clk), .reset(reset), .echo(echo), .state(state), .trig(trig), .tx(RsTx), .w_hum(hum_reg), .w_tem(tem_reg), .danger_flag(danger_flag), .dht11_data(dht11_data));
    servo u_servo(.clk(clk), .reset(reset), .rise_button(rise_button), .state(state), .door_history(door_history), .servo(servo));
    dc_motor u_dc_motor( .clk(clk), .reset(reset), .state(state), .oven_state(oven_state), .danger_flag(danger_flag), .set_tem(set_tem), .tem_reg(tem_reg), .in1(in1), .in2(in2), .dc(dc));
    timer u_timer(.clk(clk), .reset(reset), .state(state), .watch_state(watch_state), .oven_state(oven_state), .prev_watch_state(prev_watch_state), .rise_button(rise_button), .watch_seg_data(watch_seg_data), .oven_seg_data(oven_seg_data), .stop_flag_reg(stop_flag_reg));
    fnd u_fnd(.clk(clk), .reset(reset), .oven_seg_data(oven_seg_data), .watch_seg_data(watch_seg_data), .tem_hum_seg_data(tem_hum_seg_data), .set_tem_seg_data(set_tem_seg_data), .state(state), .air_state(air_state), .seg_data(seg), .an(an));
    led u_led(.clk(clk), .reset(reset), .state(state), .watch_state(watch_state), .oven_state(oven_state), .air_state(air_state), .danger_flag(danger_flag), .watch_seg_data(watch_seg_data), .set_tem(set_tem), .door_history(door_history), .led(led));
    buzzer u_buzzer (.clk(clk), .reset(reset), .rise_button(rise_button), .oven_state(oven_state), .danger_flag(danger_flag), .end_event(end_event), .buzzer(buzzer));
    tem u_tem(.clk(clk), .reset(reset), .rise_button(rise_button), .tem_reg(tem_reg), .air_state(air_state), .set_tem(set_tem));

endmodule

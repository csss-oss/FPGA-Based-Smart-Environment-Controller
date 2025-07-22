`timescale 1ns / 1ps

module uart(
    input        clk,         // FPGA 보드 클럭 (100 MHz)
    input        reset,       // 리셋 버튼
    input        echo,      // HC-SR04 센서의 Echo 핀에 연결
    input [1:0]  state,
    output       trig,      // HC-SR04 센서의 Trig 핀에 연결
    output       tx,
    output [7:0] w_hum,
    output [7:0] w_tem,
    output danger_flag,
    inout  dht11_data
    );
    // Ultrasonic Sensor
    wire [7:0] w_distance;
    wire    w_ultra_done;

    //DHT11 Sensor
    wire w_dht11_done;
    
    // Data Sender & UART
    wire w_uart_busy; 
    wire [7:0] w_uart_data;
    wire w_uart_start;

    reg r_uart_busy_d;
    wire w_uart_done;
   
 

    localparam S_IDLE     = 2'b00,
               S_SEND_UART  = 2'b01,
               S_WAIT_UART  = 2'b10;

    // 상위 모드
    localparam STOPWATCH   = 2'b00,
               MICROWAVE   = 2'b01,
               AIR_HANDLE  = 2'b10;


    reg  [7:0] r_distance_to_display; // 측정된 거리를 저장할 레지스터
 

    reg       r_uart_start;


    tick_generator #(
        .INPUT_FREQ(100_000_000),
        .TICK_HZ(1) // 1Hz --> 1초에 1번 tick
    ) u_tick_1Hz (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1Hz_raw)
    );

    wire w_tick_1Hz = (state == AIR_HANDLE) ? w_tick_1Hz_raw : 0;

    ultrasonic2 ultrasonic_sensor (
        .clk        (clk),
        .reset      (reset),
        .echo       (echo),
        .trig       (trig),
        .danger_flag(danger_flag),
        .i_state     (state),
        .distance   (w_distance),
        .done       (w_ultra_done)
    );

    data_sender u_data_sender(
    .clk(clk),
    .reset(reset),
    .i_dist_trigger(w_ultra_done), //초음파 센서 측정 완료 트리거
    .i_dist_data(w_distance), //초음파 센서 데이터(8비트)
    .i_dth_trigger(w_dht11_done), //온습도 센서 측정 완료 트리거
    .i_th_data_t(w_tem), // 온도 센서 데이터 (8비트)
    .i_th_data_h(w_hum),// 습도센서 데이터 (8비트)
    .tx_busy(w_uart_busy),
    .tx_done(w_uart_done),
    .tx_start(w_uart_start),
    .tx_data(w_uart_data)
    );
   

    dht11_driver u_dht11_sensor (
    .clk(clk),
    .rst(reset),
    .start(w_tick_1Hz),
    .rh_data(w_hum),   //상대 습도 상위 8bit
    .t_data(w_tem),    //온도 상위 8비트
    .dht11_done(w_dht11_done),
    .dht11_io(dht11_data)   //단방향 통신핀
);

   uart_tx uart_transmitter (
        .clk         (clk),
        .reset       (reset),
        .i_data      (w_uart_data),
        .i_start     (w_uart_start),
        .o_tx_serial (tx),
        .o_busy      (w_uart_busy)
    );

 always @(posedge clk or posedge reset) begin
        if(reset) begin
            r_uart_busy_d <= 1'b0;
        end else begin
            r_uart_busy_d <= w_uart_busy;
        end
    end
    assign w_uart_done = r_uart_busy_d && !w_uart_busy;
endmodule

module tick_generator#(
    parameter integer INPUT_FREQ = 100_000_000, //100MHz
    parameter integer TICK_HZ = 1000 //1000Hz -->1ms
)(
 
    input clk, 
    input reset,
    output reg tick //한주기만큼 high로 만들어주는 거를 틱 
);

    parameter TICK_COUNT =  INPUT_FREQ /  TICK_HZ; // 100_000

    reg [$clog2(TICK_COUNT)-1:0] r_tick_counter = 0; //16 bits 필요

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_tick_counter <= 0;
            tick <= 0;
        end else begin
            if(r_tick_counter == TICK_COUNT-1 ) begin
                r_tick_counter <=0;
                tick <= 1'b1;//1ms가 되면 틱이 발생
            end else begin
                r_tick_counter = r_tick_counter +1;
                tick <= 1'b0;
            end
        end
    end
endmodule
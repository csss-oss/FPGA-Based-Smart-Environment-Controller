`timescale 1ns / 1ps

module data_sender(
    // 보내는 데이터가 그냥 여기서 정리됨.. distance_cm 외부에서 받아서 bcd 전환 후 comportmaster에 뿌려줄 ascii data 생성
    input clk, reset,
    input i_dist_trigger, //초음파 센서 측정 완료 트리거
    input [7:0] i_dist_data, //초음파 센서 데이터(8비트)
    input i_dth_trigger, //온습도 센서 측정 완료 트리거
    input [7:0] i_th_data_t, // 온도 센서 데이터 (8비트)
    input [7:0] i_th_data_h, // 습도 센서 데이터 (8비트)
    input tx_busy, tx_done,

    output reg tx_start,
    output reg [7:0] tx_data
    );

    localparam S_IDLE = 2'b00;
    localparam S_SEND_DIST = 2'b01;
    localparam S_SEND_TH = 2'b10;
    reg [1:0] state;
    reg [6:0] data_cnt;

    wire valid_range;
    assign valid_range = (i_dist_data < 14'd400);

    // ################ uart로 1초에 1회씩 distance_cm 값 출력하기 ################ 
    wire [3:0] d1, d10, d100; //초음파 거리 데이터 처리

    bin2bcd_8bit U_bcd_sender(.in_data(i_dist_data), .d1(d1), .d10(d10), .d100(d100));

    wire [7:0] distance_ascii [0:7];
    assign distance_ascii[0] = 8'h44; // 'D'
    assign distance_ascii[1] = (d100  == 4'd0) ? 8'h20 : {4'b0011, d100};   // 
    assign distance_ascii[2] = (d100 == 4'd0 && d10 == 4'd0) ? 8'h20 : {4'b0011, d10};    // 
    assign distance_ascii[3]={4'b0011,d1}; 
    assign distance_ascii[4]={8'h63}; // c
    assign distance_ascii[5]={8'h6d}; // m
    assign distance_ascii[6] = 8'h0D; // CR (Carriage Return)
    assign distance_ascii[7] = 8'h0A; // LF

    //온습도 데이터 처리 

    wire [3:0] temp_d1, temp_d10, temp_d100;
    wire [3:0] hum_d1, hum_d10, hum_d100;
    bin2bcd_8bit U_bcd_temp(.in_data(i_th_data_t), .d1(temp_d1), .d10(temp_d10), .d100(temp_d100));
    bin2bcd_8bit U_bcd_hum(.in_data(i_th_data_h), .d1(hum_d1), .d10(hum_d10), .d100(hum_d100));
    //온습도 ascII문자열
    wire [7:0] th_ascii [0:8];
    assign th_ascii[0] = 8'h54;//T
    assign th_ascii[1] = {4'b0011, temp_d10}; // 온도 10의 자리
    assign th_ascii[2] = {4'b0011, temp_d1};  // 온도 1의 자리
    assign th_ascii[3] = 8'h20; // ' ' (space)
    assign th_ascii[4] = 8'h48; // 'H'
    assign th_ascii[5] = {4'b0011, hum_d10};  // 습도 10의 자리
    assign th_ascii[6] = {4'b0011, hum_d1};   // 습도 1의 자리
    assign th_ascii[7] = 8'h0D; // CR (Carriage Return)
    assign th_ascii[8] = 8'h0A; // LF (Line Feed)



 always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= S_IDLE;
            tx_start    <= 1'b0;
            data_cnt    <= 0;
        end else begin
            tx_start <= 1'b0; // 기본적으로 0으로 유지

            case (state)
                S_IDLE: begin
                    if (!tx_busy) begin
                        if (i_dist_trigger ) begin
                            tx_start <= 1'b1;
                            tx_data  <= distance_ascii[0];
                            data_cnt <= 1;
                            state    <= S_SEND_DIST;
                        end else if (i_dth_trigger) begin
                            tx_start <= 1'b1;
                            tx_data  <= th_ascii[0];
                            data_cnt <= 1;
                            state    <= S_SEND_TH;
                        end
                    end
                end

                S_SEND_DIST: begin
                    if (tx_done) begin
                        if (data_cnt < 8) begin 
                            tx_start <= 1'b1;
                            tx_data  <= distance_ascii[data_cnt];
                            data_cnt <= data_cnt + 1;
                        end else begin //모든 문자 전송 완료
                            state   <= S_IDLE;
                        end
                    end
                end
                
                S_SEND_TH: begin
                    if (tx_done) begin
                        if (data_cnt < 9) begin // "T25 H60\n" 까지 전송
                            tx_start <= 1'b1;
                            tx_data  <= th_ascii[data_cnt];
                            data_cnt <= data_cnt + 1;
                        end else begin
                            state    <= S_IDLE;
                        end
                    end
                end
                
                default:
                    state <= S_IDLE;
            endcase
        end
    end
endmodule

module bin2bcd_8bit(
    input  [7:0] in_data, // 포트 폭을 8비트로 수정
    output [3:0] d1,
    output [3:0] d10,
    output [3:0] d100
);

    // BCD 결과를 저장할 레지스터
    // bcd_val[11:8] = 100의 자리, bcd_val[7:4] = 10의 자리, bcd_val[3:0] = 1의 자리
    reg [11:0] bcd_val;
    integer i;

    // 조합 논리(Combinational Logic)로 구현
    always @(in_data) begin
        // 초기화: BCD 값은 0, 이진 데이터는 그대로
        bcd_val = 0; 

        // 8비트 데이터를 8번 시프트하며 변환
        for (i = 0; i < 8; i = i + 1) begin
            // 1의 자리(d1) 값이 4보다 크면 3을 더함
            if (bcd_val[3:0] > 4) begin
                bcd_val[3:0] = bcd_val[3:0] + 3;
            end
            // 10의 자리(d10) 값이 4보다 크면 3을 더함
            if (bcd_val[7:4] > 4) begin
                bcd_val[7:4] = bcd_val[7:4] + 3;
            end
            // 100의 자리(d100) 값이 4보다 크면 3을 더함
            if (bcd_val[11:8] > 4) begin
                bcd_val[11:8] = bcd_val[11:8] + 3;
            end

            // BCD 값과 이진 데이터를 함께 왼쪽으로 1비트 시프트
            bcd_val = {bcd_val[10:0], in_data[7-i]};
        end
    end

    assign d100 = bcd_val[11:8];
    assign d10  = bcd_val[7:4];
    assign d1   = bcd_val[3:0];

endmodule
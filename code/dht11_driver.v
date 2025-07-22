`timescale 1ns / 1ps

module dht11_driver (
    input        clk,
    input        rst,
    input        start,
    output [7:0] rh_data,   //상대 습도 상위 8bit
    output [7:0] t_data,    //온도 상위 8비트
    output       dht11_done,
    inout        dht11_io   //단방향 통신핀
);
    localparam  IDLE = 0,   //step0: power-on 1s 대기
                START = 1,   //step1: HOST start signal(18ms low)
                WAIT = 2,     //step2: 20~40us 동안 high 출력 후 I/O를 입력으로 전환
                SYNCL = 3,    //step3: DHT11의 첫번쨰 응답 (80us LOW) 감지 대기 
                SYNCH = 4,    //step4: DHT11의 두번쨰 응답 (80us High) 감지 대기
                DATA_SYNC = 5,//step5: 각 비트의 시작을 감지 대기
                DATA_DETECT = 6,  //step6: HIGH 펄스 폭 측정(26~28us 면 '0' , 70us 면 '1')
                STOP = 7;          //step7: 40비트 수신 완료 후 체크섬 검증 및 완료 플래그 세팅

    wire w_tick, w_tick_1us;
    reg [2:0] c_state, n_state;
    reg [$clog2(1900) -1:0] t_cnt_reg, t_cnt_next;  //10us 타이머 카운터
    reg [$clog2(1900) -1:0] t_cnt_reg_1us, t_cnt_next_1us;  //1us 타이머 카운터
    reg [$clog2(1900) -1:0] check_cnt_reg, check_cnt_next;  //예비 또는 추가 조건 확인용 카운터
    reg dht11_reg, dht11_next;
    reg io_en_reg, io_en_next;
    reg [39:0] data_reg, data_next;
 
    reg dht11_done_reg, dht11_done_next;

    assign dht11_io = (io_en_reg) ? dht11_reg : 1'bz;

    assign dht11_done = dht11_done_reg;
   
    assign rh_data = data_reg[39:32];   //습도 데이터 상위 8bit
    assign t_data = data_reg[23:16];    //온도 데이터 상위 8bit

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= 0;
            t_cnt_reg <= 0;
            t_cnt_reg_1us <= 0;
            dht11_reg <= 1;  // 초기값 항상 high
            io_en_reg <= 1;  // idle에서 항상 출력 모드드
            data_reg <= 0;
            dht11_done_reg <= 0;
            check_cnt_reg <= 0;
        end else begin
            c_state <= n_state;
            t_cnt_reg <= t_cnt_next;
            dht11_reg <= dht11_next;
            io_en_reg <= io_en_next;
            data_reg <= data_next;
            dht11_done_reg <= dht11_done_next;
            t_cnt_reg_1us <= t_cnt_next_1us;
            check_cnt_reg <= check_cnt_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        t_cnt_next = t_cnt_reg;
        t_cnt_next_1us = t_cnt_reg_1us;
        dht11_next = dht11_reg;
        io_en_next = io_en_reg;
        data_next = data_reg;
        dht11_done_next = dht11_done_reg;
        check_cnt_next = check_cnt_reg;
        case (c_state)
            IDLE: begin
                dht11_done_next = 0;
                dht11_next = 1;
                io_en_next = 1;
                if (start) begin
                    n_state = START;
                    t_cnt_next = 0;//측정을 새로 시작하기 전에 모든 카운터 초기화!
                    t_cnt_next_1us = 0;
                    data_next = 0;
                end
            end
            START: begin
                if (w_tick) begin
                    dht11_next = 0;
                    if (t_cnt_reg == 1900) begin
                        n_state = WAIT;
                        t_cnt_next = 0;
                    end else begin
                        t_cnt_next = t_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin
                // 출력 HIGH
                dht11_next = 1;
                if (w_tick) begin
                    if (t_cnt_reg == 2) begin
                        n_state = SYNCL;
                        t_cnt_next = 0;
                        // 출력을 입력으로 전환
                        io_en_next = 0;
                    end else begin
                        t_cnt_next = t_cnt_reg + 1;
                    end
                end
            end
            SYNCL: begin
                if (w_tick) begin
                    if (dht11_io) begin
                        n_state = SYNCH;
                    end
                end
            end
            SYNCH: begin
                if (w_tick) begin
                    if (!dht11_io) begin
                        n_state = DATA_SYNC;
                    end
                end
            end
            DATA_SYNC: begin
                if (t_cnt_reg == 40) begin
                    n_state = STOP;
                    t_cnt_next = 0;
                end else if (w_tick) begin
                    if (dht11_io) begin
                        n_state = DATA_DETECT;
                    end
                end
                
            end
            DATA_DETECT: begin
                if (w_tick_1us) begin
                    if (dht11_io) begin
                        t_cnt_next_1us = t_cnt_reg_1us + 1;
                    end else begin
                        if (t_cnt_reg_1us >= 40) begin
                            data_next = {data_reg[38:0], 1'b1};
                            t_cnt_next_1us = 0;
                            t_cnt_next = t_cnt_reg + 1;
                            if (t_cnt_reg == 39) n_state = STOP;
                            else n_state = DATA_SYNC;
                            t_cnt_next = t_cnt_reg + 1;
                        end else begin
                            data_next = {data_reg[38:0], 1'b0};
                            t_cnt_next_1us = 0;
                            t_cnt_next = t_cnt_reg + 1;
                            if (t_cnt_reg == 39) n_state = STOP;
                            else n_state = DATA_SYNC;
                        end
                    end
                end
            end
            STOP: begin
                if (w_tick_1us) begin
                    if (t_cnt_reg_1us == 49) begin
                        n_state = IDLE;
                        dht11_done_next = 1;
                        t_cnt_next = 0;
                        t_cnt_next_1us = 0;
                    end else begin
                        t_cnt_next_1us = t_cnt_reg_1us + 1;
                    end
                end
            end
        endcase
    end

    tick_gen_10us U_TICK (
        .clk(clk),
        .rst(rst),
        .o_tick(w_tick)
    );

    tick_gen_1us U_TICK_1US (
        .clk(clk),
        .rst(rst),
        .o_tick(w_tick_1us)
    );

endmodule


module tick_gen_10us (
    input clk,
    input rst,
    output reg o_tick
);
    localparam F_CNT = 1000;
    reg [$clog2(F_CNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            if (counter_reg >= F_CNT - 1) begin
                counter_reg <= 0;
                o_tick <= 1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick <= 0;
            end
        end
    end

endmodule


module tick_gen_1us (
    input clk,
    input rst,
    output reg o_tick
);
    localparam F_CNT = 100;
    reg [$clog2(F_CNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            if (counter_reg >= F_CNT - 1) begin
                counter_reg <= 0;
                o_tick <= 1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick <= 0;
            end
        end
    end

endmodule
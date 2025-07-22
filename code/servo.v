module servo(
    input clk,         // 50MHz 클럭 입력
    input reset,
    input [4:0] rise_button,
    input [1:0] state,
    output [1:0] door_history,
    output reg servo      // PWM 출력 핀
);

    reg [19:0] cnt;
    reg [19:0] high_time;

    reg [1:0]check_door_history = 2'b00;

    localparam MICROWAVE = 2'b01;

    always @(*) begin
        if(door_history[0])
            high_time = 75_000;   // 2ms, 180도 (열림)
        else
            high_time = 170_000;    // 1.5ms, 90도 (닫힘)
    end

    always @(posedge clk or posedge reset) begin
        if(reset)
            cnt <= 0;
        else if(cnt < 999_999)
            cnt <= cnt + 1;
        else
            cnt <= 0;
    end

    always @(posedge clk or posedge reset) begin
        if(reset)
            servo <= 0;
        else if(cnt < high_time)
            servo <= 1;
        else
            servo <= 0;
    end

    always @(posedge clk or posedge reset) begin
        if(reset)
        begin
            check_door_history <= 2'b00;
        end
        else
        begin
             // C버튼 눌릴 때 도어 토글
            if(rise_button[1] && state == MICROWAVE) 
            begin
                check_door_history[1] <= check_door_history[0];    // 이전값 유지
                check_door_history[0] <= ~check_door_history[0];   // 현재값만 토글
            end
        end
    end

    assign door_history = check_door_history;
endmodule
`timescale 1ns / 1ps

module buzzer(
    input reset,
    input clk,
    input [4:0] rise_button,
    input [2:0] oven_state,
    input danger_flag,
    output end_event,
    output reg buzzer // reg 타입으로 변경하여 always 블록에서 직접 제어
);

    // ──────────────── 버튼 멜로디용 상수 ────────────────
    localparam DURATION_TONE_CYCLES = 7_000_000; // 70ms

    localparam COUNT_1000HZ = 50_000;
    localparam COUNT_2000HZ = 25_000;
    localparam COUNT_3000HZ = 16_667;
    localparam COUNT_4000HZ = 12_500;

    // ──────────────── FSM 상태 ────────────────
    localparam ST_IDLE   = 3'b000;
    localparam ST_PLAY_1 = 3'b001;
    localparam ST_PLAY_2 = 3'b010;
    localparam ST_PLAY_3 = 3'b011;
    localparam ST_PLAY_4 = 3'b100;

    // ──────────────── COOK_END 부저 알림 상수 ────────────────
    localparam COOK_END_STATE      = 3'b100;
    localparam END_BEEP_REPEAT     = 3;
    localparam END_BEEP_ON_CYCLES  = 25_000_000;  // 0.25초 (100MHz 기준)
    localparam END_BEEP_OFF_CYCLES = 75_000_000;  // 0.75초 (100MHz 기준)
    localparam END_BEEP_TOTAL_CYCLES = 100_000_000; // 1초

    // ──────────────── 위험 경고음 상수 ────────────────
    localparam DANGER_TONE_DURATION = 20_000_000; // 0.2초마다 톤 변경
    localparam DANGER_FREQ_HIGH     = 16_667;     // 3000Hz
    localparam DANGER_FREQ_LOW      = 40_000;     // 1250Hz

    // ──────────────── FSM 및 타이머 변수 ────────────────
    // 버튼 멜로디
    reg [2:0] current_state;
    reg [22:0] duration_timer;
    wire melody_timer_done = (duration_timer == 0);

    // COOK_END
    reg [1:0] end_beep_count;
    reg [26:0] end_beep_timer;
    reg end_beep_on;

    // 위험 경고음
    reg [24:0] danger_timer;
    reg danger_tone_select; // 0: LOW, 1: HIGH

    // 주파수 생성
    reg [20:0] freq_counter;
    reg speaker_reg;

    // ──────────────── FSM 로직 (상태에 따른 동작 분리) ────────────────

    // 버튼 멜로디 FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state  <= ST_IDLE;
            duration_timer <= 0;
        end else begin
            // 위험상황이나 요리종료시에는 멜로디 FSM 정지 및 리셋
            if (danger_flag || oven_state == COOK_END_STATE) begin
                current_state  <= ST_IDLE;
                duration_timer <= 0;
            end else begin
                case (current_state)
                    ST_IDLE: begin
                        if (|rise_button) begin
                            current_state <= ST_PLAY_1;
                            duration_timer <= DURATION_TONE_CYCLES - 1;
                        end
                    end
                    ST_PLAY_1: if (melody_timer_done) {current_state, duration_timer} <= {ST_PLAY_2, DURATION_TONE_CYCLES - 1};
                    ST_PLAY_2: if (melody_timer_done) {current_state, duration_timer} <= {ST_PLAY_3, DURATION_TONE_CYCLES - 1};
                    ST_PLAY_3: if (melody_timer_done) {current_state, duration_timer} <= {ST_PLAY_4, DURATION_TONE_CYCLES - 1};
                    ST_PLAY_4: if (melody_timer_done) {current_state, duration_timer} <= {ST_IDLE, 23'd0};
                    default: current_state <= ST_IDLE;
                endcase

                if (!melody_timer_done) begin
                    duration_timer <= duration_timer - 1;
                end
            end
        end
    end

    // COOK_END 부저 FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            end_beep_count <= 0;
            end_beep_timer <= 0;
            end_beep_on    <= 0;
        end else begin
            // 위험상황이 아니고, COOK_END 상태일 때만 동작
            if (!danger_flag && oven_state == COOK_END_STATE) begin
                if (end_beep_count < END_BEEP_REPEAT) begin
                    end_beep_timer <= (end_beep_timer == END_BEEP_TOTAL_CYCLES - 1) ? 0 : end_beep_timer + 1;
                    end_beep_on    <= (end_beep_timer < END_BEEP_ON_CYCLES);

                    if (end_beep_timer == END_BEEP_TOTAL_CYCLES - 1) begin
                        end_beep_count <= end_beep_count + 1;
                    end
                end else begin
                    end_beep_on <= 0; // 반복 종료 후 OFF
                end
            end else begin // 비활성 조건일 때 리셋
                end_beep_count <= 0;
                end_beep_timer <= 0;
                end_beep_on    <= 0;
            end
        end
    end

    // 위험 경고음 FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            danger_timer     <= 0;
            danger_tone_select <= 0;
        end else begin
            if (danger_flag) begin
                danger_timer <= danger_timer + 1; // 타이머는 계속 증가 (자동으로 랩어라운드)
                if (danger_timer == DANGER_TONE_DURATION - 1) begin
                    danger_timer       <= 0;
                    danger_tone_select <= ~danger_tone_select;
                end else begin
                    danger_timer <= danger_timer + 1;
                end
            end else begin // 위험상황이 아니면 리셋
                danger_timer     <= 0;
                danger_tone_select <= 0;
            end
        end
    end

    // ──────────────── 출력 로직 (우선순위 기반 합성) ────────────────

    wire [20:0] freq_target_count;
    wire sound_on;

    // [중요] 우선순위에 따라 주파수 및 재생 여부 결정
    assign freq_target_count = danger_flag ? (danger_tone_select ? DANGER_FREQ_HIGH : DANGER_FREQ_LOW) :
                               (oven_state == COOK_END_STATE) ? COUNT_1000HZ :
                               (current_state == ST_PLAY_1) ? COUNT_1000HZ :
                               (current_state == ST_PLAY_2) ? COUNT_2000HZ :
                               (current_state == ST_PLAY_3) ? COUNT_3000HZ :
                               (current_state == ST_PLAY_4) ? COUNT_4000HZ : 0;

    assign sound_on = danger_flag ? 1'b1 : // 위험 경고음은 항상 ON
                      (oven_state == COOK_END_STATE) ? end_beep_on : // 요리 종료음은 end_beep_on 신호에 따름
                      (current_state != ST_IDLE); // 멜로디는 IDLE이 아닐 때 ON

    // 주파수 분주기
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            freq_counter <= 0;
            speaker_reg  <= 1'b0;
        end else begin
            if (sound_on && freq_target_count != 0) begin
                if (freq_counter >= freq_target_count - 1) begin
                    freq_counter <= 0;
                    speaker_reg  <= ~speaker_reg;
                end else begin
                    freq_counter <= freq_counter + 1;
                end
            end else begin
                freq_counter <= 0;
                speaker_reg  <= 1'b0;
            end
        end
    end

    // 최종 부저 출력
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            buzzer <= 1'b0;
        end else begin
            // sound_on 신호가 1일때만 스피커 출력을 내보냄
            buzzer <= sound_on ? speaker_reg : 1'b0;
        end
    end

    // 이벤트 종료 신호
    assign end_event = (oven_state == COOK_END_STATE && end_beep_count >= END_BEEP_REPEAT);

endmodule
FPGA-Based Smart Environment Controller


💡 한 줄 요약: 3개의 독립적인 기능(스마트 공조기, 전자레인지, 스톱워치)을 단일 FSM으로 통합하고, 2종의 센서(온습도, 초음파)를 직접 제어하여 자동화 및 안전 기능을 구현한 Verilog 기반 임베디드 시스템입니다.



🎬 프로젝트 핵심 동작 (Demo)

https://youtube.com/shorts/CgqHk4Kj1S8?feature=share



✨ 주요 기능 (Key Features)
지능형 공조 시스템

온도 자동 감지: DHT11 센서 값에 따라 팬 속도를 3단계로 자동 조절

사용자 안전 확보: HC-SR04 센서로 5cm 이내 물체 감지 시 즉시 팬 정지 및 2중 경고음(3000/1250Hz) 발생

다기능 통합 제어

3-in-1 시스템: 스마트 공조기, 전자레인지, 스톱워치 기능을 단일 FSM으로 통합 및 제어

실시간 데이터 인터페이스

PC 모니터링: UART 통신으로 온도, 습도, 거리 값을 1초 주기로 PC에 전송 (ASCII 변환)

직관적 디스플레이: FND와 LED로 현재 상태 및 주요 데이터를 시각적으로 표시




🛠️ 기술 스택 (Tech Stack)
Language: Verilog HDL

Hardware: FPGA (Xilinx Artix-7) on Basys3 Board

Tool: Xilinx Vivado

Peripherals: DHT11, HC-SR04, DC Motor, Servo Motor, Buzzer, FND, LED

Protocols: UART (9600bps), 1-Wire, PWM

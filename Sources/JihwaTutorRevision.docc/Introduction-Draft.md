# 첫 페이지 교체 원고

현재 제공하는 코드와 실제 학습용 앱 사이의 범위를 첫 화면에서 분명히 알립니다.

## Overview

> Note: 현재 구현 상태를 알리는 **첫 페이지 교체 원고**입니다. 아래의 미완성 항목은 구현·검증이 완료된 뒤 상태를 갱신합니다.

가짜 손 데이터로 채점과 교정 문장이 만들어지는 구조를 살펴보고, Apple Vision Pro의 손 추적을 연결하는 방법을 다룹니다. 실제 지화를 가르치는 데 사용하려면 표준 손 모양과 실측 기준 포즈를 별도로 검증해야 합니다.

### 무엇을 배우나요?

앱은 손 입력을 받고, 손가락 굽힘과 벌림·손바닥 방향을 숫자로 표현한 뒤, 기준 포즈와의 차이를 계산합니다. 그 차이를 화면과 교정 문장으로 전달하는 것이 이 문서의 주제입니다.

시뮬레이터에서는 가짜 입력으로 계산과 화면 연결을 살펴봅니다. 실제 손 추적은 Apple Vision Pro가 필요합니다. 착용자 자신의 손을 입력으로 사용하며, 상대방이나 영상 속 손을 인식하는 구조는 다루지 않습니다.

### 현재 제공 범위

| 항목 | 현재 상태 |
| --- | --- |
| 자모 목록 | 40개 항목을 정의합니다. 40개 모두의 판정 정확도를 검증했다는 뜻은 아닙니다. |
| 기준 포즈 | 사람이 적은 데모 값입니다. 표준 손 모양을 검증한 실측 자료가 아닙니다. |
| 시뮬레이터 입력 | 가짜 데이터로 판정·화면 연결을 시험하는 코드입니다. |
| 포즈 등록 | 평균과 편차를 계산하는 함수가 있습니다. 기록 화면·저장·보정 연결은 보완이 필요합니다. |
| 손바닥 방향 비교 | 좌표 변환과 수향 보존 설명을 맞추고 검증해야 합니다. |
| 실기기 연결 | ARKit 입력을 연결하는 코드가 있습니다. 실제 추적과 좌표 정렬은 실기기에서 확인해야 합니다. |
| 3D 표시 | 임시 도형에 오차를 표시하는 수준입니다. 정답 손 모양을 재현하지 않습니다. |

현재 단계별 발췌 코드만으로 모든 실행 화면을 그대로 재현할 수 있는 상태는 아닙니다. 코드를 읽을 때는 [전체 소스 파일](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/source-files)을 함께 확인하세요. 전체 소스에도 위 표의 미완성 항목이 남아 있습니다.

### 읽는 순서

| 단계 | 살펴볼 내용 |
| --- | --- |
| [0. 프로젝트 만들기](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/step-0-project-setup) | 개발 환경과 앱 진입점 |
| [1. 가짜 손부터 만든다](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/step-1-mock-hand) | 입력 인터페이스와 가짜 데이터 |
| [2. 관절을 22개의 숫자로](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/step-2-pose-features) | 굽힘·벌림·법선의 표현과 계산 |
| [3. 정답을 기록한다](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/step-3-reference-poses) | 기준 포즈의 평균과 편차 계산 |
| [4. 채점하고 문장을 만든다](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/step-4-scoring-and-coaching) | 오차·허용 범위·교정 문장의 연결 |
| [5. 40자로 늘린다](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/step-5-expand-to-40-characters) | 자모 선택과 기준표 비교 |
| [6. 실기기: 진짜 손과 3D 가이드](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/step-6-device-tracking-and-guide) | 손 추적·몰입 공간·오차 표시 |

### 시작하기 전에

Swift의 구조체·열거형·프로토콜·옵셔널을 읽을 수 있고, SwiftUI에서 상태가 바뀔 때 화면이 갱신되는 방식을 알면 이해하기 쉽습니다. 비동기 입력을 위해 `async`/`await`와 스트림을 사용합니다. 각도와 법선을 계산하는 부분에서는 벡터의 내적·외적을 다룹니다.

visionOS 개발 환경과 시뮬레이터가 필요합니다. 실제 손 추적을 확인하는 단계에는 Apple Vision Pro가 필요합니다. 개발 환경의 최소 지원 버전과 실제 확인한 버전은 [문서 정보](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/limits-and-references)를 함께 확인하세요.

### 코드를 읽는 방법

본문 코드는 설명할 부분을 발췌합니다. `// …`가 있으면 그대로 실행할 수 있는 전체 파일이 아닙니다. 전체 파일에서 해당 코드가 들어가는 위치와 필요한 자료형을 함께 확인하세요.

판정이 동작하는 것과 올바른 지화를 판정하는 것은 각각 확인해야 합니다. 데모 기준으로 나온 통과 결과를 실제 학습 정확도로 해석하지 마세요. 실측 자료도 표준 손 모양 검토와 입력 조건 검증이 필요합니다.

[한계와 참고 자료](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/limits-and-references)에서는 데모 기준표, 미검증 규칙, 문서의 범위를 확인할 수 있습니다.

## 계속 읽기

- <doc:JihwaTutorRevision>
- <doc:Roadmap>

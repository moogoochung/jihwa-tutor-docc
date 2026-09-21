# 지화 튜터 문서 개선안

@Metadata {
    @TechnologyRoot
}

소개문부터 단계별 구성, 코드 보완 사항과 완료 기준까지 정리한 DocC 개정안입니다.

## Overview

공개된 지화 튜터 문서와 수록 소스를 대조해 작성했습니다. 가짜 입력부터 시작하는 흐름과 단계별 체크포인트를 유지하면서, 각 단계의 코드·실행 화면·성공 조건을 같은 버전에 맞추는 것을 목표로 합니다.

> Important: 이 사이트는 **문서 개정·구현 제안**입니다. 앱 코드가 수정되었거나 빌드·실기기 검증이 완료되었다는 뜻이 아닙니다. 각 단계의 새 설명은 해당 구현과 확인을 마친 뒤 튜토리얼에 적용합니다.

@Row {
    @Column {
        ### 첫 페이지
        현재 구현 범위를 정확하게 알리는 교체 원고입니다.
    }
    @Column {
        ### 0–6단계
        앞 단계의 결과만으로 진행하도록 순서를 다시 잡았습니다.
    }
    @Column {
        ### 완료 기준
        기록·수향·교정·재시작을 어떻게 확인할지 정리했습니다.
    }
}

### 먼저 읽을 문서

전체 방향은 <doc:Roadmap>에서 확인합니다. 첫 화면에 바로 적용할 안내문은 <doc:Introduction-Draft>에 있고, 구현 우선순위는 <doc:Implementation-Plan>에 있습니다.

### 핵심 변경

- 0단계는 아직 없는 모델을 참조하지 않는 첫 창으로 끝냅니다.
- 가짜 입력은 뒤 단계의 기준표에 의존하지 않게 만듭니다.
- 기록 UI·등록·저장·허용 오차를 실제로 연결합니다.
- 손 모양과 수향의 좌표계를 구분합니다.
- 정답 손 모양과 임시 오차 표시의 구현 범위를 구분합니다.

작성 기준: 2026년 9월 21일 검토본. [기존 튜토리얼](https://moogoochung.github.io/jihwa-tutor-docc/documentation/jihwatutor/)과 대조하며 읽을 수 있습니다.

## Topics

### 개선 방향과 소개문

- <doc:Roadmap>
- <doc:Introduction-Draft>

### 단계별 개정안

- <doc:Step-0-Project-Setup>
- <doc:Step-1-Mock-Hand>
- <doc:Step-2-Pose-Features>
- <doc:Step-3-Reference-Poses>
- <doc:Step-4-Scoring-and-Coaching>
- <doc:Step-5-Expand-to-40-Characters>
- <doc:Step-6-Device-Tracking-and-Guide>

### 구현과 검증

- <doc:Implementation-Plan>
- <doc:Document-Standards>
- <doc:Limits-Draft>
- <doc:References>

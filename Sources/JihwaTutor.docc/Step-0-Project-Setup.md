# 0. 프로젝트 만들기

Xcode를 여는 것부터 시작합니다. 빈 창 하나가 뜨면 이 단계는 끝이고, 그 뒤로는 전부 계산 문제입니다.

## Overview

### 0.1

**Xcode에서 새 프로젝트를 만듭니다.** 메뉴에서 **File ▸ New ▸ Project…** (⇧⌘N)를 고릅니다. 템플릿 고르는 창이 뜨면 위쪽 탭에서 **visionOS**를 누르고, Application 칸의 **App**을 고른 뒤 **Next**를 누릅니다.

> Tip: 탭이 **iOS · macOS · tvOS · watchOS · visionOS · Multiplatform** 순으로 늘어서 있습니다. visionOS 탭이 보이지 않으면 visionOS 플랫폼 지원이 설치되지 않은 것입니다. **Xcode ▸ Settings ▸ Components**에서 visionOS를 내려받으세요. 3~4GB이므로 시간이 걸립니다.

### 0.2

**옵션을 채웁니다.** 이 튜토리얼의 코드가 그대로 맞아떨어지려면 아래 표대로 골라야 합니다. 특히 **Immersive Space Renderer**와 **Immersive Space**는 기본값이 아니므로 반드시 바꿔야 합니다.

| 항목 | 값 | 이유 |
| --- | --- | --- |
| Product Name | `JihwaTutor` | 앱 파일 이름이 `JihwaTutorApp.swift`가 됩니다 |
| Organization Identifier | `com.example` 같은 자기 것 | 번들 ID가 여기서 만들어집니다 |
| Initial Scene | **Window** | 글자를 고르는 평면 창이 필요합니다 |
| Immersive Space Renderer | **RealityKit** | 기본값은 None입니다. 반드시 바꾸세요 |
| Immersive Space | **Mixed** | 기본값은 Full입니다. 방이 보여야 손을 봅니다 |
| Testing System | None | 이 튜토리얼은 테스트를 만들지 않습니다 |

> Warning: **Immersive Space를 Full로 두면 안 됩니다.** Full은 주변을 완전히 가리는 모드입니다. 지화 연습은 자기 손과 주변을 함께 봐야 하므로 **Mixed**여야 합니다. 잘못 골랐다면 나중에 `.immersionStyle(selection:in:)`을 고쳐도 되지만, 지금 바로잡는 편이 빠릅니다.

### 0.3

**Next를 누르고 저장할 위치를 고른 뒤 Create를 누릅니다.** Xcode가 프로젝트를 만들고 `JihwaTutorApp.swift`를 열어 줍니다. 이때 함께 생기는 것들은 이렇습니다.

- `JihwaTutorApp.swift` — 앱 진입점. **이 파일은 내용을 덮어씁니다.**
- `ContentView.swift` · `ImmersiveView.swift` · `AppModel.swift` · `ToggleImmersiveSpaceButton.swift` — 템플릿 예제. **이 앱에서는 쓰지 않습니다.**
- `Packages/RealityKitContent` — Reality Composer Pro용 로컬 패키지. 쓰지 않지만 지우지 않아도 됩니다.
- `Assets.xcassets` · `Preview Content` — 그대로 둡니다.

### 0.4

**여기서 한 번 실행해 봅니다.** 코드를 한 줄도 고치기 전에, 템플릿이 그대로 도는지부터 확인합니다. 창 왼쪽 위 실행 대상 팝업에서 **Apple Vision Pro** 시뮬레이터를 고르고 ⌘R을 누릅니다. 시뮬레이터가 처음 뜰 때는 1~2분 걸립니다. "Hello, world!" 창이 보이면 준비가 끝난 것입니다.

> Tip: 실행 대상 목록에 시뮬레이터가 하나도 없으면 **Window ▸ Devices and Simulators ▸ Simulators**에서 Apple Vision Pro를 하나 추가하세요.

### 0.5

**템플릿이 만든 앱 파일의 내용을 덮어씁니다.** `JihwaTutorApp.swift`를 열어 전부 지우고 아래 코드를 붙여 넣습니다. **새 파일로 추가하지 마세요.** 새로 추가하면 `@main`이 두 개가 되어 컴파일이 깨집니다.

그리고 `ContentView.swift` · `ImmersiveView.swift` · `AppModel.swift` · `ToggleImmersiveSpaceButton.swift` 네 개는 지웁니다. 파일을 고르고 Delete → **Move to Trash**입니다.

**`JihwaTutorApp.swift`** — 파일 전체가 새 코드라서 강조할 줄이 따로 없습니다

```swift
import SwiftUI

@main
struct JihwaTutorApp: App {

    @State private var model = TutorModel()

    var body: some Scene {
        WindowGroup(id: "tutor") {
            TutorView()
                .environment(model)
        }
        .defaultSize(width: 720, height: 900)

        ImmersiveSpace(id: "practice") {
            PracticeSpace()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
```

> Note: 지금은 `TutorModel` · `TutorView` · `PracticeSpace`가 아직 없어서 빌드가 깨집니다. 정상입니다. 1단계부터 하나씩 만들면서 채워집니다. 지금 바로 창을 다시 띄워 보고 싶다면 <doc:Source-Files>에서 세 파일을 먼저 가져다 놓아도 됩니다.

> Tip: 📁 앞으로 나오는 파일 18개는 아무 데나 둬도 빌드됩니다. 다만 한 폴더에 쌓이면 찾기 어려우니 `Core`(자모·특징·판정·코칭·기준표) · `Tracking`(손 입력) · `Render`(오버레이) · `UI`(화면) 네 그룹으로 나누기를 권합니다. Xcode 그룹은 실제 폴더와 달라도 상관없습니다.

### 0.6

**앱은 창 하나와 몰입 공간 하나로 이루어집니다.** 창에서 글자를 고르고, 몰입 공간에서 손을 봅니다. 손 추적은 몰입 공간에서만 동작하기 때문에 이 구조가 강제됩니다. 0.2에서 Immersive Space Renderer를 RealityKit으로, Immersive Space를 Mixed로 고른 것이 아래 두 줄로 나타납니다.

**`JihwaTutorApp.swift`** — 창과 몰입 공간을 함께 여는 부분

```swift, highlight=[9, 10, 11, 12, 13, 14, 15]
import SwiftUI

@main
struct JihwaTutorApp: App {

    @State private var model = TutorModel()

    var body: some Scene {
        WindowGroup(id: "tutor") {
            TutorView()
                .environment(model)
        }
        .defaultSize(width: 720, height: 900)

        ImmersiveSpace(id: "practice") {
            PracticeSpace()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
```

### 0.7

**손 추적 권한 설명을 넣습니다.** 이 키가 없으면 실기기에서 권한 창이 뜨지 않고 앵커도 오지 않습니다. **visionOS 템플릿은 Info.plist 파일을 만들지 않습니다**(빌드 설정이 자동 생성). 두 가지 방법이 있습니다.

**쉬운 쪽** — 프로젝트 네비게이터에서 프로젝트 → JihwaTutor 타깃 → **Info** 탭을 열고 `+`를 눌러 `Privacy - Hands Tracking Usage Description` 한 줄만 추가합니다.

**아래 파일을 그대로 쓰는 쪽** — `Info.plist`를 만들어 넣고, **Build Settings**에서 `Generate Info.plist File`을 **No**로, `Info.plist File`을 그 경로로 지정합니다.

**`Info.plist`** — 손 추적 권한 설명

```xml, highlight=[2, 3]
<dict>
	<key>NSHandsTrackingUsageDescription</key>
	<string>손 모양을 실시간으로 판정하고 교정하기 위해 손 위치를 읽습니다. 관절 좌표는 기기 안에서만 쓰이며 저장하거나 전송하지 않습니다.</string>
</dict>
```

> Warning: ⚠️ 두 번째 방법을 고르면 `CFBundleIdentifier`·`CFBundleExecutable` 같은 필수 키를 직접 넣어야 합니다. <doc:Source-Files>의 `Info.plist`에는 전부 들어 있습니다. 빠뜨리면 설치 단계에서 **Missing bundle ID**로 실패합니다.

### 0.8

**번들 ID는 자기 것으로 바꿉니다.** 0.2에서 Organization Identifier를 `com.example`로 두었다면 번들 ID는 `com.example.JihwaTutor`가 됩니다. **시뮬레이터만 쓸 거라면 서명은 건드리지 않아도 됩니다.** 6단계에서 실기기로 넘어갈 때만 Signing & Capabilities에서 팀을 고르고, Vision Pro 쪽에서 개발자 모드를 켜면 됩니다.

**`Info.plist`** — 번들 ID는 빌드 설정 값을 그대로 받습니다

```xml, highlight=[2, 3]
<dict>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
</dict>
```

### 0.9

**다시 ⌘R로 실행합니다.** 시뮬레이터에 빈 창이 뜨면 0단계 성공입니다.

### 실행 결과

**0단계를 마치면 나오는 화면**

![0단계 실행 화면](step0.jpg)

*visionOS 26.2 시뮬레이터에서 직접 캡처*

### 체크포인트

#### 여기까지 하면

- 시뮬레이터에 창이 뜨고 제목이 보인다
- 템플릿이 만든 파일 네 개를 지웠고 `@main`이 하나뿐이다
- 실행 대상이 Apple Vision Pro 시뮬레이터로 잡혀 있다

#### 안 되면 확인할 것

- **템플릿 고르는 창에 visionOS 탭이 없다** — Xcode ▸ Settings ▸ Components에서 visionOS 플랫폼을 내려받으세요.
- **Missing bundle ID** — Info.plist를 직접 만들었다면 `CFBundleIdentifier`, `CFBundleExecutable` 같은 필수 키가 빠졌을 수 있습니다. Xcode 템플릿을 썼다면 자동으로 들어갑니다.
- **'main' attribute can only apply to one type** 또는 **Invalid redeclaration of 'JihwaTutorApp'** — 템플릿이 만든 앱 파일을 덮어쓰지 않고 새 파일로 추가했을 때 납니다. 둘 중 하나를 지우세요.
- **Cannot find 'TutorModel' in scope** — 아직 만들지 않은 것이 맞습니다. 1단계로 넘어가세요.
- **몰입 공간을 열었는데 주변이 캄캄하다** — Immersive Space가 Full로 만들어진 것입니다. `.immersionStyle(selection: .constant(.mixed), in: .mixed)`인지 확인하세요.

### 계속하기

- <doc:JihwaTutor>
- <doc:Step-1-Mock-Hand>

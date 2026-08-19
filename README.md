# JihwaTutor DocC

`JihwaTutor.docc`를 GitHub Pages용으로 빌드한 정적 DocC 사이트입니다. 저장소 이름과 DocC의 호스팅 기준 경로는 `jihwa-tutor-docc`로 맞춰져 있습니다.

## 배포

1. GitHub에 `jihwa-tutor-docc` 저장소를 만듭니다.
2. 이 디렉터리의 내용을 저장소 루트에 올리고 기본 브랜치를 `main`으로 사용합니다.
3. 저장소의 **Settings → Pages → Build and deployment → Source**에서 **GitHub Actions**를 선택합니다.
4. `main`에 변경 사항이 올라오면 포함된 워크플로가 사이트를 배포합니다.

배포 주소는 `https://<GitHub-사용자명>.github.io/jihwa-tutor-docc/` 형식입니다. 루트 주소를 열면 `/documentation/jihwatutor/`로 이동합니다.

> 저장소 이름을 바꾸면 DocC 자산 경로도 달라지므로 `--hosting-base-path` 값을 새 저장소 이름으로 바꾸어 다시 빌드해야 합니다.

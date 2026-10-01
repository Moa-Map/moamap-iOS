# iOS
Moa-Map의 iOS repositories

## Git 브랜치 전략

GitHub Flow 기반으로 운영합니다. 장기 브랜치는 `main` 하나만 둡니다.

| 브랜치 | 역할 | 직접 커밋 | 분기 출처 | 병합 대상 |
| --- | --- | --- | --- | --- |
| `main` | 항상 빌드·실행 가능한 기준 브랜치 | X | - | - |
| `feat/*` | 기능 개발 | O | `main` | `main` |
| `fix/*` | 기능 수정, 버그 수정 | O | `main` | `main` |
| `refactor/*` | 리팩터링 | O | `main` | `main` |
| `chore/*` | 설정, 빌드, 문서 등 기타 작업 | O | `main` | `main` |

### 기본 규칙

- 모든 작업은 Issue를 먼저 생성한 뒤 진행합니다.
- `main`에는 직접 push하지 않고, PR로만 병합합니다.
- 작업 브랜치는 최신 `main`에서 분기하고, `main`을 대상으로 PR을 생성합니다.
- 작업 브랜치는 짧게 유지하고, 병합 후 바로 삭제합니다.
- `main`은 언제든 빌드·실행 가능한 상태를 유지합니다.

### 배포

- 앱스토어 배포 시 `main`의 배포 커밋에 버전 태그(`v1.2.0`)를 생성합니다.
- 배포 후 긴급 수정도 `main`에서 `fix/*` 브랜치를 분기해 PR로 반영한 뒤, 새 버전 태그를 생성합니다.

## 작업 흐름

```bash
git checkout main
git pull origin main
git checkout -b chore/#23/github-flow
```

작업 완료 후:

```bash
git add .
git commit -m "[CHORE] 브랜치 전략을 GitHub Flow로 전환 #23"
git push origin chore/#23/github-flow
```

GitHub에서 PR을 생성합니다.

```text
base: main
compare: 작업 브랜치
```

## 브랜치 네이밍

```text
type/#이슈번호/작업명
```

예시:

```text
feat/#12/kakao-login
fix/#31/token-expiration
refactor/#18/place-dto
chore/#23/github-flow
```

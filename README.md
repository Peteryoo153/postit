# Postit

맥 · 아이패드 · 아이폰을 오가며 iCloud로 동기화되는 포스트잇.

- 한 줄씩 적으면 맨 위에 추가, 오른쪽 체크박스로 완료
- 완료하면 밑줄 + 흐림 처리 후 아래로 이동
- 스크롤 끝에 닿으면 이전 항목을 30개씩 더 불러옴
- 텍스트 앞 컬러 라벨로 구분, 하단 필터로 라벨별 보기
- 설정: 폰트 · 크기 · 두께 · 줄 간격 · 항목 간격 · 종이 색상 · 작성자 이름 (설정도 iCloud 동기화)
- 맥: 제목줄 없는 스티커 창, 기본으로 항상 위에 (⇧⌘T로 전환)

## 구조

| 경로 | 내용 |
|---|---|
| `Sources/Models/NoteItem.swift` | SwiftData 모델 (CloudKit 동기화) |
| `Sources/Models/StickySettings.swift` | 사용자 설정, iCloud 키-값 저장소 |
| `Sources/Models/CloudStatus.swift` | 애플 ID 로그인 · 동기화 상태 |
| `Sources/Views/` | 스티키, 한 줄, 리스트(페이지 로딩), 설정 |
| `Sources/Theme.swift` | 디자인 토큰 (종이 색, 폰트, 라벨 색) |

## 빌드

1. Xcode 설치 후 `xcodegen generate` (프로젝트는 이미 포함됨)
2. `Postit.xcodeproj` 열기 → 두 타깃(Postit_macOS, Postit_iOS)의 Signing에서 팀 선택
3. Signing & Capabilities에서 iCloud 컨테이너 `iCloud.com.peter.postit` 생성/체크
4. 실행. 같은 애플 ID로 로그인된 기기끼리 자동 동기화됨

iCloud 동기화는 유료 Apple Developer Program 계정이 필요합니다. 서명 전에는 로컬 저장으로 동작합니다.

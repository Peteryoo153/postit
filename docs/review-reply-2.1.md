# 2026-11-13 iOS 1.1 (3) 심사 반려 대응: Guideline 2.1 Information Needed

- 대상: iOS 1.1 (3), 제출 ID bcc1fd94-0807-48cf-824f-d9f04dd8ed8d (2026-11-12 오후 9:22 제출)
- 상태: "심사를 통과하지 못함 (2.1.0 Performance: App Completeness)"
- macOS 1.1은 따로 "심사 대기 중"이다. 이번 반려와는 상관없다.

## 상황 판단

- 결함 지적이 아니다. 새 앱이라서 앱을 이해할 자료를 달라는 요청이다.
- 이번에는 회신만 하면 안 된다. Apple은 아래 내용을 **앱 심사 정보 → 메모**에 넣고 **다시 제출**하라고 했다.
  1. 실기기 화면 녹화 (최신 iOS, 앱 실행부터 시작)
  2. 목적과 대상 사용자
  3. 주요 기능 사용법
  4. 외부 서비스 목록
  5. 지역별 차이
  6. 규제 업종·제3자 저작물 서류
- Postit에는 계정, 결제, 사용자 간 공유 콘텐츠가 없다. 그래서 녹화에 로그인·계정 삭제·신고 기능을 넣을 필요가 없다.

## 빌드 1.1 (4)로 다시 제출

- 2026-11-13 시뮬레이터 점검에서 버그를 찾았다. 키보드가 올라오면 아이폰 페이지 전체가 위로 밀렸다. 그래서 '할 일 적기'와 검색 칸이 시계·다이내믹 아일랜드 밑으로 들어갔다.
- 고친 방법: 페이지(`PagerView`)가 키보드 영역을 무시하게 했다. 아래 줄(이름 · ···)만 키보드 높이(`keyboardLift`)만큼 직접 올린다.
- 빌드 번호를 4로 올렸다. 녹화와 다시 제출은 1.1 (4)로 한다.

## 녹화 순서 (실기기, 최신 iOS, 1–2분)

녹화는 반드시 앱 실행부터 시작한다. 제어 센터 → 화면 기록으로 찍는다.

1. 홈 화면에서 Postit 아이콘을 눌러 연다.
2. 맨 위 입력 칸에 할 일 2–3개를 적는다.
3. 한 줄 앞에 컬러 라벨을 붙인다. … 메뉴에서 라벨별 보기를 보여 준다.
4. 체크박스로 하나를 완료한다 (취소선 → 아래로 내려가는 애니메이션).
5. 한 줄을 길게 눌러 "맨 위에 고정"을 한다.
6. 한 줄을 길게 눌러 "마감일…"을 정한다. 알림 권한을 허용한다.
7. ··· → 검색으로 할 일을 찾는다.
8. 옆으로 넘겨 다른 포스트잇으로 바꾼다.
9. 설정을 열어 글꼴·종이 색을 바꿔 본다.
10. (가능하면) 아이패드나 맥에서 같은 할 일이 iCloud로 동기화된 모습을 보여 준다.

녹화 파일은 메모에 붙일 수 없으니 링크로 넣는다. iCloud Drive나 Google Drive에 올리고 "링크가 있는 누구나 보기"로 공유한다. Cachette 때와 같은 방법이다.

## 메모 본문 (영어, 메모 칸에 붙여넣기)

`[VIDEO LINK]`를 실제 링크로 바꾼다.

```
1. Screen recording
Recorded on a physical iPhone running the latest iOS, starting from app launch: [VIDEO LINK]
Postit has no account registration or login, no user-generated content shared between users, and no paid content or in-app purchases, so those flows do not exist in the app.

2. Purpose and target audience
Postit is a simple to-do list that looks and feels like a paper sticky note and syncs across iPhone, iPad and Mac with the user's own iCloud. It solves a common problem: people write quick to-dos on a Mac sticky note or a paper note, then cannot see them on their phone when they are away from the desk. Postit keeps the same notes on every device without an account.
Target users: students, teachers, office workers and anyone who keeps a short daily to-do list and moves between a computer and a phone.
Value: one line per task, tap to complete, unfinished tasks automatically roll over to Today, color labels, pinned items, due dates with local reminders, search, and up to six separate sticky notes (for example Work, Home, Shopping).

3. How to use the main features
No login or sample files are needed. The app opens directly to an empty sticky note.
- Type in the field at the top and press Return to add a task.
- Tap the checkbox on the right to complete it; it is struck through and moves down under its date.
- Long-press a task to pin it to the top, set a due date and reminder, or change its color label.
- Tap ··· for search, label filter and settings. Swipe left or right to switch between sticky notes.
- Settings: font, size, weight, line and item spacing, default paper color, and light or dark appearance.
- iCloud sync works automatically when the device is signed in to iCloud. If it is not, the app still works fully on the device.

4. External services
Only Apple services: iCloud (CloudKit private database and iCloud key-value storage) for sync between the user's own devices, and local notifications (UserNotifications) for due-date reminders. No third-party SDKs, analytics, ads, authentication, payment or AI services. No data is sent to the developer.

5. Regional differences
None. The app has the same features and content in all regions.

6. Regulated industry or third-party material
Not applicable. Postit is a personal productivity app with no regulated features and no third-party protected content. All design and code were made by the developer.
```

## 다시 제출하는 방법

1. App Store Connect → Postit → iOS 앱 1.1 → 앱 심사 정보 → 메모에 위 본문을 넣는다.
2. 저장한다.
3. 앱 심사 → 11월 12일 제출 → "앱 심사에 다시 제출"을 누른다. (이번에는 다시 제출하는 게 맞다.)

## 진행 기록

- 2026-11-13 오후 2:59 iOS 1.1 (4)를 App Store Connect에 올렸다. 아카이브: `/Volumes/Oirco Disk/개발자/Archives/Postit-iOS-1.1-4.xcarchive`
- 실기기(iPhone 16 Pro)에서 1.1 (4)를 녹화했다. 영상: https://drive.google.com/file/d/1MzY1mK9Rr5jmG2asrG7uMWFTic7YCbZT/view?usp=sharing
- 2026-11-13 오후 3:14 빌드 4와 메모를 넣고 다시 제출했다. 상태는 "심사 대기 중"이다. 출시는 "자동으로 버전 출시"로 되어 있다.

# 2026-11-14 iOS 1.1 (4) 반려 대응: Guideline 4.3 Spam · 4.2.6 App Generation Services

- 대상: iOS 1.1 (4), 제출 ID bcc1fd94-0807-48cf-824f-d9f04dd8ed8d
- 받은 날: 2026-11-14 오전 1:44
- 상태: "해결되지 않은 문제"
- macOS 1.1은 따로 "심사 대기 중"(11-14 오후 6:46 제출)이다. 같은 이유로 반려될 수 있다.

## 상황 판단

- Apple 안내: 해당 사항이 없다고 생각하면 **다시 제출하지 말고**, 메시지에 **회신**으로 9개 질문에 모두 답한다.
- 가장 큰 원인은 같은 개발자 계정에 할 일 앱이 여럿 있다는 점으로 보인다.
  - myloop: 일·공부·삶 모드로 나눈 할 일 앱, iPhone·iPad·Mac iCloud 동기화 → Postit과 가장 비슷하다
  - 오늘의 사역: 사역자용 데일리 체크리스트
  - mylife: 하루 대시보드(할 일 모듈 포함)
- 그래서 답변의 핵심은 "Postit은 myloop과 다른 문제를 푼다"를 구체적으로 보여 주는 것이다.
  - myloop = 하루를 모드로 나눠 관리하는 '라이프 OS'(앱 안에 들어가서 쓰는 관리 도구)
  - Postit = 맥 화면 위에 항상 떠 있는 종이 포스트잇. 앱을 열지 않아도 보이는 한 장. 맥 스티커 메모(Stickies)를 아이폰·아이패드로 옮긴 것

## 보내기 전에 직접 확인할 것

- [ ] **질문 4(베타 테스트):** 개발자 본인 말고 써 본 사람이 있으면 적는다 (가족, 동료 교사 등). 없으면 아래 문장 그대로.
- [ ] **질문 7(코드 공유):** Postit은 2026-10-15에 새 저장소에서 처음부터 만들었다. myloop 등 다른 앱의 코드·에셋을 가져다 쓴 적이 없으면 그대로 둔다.
- [ ] **질문 9 · 4.2.6:** 코딩할 때 AI 코딩 도구(Claude Code)를 썼다. 템플릿·앱 생성 서비스가 아니고 개발자가 직접 만들어 직접 제출한 것이다. 이 사실을 적을지 정한다. (아래 초안에는 정직하게 적어 두었다.)

## 회신 본문 (영어, "앱 심사에 회신"에 붙여넣기)

```
Thank you for the review. We believe Postit meets guidelines 4.3(a), 4.3(b) and 4.2.6, so we are replying instead of resubmitting.

1. What the app does and the problem it solves
Postit puts a paper-like sticky note on the Mac desktop that is always visible on top of other windows, and keeps the exact same note on iPhone and iPad through the user's own iCloud. The problem: many people keep their daily to-dos on Apple's Stickies app or on paper notes stuck to the monitor. Stickies is Mac-only and does not sync to iPhone, so the list is lost the moment they leave the desk. Postit solves this specific gap: the note stays on screen on the Mac (borderless always-on-top windows, a global hotkey ⌃⌥P to bring it to the current monitor, double-click to fold it into a thin strip), and the same items appear on iPhone and iPad, where you can check them off on the go. Unfinished items automatically roll over to Today, so the note never needs to be rewritten.

2. Intended users
People who work at a computer most of the day and use a sticky note as their working memory: teachers and school staff (the developer is a school chaplain and teacher), pastors and church staff, office workers and students. They want one short list that is always in sight at the desk and in the pocket away from it, without signing up for an account or learning a project-management tool.

3. Gap in the market
- Apple Stickies: Mac only, no iPhone/iPad app, no sync, no completion or dates.
- Apple Notes / Reminders: full apps you must open and navigate; they cannot stay on top of other windows as a small note on the desktop.
- Third-party sticky-note apps are mostly single-platform or require their own account and server. Postit needs no account, stores data only in the user's private iCloud database, and is designed around the physical sticky-note metaphor on all three devices (paper colors and texture, pen-like strike-through, one-line items), rather than lists, projects or boards.

4. Beta testing
The developer has used Postit every day since October 15, 2026 on two Macs (with two monitors) and an iPhone, and distributed builds through TestFlight (internal group). Feedback that changed the production build, all visible in the public commit history at https://github.com/Peteryoo153/postit/commits/main :
- Dragging the paper itself did not move the window → fixed so the whole note can be dragged.
- Tasks left from yesterday disappeared from view → unfinished tasks now roll over to Today automatically.
- With two monitors the notes stayed on the other screen → ⌃⌥P now brings them to the monitor you are looking at.
- Folded notes looked identical → the folded strip now shows the note's name and remaining count.
- Expanding a folded note did not restore its height → fixed in 1.1.
- On iPhone the keyboard pushed the input line under the status bar → fixed in 1.1 (4).
- Users wanted to know whether sync had finished → sync status and last sync time are now shown on the note.

5. Standalone product or suite
Postit is a standalone product. Our account also publishes myloop, mylife and Today's Ministry (오늘의 사역). They are different products:
- myloop is a "life OS" that splits the day into Work / Study / Life modes with separate task and record views inside the app.
- mylife is a home dashboard that gathers weather, calendar and other modules on one screen.
- Today's Ministry is a checklist and calendar tool for pastors' ministry work (worship, visits, administration).
Postit has no modes, modules, categories or calendar. Its scope is a single always-visible sticky note on the desktop, mirrored on iPhone and iPad.

6. Could it be an in-app purchase or feature of another app?
No. Postit's core is a Mac desktop behavior: borderless floating windows that stay on top of other apps, a system-wide hotkey, folding into strips, and up to six notes placed on different monitors. None of our other apps has a desktop window model; adding this to myloop or mylife would turn them into a different kind of app and confuse their users. Postit is also intentionally tiny and free, for people who do not want a full planner.

7. Shared code, frameworks or assets with our other apps
No. Postit was written from scratch in a separate repository starting October 15, 2026 (public: https://github.com/Peteryoo153/postit). It uses only Apple frameworks (SwiftUI, SwiftData, CloudKit, AppKit, UserNotifications). The app icon, paper design, colors and texture were created for Postit.

8. Shared codebase, SDK or content library with third-party apps
No. There are no third-party SDKs or libraries.

9. Created for a client, partner or third party?
No. Postit's concept, content and design are the developer's own, and it is submitted by the developer under the developer's own account. It was not built from a commercial template or an app generation service. The developer wrote it in Xcode and used an AI coding assistant as a programming tool, the same way one would use any development tool; all product decisions, design and testing were done by the developer.

Thank you for reconsidering.
```

## 다음 단계

1. 위 "보내기 전에 직접 확인할 것" 세 가지를 정한다.
2. App Store Connect → 앱 심사 → 제출(bcc1fd94…) → **앱 심사에 회신** → 본문 붙여넣기 → 보내기. (다시 제출 버튼은 누르지 않는다)
3. 맥 1.1도 같은 이유로 반려되면 같은 본문으로 회신한다.

## 그래도 다시 반려되면

- 선택 1: Postit의 기능을 myloop 안에 '포스트잇 모드'로 합치고 Postit은 맥 직접 배포(zip)만 유지한다.
- 선택 2: Postit을 맥 전용(App Store 맥 앱)으로만 내고, iOS는 myloop 쪽 동기화로 대신한다.

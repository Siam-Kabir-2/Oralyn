# Doctor workspace and messaging refinement

## Changes

- The Doctor dashboard now shows a compact identity and verification card,
  direct links to Cases and Messages, and up to three recent assignments. The
  full queue remains under Cases; professional reviews remain under Reviews.
  Dashboard actions switch tabs so the Doctor navigation bar stays visible.
- Case cards, queue headings, profile fields, and review fields use tighter
  spacing while keeping field validation and review submission behavior.
- Conversation cards and the message composer take less space. Privacy and
  urgent-care guidance is available from the information icon in a closable
  sheet. The conversation list still states that messaging is not an emergency
  service.
- Android version `1.6.2+11` distinguishes this build from `1.6.1+10`.

No screening inference, API contract, database policy, or case permission was
changed.

## Verification on 19 November 2026

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub -r expanded`: 52 tests passed, including a widget
  check that opens and closes the chat information sheet.
- Release APK built through the `O:\` workspace alias and verified to contain
  341 Flutter assets and the complete Material Icons font (1,645,184 bytes).
  APK: `build/handoff/oralyn-android-1.6.2-build11.apk`.
  SHA-256: `8F9D42842F78E594F1E7911964266610C6A07444BC1417CF7ECFFB5166548E36`.
- No Android device was connected during this pass, so the revised screens
  still need a phone layout check. The APK uses the project's existing
  development signing setup.

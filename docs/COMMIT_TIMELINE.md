# Reconstructed Oralyn commit timeline

These dates were assigned on 2026-11-13 at the project owner's request to display weekly progress beginning 2026-09-10. They are reconstructed presentation dates, not independently verified times when the work was committed. Both author and committer dates were changed. Commit order, messages and file trees were preserved; hashes changed. The original history remains at `codex/oralyn-original-dates-20261113` and `codex/oralyn-main-original-dates-20261113`.

Week numbers start on 2026-09-10. Commit counts by week: week 1: 6, week 2: 3, week 3: 2, week 4: 2, week 5: 2, week 6: 2, week 7: 5, week 8: 11, week 9: 10, week 10: 14.

| Reconstructed date | New commit | Original commit | Message |
| --- | --- | --- | --- |
| 2026-09-10 | `1623b72` | `3aceb69` | chore: initialize Flutter platform project |
| 2026-09-11 | `f15e4dd` | `c15f85a` | feat: add theme and mock domain layer |
| 2026-09-12 | `8104558` | `ef83247` | feat: build shared UI and entry flows |
| 2026-09-14 | `69d1ba3` | `4a89b4e` | feat: implement screening and result journey |
| 2026-09-15 | `bf5cb7c` | `09136eb` | feat: add care history and profile experiences |
| 2026-09-16 | `6885896` | `8f80547` | test: document and verify the prototype |
| 2026-09-17 | `51716e7` | `8e132a5` | feat(screening): capture and retain real photos |
| 2026-09-19 | `ef051bf` | `d85ea5f` | feat(guidance): expand prevention and care recommendations |
| 2026-09-22 | `ba21e2d` | `24037b8` | docs: describe camera flow and Android build |
| 2026-09-24 | `e77eb5d` | `ecdb371` | feat(screening): connect mobile flow to prediction API |
| 2026-09-26 | `3c47e3f` | `8e4d10f` | feat(results): present model signals and attention overlays |
| 2026-10-01 | `7435a82` | `a717626` | feat(ui): refresh visual system and primary navigation |
| 2026-10-03 | `e7108d2` | `cf32755` | test(screening): cover API mapping and safety guidance |
| 2026-10-08 | `dbc1054` | `58a2f28` | feat(backend): add local two-stage inference service |
| 2026-10-10 | `54dacbb` | `06c921f` | feat(prototype): add mobile experience web mockup |
| 2026-10-15 | `e4aec9a` | `9221189` | docs: add development verification screenshots |
| 2026-10-17 | `3bdf479` | `793fdc2` | docs: document live screening setup and project context |
| 2026-10-22 | `340492f` | `68c5a58` | fix(screening): bound selected images and clarify prototype results |
| 2026-10-23 | `f5ba920` | `1111709` | fix(controllers): ignore stale and disposed async results |
| 2026-10-24 | `658d2b9` | `7663a2f` | test(backend): cover model chaining and Grad-CAM paths |
| 2026-10-26 | `8f05e22` | `b338016` | docs(architecture): audit Oralyn and design next-phase boundaries |
| 2026-10-28 | `5eb7e2b` | `ea6eeaf` | docs(security): record credential history finding |
| 2026-10-29 | `940e197` | `434a707` | refactor(backend): centralize server configuration |
| 2026-10-29 | `b7afb86` | `d335e3e` | refactor(backend): define prediction response types |
| 2026-10-30 | `1093706` | `d2ab622` | refactor(backend): isolate checkpoint loading and inference |
| 2026-10-30 | `c1e5f70` | `9adebab` | refactor(backend): isolate Grad-CAM rendering |
| 2026-10-31 | `e566818` | `0b37d28` | refactor(backend): separate screening orchestration |
| 2026-11-01 | `ba74e68` | `1ca4a82` | fix(backend): bound multipart and decoded image sizes |
| 2026-11-01 | `0117a74` | `2c8400c` | refactor(backend): route predictions through modular app |
| 2026-11-02 | `6d6255e` | `f8c0196` | test(backend): cover prediction API contracts |
| 2026-11-02 | `bbba822` | `3c16613` | test(backend): verify checkpoints through ASGI and Uvicorn |
| 2026-11-03 | `a0332ca` | `05459f9` | build(backend): launch tracked source with private runtime paths |
| 2026-11-04 | `56db8ab` | `7177bf6` | docs(backend): describe security boundaries and verification |
| 2026-11-05 | `0dd2b14` | `7bdc68b` | feat(auth): verify Clerk sessions for screening API |
| 2026-11-05 | `a66cbb6` | `55d79f4` | refactor(auth): retire shared key and update checkpoint probes |
| 2026-11-06 | `92e09fe` | `4cf93c7` | feat(auth): replace Flutter mock login with Clerk sessions |
| 2026-11-07 | `3e3251b` | `6583cb9` | docs(auth): record Clerk integration and security gates |
| 2026-11-07 | `c44b8d9` | `85396cf` | feat(db): add Clerk-owned screening schema and private storage policies |
| 2026-11-08 | `153714e` | `2253c54` | feat(api): persist authenticated screenings through Supabase |
| 2026-11-09 | `5940af4` | `5a8b4ad` | feat(flutter): save and display private screening history |
| 2026-11-09 | `5114d8e` | `391d2cd` | fix(security): validate Supabase endpoint and narrow deletion privileges |
| 2026-11-10 | `f5e5d43` | `7af84bc` | docs(history): record architecture, setup, tests, and open risks |
| 2026-11-11 | `d417fe8` | `d7fb2a7` | test(db): use valid synthetic Clerk subjects in RLS checks |
| 2026-11-12 | `9e96590` | `974627c` | docs(history): record live Supabase verification results |
| 2026-11-12 | `65b1022` | `63d72f7` | feat(db): add verified doctor case authorization |
| 2026-11-12 | `c05b0d6` | `333aeb5` | feat(api): add authenticated case and review workflow |
| 2026-11-12 | `cf76545` | `3b8bb0c` | feat(patient): request reviews and display doctor feedback |
| 2026-11-12 | `9658d6c` | `3d24318` | feat(doctor): add assigned-case workspace and review form |
| 2026-11-12 | `f967594` | `d03a386` | docs(architecture): record role workflow and release gates |
| 2026-11-12 | `fb8192e` | `570a49d` | docs(architecture): link Phase 4 implementation checkpoints |
| 2026-11-12 | `7dc8e55` | `687422a` | fix(doctor): wait for navigation guard before discarding draft |
| 2026-11-12 | `dd75c53` | `5846197` | fix(flutter): make Phase 4 workflows recoverable |
| 2026-11-12 | `2095459` | `eb6fedc` | test(db): cover assignment and private storage RLS |
| 2026-11-12 | `890794e` | `fd9aca5` | chore(testing): add Phase 4 readiness checker |
| 2026-11-12 | `a04571a` | `554005e` | docs(testing): add Phase 4 manual verification guide |
| 2026-11-12 | `bda785a` | `4053ab4` | docs(testing): record live Phase 3C verification |
| 2026-11-12 | `fe98a4b` | `bd10a1f` | chore(release): version Phase 4 Android build |


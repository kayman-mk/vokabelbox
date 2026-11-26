# Vokabelhain – Product and Technical Specification

**Status:** Draft for implementation planning  
**Source:** [Shared planning conversation](https://chatgpt.com/share/6b048a12-f46c-83ed-9342-1da4ee43303f)  
**Version:** 1.0

## 1. Product overview

Vokabelhain is a multi-user vocabulary learning application for desktop browsers, tablets, and phones. It uses one Flutter/Dart client codebase for Flutter Web, Android, and iOS. Users sign in to study vocabulary lists and track progress. There are no public sign-ups, profile pages, or user-managed account settings. Administrators provision accounts manually in the database or through a controlled administrative script.

The web, Android, and iOS clients use the same PHP REST API. MySQL is the authoritative store for accounts, lists, vocabulary, settings, and learning progress, allowing a user to continue on another device with the same state. Offline learning and synchronization are deferred to a later release.

## 2. Goals

- Provide a responsive learning experience on desktop, tablet, Android, and iOS.
- Support multiple users with isolated progress, including when users study the same shared list.
- Support private lists and shared lists.
- Offer all seven planned learning modes and both answer interaction modes where applicable.
- Make it straightforward to import vocabulary from CSV.
- Keep the client and learning algorithms portable across supported platforms.

### Out of scope for the initial release

- Public account registration, profile pages, and self-service password changes.
- Offline study and conflict resolution/synchronization.
- Search-engine-oriented public content pages.
- App-store publication workflow (the client must be buildable for Android and iOS; distribution is a separate release activity).

## 3. Users and access

### Learner

- Signs in with an administrator-provisioned username and password.
- Views the dashboard, accessible lists, learning modes, and personal statistics.
- Creates and manages private lists.
- Studies lists and retains personal progress across devices.

### Administrator

- Creates, disables, and resets user accounts outside the learner UI, using a documented secure process.
- Passwords are stored only as password hashes (Argon2id preferred); plaintext passwords are never persisted.
- The administrative process must not expose a public registration endpoint.

### Shared-list roles

The product supports shared lists and explicit access permissions. The exact default visibility and whether invited users may edit remain open decisions (see §12). Regardless of policy, authorization is enforced by the API on every list and vocabulary operation.

## 4. Functional requirements

### 4.1 Authentication and session

- Login screen accepts username and password.
- No registration, profile, or password-change screens.
- API verifies password hashes and issues revocable, expiring sessions/tokens suitable for mobile and web clients.
- Logout revokes the current session.
- Apply rate limiting to failed login attempts and avoid revealing whether a username exists.
- All traffic uses HTTPS in deployed environments.

### 4.2 Lists and vocabulary management

- Users can view lists they own or have permission to access.
- Users can create, rename, and delete private lists and add, edit, and delete vocabulary entries in lists they may edit.
- A vocabulary entry supports a prompt/term, one or more accepted answers/translations, optional notes/hints, and optional category/lesson/tags.
- Lists can be organized into categories/lessons/tags.
- Vocabulary content is separate from user-specific learning progress.
- A user can reset their progress for a list without changing the list or other users' progress.

### 4.3 CSV import

- Import UTF-8 CSV with comma or semicolon delimiters; support quoted fields and a header row.
- Preview parsed rows and allow column mapping for prompt, answer(s), notes, and optional lesson/category fields.
- Let the user select an authorized target list and review validation errors before committing.
- Detect duplicates and report them; do not silently overwrite existing entries. Duplicate matching policy is configurable/explicit in implementation.
- Import is atomic per confirmed batch or reports precisely which rows succeeded and failed; no ambiguous partial result.
- Show an import summary (created, skipped as duplicate, invalid, and failed rows).
- CSV export is not in the initial scope unless added later.

### 4.4 Learning modes

The learner may choose among all seven modes:

1. **5-box Leitner** – five stages with configurable review intervals.
2. **7-box Leitner** – seven stages with configurable review intervals.
3. **FSRS spaced repetition** – adaptive due-date calculation from review history and per-card scheduling state.
4. **Free flashcards** – study cards without a scheduled interval or automatic stage movement.
5. **Random practice** – randomized selection/order from an authorized list.
6. **Error practice** – focus on cards previously answered incorrectly.
7. **Exam mode** – test session with results at the end; it does not automatically move Leitner boxes or alter scheduling state unless the learner explicitly starts a review mode.

A learner can select a mode per user and list. Learning mode modules must have clear interfaces so algorithms can be changed or added without rewriting the UI or storage layer. A mode switch preserves historical answers; the destination mode's schedule is initialized or recalculated by documented rules, never by deleting review history.

### 4.5 Answer interaction and review

- Provide both self-assessment (reveal answer, mark known/not known) and typed-answer checking in modes where an answer is expected.
- Typed checking is case-insensitive and supports multiple accepted answers. Unicode normalization and whitespace trimming are applied. Accent/diacritic tolerance and typo tolerance are optional future decisions.
- For Leitner modes, incorrect answers return the card to box 1; correct answers advance one box. At the final box, the card is marked learned and scheduled for a later review (exact interval configurable).
- Record each review result with timestamp, mode, answer method, correctness/self-rating, and relevant scheduling transition.
- Support daily due-card sessions, targeted repetition of errors, and resuming an unfinished session.
- Random ordering is available as an option where it does not conflict with mode scheduling.

### 4.6 Dashboard, statistics, and navigation

- Dashboard shows due cards, learning progress, and a quick-start action.
- Learners can set a modest daily review goal and see today's progress toward it.
- Learners can choose a study-session size and see a brief completion summary.
- Main destinations: Dashboard, Learning boxes/lists, Study session, Vocabulary management/import, and Statistics.
- Statistics include correct/incorrect outcomes, activity over time, and card counts by stage/mode where meaningful.
- Navigation adapts to phone, tablet, and desktop layouts. Support touch gestures and keyboard operation in addition to visible controls.
- No profile page. Account identity may be shown minimally in navigation with logout only.

## 5. Learning state and scheduling

Progress is scoped to **user + vocabulary card + learning mode** (or an equivalent model that prevents one mode from corrupting another). Shared vocabulary content has no user-specific progress fields.

For 5-box and 7-box modes, each card has a stage and next-due timestamp. Intervals are configuration, not hard-coded assumptions. For FSRS, store algorithm version, parameters/state, repetitions, lapses, and next-due timestamp as needed by the selected FSRS implementation. Record immutable review events so progress can be audited and statistics rebuilt.

The initial FSRS implementation uses FSRS-4.5 with its published default parameters, 90% desired retention, a one-day minimum interval, and a 100-year maximum interval. It stores separate progress for each user, card, learning method, and translation direction (`foreign_to_local` or `local_to_foreign`). A vocabulary box's progress is the set of its cards in that scope. Reviews use the four FSRS ratings (Again, Hard, Good, Easy); each review appends an event containing the rating and scheduling transition. The initial study interaction is self-assessment after revealing the answer. The vocabulary-box statistics view reports card state, review totals by rating, and daily review activity for the selected method and direction.

Free, random, error, and exam sessions may record answers for statistics. Exam mode must not mutate scheduled progress by default. A user's progress must be consistent across devices because the server is authoritative.

## 6. Proposed application screens

1. **Login** – username and password.
2. **Dashboard** – due count, progress summary, daily goal, quick start.
3. **Lists** – private and shared lists accessible to the user; create/manage actions according to permission.
4. **List detail** – vocabulary, lessons/tags, study entry point, import and management actions according to permission.
5. **Study setup** – select learning mode, direction (A→B or B→A), answer mode, and optional session size/order.
6. **Study session** – prompt, reveal/input, feedback, next card, progress, pause/resume, and completion summary.
7. **Import flow** – file selection, delimiter/column mapping, preview/validation, confirmation, result report.
8. **Statistics** – activity, accuracy, due cards, and progress by mode/list.

## 7. Technical architecture

- **Client:** Flutter + Dart; Flutter Web, Android, and iOS targets from a shared codebase.
- **Backend:** PHP 8.3+ REST API (exact deployment/runtime baseline to confirm at implementation start).
- **Database:** MySQL 8 with migrations and foreign keys.
- **Transport:** JSON over HTTPS; version API routes (for example `/api/v1`).
- **Client state:** Keep presentation, domain/learning logic, and data access separated. Do not embed secrets or database credentials in client builds.
- **Offline:** Deferred. The client may ship its UI bundle locally, but all product data and learning operations require connectivity in the initial release.

### Conceptual data model

- `users`: username, password hash, active/disabled state, timestamps.
- `sessions` or `refresh_tokens`: revocable authentication sessions, expiry and device/client metadata as appropriate.
- `vocabulary_sets`: owner, title, description, visibility/type, timestamps.
- `set_permissions`: list, user, access role, grantor and timestamps for shared access.
- `vocabularies`: list, prompt, notes, timestamps.
- `vocabulary_answers`: vocabulary entry and accepted answer(s), if normalized separately.
- `vocabulary_tags` / `tags`: optional categorization and lessons.
- `user_set_settings`: per-user/list learning mode, direction, answer mode, and mode-specific preferences.
- `learning_progress`: per-user/card/mode current scheduling state (box/FSRS state and due time).
- `learning_sessions`: session metadata, mode, start/end and completion state.
- `learning_answers` or `review_history`: append-only answer/review events for state transitions and statistics.
- `csv_imports` (optional): import summary and audit metadata; avoid retaining uploaded source files unless explicitly required.

Use stable primary keys, UTC timestamps, indexes for due-card queries and permission checks, and unique constraints that prevent duplicate progress rows for a user/card/mode. Store password hashes using a modern password hashing API. Never store passwords or bearer tokens in logs.

## 8. REST API outline

All endpoints require authentication except login. The API checks ownership/permissions for every resource access.

- `POST /api/v1/auth/login`, `POST /api/v1/auth/logout`, optional token refresh endpoint.
- `GET /api/v1/me` for minimal session identity (not a profile page).
- `GET/POST /api/v1/sets`; `GET/PATCH/DELETE /api/v1/sets/{setId}`.
- `GET/POST /api/v1/sets/{setId}/vocabularies`; `PATCH/DELETE /api/v1/vocabularies/{id}`.
- Shared-list permission endpoints for authorized owners/admins (exact workflow depends on §12).
- `POST /api/v1/sets/{setId}/imports/preview` and `POST /api/v1/sets/{setId}/imports` for preview/commit.
- `GET /api/v1/study/due`, session create/resume/complete endpoints, and answer/review submission endpoint.
- `GET /api/v1/statistics` with list/mode/date filters.

Request/response schemas, pagination, error format, idempotency for review/import submissions, and API authentication mechanism are to be defined before implementation. Never accept client-supplied user IDs as authority for progress ownership.

## 9. Security, privacy, and operations

- HTTPS only in production; secure password hashing; least-privilege database credentials.
- Server-side authorization on every list, vocabulary, import, progress, and statistics endpoint.
- Rate-limit login and import operations; validate CSV size, row count, encoding, and field lengths.
- Protect against SQL injection using parameterized queries and against CSRF where cookie-based sessions are used.
- Set secure session/token storage per platform; avoid secrets in source control and client code.
- Log operational events without passwords, tokens, raw CSV contents, or unnecessary personal data.
- Define backups, restore procedure, schema migration and rollback practices before production use.

## 10. Delivery phases

1. **Foundation:** repository/app skeleton, database migrations, PHP API, account provisioning procedure, login, authorization, lists, vocabulary CRUD, CSV import.
2. **Learning:** review history, 5-box and 7-box modes, answer flows, session resume, dashboard and initial statistics.
3. **All modes and responsive experience:** FSRS, free, random, error, exam mode; desktop/tablet/phone layouts and accessibility/keyboard support.
4. **Platform releases:** Web deployment and Android/iOS builds; device testing and packaging/distribution planning.
5. **Later enhancement:** offline storage (for example SQLite) and conflict-safe synchronization with the server-authoritative state.

## 11. Acceptance criteria for the initial product

- An administrator can provision and disable a user without public registration; login succeeds only for active accounts with a valid password.
- Two users can study one shared list while their progress remains isolated.
- Private lists and shared-list access are enforced server-side.
- The user can create/edit vocabulary and import a CSV using a preview and column mapping, with a clear result report.
- All seven learning modes are available; scheduled modes maintain their own state and review history.
- Both self-assessment and typed checking work; case and surrounding whitespace do not affect a typed match, and multiple accepted answers are supported.
- A review performed on one device is reflected on another after refresh/login.
- A learner can set a daily review goal, see review progress toward it, choose a session size, and see a completion summary.
- The interface is usable at phone, tablet, and desktop widths and does not expose profile or registration pages.
- Flutter Web and Android builds can be produced from the shared client; iOS build configuration is maintained and buildable in a macOS environment.
- Offline learning is not required for this release and is clearly unavailable without connectivity.

## 12. Decisions to resolve before implementation

1. Who can discover/read shared lists: every authenticated user, or only explicitly granted users?
2. Who can edit a shared list: owner only, or owner plus explicitly granted editors?
3. Exact review intervals and graduation behavior for 5-box and 7-box modes.
4. FSRS library/version and parameter migration policy.
5. Authentication token/session design, expiry, and account recovery/admin password reset process.
6. CSV duplicate identity rules, maximum upload/row sizes, and handling of row-level failures.
7. Whether account usernames are treated as case-sensitive and exact password provisioning procedure.
8. Hosting target, PHP runtime compatibility, deployment and backup requirements.

## 13. Source decisions captured

- Private **and** shared lists.
- Self-rating **and** typed-answer modes.
- All seven learning modes: 5-box, 7-box, FSRS, free cards, random practice, error practice, and exam mode.
- Flutter/Dart for a shared Web, Android, and iOS client; Flutter-rendered UI rather than a WebView-based app.
- PHP REST API and MySQL.
- Login only; accounts provisioned manually; no profile pages.
- CSV vocabulary import.
- Desktop, tablet, and phone are equally important.
- Server-centralized learning progress; offline support later.

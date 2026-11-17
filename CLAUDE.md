# StyleBook Partner App

Flutter app (web/tablet first, Android, iOS) for salon owners, managers and specialists.

## Layout
- `apps/partner/` the app (`lib/shell`, `lib/features/<feature>/{data,application,presentation}`, `l10n`)
- `packages/sb_ui` theme + shared widgets (`sb_theme.dart`), `sb_core` config/auth/format, `sb_api` Dio client
- Dart pub workspace (root `pubspec.yaml`): run `flutter pub get` once at the root
- `docs/STYLEBOOK_PARTNER_APP_INSTRUCTIONS.md` screens P-01..P-22, user stories, build order, DoD
- `docs/STYLEBOOK_FLUTTER_STYLE_GUIDE.md` "Amber & Ink" design system
- `docs/api/openapi.json` API contract (live: http://localhost:8000/docs). Partner endpoints: `/v1/partner/*`
- `mobile/` PNG exports of phone screens (design reference)
- `docs/_specs/` BA specs per screen, `docs/backlog/` PM backlog and status

## Rules (full list in the instructions doc §5)
- Git: check `git status` first (if uncommitted changes exist, stop and ask to commit); work on `feature/<name>` branches off `dev`; never commit directly to `dev` or `main`.
- Development: practice strict TDD (write tests first: Red -> Green -> Refactor).
- UI: only `sb_ui` tokens/components (`context.sb`, `Theme.of`). No hard-coded colours, sizes, radii, shadows. Actions are black pills.
- API is the source of truth for slots, prices, fees, payouts. The app never computes them.
- Destructive actions confirm first; decline and stock changes need a reason; confirm buttons use `danger`.
- Money from cents: `LKR 1,500`. Dates: `Thu 29 Oct, 9:30 AM`.
- Each screen: loading, empty, error states; 44 px targets; Semantics on icon buttons; strings in ARB; role checks.
- Verify with `flutter analyze` and `flutter test` before saying done.

## Agents (`.claude/agents/`)
`ba` requirements and API mapping, `pm` planning and tracking, `dev` implementation, `code-reviewer` read-only review.
Flow: pm picks next item, ba writes spec, dev builds, code-reviewer reviews, pm updates the backlog.

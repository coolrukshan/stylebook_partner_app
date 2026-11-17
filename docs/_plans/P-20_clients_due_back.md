# P-20 Clients due back — Implementation Plan

- Spec: [docs/_specs/P-20_clients_due_back.md](../_specs/P-20_clients_due_back.md)
- Design: no PNG (web). Phone is not in More; narrow widths render cards with a bottom action bar.

## 1. Summary and dependencies

List clients overdue for a return, filter by minimum overdue days, select up to 50 eligible clients and send a nudge. Server enforces caps, opt-out, quiet hours; the app only reports `skipped` and `warnings`.

Prerequisites:
- Shell, role guard, auth/session exposing `salonId` (this endpoint needs `salon_id` explicitly, Q2) and role.
- Dio client (`packages/sb_api`), `ApiException` mapping, l10n, formatting helpers.
- `sb_ui` skeleton, error card, empty state, banner (shared; first plan to land creates them).
- Soft link: P-07 Clients (a row could open the client record later; not in scope).

## 2. Files to create / modify

`apps/partner/lib/features/engagement/` (folder named in instructions §2):
- `data/engagement_models.dart` (freezed): `DueClient`, `DueSummary`, `DuePage`, `NudgeRequest`, `NudgeResult`, `SkippedUser`.
- `data/engagement_repository.dart`.
- `application/due_clients_providers.dart`: `dueFilterProvider`, `dueClientsProvider` (paged `AsyncNotifier`), `dueSelectionProvider` (`Notifier<Set<String>>`), `nudgeControllerProvider`.
- `presentation/clients_due_back_screen.dart`, `widgets/due_summary_chips.dart`, `due_clients_table.dart` (>= 900 px), `due_client_card.dart` (narrow), `nudge_dialog.dart`, `nudge_result_sheet.dart`, `due_selection_bar.dart`.
- `apps/partner/test/features/engagement/...`.

Shell/router: `lib/router.dart` add `/clients/due` (or `/engagement/due`); sidebar entry "Due back" under Clients (web/tablet only), not in phone More.

sb_ui additions: `SbSkeleton`, `SbBanner`, `SbSelectionBar` (sticky bar: "N selected" + black pill; style from `SbActionBar` but for light pages; or reuse `SbActionBar` with dark bar), `SbAvatar` (network image with initials fallback, 44 px), `SbTag` (pill for "Nudged 3 days ago", "Not eligible"), `SbDataTable` helper only if the table needs shared styling (otherwise `data_table_2` configured with theme tokens inside the feature is acceptable once, but prefer a Row/ListView table for 200% text scale).

l10n: `app_en.arb`.

## 3. Data layer

| Method | Path | Notes |
|---|---|---|
| GET | `/v1/partner/engagement/due` | query `salon_id*` (uuid, required), `min_overdue_days`, `sort`, `cursor`, `limit` -> `DueListOut {items, next_cursor, summary {total_due_back, tier1_count, tier2_count, tier3_count}}` |
| POST | `/v1/partner/engagement/nudge` | body `NudgeRequest {salon_id*, user_ids* (min 1; spec says max 50), message?, channels[]}` -> 202 `NudgeResponse {nudge_batch_id, queued_count, skipped[{user_id, reason}], warnings[]}` |

Neither endpoint declares `X-Salon-Id`; use `salon_id` from session as query/body. Still send `X-Salon-Id` via the shared interceptor (harmless; confirm, Q2).

`DueClientOut` fields: `user_id`, `user_name?`, `user_avatar_url?`, `phone_last4?`, `last_visit` (date-time), `last_service?`, `total_visits`, `total_spend_cents`, `avg_interval_days?`, `days_since_last_visit`, `days_overdue`, `nudge_tier`, `eligible`, `ineligible_reason?`, `last_nudge_at?`. Verify nullability against the schema when generating models.

Repository: `fetchDue({salonId, minOverdueDays, sort, cursor, limit})`, `sendNudge({salonId, userIds, message, channels})`.

Errors: 422 (over 50 or invalid) -> `Validation` shown in dialog; 429 -> `RateLimited` snackbar and button re-enabled after response; 403 -> no-access view; network -> error card (list) or inline error (dialog), selection kept in both cases.

## 4. Application / state

- `DueFilter {minOverdueDays?: 7|14|30}`; `sort` omitted (default server order: most overdue first per spec AC1; do not send an undocumented sort value, Q3).
- `DueClientsNotifier extends AsyncNotifier<DueState>`: `DueState {summary, items, nextCursor, loadingMore}`; `loadMore()`, `refresh()`. Filter change invalidates the list and clears the selection of rows no longer present.
- `DueSelection`: `Set<String>` of user ids. Rules: only `eligible` rows can be toggled; `selectAllEligibleOnPage()` selects eligible loaded rows in order up to 50 (does not silently split: at 50, extra checkboxes are disabled and hint `dueMaxSelected` shows). `clear()`.
- `NudgeController extends AsyncNotifier<NudgeResult?>`: `send(message, channels)`; guard against double submit (`isLoading` disables confirm). On success: show result sheet, clear selection, `ref.invalidate(dueClientsProvider)` to refresh `last_nudge_at`. On failure: keep selection and dialog text.
- Loading: table skeleton (8 rows). Empty: "No clients are due back. Nice work." Error: retry card. Filtered empty uses the same empty text with a hint to change the filter.
- Offline: list from last data, Send disabled with banner (no drift cache yet; document).

## 5. Presentation

- `ClientsDueBackScreen` -> `LayoutBuilder`: >= 900 px table, else cards.
- Header: title `headlineMedium` "Clients due back", summary chips from `summary` (All N, Tier 1 N, Tier 2 N, Tier 3 N). Tier chips: spec does not say whether they filter (API has no tier filter); they are display-only counts unless client-side filtering is agreed (Q5; default: render as non-interactive stat chips, not `SbChoiceChip`). Overdue filter chips (Any, 7+, 14+, 30+ days) use `SbChoiceChip` and re-query.
- Table row: checkbox (theme), avatar + name, last service, `last_visit` date, usual interval ("every 28 days"), days overdue ("12 days overdue", amber `SbColors.warning` text when `days_overdue > 0`), visits, spend (`LKR` from cents), status tag ("Nudged 3 days ago" from `last_nudge_at` using a shared relative-time formatter; ineligible rows: "Not eligible: {reason}" and disabled checkbox with Semantics). Phone masked as "... 1234" without tap actions.
- Narrow: `DueClientCard` (`SbCard`) with checkbox, name, key facts, status tag; sticky `DueSelectionBar` at the bottom (`SbActionBar` look: "N selected" + white pill on ink) above the safe area.
- Sticky action bar (wide): "N selected" + `SbPrimaryButton("Send nudge")`, disabled when 0 selected or when offline or while sending.
- `NudgeDialog`: message `TextField` (multiline, optional, prefilled template text as hint/prefill; if left empty the server template is used, show hint), channel chips (`SbChoiceChip`, multiple; values undocumented, Q3), recipient count, black `SbPrimaryButton("Send")` (not destructive), Cancel text button.
- `NudgeResultSheet`: "Queued N", list of skipped clients (resolve names from loaded rows by `user_id`, else show id suffix) with `reason`, each `warnings` string.
- Tokens only; 44 px touch targets on rows and checkboxes (wrap in `ConstrainedBox(minHeight: SbTokens.minTouch)`); Semantics: row label "Select {name}", avatar excluded; text scale 200% uses wrap or horizontal scroll on the table (`SingleChildScrollView` horizontal) so nothing clips.

## 6. Role rules

- Owner, manager: view and nudge (assumed, Q1). Specialist: no route. `Permissions.canNudgeClients(role)`; route redirect, sidebar filter, and 403 fallback view. No role-dependent fields otherwise.
- Tests: owner and manager see the Send button; specialist is redirected.

## 7. Validation, confirmations, formatting

- Send disabled with 0 selected; hard cap 50 enforced in selection (`user_ids` max 50 per spec; OpenAPI shows only `minItems 1`, so the max is a spec claim).
- Dialog confirm is a black pill; no danger styling. No extra "are you sure" beyond the dialog itself.
- Message length unknown: do not enforce, show server 422 message.
- Dates: `last_visit` as "Thu 29 Oct, 9:30 AM" or date-only if the shared formatter offers it; "12 days overdue" via ARB plural from `days_overdue` (API value, not recomputed from dates). Money from `total_spend_cents`.
- Never compute eligibility, tiers or overdue client-side.

## 8. ARB keys

`dueTitle`, `dueSummaryAll` ({n}), `dueSummaryTier1` ({n}), `dueSummaryTier2` ({n}), `dueSummaryTier3` ({n}), `dueFilterAny`, `dueFilterDays` ({n}), `dueColClient`, `dueColLastService`, `dueColLastVisit`, `dueColInterval`, `dueColOverdue`, `dueColVisits`, `dueColSpend`, `dueColStatus`, `dueOverdueDays` (plural {n}), `dueIntervalEvery` ({n}), `dueNudgedAgo` ({when}), `dueNudgedJustNow`, `dueNotEligible` ({reason}), `duePhoneMasked` ({last4}), `dueSelectedCount` ({n}), `dueSelectAll`, `dueMaxSelected` ({n}), `dueSendNudge`, `dueNudgeDialogTitle`, `dueNudgeMessageLabel`, `dueNudgeMessageHint` ("Leave empty to use the standard message"), `dueNudgeTemplate`, `dueNudgeChannels`, `dueNudgeRecipients` ({n}), `dueNudgeSend`, `dueNudgeQueued` ({n}), `dueNudgeSkippedTitle`, `dueNudgeWarningsTitle`, `dueNudgeFailed`, `dueRateLimited`, `dueEmpty`, `dueLoadError`, `dueRetry`, `dueOfflineBanner`, `dueNoAccess`, `commonCancel`, `commonClose`.

## 9. Tests

Unit:
- `engagement_models_test`: parses `DueListOut` with nulls; defaults for missing `summary`.
- `engagement_repository_test`: sends `salon_id` query always; `min_overdue_days` only when set; nudge body includes `salon_id`, `user_ids`, optional `message` omitted when blank; maps 202, 422, 429.
- `due_selection_test`: ineligible not selectable; select-all picks only eligible; caps at 50; disabling further selection; clear on filter change removes absent ids.
- `nudge_controller_test`: success clears selection and refetches; failure keeps selection; double tap sends one request.

Widget:
- Row with `eligible=false` shows reason and disabled checkbox.
- "12 days overdue" text and amber style for overdue rows; phone shows only "... last4", no copy/call actions.
- Send disabled when none selected; dialog confirm is a black pill; result sheet lists skipped and warnings.
- Filter chip 14 triggers a repository call with `min_overdue_days=14`.
- Loading skeleton, empty text, error retry, offline disables send.
- Role tests (owner, manager, specialist).
- Narrow layout shows cards and bottom bar; text scale 2.0 no overflow.

Golden: `due_back_1280.png` (summary chips, table with 3 rows incl. ineligible and nudged, selection bar with 2 selected); `due_back_390.png` (cards and bottom bar).

## 10. Task checklist

1. Confirm shell/auth/session `salonId`, Dio, l10n are available.
2. Add `sb_ui` pieces (avatar, tag, selection bar, banner, skeleton) with tests.
3. Models and repository plus tests.
4. List notifier, filter, selection; unit tests.
5. Wide table UI with states; golden 1280.
6. Narrow cards and bottom bar; golden 390.
7. Nudge dialog, controller, result sheet; tests.
8. Route, sidebar entry, role guard; role tests.
9. ARB strings, text scale test.
10. `flutter analyze` and `flutter test`.

## 11. Open questions / API gaps / risks

- Q1 roles. Q2 `salon_id` required in query/body vs `X-Salon-Id`; the session must provide a salon id (multi-salon owners need the salon switcher, not yet built). Q3 `channels`, `sort`, skip reasons undocumented: send `channels` only if the user picked one; default empty list lets the server decide (confirm that empty means "all" and not "none"). Q4 only overdue clients, no "due soon". Q5 tier meanings: labels need text from PM; plan uses neutral "Tier 1/2/3".
- OpenAPI does not state the 50 max; the 422 on over 50 comes from the spec text only.
- `last_visit` is a date-time; display timezone not provided here.
- The list supports pagination only; "Select all" is per loaded page, which can surprise users with several pages (spec accepts).
- A separate `GET /v1/partner/engagement/stats` exists but is not in the spec; not used.
- Skipped users only carry `user_id`: names must be resolved from the loaded rows; a skipped user on a page no longer loaded displays a generic label.

# P-12 Leave requests — Implementation Plan

- Spec: [docs/_specs/P-12_leave_requests.md](../_specs/P-12_leave_requests.md)
- Design: no PNG. Follow the "Needs your action" pattern in `mobile/P-02_today.png` and `mobile/P-02_today_decline_reason.png`.

## 1. Summary and dependencies

"Staff leave" tab inside "Needs your action" on Today: cards for pending leave requests with Approve (black pill) and Decline (white pill, required reason, red confirm). Approve can return conflicting bookings, which needs a "Approve anyway" (`force`) dialog and a "N bookings need to be moved" follow-up.

Dependencies:
- P-02 Today screen and its "Needs your action" tab container (`features/today/presentation/today_screen.dart` exists as a stub). P-12 exports a widget `LeaveRequestsTab` and a count provider `pendingLeaveCountProvider`; P-02 mounts them. Agree the tab API with the P-02 plan: `Tab(label, badgeCount)` + body widget.
- P-09 `StaffRepository` (`list`, `timeOff`) for the N+1 stop-gap and the `TimeOffItem` model.
- P-05 / P-03 calendar link for moving bookings (route `/calendar` with date, or P-05 sheet when it exists).
- Shell/router/role guard, session, `ApiError`, `SbFormat`.
- `sb_ui`: tabs with badge, `SbCard`, `SbReasonField`, `SbConfirmDialog` (danger), `SbSecondaryButton`, `SbAvatar`, `SbPill`, `SbToast`, `SbEmptyState`, `SbErrorPanel`, `SbSkeleton`.

## 2. Files to create / modify

Create under `apps/partner/lib/features/leave/`:
- `data/leave_models.dart` (`LeaveRequest` (view model from `TimeOffItem` + staff title), `DecideLeaveIn`, `DecideLeaveResult`)
- `data/leave_repository.dart`
- `application/leave_providers.dart` (`leaveRepositoryProvider`, `pendingLeaveControllerProvider`, `pendingLeaveCountProvider`, `leaveDecisionControllerProvider` family)
- `presentation/leave_requests_tab.dart`
- `presentation/leave_request_card.dart`
- `presentation/decline_leave_panel.dart` (inline reason field)
- `presentation/approve_anyway_dialog.dart`
- `presentation/leave_history_list.dart` (optional, wide only)
- tests: `apps/partner/test/features/leave/**`

Modify:
- `apps/partner/lib/features/today/presentation/today_screen.dart` (P-02 owner): add "Staff leave" tab entry calling `LeaveRequestsTab`, visible only with `Capability.decideLeave`. Coordinate; do not duplicate the tab scaffolding.
- `apps/partner/lib/router.dart`: optional `/leave` deep link (push notification target) that opens Today with the leave tab selected.
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_core`: `SbFormat.dateRange`, `daysCount` display helper (inclusive count shown from `start_date`/`end_date`; display only).

## 3. Data layer

Endpoints:
| Method | Path | Notes |
|---|---|---|
| GET | `/v1/partner/staff` | stop-gap source of staff ids and titles (`active_only=true`) |
| GET | `/v1/partner/staff/{staff_id}/time-off` | with `status=pending` query (the parameter exists: `status`, `from_date`, `to_date`); returns `TimeOffItemOut` incl. `staff_name`, `created_at` |
| POST | `/v1/partner/leave/{leave_id}/decide` | `DecideLeaveIn {decision: "approved"|"declined", reason?, force?}` -> `DecideLeaveOut {id, status, decided_by_name, affected_booking_ids[], reason, updated_at}` |

Note: there is no salon-wide leave listing (gap 1). `LeaveRepository.pendingAll()` fans out: list staff (all pages), then `time-off?status=pending` per staff with a concurrency cap of 4, merging into one list sorted by `created_at` ascending. Isolated behind this single method so it can be replaced by `GET /v1/partner/leave?status=pending` later with no UI change. Per-staff failures are collected as `partialErrors` and shown as a small "Some staff could not be loaded" row with Retry, not a total failure.

Repository: `Future<PendingLeave> pendingAll()`, `Future<DecideLeaveResult> approve(String leaveId, {bool force = false})`, `Future<DecideLeaveResult> decline(String leaveId, String reason)`.

Error mapping: 409 on approve -> `LeaveConflict` (typed). Body shape undocumented (gap 2): treat 409 as "overlapping bookings" only when `ApiError.code` indicates conflict; read a count from the body if present, otherwise show a generic message "This leave overlaps existing bookings". Distinguish 409 "already decided" (spec 6) from 409 "conflict": use `ApiError.code`; if codes are not distinguishable, on any 409 reload the list and, if the request is still pending, show the conflict dialog; if it is no longer pending, toast "Already decided". 404 -> remove card, toast. 422 -> message.

## 4. Application / state

- `PendingLeaveController extends AsyncNotifier<List<LeaveRequest>>`: `build()` calls `pendingAll()`. `refresh()`. `removeLocally(id)` after a successful decision. Count provider derives `length` for the badge.
- `LeaveDecisionController` (family by leave id, state `idle | submitting | conflict(affectedCount) | error(message)`): guards double taps (ignore while `submitting`, plus the repository sends one request per call).
  - `approve({force})`: success with empty `affected_booking_ids` -> remove card, toast "Leave approved". Success with affected ids (force path) -> remove card and show a follow-up banner/toast "N bookings need to be moved" with a "Open calendar" action. 409 conflict (not forced) -> state `conflict`, UI opens the `ApproveAnywayDialog` (danger confirm "Approve anyway" -> `approve(force: true)`; Cancel closes).
  - `decline(reason)`: reason trimmed non-empty required; success -> remove card, toast "Leave declined".
- Ordering: oldest `created_at` first. Badge count shown in tab label; increments on real-time event (acceptance 7): subscribe to realtime provider when it exists; interim fallback: poll `pendingAll()` every 60 s while Today is visible and refresh on app resume. Mark the fallback with a TODO to replace by WebSocket.
- States: loading skeleton cards; empty "No leave requests waiting"; error panel with Retry; offline: Approve/Decline disabled and "You are offline" hint.
- History (wide, optional): decided items need `status` in (`approved`, `declined`); stop-gap: fetch non-pending for the same staff list on demand when the user expands "History"; shows `decided_by_name` and date. Default plan: ship pending-only first; history behind a later task.

## 5. Presentation

Phone: inside the Today "Needs your action" tab view: `LeaveRequestsTab` -> `ListView` of `LeaveRequestCard` (`SbCard`): row 1 `SbAvatar` initials, "Name · title" (title from the staff list item), trailing days count pill ("3 days"); row 2 date range "Mon 23 - Wed 25 Nov" (`SbFormat.dateRange`); row 3 reason (muted, "No reason given" when null); row 4 buttons: black `SbPrimaryButton` "Approve" and white `SbSecondaryButton` "Decline" (min 44 px). Tapping Decline expands an inline `DeclineLeavePanel`: `SbReasonField` (required) and a red `SbDangerButton` "Decline request" enabled only with non-empty reason, Cancel link; mirrors `P-02_today_decline_reason.png`.

Wide: the same cards in the action panel tab; optional history list beneath. Tab label "Staff leave (n)" with badge using `SbTabs` badge (add if needed).

`ApproveAnywayDialog`: title "Approve anyway?", body "This leave overlaps N bookings. They will need to be moved." danger confirm "Approve anyway", white Cancel.

Post-approval message: `SbToast` with action "Open calendar" -> `context.go('/calendar')` (with date of leave start as query parameter when P-03 supports it).

All tokens from `SbColors`/`context.sb`; Semantics on both buttons including the person name ("Approve leave for Ishara").

## 6. Role rules

- Owner and manager: tab visible, actions enabled. Specialist: no tab and no data fetch (the provider returns empty without calling the API when `!Capability.decideLeave`).
- Implement `Capability.decideLeave` (owner, manager). Today screen builds the tab list conditionally; `/leave` route redirects specialists to `/`. API 403 -> error panel.

## 7. Validation, confirmations, formatting

- Decline: reason required in UI (API says optional); confirm button enables only with trimmed non-empty text; danger styling (`SbColors.danger`).
- Approve: single tap, no confirm, except the forced approve which is a danger confirm dialog.
- Date range "Mon 23 - Wed 25 Nov"; same-day leave shows a single date; days count shown is inclusive and display-only (flag: if it is considered business logic, ask the API to return it).
- 409 refresh behaviour: reload list after any 409.
- Double tap sends one request (state guard).

## 8. ARB keys

`leaveTabTitle` ("Staff leave"), `leaveTabBadge` (placeholder `count`), `leaveEmpty` ("No leave requests waiting"), `leaveLoadError`, `leavePartialError`, `leaveApprove`, `leaveDecline`, `leaveApproveSemantics` (placeholder `name`), `leaveDeclineSemantics`, `leaveDays` (plural), `leaveNoReason`, `leaveDeclineReasonLabel`, `leaveDeclineReasonHint`, `leaveDeclineConfirm`, `leaveApproved`, `leaveDeclined`, `leaveAlreadyDecided`, `leaveConflictTitle`, `leaveConflictBody` (placeholder `count`), `leaveConflictGeneric`, `leaveApproveAnyway`, `leaveBookingsToMove` (plural), `leaveOpenCalendar`, `leaveHistory`, `leaveDecidedBy` (placeholders `name`, `date`), `leaveOfflineHint`, `commonRetry`, `commonCancel`.

## 9. Tests

Unit:
- `leave_repository_test`: `pendingAll` queries `status=pending` per staff, merges and sorts by `created_at` ascending; one staff failing returns the rest plus `partialErrors`; concurrency never exceeds 4 (counting fake); decide body shapes (`approved` + optional `force`; `declined` + `reason`).
- `leave_decision_controller_test`: approve ok (empty affected) removes card; approve 409 -> conflict state, then forced approve sends `force: true`; forced result with affected ids emits move notice with count; decline requires reason (empty never calls API); double tap one call; 404 removes card; already-decided 409 triggers reload.
- `pending_leave_controller_test`: badge count equals list length; refresh resets; specialist gets empty without any HTTP call.
- `format_date_range_test`, `days_count_test` (inclusive, same day = 1).

Widget:
- tab shows skeleton, cards sorted oldest first, empty, error with Retry, partial error row.
- Approve success removes the card and shows "Leave approved".
- 409 shows "Approve anyway" dialog; confirm button color is `SbColors.danger`; Cancel keeps the card.
- Decline: field required, confirm disabled until text entered, then submits with reason.
- Approve/Decline buttons are >= 44 px and have Semantics labels.
- roles: owner/manager see tab with badge; specialist: tab absent.
- offline: buttons disabled.
- text scale 2.0 no overflow in card.
- badge increments when the realtime stream (fake) emits a new request (or poll tick in fakeAsync).
Golden: `leave_tab_phone_390.png`, `leave_tab_wide_1280.png` (with a decline panel open in one variant).

## 10. Task checklist

1. Agree tab/badge contract with P-02 owner; confirm `status` query parameter works on time-off (check `status` param in openapi: present).
2. Add missing `sb_ui` widgets (`SbReasonField`, danger confirm, tab badge, `SbSecondaryButton`) with tests.
3. `LeaveRepository` with fan-out, tests (fake Dio, concurrency counter).
4. `PendingLeaveController` and badge provider + tests.
5. `LeaveDecisionController` with conflict/force/decline + tests.
6. `LeaveRequestCard` and `LeaveRequestsTab` UI states; goldens 390 and 1280.
7. Decline panel and approve-anyway dialog.
8. Post-approval "bookings need to be moved" notice and calendar link.
9. Mount in Today behind `Capability.decideLeave`; deep link `/leave`.
10. Refresh strategy (poll fallback, resume, realtime hook).
11. ARB strings; analyzer and tests clean.

## 11. Open questions / API gaps / risks

- Gap 1: no salon-wide pending leave endpoint; fan-out costs 1 + N calls on every refresh and polling multiplies it. Ask backend for `GET /v1/partner/leave?status=pending` and to include a `needs_action` leave item and `pending_leave_count` in `PartnerTodayOut`.
- Gap 2: 409 body for conflicts and the `force` semantics are undocumented; "already decided" and "conflict" are indistinguishable without `code` values. Need error codes.
- Gap 3: `status` values unenumerated (assumed `pending`, `approved`, `declined`, maybe `cancelled`).
- Gap 4: whether specialists may POST time-off, and where their request appears (P-11).
- Gap 5: client notification on force approve unknown; the app shows no promise about it.
- Gap 6: WebSocket event for new leave requests undefined; polling fallback is an interim, DoD real-time test can only use a fake stream.
- `TimeOffItemOut` has no staff title; the title is joined from the staff list (extra data dependency).
- Today stub has no tab scaffolding yet; P-02 plan must expose the extension point or this plan creates a minimal one (risk of merge conflict).
- Days count is a display helper; if reviewers treat it as client-side business logic, request a `days` field.

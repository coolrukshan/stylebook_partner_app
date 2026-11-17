# P-11 Staff detail — Implementation Plan

- Spec: [docs/_specs/P-11_staff_detail.md](../_specs/P-11_staff_detail.md)
- Design: `mobile/P-11_staff_detail.png`, `mobile/P-11_staff_detail_scrolled.png` (header back/avatar/name/title, "Weekly availability", "Copy from" chips, 7 day rows with toggle and Start/End `-`/`+` steppers, "Time off" with amber "+ Add" and red "Remove", Services chips, black "Save availability").

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p11-staff-detail`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies

Edit one person's weekly hours (one PUT replacing the week), see/add time off, pick the services they do, copy hours from a colleague, and (owner) deactivate. Save sends two requests (hours then services) behind one button, so partial failure handling is part of the plan.

Dependencies:
- P-09 (staff models, repository, providers, routes) built first; this plan extends `staff_repository.dart`.
- `GET /v1/partner/services` via the P-08 `ServicesRepository.listServices` (for chips). If P-08 is not built, add a read-only `servicesForPickerProvider` in `features/staff/application` that calls the endpoint directly; later swap to P-08's repository.
- P-12 (leave decisions) for the "Pending" label link (`/leave`, or the Today tab).
- Shell/router/role guard, session (`role`, `staffId`), `ApiError`, `SbFormat.time12`.
- `sb_ui` additions: `SbSwitch` (green on per PNG, uses `successAction`), `SbStepperButton`, `SbConfirmDialog`, `SbReasonField`, `SbDangerButton`, `SbDateRangePicker` wrapper, `SbAvatar`, `SbPill`.

## 2. Files to create / modify

Create under `apps/partner/lib/features/staff/`:
- `data/staff_detail_models.dart` (`StaffDetail`, `StaffServiceRef`, `PutHours`, `CreateTimeOff`, `StaffUpdate`, `DeleteStaff`, `DeleteStaffResult`)
- `application/staff_detail_controller.dart` (`StaffDetailController` family AsyncNotifier, `StaffDetailState`)
- `application/weekly_hours_draft.dart` (pure draft model + step/validation logic)
- `application/time_off_controller.dart`
- `presentation/staff_detail_screen.dart`
- `presentation/weekly_availability_card.dart`, `day_hours_row.dart`, `time_stepper.dart`
- `presentation/copy_from_chips.dart`
- `presentation/time_off_section.dart`, `add_time_off_sheet.dart`
- `presentation/staff_services_chips.dart`
- `presentation/remove_staff_dialog.dart`
- tests: `apps/partner/test/features/staff/detail/**`

Modify:
- `data/staff_repository.dart`: add `detail`, `putHours`, `copyHours`, `updateStaff`, `createTimeOff`, `deleteStaff` (P-09 owns `hours` and `timeOff` reads).
- `apps/partner/lib/router.dart`: `/staff/:id` (route order: `/staff/new` before `/staff/:id`).
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_ui` (widgets above), `packages/sb_core` (`SbFormat.dateRange` "Mon 23 - Wed 25 Nov", `time12`).

## 3. Data layer

Endpoints (partner schema; note two `StaffDetailOut` schemas exist, use the `partner` one):
| Method | Path | Body |
|---|---|---|
| GET | `/v1/partner/staff/{staff_id}` | `StaffDetailOut`: `full_name, title, avatar_url, is_active, services[], hours[], time_off[]` |
| GET | `/v1/partner/staff/{staff_id}/hours` | `StaffScheduleOut` incl. `breaks[]` (use this as hours source of truth, detail may omit breaks) |
| PUT | `/v1/partner/staff/{staff_id}/hours` | `PutHoursIn.hours[]: StaffHoursIn {day_of_week, is_working, start_time, end_time, breaks[]}` — always 7 days |
| POST | `/v1/partner/staff/{staff_id}/hours/copy` | `CopyHoursIn {source_staff_id}` -> `StaffScheduleOut` |
| PUT | `/v1/partner/staff/{staff_id}` | `StaffUpdateIn` — here `service_ids` only (title/name/phone optional later) |
| GET | `/v1/partner/staff/{staff_id}/time-off` | `TimeOffItemOut[]` (`status`, `reason`, `id`) |
| POST | `/v1/partner/staff/{staff_id}/time-off` | `CreateTimeOffIn {start_date, end_date, reason}` |
| DELETE | `/v1/partner/staff/{staff_id}` | `DeleteStaffIn {confirm: true, reason}` -> `DeleteStaffOut.deactivated_at` |
| GET | `/v1/partner/services` | chips |
| GET | `/v1/partner/staff` | "Copy from" chips (others, active) |

No endpoint removes time off (gap 1): "Remove" cannot be implemented; see section 11.

Times are `HH:MM` strings; dates `YYYY-MM-DD` (confirm in schema). Error mapping: `ApiError` with `message` and `field`; 404 -> "Team member not found" state; 409/422 -> message surfaced on the relevant section (hours, time off, services, delete); keep edits.

## 4. Application / state

- `StaffDetailController(staffId) extends AsyncNotifier<StaffDetailState>`: loads detail + hours + time-off in parallel (`Future.wait`). `StaffDetailState {detail, serverHours, draftHours: WeeklyHoursDraft, serverServiceIds, draftServiceIds, timeOff, saving: {hours, services}, errors{hours, services, timeOff}}`.
- `WeeklyHoursDraft`: 7 `DayDraft {dayOfWeek, isWorking, start, end, breaks}` (minutes since midnight ints). Methods: `toggle(day)`, `stepStart(day, ±)`, `stepEnd(day, ±)`, `isValid`, `isDirty(vs server)`. Step = 15 minutes (`kHoursStepMinutes`, proposed by spec). End must be after start: `+` on start disabled when start+step >= end; `-` on end disabled when end-step <= start; also bounds 00:00-23:45. The control at the limit is disabled (acceptance 3).
- Toggling a day on with no previous times: default times from the salon opening hours. Source is undecided (spec AC2). Plan: take the first working day's times of the same person, else of the salon hours from `GET` settings when P-21 lands, else leave start/end empty and require the user to step (start button shows "Set time"). No hard-coded 9-6.
- `save()`: (1) if hours dirty -> PUT hours with all 7 days; (2) if services dirty -> PUT staff `service_ids`. Run sequentially so a hours failure does not silently also change services; report per-part results: both ok -> toast "Availability saved"; one failed -> keep that part's draft dirty, show the API message in its section and a banner "Hours saved, services not saved". Each part uses the response to reset its baseline. Single in-flight guard for double taps.
- `copyFrom(sourceId)`: POST copy; per gap 3 it likely persists immediately. Plan: confirm dialog ("Replace Ishara's weekly hours with Kasun's?") then apply the response `StaffScheduleOut` to BOTH server and draft (it is already saved) and show toast; if the user has unsaved hour edits, the dialog states they will be lost.
- Time off: `TimeOffController` `addTimeOff(range, reason)` POST then prepend returned item (or refetch); 409/422 message displayed in the sheet. Pending rows show "Pending" pill.
- `deactivate(reason)`: DELETE with `confirm=true`; on success invalidate the staff list and pop to `/staff`; on 409 show the API message in the dialog (nothing removed).
- Dirty + discard: `PopScope`; unsaved dot indicator next to the Save button.
- States: loading skeleton (header + 7 row placeholders); error + Retry; offline: read-only (switches/steppers/Save disabled; banner); saving spinner in Save. Real-time: placeholder hook invalidating time-off on a leave-decision event when the realtime provider exists.

## 5. Presentation

Phone (390): `Scaffold` -> `CustomScrollView`: header (`SbGlassIconButton` back, `SbAvatar`, name `headlineSmall`, title muted); section "Weekly availability"; `CopyFromChips` (`SbChoiceChip` per other active staff, tap -> confirm); `WeeklyAvailabilityCard` (`SbCard` with 7 `DayHoursRow`s: day label, summary "10:00 AM - 7:00 PM" or "Day off", `SbSwitch`; when on: Start/End `TimeStepper` (`SbStepperButton -` / value / `+`)); "Time off" header with amber text button "+ Add"; time-off rows in `SbCard`: "Mon 23 - Wed 25 Nov · reason", status pill for pending (tapping goes to P-12), "Remove" (red text) shown only if/when delete endpoint exists; "Services" `Wrap` of `SbChoiceChip` (selected amber) from salon services, grouped optionally by `category_name`; bottom sticky `SbPrimaryButton` "Save availability" (`SafeArea`, shows spinner). Owner-only text button "Remove from team" (danger tone) at the bottom.

Wide (>= 900): two columns in `Row`: left `Expanded(flex: 3)` availability card; right `Expanded(flex: 2)` time off + services; Save pill top-right in the page header. Breaks: proposed per-day "+ Add break" row (spec gap 2) rendered as a small start/end stepper pair under the day; behind a `kEnableBreaks` constant until design approves, but data model keeps `breaks` so a PUT never wipes existing breaks (round-trip them unchanged).

Tokens only; no hard-coded sizes. All icon buttons have Semantics labels including the day: "Increase start time, Monday". Targets >= 44 px; layout scrolls at 200% text.

## 6. Role rules

- Owner and manager: edit everything except deactivate (owner only).
- Specialist: view own hours only (`id == session.staffId`), no switches/steppers/Save; may request time off via POST time-off (gap 4; show "+ Add" only if PM confirms) — default hidden.
- Enforcement: `Capability.editStaff` (owner, manager), `Capability.deactivateStaff` (owner), `Capability.viewOwnStaff` (specialist with matching id). Route redirect for other staff ids; controls gated; `readOnly` flag threaded through `StaffDetailScreen` to rows. API 403 shown as a message.

## 7. Validation, confirmations, formatting

- End after start (disabled steppers, plus `isValid` check on Save, button disabled with reason tooltip text if invalid).
- Working day requires both times.
- Deactivate: `SbConfirmDialog` with required `SbReasonField` ("Remove from team" confirm button `danger`, enabled when reason non-empty); sends `{confirm: true, reason}`; message from API on 409 (future bookings).
- Copy-from: confirm (not destructive-red; black confirm) since it replaces the week.
- Hours or services changes may affect bookings: surface API 409/warning text, never assume.
- Times `10:00 AM` via `SbFormat.time12`; dates `Mon 23 - Wed 25 Nov`; salon time zone only affects labels (no computation).
- Time-off range: `showDateRangePicker` themed from `SbTheme`; start <= end; no past dates when API restricts (let API 422 decide).

## 8. ARB keys

`staffDetailTitle`, `staffWeeklyAvailability`, `staffCopyFrom`, `staffCopyConfirmTitle`, `staffCopyConfirmBody` (placeholders `target`, `source`), `staffCopyDone`, `staffDayOff`, `staffStart`, `staffEnd`, `staffSetTime`, `staffIncreaseStart` (placeholder `day`), `staffDecreaseStart`, `staffIncreaseEnd`, `staffDecreaseEnd`, `staffToggleDay` (placeholder `day`), `staffDayMon`..`staffDaySun`, `staffTimeOff`, `staffTimeOffAdd`, `staffTimeOffEmpty`, `staffTimeOffRemove`, `staffTimeOffPending`, `staffTimeOffReasonHint`, `staffTimeOffDates`, `staffTimeOffSaveBtn`, `staffTimeOffAdded`, `staffServices`, `staffServicesEmpty`, `staffSaveAvailability`, `staffSaved` ("Availability saved"), `staffPartialSave` (placeholders `saved`, `failed`), `staffUnsavedDot`, `staffDiscardTitle`, `staffDiscardBody`, `staffRemoveFromTeam`, `staffRemoveTitle`, `staffRemoveBody`, `staffRemoveReason`, `staffRemoveConfirm`, `staffRemoved`, `staffReadOnlyNote`, `staffNotFound`, `staffLoadError`, `staffOfflineReadOnly`, `commonRetry`, `commonCancel`.

## 9. Tests

Unit:
- `weekly_hours_draft_test`: step by 15; start cannot reach end; end cannot go below start; clamp bounds; toggle off keeps previous times; toggle on without times -> unset until stepped; `isDirty` after revert false; `toPutPayload` always has 7 entries ordered 0..6 with `breaks` preserved; non-working days omit times.
- `staff_detail_controller_test`: load parallel; save hours only; save services only; both success; hours ok + services fail -> partial state and message; hours fail -> services not attempted; double save sends one; copy replaces server+draft; deactivate success/409.
- `staff_repository_detail_test`: payload shapes (`PutHoursIn`, `CopyHoursIn`, `StaffUpdateIn.service_ids`, `DeleteStaffIn`, `CreateTimeOffIn` date format), 409/422 mapping.
- `format_date_range_test`: same-month and cross-month ("Sat 28 Nov - Tue 1 Dec").

Widget:
- renders 7 rows from data; off day shows "Day off" and hides steppers (match PNG).
- `-`/`+` disabled at limits; Semantics labels include the day.
- save button: spinner during save, success toast, failure keeps edits and shows message.
- service chip toggling updates draft; Save payload has full list.
- time-off sheet: 409 message displayed; pending row shows Pending label.
- deactivate dialog: confirm disabled until reason; button uses `SbColors.danger`; hidden for manager.
- roles: owner/manager edit; specialist own = read-only; specialist other id redirected.
- discard dialog on back when dirty.
- offline: controls disabled.
- text scale 2.0 no overflow in a day row.
Golden: `staff_detail_phone_390.png` (compare with the PNG, plus scrolled variant), `staff_detail_wide_1280.png`.

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p11-staff-detail`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. `sb_ui` additions (`SbSwitch`, `SbStepperButton`, `SbReasonField`, `SbConfirmDialog` danger variant, `SbAvatar`, `SbPill`) with tests.
2. `SbFormat.time12`, `dateRange` + tests.
3. Models, repository additions, repository tests.
4. `WeeklyHoursDraft` + exhaustive unit tests (pure Dart, verify first).
5. `StaffDetailController` load/save/copy/deactivate + tests.
6. Phone screen: header, availability card, services chips, Save; golden 390 (and scrolled).
7. Time-off section and add sheet (no remove until API).
8. Deactivate flow (owner only).
9. Wide two-column layout; golden 1280.
10. Role gating, route, discard guard, offline read-only.
11. ARB strings; analyzer and tests clean.

## 11. Open questions / API gaps / risks

- Gap 1: no time-off cancel/remove endpoint. "Remove" in the PNG cannot work. Options: hide the button; ask backend for `DELETE /v1/partner/staff/{id}/time-off/{id}`; or use P-12 decide with `declined`/cancel (not equivalent). Plan hides Remove.
- Gap 2: breaks have no design. Plan preserves breaks on round-trip and ships the editor off by default.
- Gap 3: `/hours/copy` persistence and break overwrite unconfirmed; plan assumes persisted immediately.
- Gap 4: time-off initial status (pending vs approved) and status values undocumented; specialist submission permission unknown.
- Gap 5: two `StaffDetailOut` schemas; confirm the partner one is returned for this path.
- Gap 7: no avatar upload endpoint.
- Gap 8: two-request save is not atomic; risk of partial state covered above.
- Default times when enabling a day (spec AC2) need PM decision; salon hours endpoint belongs to P-21.
- Specialist `staffId` claim in session unknown.
- Hours changes can invalidate existing bookings; API warnings format unknown (409 body).

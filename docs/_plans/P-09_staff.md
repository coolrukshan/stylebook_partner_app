# P-09 Staff — Implementation Plan

- Spec: [docs/_specs/P-09_staff.md](../_specs/P-09_staff.md)
- Design: `mobile/P-09_staff.png` (title "Staff", amber "+ Add staff" top-right, white cards: avatar initials, name, "title · hours", status pill).

## 1. Summary and dependencies

Staff tab: paged list of active team members with avatar, name, title, today's hours and a status pill (With client, Free, On leave, Day off), entry points to P-11 (detail) and P-10 (add). This plan OWNS the shared staff data layer (`features/staff/data/staff_repository.dart`, models, providers) that P-10, P-11 and P-12 extend.

Dependencies:
- Shell (floating nav with Staff item at >= phone, sidebar >= 900 px), router, role guard, session (`role`, `salonId`), Dio + `ApiError`.
- P-02 Today provider: `PartnerTodayOut.in_chair[]` and `time_zone` (reuse `todayProvider` from `features/today`; today only `today_screen.dart` exists with no data layer, so P-02 data layer is a prerequisite, or add a minimal `GET /v1/partner/today` read here that P-02 later adopts. Agree owner with the P-02 plan).
- `sb_ui`: page header, avatar, status pill variant, skeleton, empty/error panels (additions below).
- Build order: P-09 first of the staff group, then P-11, P-10, P-12.

## 2. Files to create / modify

Create under `apps/partner/lib/features/staff/`:
- `data/staff_models.dart` (freezed: `StaffListItem`, `StaffList`, `StaffHours`, `StaffBreak`, `StaffSchedule`, `TimeOffItem`; P-11/P-10 add `StaffDetail`, `StaffCreated`, etc. in the same file or sibling `staff_detail_models.dart`)
- `data/staff_repository.dart` (`list`, `hours`, `timeOff`; P-10/P-11 append methods)
- `application/staff_providers.dart` (`staffRepositoryProvider`, `staffListControllerProvider`, `staffTodayInfoProvider` family, `StaffTodayStatus` enum)
- `application/staff_status.dart` (pure function mapping API data to status, see section 4)
- `presentation/staff_screen.dart`
- `presentation/staff_card.dart`
- `presentation/staff_status_pill.dart` (maps enum -> `SbPill` variant; or add to sb_ui)
- tests: `apps/partner/test/features/staff/**`

Modify:
- `apps/partner/lib/router.dart`: `/staff` (shell tab), `/staff/new` (P-10), `/staff/:id` (P-11); `/staff` redirect for specialist (see section 6).
- Shell nav items: Staff tab (index 2 in phone floating nav per instructions: Today, Calendar, Staff, Gallery, More).
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_ui`: `SbAvatar` (initials fallback), `SbPill` (generic status pill with label + tone; `SbStatusPill` is booking-status only), `SbPageHeader` (title 27/600 + trailing action), `SbSkeleton`, `SbEmptyState`, `SbErrorPanel`.
- `packages/sb_core`: `SbFormat.time12(String hhmm)` ("9:00 AM"), `ApiError` with `retryAfter` for 429.

## 3. Data layer

Endpoints:
| Method | Path | Use |
|---|---|---|
| GET | `/v1/partner/staff` | `active_only`, `cursor`, `limit` -> `StaffListOut {items: StaffListItemOut, next_cursor}` |
| GET | `/v1/partner/staff/{staff_id}/hours` | `StaffScheduleOut.hours[]` (`day_of_week` 0=Mon, `start_time`, `end_time`, `is_working`, `breaks[]`) |
| GET | `/v1/partner/staff/{staff_id}/time-off` | query `status`, `from_date`, `to_date` -> `TimeOffItemOut[]` |
| GET | `/v1/partner/today` | `in_chair[]`, `time_zone` (read through the Today repository) |

Note: `StaffListItemOut` fields are `id, full_name, title, avatar_url, rating, review_count, is_active, service_count, upcoming_bookings_today` (no status, hours or role).

Repository methods: `Future<StaffList> list({bool activeOnly = true, String? cursor, int limit = 50})`, `Future<StaffSchedule> hours(String staffId)`, `Future<List<TimeOffItem>> timeOff(String staffId, {String? status, DateTime? from, DateTime? to})`.

Check in the schema whether `GET .../time-off` returns a bare array or an envelope before modelling.

Error mapping: `ApiError`; 429 carries `Retry-After` header -> `ApiError.retryAfter`; 404/409/422/500 -> message + Retry. Per-row hours/time-off failures are swallowed into "no hours / no status" (spec 7), never failing the screen.

## 4. Application / state

- `StaffListController extends AsyncNotifier<StaffListState>` with `{items, nextCursor, loadingMore}`; `build()` loads page 1 with `active_only=true` (explicit param, since the default is unconfirmed); `loadMore()` follows `next_cursor`; `refresh()`.
- Per-row lazy info (stop-gap for G1): `staffTodayInfoProvider(staffId)` is a `FutureProvider.family` that, only when its card is built, fetches `hours(staffId)` and `timeOff(staffId, from=today, to=today)` in parallel (`Future.wait`), caches via `keepAlive` for 5 minutes and invalidates on refresh. Concurrency cap: use a small shared semaphore (4 in flight) to avoid 429 on long lists.
- Today in salon time zone: `todayInSalonTzProvider` derives the date and weekday index from `PartnerTodayOut.time_zone` (use `timezone` package or compare via the API's `now` timestamp if present). This is for picking which `hours[]` entry applies, not availability computation; flag this in review.
- Status resolution `resolveStaffStatus({inChairIds, schedule, timeOff, today})` (pure, unit tested), priority per spec: in_chair -> `withClient`; approved time-off covering today -> `onLeave`; `is_working == false` today -> `dayOff`; otherwise `free`. Unknown (data not loaded) -> no pill (skeleton chip), never "Free" by default.
- When the API later adds `today_status`, `today_start_time`, `today_end_time` (spec gap 1), `staffTodayInfoProvider` is replaced by reading them from `StaffListItem`; keep the status widget input as a simple `StaffRowInfo` value type so only the provider changes.
- Real-time: placeholder `staffListControllerProvider` invalidation hook from the shared realtime provider; no event names in OpenAPI, so none wired now.
- States: loading skeleton cards; empty "No team members yet" + black "Add staff" (owner/manager); error + Retry (429 shows "Try again in N s"); offline: banner, cached list deferred (drift not set up), actions disabled via connectivity provider if present.

## 5. Presentation

Phone: `SbPageHeader(title: Staff, trailing: amber text action "+ Add staff")` -> `RefreshIndicator` -> `ListView.separated` of `StaffCard`. Floating nav shows Staff selected (shell). Wide (>= 900): same content in the shell content area as a `LayoutBuilder` grid (2 columns at 900-1279, 3 at >= 1280; `SliverGrid` with fixed `crossAxisCount`), "+ Add staff" becomes `SbPrimaryButton(expand: false)` black pill top-right.

`StaffCard` (`SbCard`, onTap -> `context.push('/staff/${id}')`, min height 44): `SbAvatar` (network image via `avatar_url`, initials fallback), name (`titleMedium`), `"Sr. Barber · 9:00 AM - 6:00 PM"` (muted; omit the hours part while loading/failed), trailing `StaffStatusPill` with text always visible. Pill tones: With client = amber (`SbColors.amberTint`/`amberDark`), Free = `successBg`/`success`, On leave = `soft`/`muted`, Day off = `soft`/`muted`. Tokens only.

Semantics: card `Semantics(button: true, label: "name, title, status")`; "+ Add staff" has a label.

## 6. Role rules

- Owner: view, add, open detail, deactivate (in P-11). Manager: view, add (provisional, gap 4), open detail. Specialist: no Staff tab; own detail only if PM agrees.
- Implement `Capability.viewStaff` (owner, manager), `Capability.addStaff` (owner, manager provisional), `Capability.viewOwnStaffDetail` (specialist). Nav builder hides the Staff tab for specialist; `/staff` route redirect to `/`; `/staff/:id` allowed for a specialist only when `id == session.staffId` (needs the session to carry the specialist's staff id; confirm claim). "+ Add staff" and empty-state Add hidden without `addStaff`.
- API still enforces; 403 shown in the error panel.

## 7. Validation, confirmations, formatting

- No destructive actions here.
- Times `9:00 AM - 6:00 PM` via `SbFormat.time12`; salon time zone for "today".
- Pull-to-refresh; list rows at least 44 px high; pill never colour-only.
- 429: show Retry with the `Retry-After` hint.

## 8. ARB keys

`staffTitle`, `staffAdd`, `staffEmptyTitle`, `staffEmptyBody`, `staffStatusWithClient`, `staffStatusFree`, `staffStatusOnLeave`, `staffStatusDayOff`, `staffTitleHours` (placeholders `title`, `hours`), `staffNoHours`, `staffLoadError`, `staffRateLimited` (placeholder `seconds`), `staffOfflineBanner`, `staffCardSemantics` (placeholders `name`, `title`, `status`), `staffAddSemantics`, `commonRetry`.

## 9. Tests

Unit:
- `staff_status_test`: in_chair beats leave; approved leave covering today -> onLeave; pending/declined leave ignored; `is_working=false` -> dayOff; working and nothing else -> free; missing data -> unknown; leave range boundaries inclusive (start == today, end == today).
- `staff_repository_test`: list passes `active_only=true` and cursor; parses `next_cursor`; hours parse breaks; 429 retry-after mapping.
- `staff_list_controller_test`: paging append, stop at null cursor, refresh resets.
- `staff_today_info_provider_test`: failure of hours or time-off yields partial info without throwing; concurrency cap respected.
- `sb_format_time12_test`: "09:00" -> "9:00 AM", "18:00" -> "6:00 PM", "00:30" -> "12:30 AM".

Widget:
- loading skeleton, list with pills, empty (owner sees Add, specialist does not), error with Retry, 429 message.
- card tap navigates to `/staff/:id` (use a `GoRouter` test harness); "+ Add staff" navigates to `/staff/new`.
- roles: specialist -> no Add, tab hidden, redirect from `/staff`.
- pill text present for each status (find.text).
- text scale 2.0 no overflow.
Golden: `staff_phone_390.png` (compare with PNG: 4 cards), `staff_wide_1280.png` (grid).

## 10. Task checklist

1. Add `sb_ui` widgets (`SbAvatar`, `SbPill`, `SbPageHeader`, `SbSkeleton`, `SbEmptyState`, `SbErrorPanel`) with widget tests and exports.
2. `SbFormat.time12`, `ApiError.retryAfter` in `sb_core` with tests.
3. Models + repository + tests (`flutter test test/features/staff/data`).
4. `StaffListController`, status resolver, per-row info provider + unit tests.
5. `StaffCard`, `StaffScreen` phone layout; widget tests; golden 390.
6. Wide grid layout; golden 1280.
7. Route entries, nav item, role gating and redirects.
8. ARB strings, analyzer and tests clean.

## 11. Open questions / API gaps / risks

- Gap 1: no today status/hours/leave on list item. N+1 stop-gap costs up to 2 extra calls per card (hours + time-off) plus one Today call; with 20+ staff risk of 429. Ask backend for `today_status`, `today_start_time`, `today_end_time`.
- Gap 2: no role field; `title` is free text. Manager/specialist cannot be distinguished in the list.
- Gap 3: WebSocket channel and events unspecified; real-time requirement of the DoD cannot be tested yet.
- Gap 4: manager "Add staff" permission unconfirmed.
- `active_only` default unknown; plan sends `true` explicitly. Inactive staff list view is not in scope.
- P-02 data layer ownership (`/v1/partner/today`) must be agreed to avoid duplicate providers.
- Salon time-zone handling needs a tz library or the API's server time; confirm `PartnerTodayOut` includes a current timestamp.
- Specialist own-detail needs `staffId` in session claims (not documented).

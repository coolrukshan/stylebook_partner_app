# P-02 Today — Implementation Plan
- Spec: [docs/_specs/P-02_today.md](../_specs/P-02_today.md)
- PNGs: `mobile/P-02_today.png`, `P-02_today_scrolled.png`, `P-02_today_decline_reason.png`

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p02-today`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies
Home screen: stats, "Needs your OK" request cards (accept / decline with reason), "In the chair now", "Up next". Phone layout is built to the PNG; web/tablet gets the five-stat row and right column with what the API supports.
Depends on: P-01 (session, role, salon context, Dio interceptors, `SbFormat`, l10n). Shares booking-action plumbing with P-04 (`BookingActionsRepository`); P-02 owns the adaptive shell (sidebar >= 900 px, floating nav on phone) because it is the first screen that needs it.
- Shared pieces created here: `shell/` (adaptive scaffold, role-aware nav), `sb_ui` `SbStatCard`, `SbSecondaryButton` (white pill), `SbDangerButton`, `SbCountPill`, `SbSectionHeader`, `SbSkeleton`, `SbEmptyState`, `SbAvatar` (initials), `SbReasonChips`, `SbTabs`, `showSbSheet()` (style guide §5, if not yet added), amber-tint variant of `SbChoiceChip`.
- Existing code: `features/today/presentation/today_screen.dart` is a scaffold placeholder; `sb_ui` already has `SbCard`, `SbStatusPill`, `SbPrimaryButton`, `SbChoiceChip` (selected=ink, PNG decline chips need amber tint), `SbFloatingNav`/`SbNavItem`, `SbHomeHeader` (client style, not used here).

## 2. Files to create / modify
- `apps/partner/lib/shell/partner_shell.dart` (uses `LayoutBuilder`; >= 900 -> `SbSidebar`, else `SbFloatingNav`), `shell/nav_destinations.dart` (id, label key, icon, `allowedRoles`), `shell/role_guard.dart` (if P-01 did not already create it)
- `apps/partner/lib/router.dart` (modify: `StatefulShellRoute.indexedStack` with `/today`, `/calendar`, `/staff`, `/gallery`, `/more`; `/` redirects to `/today`)
- `apps/partner/lib/features/today/data/today_repository.dart`, `models/today_models.dart` (freezed: `PartnerToday`, `TodayStats`, `NeedsActionItem`, `InChairItem`, `UpNextItem`, `TodayServiceItem`)
- `apps/partner/lib/features/booking_detail/data/booking_actions_repository.dart` (shared with P-04; method `perform(bookingId, BookingAction action, {String? reason})`), `models/booking_action.dart` (enum -> wire strings in ONE place)
- `apps/partner/lib/features/today/application/today_controller.dart` (`TodayController extends AsyncNotifier<TodayState>`), `request_card_controller.dart` (per-card family: `idle|accepting|decliningOpen|declining|error`), `realtime_provider.dart` (poll fallback; WS stub), `today_cache.dart` (drift-ready interface, in-memory impl first)
- `apps/partner/lib/features/today/presentation/today_screen.dart` (rewrite), `widgets/{today_header,stat_row,needs_ok_section,request_card,decline_panel,in_chair_section,up_next_section,today_skeleton,tablet_right_column}.dart`
- `packages/sb_ui/lib/widgets/*` (new components above; export in `sb_ui.dart`)
- `apps/partner/lib/l10n/app_en.arb` (append keys)

## 3. Data layer
- GET `/v1/partner/today?date=YYYY-MM-DD&staff_id=<uuid>` with `X-Salon-Id` -> `PartnerTodayOut{date, time_zone, needs_action[], in_chair[], up_next[], stats}`; `PartnerTodayStats{total_bookings_today, completed_today, revenue_today_cents, cancellations_today, no_shows_today, walk_ins_today}`. `staff_id` sent only when role is specialist (own id).
- POST `/v1/partner/bookings/{booking_id}/{action}` -> `BookingDetailOut`. No body is defined, so a decline reason cannot be transmitted today (Gap 1). Wire values live in `BookingAction.wire` (assumed `accept`, `decline`, `check_in`, `start`, `complete`; `no_show` in P-05) and can be corrected in one place. Decline: send `reason` as a JSON body `{reason}` ONLY once the contract is confirmed; until then the reason UI is built but the repository sends the action without a body and logs a TODO flag `kDeclineReasonSupported = false` (decide with PM whether to ship decline disabled).
- Leave tab and dispute card: deferred (no list source, Gap 4/7); the tab widget is not rendered until P-12/P-04 provide data.
- Error mapping (via P-01 `ApiError`): 404/409 on action -> remove the card, snackbar with `message`, refetch; 422 -> inline on reason field; 429 -> snackbar with backoff; 403 -> snackbar and refetch (role changed); offline -> disabled actions.
- Idempotency: key generated per card action attempt and reused on retry of the same attempt (the interceptor accepts a caller key via `extra`).

## 4. Application / state
- `todayControllerProvider` = `AsyncNotifierProvider<TodayController, TodayState>`; `TodayState{PartnerToday data, DateTime fetchedAt, bool isStale, Object? refreshError}`.
- `build()` watches `sessionProvider` (role, staffId) and `sessionEpoch`; fetch once (AC 1). `refresh()` for pull-to-refresh keeps previous data (`AsyncValue.copyWithPrevious`); failures set `refreshError`, stale data stays with a retry banner.
- Derived selectors (no money maths): `needsCount = data.needsAction.length`, `inChairCount = inChair.length`, `stillToCome = upNext.length` (approximation, flagged Gap 2; stat card hides if backend later supplies the field). Reschedule vs request distinction: not representable (Gap 3); all `needs_action` items render as booking requests.
- Optimistic updates: Accept -> mark card `accepting`, on 200 remove from `needsAction`, show nothing optimistic about stats; then silent refetch to reconcile (also moves booking into `up_next`). Check in/Start/Complete on in_chair rows: update row status from the returned `BookingDetailOut.status`, then refetch. Rollback on error = restore state + snackbar.
- Real-time: `todayRealtimeProvider` currently = `Timer.periodic(60s)` refetch while the screen is visible (`WidgetsBindingObserver` / `RouteAware`), pausing in background. WebSocket client behind an interface `TodayEventSource` with a no-op impl until endpoint/schema exist (Gap 6); AC 9 cannot be satisfied or tested on a real socket yet, so a fake `TodayEventSource` drives the widget test.
- Expiry: a 1-minute ticker `nowProvider` marks cards with `expires_at < now` as "Expired" and hides them after the next refetch (API decides).
- Offline: `TodayCache` stores last successful JSON + `fetchedAt`; on network error build() returns cached with `isStale=true` and banner "Offline, last updated 9:05 AM"; all action buttons disabled.

## 5. Presentation
Phone (to PNG)
`PartnerShell` -> `TodayScreen` -> `RefreshIndicator` -> `CustomScrollView`
1. `TodayHeader`: eyebrow "{salon} . {area}" (area unavailable -> salon name only, Gap 9), date title `headlineMedium` from `data.date` formatted in `time_zone`, `SbAvatar` initials top right.
2. `StatRow`: 3 `SbStatCard` (Bookings=`total_bookings_today`, Still to come, Needs your OK with `highlight: needsCount > 0` -> amber border/tint tokens).
3. `NeedsOkSection`: `SbSectionHeader("Needs your OK", trailing SbCountPill, caption)`; empty -> `SbEmptyState("Nothing needs your OK")`; list of `RequestCard`.
4. `RequestCard` (`SbCard`): left column date label (amber "Today", muted otherwise) + time; right column client name, tag (`SbStatusPill`-style tag: Returning / New client via `is_returning_client`), "service . staff . duration" joined from `services[]`, meta line (created_at relative; payment text omitted, Gap 5), "Booked for X", home badge when `location_type` is home, expiry hint when near. Buttons: `SbPrimaryButton(Accept)` + `SbSecondaryButton(Decline)` (hidden for specialist).
5. `DeclinePanel` (expands in place via `AnimatedSize`): label, `SbReasonChips` (Fully booked, Specialist unavailable, Service not offered, Other; selected = amber tint), "Other" shows `SbTextField` (required), `SbDangerButton("Confirm decline")` disabled until valid, `SbSecondaryButton("Back")`.
6. `InChairSection`: row with `SbAvatar`, "service . staff . until {end_time_utc in tz}", `SbPrimaryButton` small: Start if status `checked_in`, Complete if `in_service` (AC 6).
7. `UpNextSection`: time, client, "service . staff", `SbStatusPill`, "Calendar" `SbTextLink` -> `/calendar`. Tap row opens P-04 sheet.
Loading: `TodaySkeleton` (SbSkeleton stat cards + 2 card placeholders). Error (no data): full-width `SbErrorBanner` + Retry. Empty (zero bookings, zero lists): `SbEmptyState("No bookings today")` + New booking pill (owner/manager).
Web/tablet (>= 900): sidebar shell, top row title + `+ New booking` black pill (opens P-06 dialog), five stat cards in one row (Bookings, Needs your OK amber, Still to come, In the chair=`in_chair.length`, Completed=`completed_today`), two columns: left "Needs your action" (`SbTabs`: Booking requests only until leave/reschedule data exists), in chair, arriving next; right column: earnings (`revenue_today_cents` via `SbFormat.money`), schedule/stock summaries omitted (no source; Gap 7).
Status text: `SbStatusPill` currently has hard-coded English labels ('Waiting for salon', 'Declined by salon'); the partner wording is Requested/Declined, so add an optional `label` override or a partner label map in sb_ui plus ARB, not a feature hack.

## 6. Role rules
| Item | Owner | Manager | Specialist |
|---|---|---|---|
| Data scope | whole salon | whole salon | `staff_id` = own id sent |
| Accept/Decline | yes | yes | hidden unless manager rights (claim TBD, Gap Q in P-01) |
| Check in/Start/Complete | yes | yes | own bookings |
| New booking pill | yes | yes | hidden unless rights |
| Leave tab | yes | yes | hidden |
Enforcement: `ref.watch(roleProvider)` and a `can(Permission.acceptBookings)` helper in `sb_core` (`Permission` derived from `Role` + manager-rights flag). Widgets do not hide anything based on `allowed_actions` here, since Today items carry only status; rely on status mapping and API 403.

## 7. Validation, confirmations, formatting
- Decline: confirm button disabled until a chip is selected; "Other" needs non-empty trimmed text (max length 200 as local UX limit, confirm with API); danger button; Accept has no confirm.
- Money `SbFormat.money(cents)` only for display of `revenue_today_cents`, `total_cents`. Dates: label "Today 4:00 PM" when same day in salon tz else `Tue 27 Oct, 10:30 AM`; "25 min ago" relative from `created_at`. Convert with `time_zone`, not device zone.
- Double-tap guard: card controller state `accepting` disables both buttons.

## 8. ARB keys
`todayTitle`, `statBookings`, `statStillToCome`, `statNeedsOk`, `statInChair`, `statCompleted`, `needsOkTitle`, `needsOkCaption`, `needsOkEmpty`, `needsActionTitle`, `tabBookingRequests`, `tabReschedule`, `tabStaffLeave`, `accept`, `decline`, `confirmDecline`, `back`, `declineReasonLabel`, `reasonFullyBooked`, `reasonSpecialistUnavailable`, `reasonServiceNotOffered`, `reasonOther`, `reasonOtherHint`, `tagReturning`, `tagNewClient`, `tagReschedule`, `bookedFor` (`name`), `homeVisit`, `minutesAgo` (`n`), `expiresIn` (`time`), `expired`, `inChairTitle`, `untilTime` (`time`), `start`, `complete`, `checkIn`, `upNextTitle`, `calendarLink`, `emptyToday`, `newBooking`, `offlineLastUpdated` (`time`), `retry`, `actionConflict`, `earningsToday`, `semAvatar`, `semNavToday`.

## 9. Tests
Unit
- `PartnerToday.fromJson` with fixture of full response and missing optional fields.
- `TodayController`: initial load calls repo once; specialist passes own `staff_id`; refresh keeps previous on error; 409 on accept removes card and surfaces message; accept success removes card; expiry hides card after tick.
- `BookingAction.wire` mapping table test (single source of truth).
- Date label helper: Today vs other day in `Asia/Colombo` with device tz UTC.
Widget
- Loading -> skeleton; error w/o data -> banner + Retry calls repo; error with data keeps data + banner.
- Needs OK non-empty: count pill, amber stat card; empty: "Nothing needs your OK", neutral card.
- Accept button shows progress and fires one call on double tap.
- Decline flow: open panel, confirm disabled, pick chip enables, "Other" requires text, Back collapses, confirm uses danger style (find `SbDangerButton`).
- In chair: `checked_in` shows Start, `in_service` shows Complete, tap calls action once.
- Role matrix (owner/manager/specialist): Accept/Decline presence, New booking pill presence, leave tab absence.
- Pull to refresh refetches. Offline cached banner disables actions. Fake `TodayEventSource` event adds new request at top without refresh.
- Semantics: avatar/nav buttons labelled; tap targets >= 44 (`tester.getSize`).
- Text scale 2.0 at 390 px, no overflow.
Golden: `today_390.png` (populated), `today_decline_390.png`, `today_1280.png`.

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p02-today`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. `sb_ui` components with widget tests (`SbStatCard`, buttons, `SbReasonChips`, `SbSkeleton`, `SbEmptyState`, `SbCountPill`, `SbAvatar`, `SbSectionHeader`, `showSbSheet`) and amber-tint chip variant.
2. Shell + router restructure (phone nav + sidebar) with tests of breakpoint 899/900.
3. Models + `TodayRepository` + fixtures + tests.
4. `BookingActionsRepository` + `BookingAction` enum (shared with P-04).
5. `TodayController` + request-card controller + cache + poll/ticker + tests.
6. Phone layout widgets against PNG; loading/empty/error states.
7. Decline panel and danger confirm; gate on `kDeclineReasonSupported`.
8. In-chair actions; up-next rows -> open P-04 route (stub until P-04).
9. Tablet layout (stats row, tabs, right column).
10. Role matrix tests, offline test, realtime fake test, goldens 390/1280, analyze + test.

## 11. Open questions / API gaps / risks
- Gap 1 (blocker for decline reason): action endpoint undocumented (values, body). Decide with PM whether decline ships without reason; reason is mandatory by project rules.
- Gap 2: no "still to come" or "in chair" counts; derived from arrays, and `up_next` may be limited to 2 hours so "Still to come" may undercount. Request explicit stats.
- Gap 3: reschedule requests and "Move it" are not in the API; the reschedule card and tab are not built.
- Gap 4/7: no pending-leave list, no disputes on Today, no schedule/stock sources; tablet right column limited to earnings.
- Gap 5: no payment mode on cards; meta line shows only relative time.
- Gap 6: no WebSocket contract; DoD "new request appears without refresh" met only via 60 s polling.
- Gap 8/9: confirm `services[].staff_name` is the assignee; no salon area/profile endpoint (only `/v1/partner/settings` name; may be owner-only).
- Specialist "own staff id" source (see P-01 Gap 2).
- Stale `needs_action` after `expires_at`: API may still return it; accept returns 409, handled.

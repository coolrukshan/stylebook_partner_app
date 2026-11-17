# P-03 Calendar — Implementation Plan
- Spec: [docs/_specs/P-03_calendar.md](../_specs/P-03_calendar.md)
- PNGs: `mobile/P-03_calendar.png`, `mobile/P-03_calendar_other_day.png`

## 1. Summary and dependencies
Phone: week day-strip, staff chips, agenda list for the selected day, FAB. Web/tablet: Day view (column per specialist, time grid, now line), Week view, List view, date navigation. Tapping a booking opens P-04; FAB / "+ New booking" opens P-06.
Depends on: P-01 (session, role, `SbFormat`, interceptors), P-02 (shell, `SbSkeleton`, `SbEmptyState`, `SbErrorBanner`, `SbSecondaryButton`, `SbAvatar`, `showSbSheet`, partner status labels). Consumed by: P-04 (opened with a `CalendarBookingOut` summary), P-05 (drag-to-move later), P-06 (prefill date/time/staff).
- Existing `sb_ui`: `SbDateChip` (round date chip, selected=ink), `SbChoiceChip` (ink when selected = matches PNG staff chips), `SbStatusPill`, `SbFloatingNav`. Status card colours come from `SbTokens.status(SbStatus)`; PNG shows green/peach/yellow/blue tints which map to Completed / In service+Checked in / Requested / Confirmed.

## 2. Files to create / modify
- `apps/partner/lib/features/calendar/data/calendar_repository.dart`, `models/calendar_models.dart` (freezed: `PartnerCalendar`, `StaffSchedule`, `CalendarDay`, `WorkingHours`, `CalendarBreak`, `TimeOffInfo`, `CalendarBooking`)
- `apps/partner/lib/features/calendar/application/calendar_controller.dart` (`CalendarController extends AsyncNotifier<CalendarState>` keyed by range via a `CalendarQuery` provider), `calendar_selection.dart` (selected date, view, staff filter: `Notifier<CalendarSelection>`), `calendar_realtime.dart` (60 s refetch + event-source interface), `calendar_cache.dart`
- `apps/partner/lib/features/calendar/presentation/calendar_screen.dart` (adaptive switch), `phone/calendar_phone_view.dart`, `phone/day_strip.dart`, `phone/agenda_list.dart`, `tablet/calendar_toolbar.dart`, `tablet/day_grid_view.dart`, `tablet/week_view.dart`, `tablet/list_view_table.dart`, `widgets/{staff_chips,booking_card,off_block,now_line,calendar_skeleton}.dart`
- `apps/partner/lib/router.dart` (add `/calendar` branch; booking opens `/calendar?booking=<id>` or a sheet route owned by P-04)
- `packages/sb_ui/lib/widgets/sb_booking_tile.dart` (status-tinted card), `sb_fab.dart` (black round button 56, Semantics label), `sb_week_strip.dart` (7 `SbDateChip`)
- `apps/partner/pubspec.yaml`: add `data_table_2` (list view, web only); decide on `syncfusion_flutter_calendar` vs custom grid (recommend CUSTOM grid: avoids license, we only draw bookings from API and no drag until P-05 endpoint exists)
- `apps/partner/lib/l10n/app_en.arb`

## 3. Data layer
- GET `/v1/partner/calendar` query `from` (date, required), `to` (date, required), `staff` (uuid, repeated), `view` (`day|week|list`) + `X-Salon-Id` -> `PartnerCalendarOut{from, to, view, staff_schedules[]}`; `CalendarStaffScheduleOut{staff_id, staff_name, days[]}`; `CalendarDayOut{date, is_working, working_hours{start,end}, breaks[{start,end}], time_off{reason}, bookings[]}`; `CalendarBookingOut{id, status, client_name, start_time, end_time, services[] (strings), location_type, notes}`.
- Dio repeated array: `queryParameters: {'staff': [..]}` with `ListFormat.multi`.
- Staff chips: from the unfiltered response's `staff_schedules` (cached in `staffRosterProvider`) so chips stay visible when filtered; fallback GET `/v1/partner/staff` (`StaffListItemOut`) only if the day is empty and roster unknown.
- Time parsing is ambiguous (Gap 3): write `CalendarTime.parse(String, tz)` that accepts ISO-8601 with offset/Z (UTC -> salon tz) and bare `HH:mm`/local datetime (treated as salon-local); single place to fix once the backend answers. Salon tz from `SessionUser.timeZone` (settings) or `PartnerToday.time_zone`.
- Error mapping: 422 -> inline "Invalid date range" (should not happen; log); 403 -> reset staff filter to own and show banner; 429 -> retry after delay; 5xx/offline -> error state keeping last data.

## 4. Application / state
- `CalendarSelection{DateTime date (today), CalendarView view (day), String? staffId}`; default per AC 1; specialist: `staffId` forced to own id and cannot change.
- Range derivation (pure fn `rangeFor(selection, isTablet)`): phone -> `from=to=date`; tablet day -> same; week -> Monday..Sunday of `date`; list -> date..date+30 (limit 31, assumption). Phone week strip uses only local date arithmetic (no slots/money).
- `calendarProvider = AsyncNotifierProvider.family<CalendarController, CalendarState, CalendarQuery>`; changing date creates a new family entry; UI uses `ref.watch(...).when(skipLoadingOnReload: true)` plus last-good holder so the previous result stays visible (AC 2). Prefetch next/previous day lightly is NOT done (avoid extra calls).
- Agenda derivation (pure, tested): flatten bookings of all schedules, attach staff name, filter hidden statuses (`declined`, `expired`, `cancelled` hidden by default, flag `kShowInactiveStatuses=false`; Gap 4), sort by `start_time` then staff name (AC 4).
- Real-time: `CalendarEventSource` interface (no-op until WS contract, Gap 5) + `Timer.periodic(60s)` refetch while visible; minute ticker `nowProvider` for the now line.
- Offline: cache the loaded range JSON; when offline serve cached week and show "Offline" banner; FAB disabled.
- Invalidation hooks: P-04/P-05/P-06 call `ref.invalidate(calendarProvider)` (exposed helper `invalidateCalendar(ref)`), and P-02 uses the same after actions.

## 5. Presentation
Phone: `CalendarScreen` -> `Scaffold` + `Stack`: `Column`[ header row (title `headlineMedium`, selected-date caption `bodyMedium` muted, right), `DayStrip` (`SbWeekStrip`, horizontal week paging, selected `SbDateChip` ink), `StaffChips` (horizontal `ListView` of `SbChoiceChip`, "Everyone" first; hidden for specialist), `Expanded(AgendaList)` ] + positioned `SbFab` above floating nav (bottom offset = `SbTokens.navHeight + gap`).
- `AgendaList`: rows `[time label | SbBookingTile]`; tile shows client name, "service . staff . duration" (duration = end-start since API gives times, not minutes; staff from parent schedule), status-coloured via `SbTokens.status`, plus a status word for accessibility (AC 7) in Semantics label and a small pill when tile height allows. Same-time bookings stack as separate rows (AC 4, other_day PNG). Walk-in tile uses `client_name` as returned.
- Off staff/time off: when a specific staff is filtered and `is_working=false` or `time_off != null`, show `OffBlock("Off . {reason}")` instead of agenda; with Everyone, add a muted line "{name} is off" per such staff above the list.
Tablet/web (>= 900): `CalendarToolbar` (prev, Today, next, date-picker button -> `showDatePicker`, `SegmentedButton` Day/Week/List styled by tokens or new `SbSegmented`, `+ New booking` black pill). Day: `DayGridView` — left time gutter (hours from min working-hours start to max end across staff), one column per staff in `staff_schedules`, header with `SbAvatar` + name, cards positioned with `Stack`/`Positioned` from start/end minutes (layout math is rendering only), non-working/breaks/time off as muted blocks from `working_hours/breaks/time_off`, now line (amber token) updated per minute when date is today; overlapping bookings in the same column split width. Week: 7 columns grouped by day, staff chips filter on top. List: `PaginatedDataTable2`/`DataTable2` columns Time, Client, Service, Staff, Status (no price: not in API, Gap 8).
Booking tap: phone -> `showSbSheet` with P-04 `BookingSheet(bookingId, summary)`; tablet -> side panel (`endDrawer`-like fixed width) hosting same widget (owned by P-04).
Loading: `CalendarSkeleton` (strip + chips remain interactive). Empty: "No bookings on Wed 28 Oct" + New booking pill (owner/manager). Error: inline `SbErrorBanner` with Retry above the last good content.
New shared: `SbBookingTile`, `SbFab`, `SbWeekStrip`, `SbSegmented`.

## 6. Role rules
- Owner/Manager: all chips, all views, FAB/new-booking pill.
- Specialist: `staff` param always own id, chips row not built, week/list restricted to own, FAB hidden unless manager rights (shared `can(Permission.createBooking)` from P-02/P-01).
- Enforced in `CalendarSelection` notifier (clamps `staffId`), widgets (`if (can(...))`), API 403 fallback.

## 7. Validation, confirmations, formatting
- No destructive actions. Times `h:mm a` in salon tz (`9:30 AM`); caption `Mon 26 Oct`; empty text `No bookings on Wed 28 Oct`. Week boundaries Monday-based in salon tz. Date picker lower/upper bound unconstrained (API validates 422).
- No computation of slots or prices; durations displayed are `end - start` for display only (flag as derived; ask backend for `duration_minutes`).

## 8. ARB keys
`calendarTitle`, `calendarToday`, `viewDay`, `viewWeek`, `viewList`, `everyone`, `newBooking`, `newBookingSemantics`, `closeSemantics`, `prevSemantics`, `nextSemantics`, `pickDate`, `emptyDay` (`date`), `staffOff` (`name`), `offReason` (`reason`), `notWorking`, `breakLabel`, `offlineBanner`, `retry`, `walkIn`, `statusRequested`, `statusConfirmed`, `statusCheckedIn`, `statusInService`, `statusCompleted`, `statusDeclined`, `statusExpired`, `statusCancelled`, `statusNoShow`, `colTime`, `colClient`, `colService`, `colStaff`, `colStatus`, `bookingTileSemantics` (`client`,`service`,`staff`,`time`,`status`), `dayChipSemantics` (`date`,`selected`), `staffChipSemantics`, `durationMin` (`n`), `homeVisitBadge`.

## 9. Tests
Unit
- `rangeFor`: phone day; week Monday..Sunday for a Wednesday and for a Sunday; list 31-day cap.
- `CalendarTime.parse`: Z/offset/local forms across midnight in `Asia/Colombo`.
- Agenda flattening: stable order by start then staff name; hides declined/expired/cancelled; two bookings at 2:00 PM both present.
- `CalendarRepository`: query params (`from`, `to`, repeated `staff`, `view`), parsing fixture with `time_off` and breaks.
- `CalendarSelection`: specialist clamp; "Everyone" clears staff.
- Controller: initial single call with from=to=today; date change keeps previous data while loading; error keeps last good.
Widget
- Phone: strip selection updates caption and calls repo with new date; chip tap sends `staff`; Everyone clears; FAB opens new-booking route; tile tap opens sheet with id.
- Status tile: Requested has label text not just colour; Semantics label includes status.
- Role matrix: specialist has no chips/FAB; manager has both.
- States: skeleton while loading with strip interactive; empty text; error banner + Retry.
- Off staff: filtered staff time off shows "Off . reason".
- Tablet: columns count equals staff schedules; card vertical position proportional to start (tolerance test); now line only for today; view switch triggers week range call.
- Fake event source adds a booking without refresh.
- Text scale 2.0 at 390 px no overflow; touch targets >= 44 on chips, date chips, FAB.
Golden: `calendar_390.png`, `calendar_other_day_390.png`, `calendar_day_1280.png`, `calendar_week_1280.png`.

## 10. Task checklist
1. `sb_ui`: `SbFab`, `SbWeekStrip`, `SbBookingTile`, `SbSegmented` + widget tests.
2. Models, `CalendarTime`, repository + fixtures + tests.
3. `CalendarSelection` + `rangeFor` + tests (incl. role clamp).
4. Controller, agenda derivation, cache, realtime/poll + tests.
5. Phone view to PNG (strip, chips, agenda, FAB), states.
6. Booking tap -> P-04 sheet hook (stub route until P-04), FAB -> P-06 hook.
7. Tablet toolbar + Day grid + now line.
8. Week and List views (`data_table_2`).
9. Offline/role tests, goldens 390/1280, analyze + test.

## 11. Open questions / API gaps / risks
- Gap 1: bookings carry no `staff_id`; a split booking appears under each staff? Chips/columns rely on nesting. Duplicate card risk for multi-staff bookings: dedupe by booking `id` in "Everyone" agenda (assumption; confirm).
- Gap 2: no segment link, group id, address, patch-test flag; US-P-12 visuals deferred (phase 5).
- Gap 3: time format of `start_time`/`end_time`/`working_hours` unspecified; parser isolated.
- Gap 4: which statuses are returned; default hide declined/expired/cancelled, ask for a status filter.
- Gap 5: no WebSocket contract; 60 s polling only.
- Gap 6/AC drag-to-move: not built; needs partner reschedule endpoint (P-05 G1).
- Gap 7/8: walk-in marker and price column unavailable; list view has no price.
- Duration and `staff_name` on tiles are derived (end-start, parent schedule), not API fields.
- Calendar widget choice: custom grid recommended; reconsider if drag-to-move becomes needed.
- Range limits (7/31 days) unconfirmed.
- Specialist staff id (P-01 Gap 2) required for clamping.

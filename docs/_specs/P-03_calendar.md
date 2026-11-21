# P-03 Calendar

Feature folder: `features/calendar/`. PNGs: `mobile/P-03_calendar.png`, `P-03_calendar_other_day.png`. Stories: US-P-06, US-P-07, US-P-12 (display part). New booking (US-P-08) is P-06, move (US-P-09) is P-05.

## 1. Goal and roles
See who is booked when, by day, week or list, and open a booking.
| Role | Can do |
|---|---|
| Owner, Manager | All staff, all views, staff filter, tap booking to open P-04, "+" to start P-06 |
| Specialist | Opens on Day view of their **own column** (own `staff` id forced); Week and List one tap away, still own bookings only; open P-04 and Accept/Decline pending there; no staff chips for others; no "+" unless manager rights |

Default view (plan P-01 section 6b): Calendar opens on **Day view, today, for the signed-in worker's own column**, for every role that has a `staff_id` (Specialist; Owner/Manager who are also staff). Week and List are one tap away via the view switch (phone too). No setup or filters needed on first open. Owner/Manager without a `staff_id` open on Everyone. **Hard dependency on API Gap 2 (P-01): own `staff_id` is not in `UserOut`; without it the own-column default and the Specialist clamp are blocked.**

## 2. User stories
| Story | SRS | Notes |
|---|---|---|
| US-P-06 | PTN-09 | Day, week, list, date navigation |
| US-P-07 | PTN-09 | Staff filter chips |
| US-P-12 | CLI-25, 28, 29, 34 | Split segments, group side by side, home visit, patch test markers (phase 5; API partial) |

## 3. Layout notes
- Phone (`P-03_calendar.png`): title "Calendar" with selected date caption right; round day strip Mon..Sun (selected is black pill, others white); staff chips row "Everyone" (selected black) then names, horizontally scrolling; agenda list: time label left, coloured card right (client name, "service . staff . duration"); black FAB "+" bottom right above the floating nav (Semantics label "New booking").
- Status colours (same as client app, BR-01): Confirmed blue, Requested yellow/amber, Checked in and In service orange tint, Completed green, Declined/No-show use the status pill tokens. Use `sb_ui` status tokens; do not pick colours here.
- Web/tablet: Day view with a column per specialist, time grid, a "now" line, cards positioned by start/end; Week view (days across, staff chip filter); List view (table via `data_table_2`); date nav (prev, Today, next, date picker); view switch (Day, Week, List); "+ New booking" top right. Drag to move is P-05 (needs a move endpoint, see Gaps).
- Phone: default is the Day agenda of the worker's own column (list for selected day); add a compact Day / Week / List switch (`SbSegmented`) under the title so Week and List are one tap away (previously phone was agenda only); the day strip scrolls by week. Web/tablet Day view opens with only the own column; Everyone adds the other columns.

## 4. Data and API map
GET `/v1/partner/calendar` query `from` (date, required), `to` (date, required), `staff` (array of uuid, optional, repeated), `view` (`day|week|list`, default `day`), header `X-Salon-Id`. Response `PartnerCalendarOut{from, to, view, staff_schedules[]}`.

| UI element | Field |
|---|---|
| Staff columns / chips | `staff_schedules[]` -> `CalendarStaffScheduleOut{staff_id, staff_name, days[]}` |
| Day column | `CalendarDayOut{date, is_working, working_hours{start,end}, breaks[{start,end}], time_off{reason}, bookings[]}` |
| Greyed non-working / break / time-off blocks | `is_working`, `breaks`, `time_off.reason` |
| Booking card | `CalendarBookingOut{id, status, client_name, start_time, end_time, services[] (strings), location_type, notes}` |
| Card tap | open P-04 with `id` |
| Day strip dates | local computation of dates only (no money/slots) |
| "+" FAB | navigate to P-06 (POST `/v1/partner/bookings`, `PartnerCreateBookingIn`) |

Staff chips come from `staff_schedules` of an unfiltered call, or GET `/v1/partner/staff`. Filter sends `staff=<uuid>`; "Everyone" omits it.
Errors: 422 (range invalid or `to` before `from`), 403 (specialist requesting others), 429, 5xx.

## 5. Acceptance criteria
1. Given Calendar opens, then the selected date is today, view is Day, the signed-in worker's own column/chip is selected (not "Everyone") and one call is made with `from=to=today` and `staff=<own staff_id>`. Owner/Manager can tap Everyone to see all columns; a worker with no `staff_id` falls back to Everyone.
1a. Given the view switch (Day, Week, List; shown on phone and tablet), when Week or List is tapped, then one call is made with `view` and the matching range, still limited to own `staff` for Specialist and for Owner/Manager while their own chip is selected; switching back to Day returns to today's own column.
1b. Given a booking with status `requested` is opened from Calendar, then P-04 shows inline Accept / Decline (see P-04).
2. Given the user taps another date in the strip, then the title caption updates and a new call is made; the previous result stays until the new one arrives.
3. Given a staff chip is tapped, then only that person's bookings show and the call includes `staff`; tapping Everyone clears it.
4. Given two bookings share a time (e.g. two at 2:00 PM, `P-03_calendar_other_day.png`), then both show in separate cards in order of start time, then staff name.
5. Given week view (web/tablet), then `from` is Monday and `to` Sunday of the displayed week and cards group per day.
6. Given a booking card is tapped, then P-04 opens (sheet on phone, side panel on web) for that `id`.
7. Given status `requested`, the card uses the Requested colour and the label text, not colour alone (accessibility).
8. Given a staff member on time off or not working, then the column shows "Off" (time_off.reason) and no slots invite taps.
9. Given a Specialist, then no chips for others, `staff` is always own id on every view, and "+" is hidden.
10. Given a WebSocket booking event for a visible date, then the card is added/updated without refresh.
11. Day strip, chips and cards have Semantics labels and 44 px targets; times format "9:30 AM"; strings in ARB; goldens at 390 and 1280 px.

## 6. States
- Loading: skeleton cards; date strip remains interactive.
- Empty: "No bookings on Wed 28 Oct" with New booking pill (manager/owner).
- Error: inline retry; keep the last good day visible.
- Offline: cached current week from drift, banner "Offline", "+" disabled.
- Real-time: WebSocket booking created/changed/cancelled; fallback refetch every 60 s while visible (Gap 5). The now line updates each minute on web.

## 7. Rules and edge cases
- The app never computes free slots; free times come only from the API (P-06).
- Times: bookings carry `start_time`/`end_time`; render in the salon time zone (see `/v1/partner/today` `time_zone`). Confirm format (Gap 3).
- Split visits: segments of one booking should be shown linked (US-P-12); needs segment data in the calendar (Gap 2). Group bookings side by side; home visits show address/travel time badge via `location_type`; patch test marker.
- Declined, expired and cancelled bookings: hidden by default; confirm with PM (Gap 4).
- Range limits: week view max 7 days, list view max 31 days (assumption; ask backend limit).

## 8. Gaps and questions
1. `CalendarBookingOut.services` is a plain string array: no per-booking `staff_id`, so staff columns must rely on the nesting inside `staff_schedules`. A booking with multiple staff (split) appears under which staff? No segment/duration fields.
2. Missing for US-P-12: segment link id, party/group id, `visit_mode`, address/travel time, patch-test flag, client photo. Only `location_type` and `notes` exist.
3. Time type of `start_time`/`end_time` and `working_hours.start` is a plain string (no format given). Confirm ISO UTC vs local.
4. Which statuses does the calendar return (declined/cancelled/no_show/expired)? Add a status filter if all are returned.
5. WebSocket endpoint and event schema are not in the OpenAPI.
6. Drag-to-move on web needs a partner reschedule endpoint (P-05); none exists (only client `/v1/bookings/{booking_id}/reschedule`).
7. "Walk-in" cards (name "Walk-in" in PNG) imply `client_name` for phone/walk-in; confirm it is returned as such and whether there is a `source` field.
8. No booking payment info, so list view columns for payment/price are not possible without `total_cents` on `CalendarBookingOut`.
9. **Own-staff identity (hard dependency, P-01 Gap 2)**: `UserOut` has no `staff_id` or salon role; own-column default, Specialist clamp and `staff=<own id>` cannot be implemented until the API provides it.
10. Phone Week/List views are new relative to the PNG (agenda only) and the earlier spec; design needed from PM/UX for a phone Week and List layout (can reuse the tablet List table as a grouped list).

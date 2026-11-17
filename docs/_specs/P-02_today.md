# P-02 Today

Feature folder: `features/today/`. PNGs: `mobile/P-02_today.png`, `P-02_today_scrolled.png`, `P-02_today_decline_reason.png`. Stories: US-P-01, 02, 03, 04, 05, 17 (leave card), 35 (disputes card).

## 1. Goal and roles
Home screen on every device: run the day from one screen. Requests needing action sit at the top with a count.
| Role | Sees | Can do |
|---|---|---|
| Owner | Whole salon | Accept/decline requests, handle reschedules and leave, check in/start/complete |
| Manager | Whole salon | Same as Owner |
| Specialist | Own bookings only (send `staff_id` = own id) unless given manager rights | Check in, Start, Complete own bookings; no Accept/Decline unless manager rights; no leave approvals |

## 2. User stories
| Story | SRS | Notes |
|---|---|---|
| US-P-01 | PTN-01 | Stats, needs OK, in the chair, up next |
| US-P-02 | BR-02 | Accept in one tap before expiry |
| US-P-03 | BR-14, PTN-08 | Decline with reason the client sees |
| US-P-04 | BR-07 | Reschedule accept/decline (blocked by Gap 3) |
| US-P-05 | BR-01 | Check in / Start / Complete |
| US-P-17 | PTN-12 | Staff leave tab (blocked by Gap 4) |
| US-P-35 | BR-09 | Dispute card with 48 h timer (Gap 7) |

## 3. Layout notes
- Phone (`P-02_today.png`): header "Salon name . area", date title (27/600), avatar chip top right; three stat cards (Bookings, Still to come, Needs your OK, the last with amber border/tint); section "Needs your OK" with black count pill and "Requests and changes" caption; request cards; then "In the chair now" (avatar initials, "service . staff . until 11:30 AM", black pill Complete or Start); then "Up next" list with time, client, "service . staff", status pill, "Calendar" orange link; floating black nav.
- Request card: left column date label (orange "Today", grey otherwise) and time; right column client name, tag pill (Returning, New client, Reschedule), service . staff . duration, meta line (payment . "25 min ago"); black Accept and white Decline pills side by side. Reschedule card shows "2:00 -> 4:30 PM" and "Move it".
- Decline (`..._decline_reason.png`): card expands in place: "Reason (the client sees it)", choice chips (Fully booked, Specialist unavailable, Service not offered, Other), red `danger` "Confirm decline", white Back. Selected chip uses amber tint.
- Web/tablet: sidebar, "+ New booking" black pill top right; stat cards in one row of five (Bookings, Needs your OK amber, Still to come, In the chair, Completed); "Needs your action" with tabs (Booking requests, Reschedule, Staff leave); in the chair, arriving in next 2 hours, today's schedule, earnings and stock summary in a right column.
- Components: `sb_ui` stat card, status pill, action bar, black pill, chips, floating nav.

## 4. Data and API map
Main read: GET `/v1/partner/today` query `date` (YYYY-MM-DD, optional), `staff_id` (optional), header `X-Salon-Id`. Response `PartnerTodayOut{date, time_zone, needs_action[], in_chair[], up_next[], stats}`.

| UI element | Field | Notes |
|---|---|---|
| Date title | `date`, `time_zone` | Render in salon `time_zone`; items carry UTC |
| Stat "Bookings" | `stats.total_bookings_today` (`PartnerTodayStats`) | |
| Stat "Completed" (web) | `stats.completed_today` | |
| Stat "Needs your OK" | `needs_action.length` | count of array, not computed money |
| Stat "Still to come" | none | Gap 2 |
| Stat "In the chair" (web) | `in_chair.length` | |
| Earnings (web) | `stats.revenue_today_cents` | Money from cents |
| Request card | `PartnerTodayNeedsActionItem{booking_id, client_name, client_avatar_url, services[], start_time_utc, end_time_utc, total_cents, status, expires_at, is_returning_client, booking_for_name, location_type, created_at}` | `services[]` is `PartnerTodayServiceItem{service_name, staff_name, staff_id, option_name, duration_minutes}` |
| "Returning" / "New client" tag | `is_returning_client` | |
| "25 min ago" | `created_at` | relative |
| Expiry countdown | `expires_at` | Show when near; after expiry card disappears |
| "Booked for X" | `booking_for_name` | |
| Home visit badge | `location_type` | |
| In the chair row | `PartnerTodayInChairItem{..., staff_name, elapsed_minutes, remaining_minutes, status}` | "until" = `end_time_utc` |
| Up next row | `PartnerTodayUpNextItem{..., staff_name, minutes_until_start, status}` | |
| Accept | POST `/v1/partner/bookings/{booking_id}/{action}` | action string not enumerated (Gap 1); response `BookingDetailOut` replaces the card state |
| Confirm decline | same endpoint | Reason not accepted by the spec (Gap 1) |
| Check in / Start / Complete | same endpoint | Shown only if the action is in `allowed_actions` of `BookingDetailOut` (needs GET `/v1/bookings/{booking_id}` or the response of last action) |
| Move it / reschedule Decline | none | Gap 3 |
| Leave tab | POST `/v1/partner/leave/{leave_id}/decide` `DecideLeaveIn{decision, reason, force}` | No list source on Today (Gap 4); list via GET `/v1/partner/staff/{staff_id}/time-off` per staff |
| Dispute card | GET `/v1/partner/disputes`, POST `/v1/partner/disputes/{dispute_id}/respond` | Today has no dispute field |

Error codes: 404 booking gone, 409 state conflict (already accepted, expired, slot taken) -> toast with `message`, refetch card; 422 reason invalid; 429 backoff; 403 role.

## 5. Acceptance criteria
1. Given the app opens, when Today loads, then GET `/v1/partner/today` is called once and stat cards, requests, in the chair and up next render from the response.
2. Given `needs_action` is non-empty, then the section appears at top with the count in a black pill, and the Needs your OK stat card has the amber highlight. When empty the card is neutral and the section shows "Nothing needs your OK".
3. Given a request, when Manager taps Accept, then the button shows progress, the API is called once (idempotency key), and on 200 the card leaves the list and the count drops. On 409 the card is removed and a message shows.
4. Given a request, when Decline is tapped, then the reason panel opens in the card. Confirm decline is disabled until a reason chip is chosen. "Other" requires text.
5. Given a reason is confirmed, then the request is declined and the client sees the reason (BR-14). The confirm button uses `danger`.
6. Given an item in `in_chair` with status `checked_in`, then the pill reads Start; with `in_service` it reads Complete. One tap calls the action and moves the row.
7. Given a Specialist without manager rights, then Accept/Decline and leave tabs are not rendered, and the data is filtered to their own `staff_id`.
8. Given the pull-to-refresh gesture, then data reloads.
9. Given a WebSocket event (new request, status change), then Today updates within 2 s without refresh and a new request appears at the top (see States).
10. Money shown as `LKR 1,500`; times as `Thu 29 Oct, 9:30 AM` or "Today 4:00 PM"; never computed by the app.
11. All icon buttons have Semantics; touch targets >= 44 px; strings in ARB; golden tests at 390 and 1280 px.

## 6. States
- Loading: skeleton stat cards and card placeholders.
- Empty: "No bookings today" with a New booking pill (Manager/Owner); empty needs-action as above.
- Error: full-width retry banner; stale data stays visible if present.
- Offline: show last cached Today (drift) with "Offline, last updated 9:05 AM"; all actions disabled.
- Real-time: WebSocket (instructions §1) for new requests, status changes, leave requests. Fallback: poll every 60 s when the socket is down. Gap 6.

## 7. Rules and edge cases
- Decline needs a reason and confirm (danger button); Accept does not need confirm.
- Request expiry: use `expires_at`; hide or mark Expired locally, but the API decides.
- The same booking cannot appear in two sections; if status changes, move it.
- Group/split/home bookings: show `location_type` badge; details on P-04.
- Time zone: render with `time_zone`, not the device's.
- Specialist sees only own work; API still enforces.

## 8. Gaps and questions
1. **Booking action contract**: POST `/v1/partner/bookings/{booking_id}/{action}` has `action` as a free string, no request body, no description. Needs: list of values (accept, decline, check_in, start, complete, no_show, ...) and a body with `reason` for decline (BR-14). Without it the decline reason cannot be sent. Blocks AC 4-5.
2. `PartnerTodayStats` has no "still to come" and no "in the chair" count; the app can derive from arrays (`in_chair`, `up_next`) but `up_next` may be limited to 2 hours. Ask for explicit fields.
3. **Reschedule requests** are not in `PartnerTodayOut`; there is no kind field to tell request vs reschedule, nor requested new time, nor an endpoint to accept ("Move it") or decline one. Client reschedule is `/v1/bookings/{booking_id}/reschedule`. BR-07 flow for partners is undefined.
4. **Staff leave tab**: no leave list in Today; `/v1/partner/leave/{leave_id}/decide` exists but not the list of pending leave across staff.
5. Payment line on cards ("Pay at salon", "Paid by card", "Deposit paid") has no field in `PartnerTodayNeedsActionItem`; only `total_cents`. Add payment mode/status.
6. **WebSocket**: no endpoint, URL or event schema in the OpenAPI. Needed for the DoD real-time test.
7. Web sections "today's schedule" and "stock summary" have no source on `/v1/partner/today` (schedule can use `/v1/partner/calendar`; stock via `/v1/partner/inventory`). Disputes with 48 h timer (US-P-35) are not on Today.
8. Today's needs_action cards show `staff_name` only inside `services[]`; confirm that is the assigned specialist.
9. Header "Salon name . area" and avatar initials: source is not in Today (needs salon profile endpoint).

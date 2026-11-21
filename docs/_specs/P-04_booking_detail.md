# P-04 Booking detail

Feature folder: `features/booking_detail/`. PNG: `mobile/P-04_booking_sheet.png` (P-05 sheets for Move and No-show are separate specs). Stories: US-P-05, US-P-12, US-P-13, US-P-35.

## 1. Goal and roles
Show everything about one booking and let staff move it through its status.
| Role | Can do |
|---|---|
| Owner, Manager | View; Accept/Decline (requested), Check in, Start, Complete, Move (P-05), No-show (P-05), Call, Message, respond to dispute |
| Specialist | View own bookings; **Accept / Decline pending own bookings (inline)**, Check in, Start, Complete; Call; Message (US-P-11); no Move/No-show unless manager rights |
Visible buttons always come from the booking's `allowed_actions`, filtered further by role. Worker-first rule (plan P-01 section 6b): a pending booking shows Accept (black pill) and Decline (white pill) directly at the top of the sheet/panel and on the Today card, no extra screens. Own-booking check needs the worker's `staff_id` (**hard dependency on API Gap 2, P-01**).

## 2. User stories
| Story | SRS | Notes |
|---|---|---|
| US-P-05 | BR-01 | One tap Check in, Start, Complete |
| US-P-12 | CLI-25, 28, 29, 34 | Split segments, group, home visit address and travel, patch test |
| US-P-13 | CLI-25, CLI-38 | Client photo, hair type, notes for salons, reference photo |
| US-P-35 | BR-09 | Dispute answer within 48 h |

## 3. Layout notes
- Phone (`P-04_booking_sheet.png`): bottom sheet over Calendar or Today with drag handle. Header: client name (large) and status pill (Confirmed = blue). Line "service . 1:30 PM - 2:15 PM . with Dilan". Info strip (sand background): "Usually every 4 weeks . paid by card". Primary black pill (full width): next action (Check in). Row of three white pills: Move, Call, No-show (No-show text is plain; confirm happens in P-05).
- Web/tablet: right side panel (fixed width) with the same content plus sections: client card (photo, hair type, notes for salons, visits), services and staff table, visit plan (segments), reference photo, payment summary, dispute card.
- Sections below the fold on phone: Client, Services, Visit plan (split visits as linked rows with time and staff), Home visit (address, travel fee), Patch test, Reference photo, Notes, Payment, Dispute.
- Components: `sb_ui` bottom sheet, status pill, action bar, black/white pills, `danger` for destructive confirm.

## 4. Data and API map
| UI element | Endpoint | Fields used | Errors |
|---|---|---|---|
| Load detail | GET `/v1/bookings/{booking_id}` (client-named route, summary "Get Booking"; no partner GET exists, see Gap 1) | `BookingDetailOut{id, reference_code, status, date, start_time, total_cents, deposit_cents, cancellation_fee_cents, payment_intent_id, segments[], plan[], notes, patch_test_date, patch_test_booking_id, reschedule_count, allowed_actions[], location_type, visit_mode, party_size, travel_fee_cents, address_snapshot, created_at, salon_name, user_id}` | 404, 403 |
| Header status pill | `status`: requested, confirmed, checked_in, in_service, completed, declined, expired, cancelled, no_show | | |
| Service line | `segments[]` = `BookingSegmentOut{service_id, service_name, staff_id, staff_name, start_time, duration_minutes, price_cents}` | | |
| Visit plan | `plan[]` (same shape, ordered) | | |
| Price / deposit / fee | `total_cents`, `deposit_cents`, `cancellation_fee_cents`, `travel_fee_cents` (display only) | | |
| Client name, photo, hair type, notes for salons, "usually every 4 weeks" | GET `/v1/partner/clients/{user_id}` with `user_id` from detail -> `ClientDetailOut{full_name, phone, avatar_url, hair_type, notes, average_interval_days, visit_count, upcoming_bookings}` | 404 for a client without completed visits (Gap 2) | |
| Edit private note | PUT `/v1/partner/clients/{user_id}/notes` `ClientNotesIn` | | |
| Primary action and Accept/Decline | POST `/v1/partner/bookings/{booking_id}/{action}` -> `BookingDetailOut` | action values not documented (Gap 3) | 409 conflict, 404, 422, 403 |
| Move | opens P-05 | | |
| Call | `tel:` link with `ClientDetailOut.phone` | | |
| No-show | opens P-05 confirm with fee from API | Gap 4 | |
| Message (specialist) | POST `/v1/threads` `ThreadCreateRequest` then `/v1/threads/{thread_id}/messages` | P-05 | |
| Dispute | GET `/v1/partner/disputes`, POST `/v1/partner/disputes/{dispute_id}/respond` | link between booking and dispute not in `BookingDetailOut` (Gap 6) | |
| Reference photo | none | Gap 5 | |

## 5. Acceptance criteria
1. Given a booking id from Calendar or Today, when P-04 opens, then the sheet shows header and summary immediately (from the list item) and fills the rest after the detail call.
2. Given `status = confirmed` and `allowed_actions` contains check-in, then the primary pill reads "Check in". After success the pill becomes "Start" (checked_in) then "Complete" (in_service), updating status pill from the API response.
3. Given an action is not in `allowed_actions`, then its button is hidden (not just disabled). A Specialist never sees Move or No-show without manager rights.
4. Given `status = requested` and `accept`/`decline` are in `allowed_actions`, then Accept (black) and Decline (white) show for Owner, Manager and for a Specialist on their own booking, in place of the primary pill. Accept is one tap, no confirm. Decline expands the reason chips in place (same component as P-02); "Other" needs text; confirm button uses `danger` and is disabled until a reason is chosen; the reason is sent to the API and shown to the client (BR-14).
4a. Given a Specialist opens a booking that is not theirs, then 403 -> "Not available" and the sheet closes.
5. Given a double tap, then only one request is sent (button disabled while busy, idempotency key).
6. Given 409 on an action, then a message shows, the detail is reloaded and buttons reflect the new state.
7. Given a completed, declined, cancelled, expired or no-show booking, then no status actions show; payment and history remain visible.
8. Given `plan` has more than one segment, then they show as linked ordered steps with time and staff; given `location_type` is home, then address from `address_snapshot` and `travel_fee_cents` show; given `patch_test_date`, then a patch-test chip shows and links to `patch_test_booking_id`.
9. Given the client has `hair_type`, `notes`, `avatar_url`, then they show in the Client section; if client record fails, the rest of the sheet still renders with name only.
10. Money formatted from cents (`LKR 1,500`), no totals computed by the app; times "Thu 29 Oct, 9:30 AM".
11. Close button and Call have Semantics labels and 44 px targets; strings in ARB; goldens at 390 and 1280 px.

## 6. States
- Loading: sheet skeleton with header from the list item.
- Empty: not applicable; optional sections hidden when null.
- Error: 404 shows "Booking no longer exists" and closes; other errors show Retry.
- Offline: cached detail read-only; actions disabled with reason.
- Real-time: a status change event for the open booking refreshes it; if another user changed it, show a small "Updated" note.

## 7. Rules and edge cases
- Destructive actions (Decline, No-show) confirm first; decline needs a reason the client sees; no-show shows the fee returned by the API (BR-06), never computed locally.
- Fees, deposit, travel fee are display-only from the API.
- Client notes are "for salons": show only in the partner app.
- Specialist may only open own bookings; others return 403.
- Group booking (`party_size > 1`) show party size and segments per person.
- Status names and colours match the client app (BR-01).

## 8. Gaps and questions
1. **No partner booking GET.** Only client `/v1/bookings/{booking_id}`; unclear if it authorises salon staff. `BookingDetailOut` also lacks client name, avatar, hair type and payment method. Need `GET /v1/partner/bookings/{booking_id}` returning a partner view.
2. `/v1/partner/clients/{user_id}` is "clients with completed visits"; a new client (first booking, Requested) may 404, yet US-P-13 needs hair type, notes and photo for them. Confirm.
3. **Action contract** for POST `/v1/partner/bookings/{booking_id}/{action}`: undocumented action names, no request body (decline reason, no-show confirmation), no description.
4. No no-show preview endpoint to show the fee before confirming (client has `/v1/bookings/{booking_id}/cancel-preview`). `cancellation_fee_cents` on the booking may be the source; confirm.
5. **Reference photo** (CLI-38) has no field in `BookingDetailOut`.
6. Dispute (US-P-35): no booking link or dispute flag in `BookingDetailOut`; need `dispute_id`/status.
7. "Usually every 4 weeks . paid by card": `average_interval_days` exists; payment method does not (`payment_intent_id` only).
8. Message and Move behaviour belong to P-05; this spec assumes they open as separate sheets.
9. WebSocket event schema missing (see P-02).
10. **Own-staff identity (hard dependency, P-01 Gap 2)**: needed to decide "own booking" for Specialist Accept/Decline; `BookingDetailOut` has per-segment `staff_id` to compare against once the user's `staff_id` is known.
11. Specialist Accept/Decline permission: earlier spec limited it to manager rights; plan 6b grants it for own bookings. Confirm the action endpoint allows it (else 403).

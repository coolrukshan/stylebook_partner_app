# P-05 Move / no-show / message

Refs: instructions §3 (P-05), US-P-09, US-P-10, US-P-11. PNGs: `mobile/P-05_move_booking.png`, `mobile/P-05_no_show_confirm.png`. Lives inside the P-04 booking sheet (no own route); feature folder `features/booking_detail/`.

## 1. Goal and roles
Let staff reschedule a booking to a free time (or another specialist), mark a no-show after confirming, and message the client, all from the booking sheet.

| Role | Move | No-show | Message |
|---|---|---|---|
| Owner | any booking | any booking | yes |
| Manager | any booking | any booking | yes |
| Specialist | no (hide Move) unless given manager rights; see Q4 | no unless manager rights | own bookings' clients only |

Buttons shown only if the action is in `BookingDetailOut.allowed_actions`; role gates are on top of that (API still enforces).

## 2. User stories
| Story | SRS | Summary |
|---|---|---|
| US-P-09 | PTN-07 | Move to a free time or other specialist; client is told |
| US-P-10 | BR-06, PTN-08 | No-show only after confirmation with fee shown |
| US-P-11 | PTN-10 | Message the client from the booking |

## 3. Layout notes
- Phone: actions are part of the P-04 bottom sheet. Row of three white pill buttons (Move, Call, No-show) under the black "Check in" pill. Tapping Move expands the section "Free times for <staff> today" with time chips (`sb_ui` chip, 44 px, selected = amber tint). Tapping No-show replaces the helper area with the confirm text and a red `danger` "Confirm no-show" plus white "Back" (see PNG 2).
- Web/tablet: same content in a centred dialog/side panel opened from the calendar or Today row; chips wrap; date picker added to Move (phone shows today only in the PNG; see Q2).
- Message: text field with a Send black pill and a channel hint ("Sent in app, SMS if unread"); web shows the thread inline, phone opens a full-height sheet.
- Use `sb_ui` bottom sheet, status pill, chip, black/white pill buttons, danger button. No hard-coded colours.

## 4. Data and API map
| UI element | Endpoint | Request | Response / fields used | Errors |
|---|---|---|---|---|
| Booking header, allowed buttons | `GET /v1/bookings/{booking_id}` (or carried from calendar) | - | `BookingDetailOut`: `status`, `date`, `start_time`, `segments[].staff_id/staff_name/duration_minutes`, `allowed_actions`, `reschedule_count`, `total_cents`, `deposit_cents` | 404 |
| Free-time chips (Move) | `POST /v1/availability/slots` | `SlotRequest`: `salon_id`, `services[]` (`ServiceSelection`: `service_id`, `option_id`, `addon_ids` from booking segments), `staff_id`, `date`, `mode=single` | `SlotResponse.slots[]` (`TimeSlot`: `start_time`, `utc_start`, `duration_minutes`, `staff_id`) | 403, 409, 422 |
| Move confirm | `POST /v1/bookings/{booking_id}/reschedule` (client route; see Gap G1) | `RescheduleRequest`: `new_date`, `new_start_time`, `hold_id?` | `BookingDetailOut` (`date`, `start_time`, `reschedule_count`) | 404, 409, 422 |
| No-show fee text | `GET /v1/partner/settings` | - | `booking_rules.no_show_fee_percent` | - |
| Confirm no-show | `POST /v1/partner/bookings/{booking_id}/{action}` with `action=no_show` (value unconfirmed, G2) | none documented | `BookingDetailOut`: `status`, `cancellation_fee_cents` | 404, 409, 422 |
| Call | `tel:` link, phone from `GET /v1/partner/clients/{user_id}` `phone` | - | `ClientDetailOut.phone` | - |
| Message: open thread | `POST /v1/threads` | `ThreadCreateRequest`: `salon_id`, `user_id` (`BookingDetailOut.user_id`) | `ThreadCreatedOut.id` | 401, 403, 409 |
| Message: history | `GET /v1/threads/{thread_id}/messages` | cursor | `MessageOut` | 403 |
| Message: send | `POST /v1/threads/{thread_id}/messages` | `MessageCreateRequest`: `content`, `msg_type=text`, `idempotency_key` (uuid per send) | `MessageOut` | 403, 409, 422 |

Error body is always `ErrorResponse` `{code, message, field}`; show `message`, branch on `code`. 429: honour `Retry-After`.

## 5. Acceptance criteria
1. Given a booking whose `allowed_actions` lacks the move action, Move is hidden/disabled.
2. Given Move is tapped, chips list only `slots` from the API for that staff and date; the app computes none. Selecting a chip enables a black "Move booking" pill.
3. When move succeeds, the sheet and calendar/Today refresh with the new `start_time`; a toast confirms "Client notified" only if the API confirms it (G3).
4. Given 409 on move (slot taken), show the message, reload slots, keep the sheet open.
5. Given `reschedule_count` reached the salon `max_reschedules`, show the API error message; do not hide the rule client-side.
6. When No-show is tapped, no request is sent; the confirm panel shows "Mark as no-show? The no-show fee is charged under your policy." with `no_show_fee_percent` (e.g. "Fee: 50% of the booking") and `LKR` amount only if the API supplies it (G4).
7. "Confirm no-show" is a `danger` button; "Back" returns without change. Double tap sends one request (disabled while loading).
8. After no-show succeeds, status pill becomes "No-show" and shows `cancellation_fee_cents` formatted as `LKR 1,500`.
9. No-show is offered only when the booking is Confirmed/Checked in and its start time has passed (rule from BR-06; confirm in Q3); otherwise hidden.
10. Message: Send is disabled while empty; message appears in the thread on 201; a retry reuses the same `idempotency_key`.
11. Specialist role cannot see Move/No-show (unless manager rights) and sees Message only for own bookings.
12. All buttons 44 px min, icon buttons have Semantics labels, strings in ARB.

## 6. States
- Loading: chips shimmer; buttons show progress and are disabled during requests.
- Empty: no free slots -> "No free times left today. Pick another day" (web date picker) or choose another specialist.
- Error: inline `ErrorResponse.message` with Retry; sheet stays open.
- Offline: Move, No-show and Send disabled with "You are offline"; Call still works. Messages are not queued.
- Real-time: booking status change or new chat message (WebSocket) updates the open sheet; if the booking changed meanwhile, reload and show "Booking was updated".

## 7. Rules and edge cases
- Move and no-show affect payments; always show the result from the API, never compute fees or refunds.
- No-show requires confirmation; no reason field in the design (see Q5).
- Moving to another specialist: chips are per specialist; offer a specialist selector on web (slots call with other `staff_id`).
- Prices may be recalculated on reschedule (API docs: "Price recalculated"); show the new `total_cents` after success.
- Booking may be part of split/group/home visit (`visit_mode`, `location_type`); Move for those is out of scope until US-P-12 (hide Move).

## 8. Gaps and questions for the PM
- G1: No partner reschedule endpoint. `POST /v1/partner/bookings/{booking_id}/{action}` has no request body, so it cannot carry a new time or staff. Only the client route `POST /v1/bookings/{booking_id}/reschedule` takes a time, and it may reject a partner token. Need a partner endpoint with `new_date`, `new_start_time`, `staff_id`.
- G2: `{action}` is a free string; allowed values are not in OpenAPI (we assume `check_in`, `start`, `complete`, `decline`, `no_show`, `accept`). Request an enum.
- G3: Instructions say "client is told" (US-P-09); the API does not say whether a notification is sent. Confirm.
- G4: No fee preview. Only `no_show_fee_percent` in settings (owner-level endpoint; check manager access) and `cancellation_fee_cents` after the fact. Request a preview field or endpoint.
- G5: Instructions say message goes "app and SMS"; threads API is in-app only, no SMS or channel field. Flag.
- G6: Threads endpoints are not under `/v1/partner`; confirm specialists and managers count as "chat staff".
- Q2: PNG shows only "today"; Move to another date is assumed on web. Confirm.
- Q3: Earliest time a no-show may be marked (BR-06) is not in the API; rely on `allowed_actions`.
- Q4: Is Move/No-show for specialists governed by "manager rights"? Which claim?
- Q5: Is a no-show reason required (instructions §5 only requires reasons for decline and stock)? Assumed no.

# P-12 Leave requests

## 1. Goal and roles
Approve or decline staff leave requests. Lives as the "Staff leave" tab in "Needs your action" on Today (P-02); no separate PNG.
- Owner, Manager: approve/decline. Specialist: no access (sees own status in P-11 only).

## 2. User stories
US-P-17 (PTN-12); shown in Today (P-02).

## 3. Layout
- No PNG. Follow P-02 "Needs your action" tab pattern (`mobile/P-02_today.png`, `P-02_today_decline_reason.png`): card per request with avatar initials, "Name · title", date range "Mon 23 - Wed 25 Nov", reason, days count, black "Approve" pill and white "Decline" pill. Decline opens inline reason field (as booking decline) with red/danger confirm.
- Phone: tab inside Today home. Web/tablet: tab in the action panel; optional history list below.
- sb_ui: tabs, action card, status pill, reason field, confirm.

## 4. Data and API map
| UI element | Endpoint | Fields | Errors |
|---|---|---|---|
| Pending list | none for whole salon (see Gap 1). Stop-gap: GET `/v1/partner/staff` then GET `/v1/partner/staff/{id}/time-off` each | `TimeOffItemOut`: `id`, `staff_id`, `staff_name`, `start_date`, `end_date`, `reason`, `status`, `created_at` | |
| Approve | POST `/v1/partner/leave/{leave_id}/decide` | `DecideLeaveIn`: `decision`=`approved`, `force` | 404, 409, 422 |
| Decline | same | `decision`=`declined`, `reason` | 404, 409, 422 |
| Result | `DecideLeaveOut` | `status`, `decided_by_name`, `affected_booking_ids[]`, `updated_at` | |

## 5. Acceptance criteria
1. Given pending requests exist, then the tab shows a count badge and cards sorted by `created_at` oldest first.
2. When Approve is tapped and `affected_booking_ids` is empty, then the card disappears with toast "Leave approved".
3. Given the API answers 409 because bookings overlap the leave, then show a dialog listing the conflict count and offer "Approve anyway" (sends `force=true`, danger style) or Cancel; moving bookings is done in P-05.
4. When Decline is tapped, a reason field is required (decline needs a reason) before the confirm button enables; sends `reason`.
5. After a response with `affected_booking_ids`, show "N bookings need to be moved" with link to the calendar.
6. Double tap sends one request; a request already decided elsewhere (409) refreshes the list.
7. Given a new leave request arrives by WebSocket/push, then the tab badge increments without refresh.

## 6. States
Loading skeleton; empty "No leave requests waiting"; error with retry; offline: actions disabled; real-time: new request and decisions via WebSocket (PTN-12 push "leave request").

## 7. Rules and edge cases
- Approved leave removes slots (API side); the app does not alter availability.
- Reason mandatory in UI for decline although API marks `reason` optional.
- Role check: only owner/manager see the tab.
- Show who decided and when for decided items in history (`decided_by_name`).

## 8. Gaps and questions
1. No salon-wide list endpoint for leave (`GET /v1/partner/leave?status=pending` needed). `PartnerTodayOut` has no leave items (`needs_action` is bookings only, `PartnerTodayNeedsActionItem` has booking fields). Stop-gap N+1 is poor.
2. `force` semantic and 409 body (conflict details) undocumented; confirm that 409 means overlapping bookings.
3. `status` values undocumented (pending/approved/declined/cancelled?).
4. How do specialists submit leave? Only `POST /staff/{id}/time-off` exists; confirm specialist permission.
5. Whether affected clients are notified automatically on force approve.
6. WebSocket event for new leave request not specified.

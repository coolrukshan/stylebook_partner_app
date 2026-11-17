# P-11 Staff detail

## 1. Goal and roles
Edit one person's weekly availability, breaks, time off, and the services they do. Save in one action.
- Owner, Manager: edit all. Specialist: view own hours; may request time off (see Gaps). Deactivate/remove: Owner only.

## 2. User stories
US-P-15 (hours, breaks, time off), US-P-16 (services, BR-03), US-P-17 (leave), US-P-14.

## 3. Layout
- Ref: `mobile/P-11_staff_detail.png`, `P-11_staff_detail_scrolled.png`. Header: back circle, avatar, name, title. "Weekly availability" with "Copy from" chips (other staff). Card of 7 rows Mon-Sun: toggle (green on; "Day off" label when off), summary "10:00 AM - 7:00 PM", Start and End steppers with - / + (step 15 min proposed). "Time off" section with "+ Add" and rows "Mon 23 - Wed 25 Nov · reason" with red "Remove". "Services" multi-select chips (selected amber). Black pill "Save availability".
- Phone: single scroll, sticky save. Web/tablet: two columns (availability left; time off and services right), Save top-right.
- sb_ui: toggle, stepper, chip, list card, date range picker, black pill, confirm dialog.

## 4. Data and API map
| UI element | Endpoint | Fields | Errors |
|---|---|---|---|
| Load | GET `/v1/partner/staff/{staff_id}` | `StaffDetailOut`: `full_name`, `title`, `avatar_url`, `is_active`, `services[]` (`service_id`, `service_name`, `category_name`), `hours[]`, `time_off[]` | 404 |
| Hours | GET `/v1/partner/staff/{staff_id}/hours` | `StaffScheduleOut.hours[]`: `day_of_week` (0=Mon..6=Sun), `start_time`, `end_time` (HH:MM), `is_working`, `breaks[]` (`start_time`, `end_time`) | 404 |
| Save availability | PUT `/v1/partner/staff/{staff_id}/hours` | `PutHoursIn.hours[]: StaffHoursIn` (`day_of_week`, `is_working`, `start_time`, `end_time` required if working, `breaks[]: StaffBreakIn`) - replaces whole week | 404, 409, 422 |
| Copy from chips | POST `/v1/partner/staff/{staff_id}/hours/copy` | `CopyHoursIn.source_staff_id`; response `StaffScheduleOut` fills the form (not saved until Save? see Gap 3) | 404, 409 |
| Service chip list | GET `/v1/partner/services` | all salon services | |
| Save services | PUT `/v1/partner/staff/{staff_id}` | `StaffUpdateIn.service_ids` (also `title`, `full_name`, `phone`, `is_active`) | 404, 409, 422 |
| Time off list | GET `/v1/partner/staff/{staff_id}/time-off` | `TimeOffItemOut`: `id`, `start_date`, `end_date`, `reason`, `status` | |
| + Add time off | POST `/v1/partner/staff/{staff_id}/time-off` | `CreateTimeOffIn`: `start_date`, `end_date`, `reason` | 409 (overlap/bookings?), 422 |
| Remove time off | none | see Gap 1 | |
| Remove/deactivate person | DELETE `/v1/partner/staff/{staff_id}` | `DeleteStaffIn`: `confirm`=true, `reason`; returns `DeleteStaffOut.deactivated_at` | 404, 409 |

## 5. Acceptance criteria
1. Given the page loads, then all 7 days show with values from the API; days with `is_working=false` show "Day off" and hide steppers.
2. When user toggles a day on with no previous times, then default to salon hours as returned by API/prefill (no hard-coded values; PM to confirm source).
3. Start/End steppers move by a fixed step; End must be after Start; the - control at the limit is disabled.
4. When Save is tapped, one PUT hours sends all 7 days; success toast "Availability saved"; failures keep edits.
5. Services: tapping a chip toggles it; Save sends `service_ids` with the full selected list.
6. Given an overlapping or invalid time off (422/409), show API message.
7. Given a time-off with `status=pending`, show "Pending" label and link to P-12; approved rows show as in the design.
8. Remove person: confirm dialog with reason field, red confirm "Remove from team" (`danger`); if future bookings exist the API 409 message is shown and nothing is removed.
9. Leaving with unsaved changes asks to discard.
10. Slots shown to clients come from the API only; the app never computes availability.

## 6. States
Loading skeleton; error + retry; offline: read-only cached copy, Save disabled; saving: spinner on Save; dirty indicator. Real-time: if a leave decision arrives (WebSocket) refresh time off list.

## 7. Rules and edge cases
- PUT hours replaces the week, so always send all 7 days.
- Changing hours or removing a service may affect existing bookings: show API warning/409 rather than assuming.
- Removing a service (BR-03): only services the salon offers are shown.
- Times in salon time zone, 12 hour display `10:00 AM`.
- Specialist cannot edit others.

## 8. Gaps and questions
1. No DELETE/cancel endpoint for time off. Design has "Remove". Need `DELETE /v1/partner/staff/{id}/time-off/{id}` or a decision to cancel.
2. Breaks exist in the API (`breaks[]`) and instructions ("breaks") but the design has no break UI. Needs design; proposal: "+ Add break" per day.
3. "Copy from" chips: does `/hours/copy` persist immediately (likely yes, as POST returns `StaffScheduleOut`)? Then the design's "Save availability" is not needed for copy. Confirm; also whether it overwrites breaks.
4. Does time off created by manager start as `approved` or `pending`? `TimeOffItemOut.status` values are not enumerated.
5. Two StaffDetailOut schemas exist (`app__modules__partner__schemas__` used here vs `app__modules__staff__schemas__`); partner version used.
6. Unclear how overlapping bookings are handled on time-off creation (affected bookings only returned for decide).
7. Avatar upload endpoint for staff not found (only `avatar_url` string).
8. Service assignment saved via PUT staff, hours via PUT hours: two requests behind one "Save availability" button; partial failure handling needed.

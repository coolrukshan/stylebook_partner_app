# P-09 Staff

## 1. Goal and roles
Team list with today's status per person; entry to P-10 (add) and P-11 (detail). Tab "Staff" (phone bottom nav, web sidebar).
- Owner: view, add, open detail, deactivate.
- Manager: view, add (confirm with PM, see Gaps), open detail.
- Specialist: no Staff tab. May open own detail only (read-only hours) if PM agrees; otherwise hidden by role guard.

## 2. User stories
US-P-14 (add staff, PTN-11), US-P-15 (hours), US-P-17 (see who is off today, PTN-12).

## 3. Layout
- Ref: `mobile/P-09_staff.png`. Title "Staff" 27/600, "+ Add staff" text action top-right (amber). One white card per person: avatar with initials, name, "title · hours", status pill right.
- Phone: single column list, floating black nav, Staff selected. Web/tablet: 2-3 column card grid or table inside the content area, "+ Add staff" as black pill top-right (as "+ New booking").
- Components (sb_ui): page header, list card, avatar, status pill (amber "With client", green "Free", neutral "On leave"), floating nav, empty and error panels.

## 4. Data and API map
| UI element | Endpoint | Fields | Errors |
|---|---|---|---|
| List | GET `/v1/partner/staff` (`active_only`, `cursor`, `limit`, header `X-Salon-Id`) | `StaffListOut.items[]: StaffListItemOut` (`id`, `full_name`, `title`, `avatar_url`, `is_active`, `service_count`, `upcoming_bookings_today`, `rating`, `review_count`), `next_cursor` | 404, 409, 422, 429, 500 |
| Today's hours "9:00 AM - 6:00 PM" | GET `/v1/partner/staff/{staff_id}/hours` per row (N calls) | `StaffScheduleOut.hours[]: StaffHoursOut` (`day_of_week` 0=Mon, `start_time`, `end_time`, `is_working`) | 404 |
| "With client" pill | GET `/v1/partner/today` | `PartnerTodayOut.in_chair[]` (`staff_id`, `staff_name`, `remaining_minutes`) | 429, 500 |
| "On leave" pill | GET `/v1/partner/staff/{staff_id}/time-off` per row | `TimeOffItemOut` (`start_date`, `end_date`, `status`=approved covering today) | 404 |
| + Add staff | navigate to P-10 | | |

## 5. Acceptance criteria
1. Given an owner or manager, when Staff opens, then all active staff from GET `/v1/partner/staff` show, paged by `next_cursor`.
2. Each row shows avatar initials (when `avatar_url` null), `full_name`, `title` and today's hours from the API hours (day index from salon time zone `PartnerTodayOut.time_zone`).
3. Status: person in `in_chair` -> "With client"; has approved time-off covering today -> "On leave"; not working today (`is_working=false`) -> "Day off"; otherwise "Free".
4. Tapping a row opens P-11 for that `id`; "+ Add staff" opens P-10.
5. Pill text always has a label (not colour only); rows are at least 44 px high.
6. Specialist role does not see "+ Add staff".

## 6. States
- Loading: skeleton cards. Empty: "No team members yet" + black "Add staff" (owner/manager). Error: message + Retry (error codes 429 shows Retry-After). Offline: show cached list (drift) with "Offline" banner, actions disabled.
- Real-time: WebSocket status changes refresh pills (booking started/completed) and leave decisions. Event names not in OpenAPI (see Gaps).

## 7. Rules and edge cases
- Inactive staff are hidden (`active_only=true` default assumed; PM to confirm default).
- Status is read-only here; the app never computes availability beyond reading the API data.
- Per-row hours and time-off calls must be fetched lazily and cached; failures degrade to showing no hours, not a screen error.

## 8. Gaps and questions
1. `StaffListItemOut` has no today status, no hours, no on-leave flag and no role. The design needs all three. Proposal: add `today_status` (`with_client|free|on_leave|day_off`), `today_start_time`, `today_end_time` to the list item. Until then the N+1 calls above are a stop-gap (up to 3 calls per person).
2. No role field: design shows "Sr. Barber", the API has free-text `title`. Owner/Manager/Specialist role of a staff user is not in `StaffCreateIn` or `StaffListItemOut` (see P-10).
3. WebSocket channel and event payloads are not in OpenAPI; PM to supply.
4. May a Manager add staff? Instructions US-P-14 says owner; US-P-15 says manager for hours. Confirm.

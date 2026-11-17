# P-10 Add staff

## 1. Goal and roles
Owner adds a team member directly with name and mobile (no invite), picks a role, and optionally copies weekly hours and services from an existing person.
- Owner: full. Manager: pending PM decision (Gap 4 in P-09). Specialist: no access.

## 2. User stories
US-P-14 (PTN-11). Related US-P-16 (services, BR-03).

## 3. Layout
- Ref: `mobile/P-10_add_staff.png`. Back circle button + title "Add staff member"; fields "Full name", "Mobile number" (+94 7X XXX XXXX); "Role" chips (Barber, Stylist, Makeup artist, Manager, single select, selected amber outline); "Copy details from" radio list (first row "Start blank - Salon hours, no services", then each staff: "Name · title", "6 days · 9:00 AM - 6:00 PM · 3 services"); helper text; black full-width pill "Add to team".
- Phone: full screen. Web/tablet: centred modal (max width ~560) with the same form, button bottom-right.
- sb_ui: text field, filter chip, radio list tile, black pill button, back button with Semantics label.

## 4. Data and API map
| UI element | Endpoint | Fields | Errors |
|---|---|---|---|
| Copy source list | GET `/v1/partner/staff` + per-person GET `/v1/partner/staff/{id}/hours` | `service_count`, hours days working, first start/end | |
| Add to team | POST `/v1/partner/staff` | `StaffCreateIn`: `full_name` (required, 1-255), `title` (role label), `phone`, `service_ids`, `copy_from` (staff id), `is_active`=true | 409 (duplicate phone?), 422 (validation), 404, 429 |
| Result | 201 `StaffCreatedOut` | `id`, `full_name`, `title`, `services[]`, `hours[]` | |
| Copy after create (alternative) | POST `/v1/partner/staff/{staff_id}/hours/copy` | `CopyHoursIn.source_staff_id` | 404, 409 |

## 5. Acceptance criteria
1. Given empty name, when user taps Add to team, then inline error "Enter a name" and no request.
2. Given invalid mobile (not +94 7XXXXXXXX or local 07X), then inline error; the number is sent as typed in E.164 (+947XXXXXXXX).
3. Given role chip Barber selected by default, when the user selects another chip, then only that chip is selected.
4. Given "Start blank", then request has no `copy_from` and no `service_ids`.
5. Given a staff row is selected, then request has `copy_from=<id>`; on 201 the new person shows copied hours and services (from `StaffCreatedOut.hours` and `.services`) and time off and gallery are not copied.
6. Button shows progress and is disabled while submitting; double tap sends one request (idempotency key).
7. On 201: go to P-11 for the new `id` (so hours can be tuned) with a success toast "Added to team".
8. On 409/422: show the API message inline; keep the form values.

## 6. States
Loading: copy list skeleton; Add shows spinner. Empty copy list (first person): only "Start blank", pre-selected. Error: toast + inline. Offline: Add disabled with "You are offline".

## 7. Rules and edge cases
- No invite is sent: the person logs in by mobile OTP, so the number must be owned by them (helper text).
- Copy option helper text from design: "Weekly hours and services are copied. Time off and gallery photos are not."
- Does not copy ratings, reviews, bookings.
- Discard changes confirm when leaving with a dirty form.

## 8. Gaps and questions
1. Role: `StaffCreateIn` has no role or permission field. Chips "Barber/Stylist/Makeup artist" are job titles (map to `title`), but "Manager" is an access role. API cannot create a Manager login. Needs field (e.g. `role`: owner|manager|specialist) or separate endpoint.
2. `phone` is optional in the API but required in the design and instructions (login identity). Does the API create a user and link `user_id` from phone? Unclear.
3. Documented copy behaviour: `copy_from` in `StaffCreateIn` vs `/hours/copy`. Confirm that `copy_from` copies both hours and services (design says so); `/hours/copy` is hours only.
4. Error codes for duplicate mobile are not documented beyond generic 409.
5. Design list shows "6 days · hours · N services" summary; API gives only `service_count` on list and hours on a separate call (same N+1 problem as P-09).

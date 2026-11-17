# P-06 New booking

Refs: instructions §3 (P-06), US-P-08, SRS PTN-06, BR-03. PNG: `mobile/P-06_new_booking_sheet.png`. Feature folder `features/new_booking/`.

## 1. Goal and roles
Add a walk-in or phone booking showing only specialists who do the service and only free times.

| Role | Access |
|---|---|
| Owner | all specialists |
| Manager | all specialists |
| Specialist | can add only for themselves (specialist chips locked to self); see Q2 |

Entry: FAB on phone, "+ New booking" black pill top-right on web/tablet, also tapping a free calendar slot (prefills date/time/staff).

## 2. User stories
- US-P-08 (PTN-06, BR-03): add a walk-in or phone booking, see only staff who do the service and free times.

## 3. Layout notes
- Phone: bottom sheet over the calendar titled "New booking · today" (date label "· Thu 29 Oct" when not today). Order: Client text field "Client (empty = walk-in)" with placeholder "Name or mobile"; Service chips; Specialist chips; Free times chips; black full-width "Add booking" pill (PNG). Selected chips use amber tint.
- Web/tablet: modal dialog (max about 560 px), "+ New booking" as entry, adds a date picker and, when the chosen service has options/add-ons, option and add-on selectors.
- Components: `sb_ui` bottom sheet, text field, chip group, black pill button.

## 4. Data and API map
| UI element | Endpoint | Request | Response / fields used | Errors |
|---|---|---|---|---|
| Service chips | `GET /v1/partner/services?active_only=true` | - | `ServiceListOut.categories[].services[]` `ServiceOut`: `id`, `name`, `duration_minutes`, `base_price_cents`, `options[]`, `addons[]`, `staff_count` | 422 |
| Specialist chips (eligible only) | `GET /v1/partner/staff` for names; eligibility per service from `GET /v1/partner/staff/{staff_id}` (services list) | - | `StaffListItemOut.id/full_name`; detail services (see G1) | 422 |
| Client lookup | `GET /v1/partner/clients?q=<text>&limit=5` | `q` name or mobile | `ClientListItemOut`: `user_id`, `full_name`, `phone` | 422 |
| Free times | `POST /v1/availability/slots` | `SlotRequest`: `salon_id`, `services[]` (`service_id`, `option_id`, `addon_ids`), `staff_id` (selected, or null = any), `date`, `mode=single` | `SlotResponse.slots[]`: `start_time`, `utc_start`, `duration_minutes`, `staff_id`, `staff_ids` | 403, 409, 422 |
| Add booking | `POST /v1/partner/bookings` | `PartnerCreateBookingIn`: `salon_id`, `type` (walk-in or phone, values undocumented, G2), `client_name`, `client_phone`, `user_id` (if existing client picked), `services[]` (`BookingServiceItem`: `service_id`, `option_id`, `addon_ids`, `staff_id`), `date`, `start_time`, `notes` | 201 `BookingDetailOut`: `id`, `status`, `total_cents`, `segments[]` | 404, 409, 422, 429 |

Error body `ErrorResponse {code, message, field}`; map `field` to the form field when set (e.g. `client_phone`).

## 5. Acceptance criteria
1. Given the sheet opens, services load from the API; inactive services are not shown.
2. Given a service is selected, specialist chips show only staff who perform it; none shown for others (BR-03). Changing service clears specialist and time.
3. Given service and specialist are chosen, free times load from `/v1/availability/slots` for the date; the app never generates times. Past times never appear (API enforces).
4. "Add booking" is disabled until service, specialist (or "Any" if the API returns slots without staff) and time are selected. Client may stay empty.
5. Empty client: send `client_name="Walk-in"` (localized, see G3) and no `user_id`. Typed text with digits only is treated as `client_phone`; text otherwise as `client_name`.
6. Picking a suggested client sends their `user_id`, `client_name`, `client_phone`.
7. Given 409 (slot just taken), show "That time was just taken", reload slots, keep other selections.
8. On 201 the sheet closes, calendar/Today refresh and show the booking; the price shown comes from `total_cents` (`LKR 2,000`).
9. 422 shows the `message` on the field in `field`.
10. Button shows progress and blocks double submit; the request carries an idempotency key (Dio interceptor).
11. Specialist role: only own name selectable.
12. 44 px targets, strings in ARB, Semantics on close/FAB.

## 6. States
- Loading: chip shimmers for services and times; Add booking disabled.
- Empty: no services -> "Add a service in Services and prices" link (owner/manager); no eligible specialist -> "No specialist does this service"; no times -> "No free times on this day", with date picker on web.
- Error: inline `message` and Retry per section; submit errors stay in the sheet.
- Offline: sheet opens from cache but Add booking disabled ("You are offline"); no offline booking creation.
- Real-time: if a WebSocket booking event takes the selected time, remove the chip and show the note "Time no longer free".

## 7. Rules and edge cases
- Free times, price, duration and deposit come from the API only.
- Multiple services in one booking (several `services[]`) are allowed by the API; the PNG shows single selection. Build single first, multi-select as web follow-up (Q1).
- Service with options or add-ons: option required if the service has options (phone shows a second step).
- Home visit, split, group are out of scope (US-P-12, build order step 5).
- Walk-in "now": default date today; default time is the first free chip, not auto-selected.
- Notes optional, max length per API (unspecified).

## 8. Gaps and questions
- G1: No endpoint returns "specialists eligible for service X". `ServiceOut` has only `staff_count`; `StaffListItemOut` has `service_count`. Eligibility needs `GET /v1/partner/staff/{id}` per staff (N calls) or calling slots without `staff_id` and reading `TimeSlot.staff_ids`. Prefer the latter if confirmed; request `staff_ids` on `ServiceOut`.
- G2: `PartnerCreateBookingIn.type` is a free string; allowed values unknown (assume `walk_in`, `phone`). The PNG has no walk-in/phone toggle; we send `walk_in` when the client is empty, `phone` when a client is chosen. Confirm.
- G3: `client_name` is required but the UI allows an empty client; confirm the accepted placeholder.
- G4: `/v1/partner/clients` lists only clients with completed visits, so a first-time registered client cannot be found by mobile. Request a user lookup or accept new name + phone.
- G5: No payment fields on create (deposit, pay at salon, paid by cash); confirm all partner-created bookings are unpaid, status confirmed.
- Q1: Multi-service selection in phone sheet?
- Q2: May specialists create bookings for others?

# P-21 Settings (booking rules)

Refs: US-P-22, US-P-23; SRS PTN-03, BR-02, BR-06. Mockup: `mobile/P-21_booking_rules.png`. API: `/v1/partner/settings*`.

## 1. Goal and roles
Owner sets how bookings are accepted and what clients pay for late cancellations and no-shows, and manages opening hours, holidays and the payout account. Clients see a preview of the policy.

| Role | Booking rules | Hours, holidays | Payout account |
|---|---|---|---|
| Owner | Edit all | Edit | Edit |
| Manager | View, edit auto-confirm, cancel window, reschedule limit, pay at salon; fee fields read only (instructions: "no fee changes") | Edit | Hidden |
| Specialist | No access | No access | No access |

The API shows no role split on `PUT /v1/partner/settings`; the app hides or disables controls and relies on 403 as the fallback (Q1).

## 2. User stories
US-P-22 (auto-confirm, free-cancel window, late fee, no-show fee, reschedule limit, pay at salon, preview), US-P-23 (opening hours, Poya and public holidays, payout account).

## 3. Layout
- Phone (PNG): back pill, title "Booking rules"; sections with chip groups: Auto-confirm (Everyone, Returning only, Nobody), Free cancellation until (12 h, 24 h, 48 h), Late cancellation fee (No fee, 25%, 50%); preview card "Clients see: ..."; floating black pill "Save settings". Selected chip: amber outline and tint.
- Phone additions (not in PNG, derived from US-P-22): No-show fee chips, Reschedule limit stepper, "Pay at salon" switch.
- Web/tablet: page with tabs or sections: Booking rules (left form, right sticky preview card), Opening hours (7 rows with toggle and times), Holidays (list + "Add closure"), Payout account (owner only). One Save per section.
- Components: `sb_ui` chip, card, switch, black pill, date picker, time field.

## 4. Data and API map
| UI element | Endpoint | Request | Response fields | Errors |
|---|---|---|---|---|
| Load everything | GET `/v1/partner/settings` | | `PartnerSettingsOut`: `salon_name`, `time_zone`, `booking_rules` (`BookingRulesOut`: `auto_confirm`, `cancellation_window_hours`, `cancellation_fee_percent`, `no_show_fee_percent`, `max_reschedules`, `allow_pay_at_salon`), `hours[]`, `holidays[]`, `payout_account`, `home_service`, `warnings[]` | 403 |
| Save rules | PUT `/v1/partner/settings` | `PartnerSettingsUpdateIn {booking_rules: BookingRulesIn}`: `auto_confirm` enum `all`/`returning`/`none`; `cancellation_window_hours` 0..168; `cancellation_fee_percent` 0..100; `no_show_fee_percent` 0..100; `max_reschedules` 0..10; `allow_pay_at_salon` bool. Send only changed fields | `PartnerSettingsOut` | 422 with `field`, 403 |
| Save hours | PUT `/v1/partner/settings/hours` | `PutSalonHoursIn {hours[7]}`: `SalonHoursItemIn {day_of_week, open_time, close_time, is_open}` | `[SalonHoursItemOut]` | 422 |
| Add closure | POST `/v1/partner/settings/holidays` | `CreateHolidayIn {date, reason}` | `HolidayOut {id, date, reason}` (201) | 409 (duplicate date), 422 |
| Remove closure | DELETE `/v1/partner/settings/holidays/{holiday_id}` | | 204 | 404 |
| Payout account | PUT `/v1/partner/settings/payout-account` | `PayoutAccountIn {bank_name, branch, account_name, account_number}` | `PayoutAccountOut {bank_name, branch, account_name, account_number_masked, verified, verified_at}` | 422, 403 |

Mapping chips to fields: Everyone = `all`, Returning only = `returning`, Nobody = `none`; 12/24/48 h = `cancellation_window_hours`; No fee/25%/50% = `cancellation_fee_percent` 0/25/50.

## 5. Acceptance criteria
1. Given the screen opens, then chips are pre-selected from `booking_rules`. A value outside the preset chips (e.g. 36 h or 30%) shows an extra selected "Custom: 36 h" chip, not an empty state.
2. Given I change any chip, then "Save settings" becomes enabled and a leave-without-saving confirm appears on back.
3. The preview card text is generated from the current form values, e.g. "Clients see: free cancellation until 24 h before, then 50% fee. New clients wait for you to accept." Wording by `auto_confirm`: all = "Bookings are confirmed instantly", returning = "New clients wait for you to accept", none = "Every booking waits for you to accept". Fee 0 = "no fee". The preview shows text only and no currency amounts.
4. When I tap Save, then PUT sends only changed `booking_rules` fields; on 200 the form re-syncs with the response and a snackbar shows "Settings saved".
5. On 422, the offending control shows the API `message` (use `field`).
6. Opening hours: 7 rows Mon..Sun with toggle (`is_open`) and open/close times; save is blocked if `close_time <= open_time` for an open day. On save, all 7 days are sent in one PUT.
7. Add closure: pick date and reason, POST; list sorted by date; removing asks to confirm (`danger`) then DELETE. Past dates are listed greyed and cannot be added.
8. Payout account (owner only): shows `bank_name`, `account_number_masked`, "Verified" or "Pending verification" pill. Editing requires full account number again; after save, show "Pending verification" since the API resets `verified` to false.
9. Manager: fee chips are disabled with a hint "Only the owner can change fees"; payout section hidden. Specialist: route guarded.
10. Any `warnings[]` returned by GET or PUT are shown in an amber banner at the top.
11. Does not affect existing bookings: info text "Changes apply to new bookings only" (Q4).

## 6. States
- Loading: skeleton chips and preview card.
- Error (load): retry card; no form shown. Error (save): form stays dirty, snackbar with message.
- Offline: form viewable from cache, Save disabled with banner. Never queue settings writes offline.
- Empty: holidays "No closures added". No payout account: "Add a payout account to receive earnings".
- Real-time: none.

## 7. Rules and edge cases
- Fees shown are API values; the app does not calculate amounts. The app does not know what the percentage applies to (booking price, per API/SRS BR-02), so wording says "% fee".
- Late cancellation fee only makes sense if window > 0; if window is 0, preview says "Cancel any time before the visit".
- `account_number` is never stored on device or logged; field is obscured with show/hide.
- Concurrent edit by another admin: last write wins; GET after save is the truth.
- Holidays: only dates; Poya days are normal closure dates (Q2).

## 8. Gaps and questions
- Q1: Roles. Instructions: Manager "no payout account, no fee changes". OpenAPI declares no per-role security on these endpoints; backend must enforce (403). Which fields exactly can a manager edit?
- Q2: Instructions list "Poya and public holidays". API only has manual closure dates (`/settings/holidays`); no Poya or public-holiday calendar or suggestion endpoint. Not invented here; PM to decide on a hard-coded list from the client or a backend endpoint.
- Q3: The mockup offers only 12/24/48 h and No fee/25/50%, while the API accepts 0..168 h and 0..100%. Confirm the chip presets are final (spec supports Custom display only).
- Q4: Whether new rules apply to existing bookings is not stated in the API.
- Q5: Instructions mention "pay at salon" and "reschedule limit" but the PNG shows neither; layout proposed above.
- Q6: `home_service` settings are returned here but belong to P-08; not edited on this screen.
- Q7: `day_of_week` numbering (0 = Monday or Sunday) and time format (`HH:MM`) are undocumented.

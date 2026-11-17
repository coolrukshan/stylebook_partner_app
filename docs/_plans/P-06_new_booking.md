# P-06 New booking — Implementation Plan
- Spec: [docs/_specs/P-06_new_booking.md](../_specs/P-06_new_booking.md)
- PNG: `mobile/P-06_new_booking_sheet.png`

## 1. Summary and dependencies
Bottom sheet (phone) / modal dialog (web, max ~560 px) to add a walk-in or phone booking: client (optional, with lookup), service chips, eligible specialist chips, free-time chips from the slots API, "Add booking". Entry points: Calendar FAB, "+ New booking" pill (Today, Calendar toolbar), tapping a free calendar slot (prefill).
Depends on: P-01 (session `salonId`, role/permissions, interceptors incl. idempotency, `SbFormat`), P-02 (`SbSkeleton`, `SbEmptyState`, `SbErrorBanner`, `showSbSheet`, `SbReasonChips`-style chip groups, amber-tint chips, `SbSecondaryButton`), P-03 (route entry, `invalidateCalendar`), shared `AvailabilityRepository` (created with P-05 or here; coordinate: path `apps/partner/lib/shared/availability/`). Services are read read-only (P-08 owns editing).
- Existing `sb_ui`: `SbChoiceChip` (selected=ink; PNG uses amber tint, so use the tint variant), `SbSlotChip`, `SbPrimaryButton`; text field comes from P-01 `SbTextField`.

## 2. Files to create / modify
- `apps/partner/lib/features/new_booking/data/new_booking_repository.dart` (`createBooking`), `catalog_repository.dart` (`services`, `staff`), `client_lookup_repository.dart`, `models/{partner_create_booking_in,service_option,catalog_service,staff_member,client_suggestion}.dart` (freezed)
- `apps/partner/lib/shared/availability/*` (if not present from P-05)
- `apps/partner/lib/features/new_booking/application/new_booking_controller.dart` (`NewBookingController extends Notifier<NewBookingState>` with `NewBookingArgs{DateTime? date, String? startTime, String? staffId}`), `catalog_provider.dart`, `client_search_controller.dart` (debounced), `eligible_staff_provider.dart`
- `apps/partner/lib/features/new_booking/presentation/new_booking_sheet.dart` (phone), `new_booking_dialog.dart` (web), `new_booking_form.dart` (shared body), `widgets/{client_field,client_suggestions,service_chips,option_addon_selector,specialist_chips,free_times_section,date_row,form_section}.dart`, `show_new_booking.dart` (adaptive launcher: `showSbSheet` vs `showDialog` by width >= 900)
- `apps/partner/lib/router.dart` (modify: optional deep link `/calendar/new?date=&time=&staff=` that triggers the launcher)
- `packages/sb_ui/lib/widgets/sb_form_section.dart` (label + child), `sb_dialog.dart` (max-width dialog shell with close button) if not added earlier
- `apps/partner/lib/l10n/app_en.arb`

## 3. Data layer
- Services: GET `/v1/partner/services?active_only=true` -> `ServiceListOut.categories[].services[]` `ServiceOut{id, name, duration_minutes, base_price_cents, deposit_cents, requires_patch_test, home_service_eligible, is_active, options[], addons[], staff_count}`. Flatten categories; keep only `is_active`.
- Staff: GET `/v1/partner/staff?active_only=true&limit=` (cursor-paged; read all pages) -> `StaffListItemOut{id, full_name, avatar_url, service_count, ...}`.
- Eligibility (BR-03, Gap G1): preferred approach — call `POST /v1/availability/slots` WITHOUT `staff_id` for (service, date) and derive specialist chips from the union of `TimeSlot.staff_ids`/`staff_id`, mapped to names from the staff list. No separate eligibility endpoint exists; fallback only if the slots response omits `staff_ids`: `GET /v1/partner/staff/{staff_id}` per staff (N calls, cached) reading the services list. Decide which after checking a real response; both live behind `EligibleStaffResolver`. The app never invents times or eligibility.
- Free times: POST `/v1/availability/slots` `SlotRequest{salon_id, services[ServiceSelection{service_id, option_id, addon_ids}], staff_id (selected), date, mode:'single'}` -> `SlotResponse.slots[]`. `salon_id` from session (settings). When the selected staff changes, re-call with that `staff_id`.
- Client lookup: GET `/v1/partner/clients?q=<text>&limit=5` -> `ClientListItemOut{user_id, full_name, phone, ...}` (completed-visit clients only, Gap G4).
- Create: POST `/v1/partner/bookings` `PartnerCreateBookingIn{salon_id, type, client_name, client_phone?, user_id?, services[BookingServiceItem{service_id, option_id?, addon_ids, staff_id?}], date, start_time, notes?}` -> 201 `BookingDetailOut`. `start_time` is sent exactly as returned in the chosen `TimeSlot.start_time`. `type`: `walk_in` when no client picked/typed, `phone` when a client was chosen or typed (G2, constants in one file).
- Error mapping: 409 -> "That time was just taken", reload slots, keep selections (AC 7); 422 with `field` -> map to form field (`client_phone`, `client_name`, `date`, `start_time`, `services`) else banner; 404 (service/staff gone) -> reload catalog; 429 -> backoff message; 403 -> banner; offline -> Add disabled. Idempotency key generated when the sheet opens, reused on retry, regenerated after a success.

## 4. Application / state
- `NewBookingState{ date, serviceId?, optionId?, Set<addonId>, staffId?, startTime?, clientText, ClientSuggestion? pickedClient, notes, AsyncValue<List<TimeSlot>> slots, AsyncValue<List<StaffMember>> eligibleStaff, submit status (idle|submitting|error), fieldErrors map, idempotencyKey }`.
- Rules in controller (pure, unit-tested):
  - selecting a service clears staff + time + options (AC 2); if the service has options, option required before slots load; add-ons optional.
  - selecting staff clears time and reloads slots; "Any" chip is offered only if the slots response without `staff_id` returned slots (AC 4); sending `staff_id=null` in services item then.
  - date change (web date row) clears time, reloads slots; no past dates selectable in picker (display rule only; API enforces times).
  - canSubmit = serviceId && (option if required) && startTime && (staffId or any) && !submitting && online.
  - Client text parsing (AC 5): empty -> `client_name = l10n.walkInName` ("Walk-in"), no user_id; digits/+ only (>= 7) -> `client_phone` set and `client_name` = same text or Walk-in placeholder (G3); otherwise `client_name` text. Picked suggestion -> `user_id`, `client_name`, `client_phone`.
- `ClientSearchController`: debounce 300 ms, min 2 chars, cancel stale requests, `AsyncValue<List<ClientSuggestion>>`; failure silent (lookup is optional).
- `catalogProvider` (services + staff) cached per session; refresh on sheet open; empty services -> state `noServices`.
- Specialist role: `staffId` fixed to own id (read from session, P-01 gap), eligibility check: if own id absent from eligible list -> "You don't do this service".
- On success: pop with `BookingDetailOut`, `invalidateCalendar`, `invalidateToday`, snackbar "Booking added . LKR 2,000" from `total_cents`.
- Real-time: event "time no longer free" -> remove chip and show note (stub; poll slots on resume only). Offline: sheet opens with cached catalog, Add disabled "You are offline".
- Prefill from calendar tap: args set date/staff/time; time only preselected if it appears in returned slots, otherwise ignored.

## 5. Presentation
Phone (to PNG): `showSbSheet(isScrollControlled)` -> `NewBookingForm`:
1. Title "New booking . today" (`headlineSmall`; "· Thu 29 Oct" when other date).
2. `ClientField` (`SbTextField`, label "Client (empty = walk-in)", hint "Name or mobile") + suggestion list (up to 5 rows: name, phone) below the field.
3. `ServiceChips`: `Wrap` of `SbChoiceChip` (amber tint selected). Loading: shimmer chips; empty: `SbEmptyState("Add a service in Services and prices")` with link for owner/manager; error: inline Retry.
4. Option/add-on selector (second step for services with `options`; always shown when present): radio list options (name, duration/price as returned), add-on checkboxes; displays prices from API fields only, no totals computed.
5. `SpecialistChips` (only eligible; "No specialist does this service" empty state; specialist role shows own chip locked).
6. `FreeTimesSection`: `Wrap` of `SbSlotChip` (amber tint selected), shimmer/empty "No free times on this day" (+ date picker on web)/error Retry.
7. Notes (optional `SbTextField`, max 1000 matching `PartnerCreateBookingIn.notes` maxLength; phone collapsed under "Add note").
8. `SbPrimaryButton("Add booking")` pinned to the bottom with safe area; progress while submitting.
Web/tablet: `SbDialog` (max width token ~560) with the same form, a `DateRow` (prev/next + `showDatePicker`), option/add-on selectors inline. Sticky submit.
Loading overall: services shimmer; Add disabled. Error: per-section inline message + Retry; submit errors stay in the sheet.
New shared: `SbFormSection`, `SbDialog`, chip tint variants (from P-02).

## 6. Role rules
- Owner/Manager: all specialists; entry points visible.
- Specialist: entry visible only with manager rights (shared `Permission.createBooking`, Q2); when allowed, staff chip locked to self.
- Enforcement: entry-point widgets check `can(...)`; controller forces `staffId` for specialist; API 403 -> banner.

## 7. Validation, confirmations, formatting
- Client optional; phone text uses E.164 helper from P-01 `Phone.toE164` (+94) before sending `client_phone` (max 30); invalid number-looking text falls back to name with warning-free handling.
- Add booking disabled until service, (option if required), specialist/any, time. No destructive actions, no confirm dialog.
- Money `LKR 2,000` from `total_cents` (snackbar + option/add-on price labels from `price_cents`); dates `Thu 29 Oct`, slot times `h:mm a`; slot value sent verbatim.
- Double submit blocked (status + idempotency key).
- Multi-service (several `services[]`) deferred to web follow-up (Q1); controller stores a single service but the request model is already a list.

## 8. ARB keys
`newBookingTitle`, `newBookingTitleToday`, `newBookingTitleDate` (`date`), `clientLabel`, `clientHint`, `walkInName`, `serviceLabel`, `optionLabel`, `addonsLabel`, `specialistLabel`, `anySpecialist`, `freeTimesLabel`, `notesLabel`, `addNote`, `addBooking`, `bookingAdded` (`price`), `noServices`, `noServicesAction`, `noSpecialist`, `noFreeTimes`, `pickAnotherDay`, `timeTaken`, `timeNoLongerFree`, `offlineCannotAdd`, `retry`, `closeSemantics`, `fabSemantics`, `dateRowPrev`, `dateRowNext`, `errNameRequired`, `errPhoneInvalid`, `errGeneric`.

## 9. Tests
Unit
- Controller: choose service clears staff/time; choose staff reloads slots; canSubmit truth table (service/option-required/time/online); date change clears time.
- Client text parsing table: empty, "0771234567", "+94771234567", "Nimal", "Nimal 077..."; picked suggestion fields; `type` selection (`walk_in` vs `phone`).
- `EligibleStaffResolver`: union of `staff_ids` mapped to names; slots without staff -> empty; fallback path per-staff detail cached.
- Repository: request JSON shape exactly matches `PartnerCreateBookingIn`; `start_time` copied verbatim; query for services `active_only=true`.
- Error mapping: 409 -> reload slots, selections kept; 422 `field=client_phone` lands on field; idempotency key stable across retries, new after success.
- Client search debounce and cancellation (fake async).
Widget
- Phone sheet: loading shimmer -> chips; inactive services not rendered; empty services state with link only for owner/manager.
- Selecting service shows only eligible specialists; none -> message; changing service resets later fields.
- Free times chips only from API; empty/error states; Add booking disabled until complete, shows progress and blocks double tap.
- 409 shows "That time was just taken" and reloads slots; 422 message under field.
- Success closes, triggers invalidation (spy), snackbar shows `LKR 2,000`.
- Specialist: only own chip and locked; entry hidden without rights. Owner/manager role matrix.
- Offline: Add disabled with message. Option required flow (service with options).
- Semantics on close/FAB, 44 px targets, text scale 2.0 at 390 px.
Golden: `new_booking_390.png` (PNG state: Skin fade, Dilan, 6:00 PM), `new_booking_dialog_1280.png`.

## 10. Task checklist
1. Shared `AvailabilityRepository` (or reuse from P-05) + models + tests.
2. Catalog, staff, client-lookup repositories + fixtures + tests.
3. `EligibleStaffResolver` + tests (verify against a real response before locking approach).
4. `NewBookingController` (rules, parsing, submit, errors, idempotency) + tests.
5. `ClientSearchController` debounce + tests.
6. `sb_ui`: `SbFormSection`, `SbDialog` + tests.
7. Form widgets + phone sheet to PNG; states.
8. Web dialog with date row and option/add-on selectors.
9. Entry points: Calendar FAB/toolbar, Today pill, free-slot tap prefill; invalidation hooks.
10. Role/offline tests, goldens 390/1280, analyze + test.

## 11. Open questions / API gaps / risks
- G1 (design risk): no "staff eligible for service" endpoint; plan uses slots without `staff_id` and `staff_ids`. If `staff_ids` is not populated in single mode, N detail calls are needed (slow on large teams). Request `staff_ids` on `ServiceOut`.
- G2: `type` allowed values unknown (`walk_in`/`phone` assumed). G3: `client_name` is required while the UI allows empty; "Walk-in" placeholder assumed accepted. G4: client lookup excludes first-time clients, so a registered but never-completed client cannot be matched; new name+phone are sent without `user_id`. G5: no payment fields on create; unclear if status is confirmed and unpaid.
- `salon_id` is required on slots/create but the app has no salon endpoint; plan uses `/v1/partner/settings.salon_id` (may be owner-only; see P-01 gap 3).
- Option/add-on schema (`options[]`, `addons[]` item fields: id, name, price delta, duration delta) must be read from openapi before the selector is built; whether a service with options requires one is inferred from `options.isNotEmpty`.
- Q1: multi-service on phone; Q2: specialists creating for others (assumed no, locked to self with rights).
- Idempotency header support on POST `/v1/partner/bookings` is not documented.
- Real-time chip removal needs WebSocket contract; only slot refresh on resume for now.
- Prefill from a calendar slot tap requires Calendar (P-03) day grid hit-testing, tablet only in v1.

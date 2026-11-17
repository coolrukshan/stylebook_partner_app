# P-04 Booking detail — Implementation Plan
- Spec: [docs/_specs/P-04_booking_detail.md](../_specs/P-04_booking_detail.md)
- PNG: `mobile/P-04_booking_sheet.png` (P-05 sheets are a separate plan)

## 1. Summary and dependencies
Booking sheet (phone bottom sheet, web side panel) showing header, summary, status actions, client info and below-the-fold sections. Primary black pill and Accept/Decline come from `allowed_actions` filtered by role. Move / No-show / Message are P-05 and plug into the same sheet via slots.
Depends on: P-01 (session, role, interceptors, formatters), P-02 (`BookingActionsRepository`, `BookingAction`, `SbReasonChips`, `SbDangerButton`, `SbSecondaryButton`, `showSbSheet`, `SbSkeleton`, `SbErrorBanner`), P-03 (opens it with a `CalendarBooking` summary; invalidation helper). Feature folder `features/booking_detail/`.
- Existing `sb_ui`: `SbStatusPill` (use for header), `SbCard`, `SbPrimaryButton`. Header status wording "Confirmed" is already correct; "Requested" label needs the partner label (see P-02 plan).

## 2. Files to create / modify
- `apps/partner/lib/features/booking_detail/data/booking_detail_repository.dart` (`getBooking`, `getClient`, `saveClientNote`), `models/{booking_detail,booking_segment,client_detail}.dart` (freezed), `booking_actions_repository.dart` (created in P-02; extended here: returns `BookingDetailOut`)
- `apps/partner/lib/features/booking_detail/application/booking_detail_controller.dart` (`family AsyncNotifier<BookingDetailState, String bookingId>`), `client_summary_provider.dart` (separate `FutureProvider.family` so client failure does not break the sheet), `booking_action_controller.dart` (busy/idempotency/409 handling), `booking_realtime.dart`
- `apps/partner/lib/features/booking_detail/presentation/booking_sheet.dart` (container: header, actions, sections; used by both `showSbSheet` and side panel), `booking_side_panel.dart`, `widgets/{booking_header,info_strip,primary_action_bar,secondary_actions_row,decline_panel,client_section,services_section,visit_plan_section,home_visit_section,patch_test_chip,payment_section,notes_section,dispute_section,booking_sheet_skeleton}.dart`, `booking_presenter.dart` (`BookingVisibleActions` pure function: allowed_actions + status + role -> buttons)
- `apps/partner/lib/router.dart` (modify: `/booking/:id` route that shows the sheet on phone, panel on tablet, deep-linkable)
- `packages/sb_ui/lib/widgets/sb_info_strip.dart` (sand strip), `sb_section.dart` (titled section), `sb_step_timeline.dart` (linked visit-plan steps)
- `apps/partner/lib/l10n/app_en.arb`

## 3. Data layer
- GET `/v1/bookings/{booking_id}` (client route, only "Get Booking" exists; Gap 1) -> `BookingDetailOut{id, reference_code, salon_id, salon_name, user_id, status, date, start_time, total_cents, deposit_cents, cancellation_fee_cents, payment_intent_id, segments[], plan[], notes, patch_test_date, patch_test_booking_id, reschedule_count, allowed_actions[], location_type, visit_mode, party_size, travel_fee_cents, address_snapshot, created_at}`; `BookingSegmentOut{service_id, service_name, staff_id, staff_name, start_time, duration_minutes, price_cents}`.
- GET `/v1/partner/clients/{user_id}` -> `ClientDetailOut{full_name, phone, avatar_url, hair_type, notes, average_interval_days, visit_count, upcoming_bookings, ...}`; 404 for new client (Gap 2) is treated as "no client record", not an error.
- PUT `/v1/partner/clients/{user_id}/notes` (`ClientNotesIn`) for editing private notes (optional in v1; hide the edit control if the body schema is not confirmed; check schema before building).
- POST `/v1/partner/bookings/{booking_id}/{action}` -> `BookingDetailOut` (accept, decline, check_in, start, complete; wire strings in `BookingAction`, Gap 3). Idempotency key per attempt.
- Dispute: GET `/v1/partner/disputes` and POST `/v1/partner/disputes/{dispute_id}/respond`; no booking link (Gap 6) so the dispute section is not built in this pass.
- Error mapping: GET 404 -> `BookingGone` (toast "Booking no longer exists" and pop); 403 (specialist, not own) -> "Not available" and pop; 409 on action -> message, reload detail; 422 -> inline; offline -> cached read-only.
- Header/summary first: sheet receives a `BookingSummary` (from Calendar: client_name, start/end, services, status; from Today: client_name, services[], start/end, status) so it renders instantly (AC 1); the detail call enriches.

## 4. Application / state
- `bookingDetailProvider(bookingId)`: `AsyncNotifier<BookingDetailState{BookingSummary? seed, BookingDetail? detail, bool updatedByOther}>`. `build` emits the seed immediately as data (skeleton only for missing parts) then fetches detail. `reload()` after 409 or realtime event.
- `clientSummaryProvider(userId)`: independent; failure -> client section shows only name (AC 9).
- `BookingActionController` (per booking): state `idle|busy(action)|error`; `perform(action, {reason})`: if busy return (double-tap guard, AC 5), generate idempotency key, call repo, on success replace `detail` with the returned `BookingDetailOut` (status pill and primary label update from API response, AC 2), then `invalidateCalendar` and `invalidateToday`. 409 -> snackbar `message`, `reload()`.
- Real-time: event source stub (same interface as P-02/P-03); fallback: refetch on sheet resume and every 60 s while open; if fetched `status` differs from the last known without a local action, set `updatedByOther` and show "Updated" note.
- Offline: cached last detail; `actionsEnabled=false` with reason text.
- Visible actions (pure, `BookingVisibleActions.resolve(detail, role, permissions)`):
  - terminal statuses (completed, declined, cancelled, expired, no_show) -> none (AC 7).
  - `requested` -> Accept (black) + Decline (white) if `accept`/`decline` in `allowed_actions` and can(manage).
  - `confirmed` -> primary "Check in"; `checked_in` -> "Start"; `in_service` -> "Complete" only when matching action is in `allowed_actions` (hidden, not disabled, AC 3).
  - Move and No-show buttons: only if present in allowed_actions and role/permission (P-05 supplies the handlers; P-04 renders buttons through callbacks `onMove`, `onNoShow`).
  - Call: always when a phone exists. Message: owner/manager always, specialist for own bookings (P-05).
  Action key names in `allowed_actions` are undocumented (Gap 3); the mapping from string to `BookingAction` is in one table and unknown strings are ignored.

## 5. Presentation
Phone (to PNG): `showSbSheet(DraggableScrollableSheet)` -> `BookingSheet`:
1. `BookingHeader`: client name (`headlineSmall`, large), `SbStatusPill`, close `IconButton` (44 px, `Semantics(label: 'Close')`).
2. Line: "service . 1:30 PM - 2:15 PM . with Dilan" (segments joined; end = start + sum of `duration_minutes`, display only; staff names from segments).
3. `SbInfoStrip` "Usually every 4 weeks . paid by card": interval from `average_interval_days` ("Usually every N weeks" via rounding days/7, formatting only); payment text omitted until a method exists (Gap 7); strip hidden when nothing to show.
4. `PrimaryActionBar`: `SbPrimaryButton` (progress while busy) or Accept/Decline pair; decline expands `DeclinePanel` (shared reason chips; "Other" needs text; `SbDangerButton` confirm; Back).
5. `SecondaryActionsRow`: three `SbSecondaryButton` Move, Call, No-show (each hidden individually).
6. Below the fold (`SbSection`): Client (avatar, hair type, notes for salons, visits), Services (segments with `price_cents`, display only), Visit plan (`plan` as `SbStepTimeline` when `plan.length > 1`: time, service, staff), Home visit (address from `address_snapshot`, `travel_fee_cents`) when `location_type` is home, Patch test chip (links to booking `patch_test_booking_id` via route) when `patch_test_date`, Group (party size) when `party_size > 1`, Notes, Payment (`total_cents`, `deposit_cents`, `cancellation_fee_cents` if > 0, `travel_fee_cents` if > 0; all via `SbFormat.money`). Reference photo and Dispute: not rendered (Gap 5, 6).
Loading: header from seed + `BookingSheetSkeleton` for rest. Error: retry `SbErrorBanner` inside sheet; 404 closes. Empty: n/a, optional sections hidden when null.
Tablet/web: `BookingSidePanel` (fixed width token `SbTokens.sidePanelWidth`, add to sb_theme) docked right of calendar/Today with same widgets, sections laid out without sheet scrolling constraints; close button top right.
`address_snapshot` is a free map; render keys `line1, line2, city` etc. defensively through `AddressFormatter` that ignores unknown keys (confirm shape).

## 6. Role rules
- Owner/Manager: all visible actions per `allowed_actions`.
- Specialist: view own bookings (API 403 otherwise -> pop with message); Check in/Start/Complete, Call, Message (P-05); no Accept/Decline/Move/No-show without manager rights (`Permission.manageBookings`).
- Enforcement: `BookingVisibleActions` (unit-tested matrix) + API.
- Client notes only in partner app.

## 7. Validation, confirmations, formatting
- Decline = reason chip required, "Other" text required, `SbDangerButton`; Accept/Check in/Start/Complete no confirm. No-show confirm is P-05.
- Fees and totals displayed as returned, never computed; money `LKR 1,500`; header time range `1:30 PM - 2:15 PM`; sections date `Thu 29 Oct, 9:30 AM`; all in salon tz.
- Double-tap guard + idempotency key reused for retry of the same attempt.
- Call: `url_launcher` `tel:` (add dependency); hidden if no phone.

## 8. ARB keys
`bookingTitleFallback`, `closeSemantics`, `withStaff` (`name`), `timeRange` (`start`,`end`), `usuallyEveryWeeks` (`n`), `paidByCard`, `checkIn`, `start`, `complete`, `accept`, `decline`, `confirmDecline`, `back`, `move`, `call`, `noShow`, `message`, `callSemantics`, `sectionClient`, `sectionServices`, `sectionVisitPlan`, `sectionHomeVisit`, `sectionPatchTest`, `sectionNotes`, `sectionPayment`, `sectionReferencePhoto`, `hairType`, `notesForSalons`, `visitsCount` (`n`), `partyOf` (`n`), `patchTestOn` (`date`), `totalLabel`, `depositLabel`, `cancellationFeeLabel`, `travelFeeLabel`, `bookingGone`, `bookingUpdated`, `actionConflict`, `offlineActionsDisabled`, `retry`, `clientUnavailable`.

## 9. Tests
Unit
- `BookingDetail.fromJson` with fixtures: simple, split plan, home visit, patch test, nulls.
- `BookingVisibleActions.resolve`: matrix status x allowed_actions x role (owner, manager, specialist with/without rights); terminal statuses -> none; unknown action strings ignored; Move absent when not in allowed_actions.
- `BookingActionController`: double tap sends one request; success replaces detail; 409 reloads; idempotency key stable across retry; busy state.
- `clientSummaryProvider`: 404 -> null client without error.
- Interval formatter: 28 days -> "4 weeks", 10 days -> rounded text.
Widget
- Sheet shows header/summary from seed before detail resolves; skeleton for rest.
- Check in -> Start -> Complete labels follow returned status (fake repo sequence).
- Requested shows Accept + Decline; decline panel flow with danger button; confirm disabled until reason.
- Action absent from `allowed_actions` is not in the tree (`findsNothing`).
- Terminal status shows no actions, payment still visible.
- Multi-segment plan renders timeline; home visit shows address + travel fee; patch-test chip; party size.
- Client failure still renders sheet with name only.
- 404 closes sheet with message; other error shows Retry.
- Role matrix widget test; Semantics for close and Call; 44 px targets; text scale 2.0.
- Offline disables actions with reason.
Golden: `booking_sheet_390.png` (confirmed, Check in), `booking_sheet_requested_390.png`, `booking_panel_1280.png`.

## 10. Task checklist
1. `sb_ui`: `SbInfoStrip`, `SbSection`, `SbStepTimeline`, side-panel width token + tests.
2. Models + repositories (+ fixtures) + tests.
3. `BookingVisibleActions` + tests (matrix).
4. Detail controller (seed + fetch + reload), client provider, action controller + tests.
5. Header, actions, decline panel, secondary row to PNG; skeleton/error/404.
6. Below-the-fold sections.
7. Phone sheet + tablet panel containers and `/booking/:id` route; wire from P-02 and P-03.
8. Realtime/poll refresh + "Updated" note; offline.
9. Goldens, role/Semantics tests, analyze + test.

## 11. Open questions / API gaps / risks
- Gap 1 (blocker for quality): no partner booking GET; `/v1/bookings/{id}` may reject a staff token, and lacks client name, avatar, payment method. Mitigation: seed header from the list item; client data from `/v1/partner/clients/{user_id}`. Ask backend for `GET /v1/partner/bookings/{booking_id}`.
- Gap 2: new clients may 404 on client detail, so hair type/notes/photo missing exactly for first-time requests.
- Gap 3: action names and `allowed_actions` vocabulary undocumented; no decline reason body.
- Gap 4: no-show fee preview (P-05 uses `cancellation_fee_cents` only after the fact).
- Gap 5/6/7: no reference photo, no dispute link, no payment method; sections omitted.
- `address_snapshot` shape unknown; rendering defensive.
- Specialist permission claim ("manager rights") unspecified.
- WebSocket contract missing; polling only.

# P-05 Move / no-show / message — Implementation Plan
- Spec: [docs/_specs/P-05_move_noshow_message.md](../_specs/P-05_move_noshow_message.md)
- PNGs: `mobile/P-05_move_booking.png`, `mobile/P-05_no_show_confirm.png`

## 1. Summary and dependencies
Three flows inside the P-04 booking sheet (no own route): Move (free-time chips from the slots API, then reschedule), No-show (confirm panel with fee text, red confirm) and Message (in-app thread with the client). Feature folder `features/booking_detail/` (sub-folders `move/`, `no_show/`, `message/`).
Depends on: P-04 (sheet container, `BookingVisibleActions`, detail controller, action controller), P-02 (`BookingActionsRepository`, `BookingAction`, `SbDangerButton`, `SbSecondaryButton`, `SbSkeleton`, `SbErrorBanner`), P-01 (interceptors, session `salonId`, `SbFormat`). Reuses P-06's `AvailabilityRepository` (slots call); whichever plan lands first creates it in `features/booking_detail/data/availability_repository.dart` (or a shared `core` location agreed with P-06; recommend `apps/partner/lib/shared/availability/`).
- Existing `sb_ui`: `SbSlotChip` (48 high, selected=ink; PNG move chips use amber tint, so reuse the amber-tint choice variant added in P-02 or add `tint` mode to `SbSlotChip`), `SbPrimaryButton`.

## 2. Files to create / modify
- `apps/partner/lib/shared/availability/availability_repository.dart`, `models/{slot_request,slot_response,time_slot}.dart` (freezed; shared with P-06)
- `apps/partner/lib/features/booking_detail/data/reschedule_repository.dart` (`reschedule(bookingId, newDate, newStartTime)`), `settings_rules_repository.dart` (reads `no_show_fee_percent`), `messaging_repository.dart` (`openThread`, `messages`, `send`), `models/{reschedule_request,booking_rules,thread,message}.dart`
- `apps/partner/lib/features/booking_detail/application/move_controller.dart` (`family Notifier<MoveState, String bookingId>`), `no_show_controller.dart`, `message_controller.dart`, `message_composer_state.dart`
- `apps/partner/lib/features/booking_detail/presentation/move/{move_panel,move_slots_wrap,move_date_picker_row,move_staff_selector}.dart`, `no_show/no_show_confirm_panel.dart`, `message/{message_sheet,message_thread_view,message_composer}.dart`
- Modify P-04: `secondary_actions_row.dart` (wire `onMove`, `onNoShow`, add Message), `booking_sheet.dart` (panel state: `none|move|noShow`, mutually exclusive with decline), `booking_visible_actions` (add `canMove`, `canNoShow`, `canMessage`)
- `packages/sb_ui/lib/widgets/sb_slot_chip.dart` or theme file: tint variant; `sb_message_bubble.dart`, `sb_composer.dart` (text field + send)
- `apps/partner/lib/l10n/app_en.arb`

## 3. Data layer
- Slots: POST `/v1/availability/slots` `SlotRequest{salon_id, services[ServiceSelection{service_id, option_id, addon_ids}], staff_id, date, mode:'single'}` -> `SlotResponse{slots[TimeSlot{start_time, utc_start, duration_minutes, staff_id, staff_ids}]}`. Built from `BookingDetailOut.segments` (service_id, staff_id; `option_id`/`addon_ids` are NOT in `BookingSegmentOut`, Gap A). `salon_id` from detail.
- Move: POST `/v1/bookings/{booking_id}/reschedule` `RescheduleRequest{new_date, new_start_time, hold_id?}` -> `BookingDetailOut`. Client route; may reject a partner token (G1). Repository isolates the call; swap to the partner endpoint when it exists. Another-specialist move cannot be expressed (no staff field), so the staff selector is OFF in v1 (hidden by `kMoveToOtherStaff=false`).
- No-show fee: GET `/v1/partner/settings` -> `PartnerSettingsOut.booking_rules.no_show_fee_percent` (check `BookingRulesOut` field name in openapi before coding; may be owner-only: on 403 show the generic policy sentence without percent).
- Confirm no-show: POST `/v1/partner/bookings/{booking_id}/no_show` (wire string assumed, `BookingAction.noShow`) -> `BookingDetailOut` with `status`, `cancellation_fee_cents`.
- Message: POST `/v1/threads` `ThreadCreateRequest{salon_id, user_id}` -> `ThreadCreatedOut{id}`; GET `/v1/threads/{thread_id}/messages?cursor&limit` -> `MessageOut[]` (check the actual list envelope in openapi: items/next cursor); POST `/v1/threads/{thread_id}/messages` `MessageCreateRequest{content, msg_type:'text', idempotency_key}` -> `MessageOut`.
- Error mapping: slots 403/409/422 -> inline with Retry; move 409 -> "That time was just taken" (use `message`), reload slots; move 422/limit errors -> show `message` verbatim (AC 5); no-show 409/422 -> message, reload detail; message 403 -> "You can't message this client"; 429 honour retry.

## 4. Application / state
- `MoveController`: `MoveState{DateTime date (booking date or today), AsyncValue<List<TimeSlot>> slots, TimeSlot? selected, bool submitting, ApiError? error}`. `loadSlots()` on open and on date change; `select(slot)`; `confirm()` -> reschedule -> on success push returned detail into P-04 detail controller, `invalidateCalendar/Today`, close panel, toast "Client notified" ONLY if API confirms (G3: otherwise generic "Booking moved"). 409 -> reload slots, keep sheet and clear selection. Slots never computed or filtered client-side; chips show `TimeSlot.start_time` formatted.
- `NoShowController`: `NoShowState{ rules AsyncValue<BookingRules>, submitting }`. Opening the panel sends NO request (AC 6) except the settings read (cached provider, one call). `confirm()` guarded against double tap (AC 7); on success replace detail; status pill becomes No-show; fee line shown from `cancellation_fee_cents` (AC 8).
- Eligibility: shown only if `no_show` (wire) is in `allowed_actions` and role permits; the client-side "start time passed" rule (AC 9) is NOT re-implemented beyond relying on `allowed_actions` (Q3) — but a defensive check `status in {confirmed, checked_in}` is applied.
- `MessageController` (family by bookingId/userId): `openThread()` once (cached thread id), paginated `messages` (AsyncNotifier with cursor), `send(text)`: creates `idempotency_key` once per draft; on failure keeps the same key for retry; success appends message (optimistic bubble with `sending` -> confirmed -> `failed` + Retry). Poll thread every 15 s while open; WS later (no contract).
- Offline: Move, No-show, Send disabled with "You are offline"; Call unaffected. Messages not queued.
- Real-time: if detail `status/start_time` changes while the panel is open (via P-04 reload), show "Booking was updated", reload slots.

## 5. Presentation
- Move (phone, per PNG): inline expanding section under the action row, titled "Free times for {staff} today" (date label when not today), `Wrap` of `SbSlotChip` (amber tint selected, 48 high, text scale safe), `SbPrimaryButton("Move booking")` enabled on selection, `SbSecondaryButton("Back")`. Loading: chip shimmers (`SbSkeleton`). Empty: "No free times left today. Pick another day" + date picker button. Error: `SbErrorBanner` + Retry.
- Web/tablet: same content in a centred dialog/panel section; `MoveDatePickerRow` (prev/next day + `showDatePicker`) enabled; selector for specialist hidden (v1). Phone gets the date picker too as a small "Pick another day" link (Q2 assumption).
- No-show (per PNG): panel replaces helper area: text "Mark as no-show? The no-show fee is charged under your policy." + "Fee: 50% of the booking" (from `no_show_fee_percent`; LKR amount only if API supplies, G4), `SbDangerButton("Confirm no-show")`, `SbSecondaryButton("Back")`. After success: status pill + "No-show fee {LKR}" row from `cancellation_fee_cents`.
- Message: phone -> `showSbSheet` full height (`isScrollControlled`) with `MessageThreadView` (reverse `ListView`, `SbMessageBubble`) + `SbComposer` (multi-line field, Send black pill disabled when empty, channel hint "Sent in app, SMS if unread" shown only if backed by API, see G5; otherwise "Sent in app"). Web: inline thread section in the side panel.
- New shared sb_ui: slot chip tint, `SbMessageBubble`, `SbComposer`.
- Only one inline panel (decline / move / no-show) open at a time; `AnimatedSize`.

## 6. Role rules
| | Owner | Manager | Specialist |
|---|---|---|---|
| Move | yes | yes | hidden unless manager rights |
| No-show | yes | yes | hidden unless manager rights |
| Message | yes | yes | own bookings only (sheet only opens for own anyway; API 403 otherwise) |
Enforced by `BookingVisibleActions` (+ `Permission` from P-01) and `allowed_actions`; settings read failure (403) degrades only the percent text. Move hidden also for split/group/home bookings (`visit_mode != single` or `location_type` home or `party_size > 1`) until US-P-12.

## 7. Validation, confirmations, formatting
- No-show: explicit confirm panel, red `danger` button, no reason field (Q5 assumption), double-tap guard + idempotency key.
- Move: confirm is the black "Move booking" pill (not destructive); show the new price from returned `total_cents` if it changed (display only).
- Message: trim, non-empty, max length per API (unspecified; soft cap 2000 local UX only, confirm), one `idempotency_key` per draft.
- Format: slot `start_time` -> `h:mm a`; new date/time `Thu 29 Oct, 9:30 AM`; fee `LKR 1,500`; percent from API int as `50%`.

## 8. ARB keys
`moveTitle`, `moveFreeTimesFor` (`staff`, `day`), `moveToday`, `moveBooking`, `moveEmpty`, `movePickAnotherDay`, `moveTaken`, `moveSuccess`, `moveSuccessNotified`, `moveUpdatedMeanwhile`, `noShowTitle`, `noShowConfirmText`, `noShowFeePercent` (`percent`), `noShowFeeAmount` (`amount`), `confirmNoShow`, `back`, `noShowDone`, `messageTitle`, `messageHintInApp`, `messageHintInAppSms`, `messageSend`, `messageEmpty`, `messageSendFailed`, `messageRetry`, `messageNoThread`, `messageSemanticsSend`, `offlineActionsDisabled`, `bookingWasUpdated`, `reschedulesLimitReached` (fallback only), `retry`.

## 9. Tests
Unit
- Slot request builder: from segments -> `ServiceSelection` list, `mode=single`, date `yyyy-MM-dd`, `staff_id` from first segment.
- `MoveController`: load slots, select enables confirm, 409 reloads slots and clears selection, success returns detail and invalidates, empty slots state, date change reloads.
- `NoShowController`: opening panel makes zero POSTs; confirm once on double tap; 409 -> reload; settings 403 -> percent null.
- `MessageController`: opens thread once, send uses stable idempotency key across retry, failure -> failed bubble then retry succeeds, pagination cursor.
- `BookingVisibleActions` additions: Move/No-show hidden for home/group/split; role matrix.
- Repository tests with fake Dio: reschedule body fields, no-show path, thread payloads.
Widget
- Move panel: shimmer then chips from API only; selecting chip enables "Move booking"; 409 shows message, chips reload; empty shows pick-another-day text.
- No-show: tap shows panel, no request sent; text includes percent; danger button; Back returns; after success pill reads "No-show" and fee `LKR 1,500` visible.
- Message: Send disabled when empty; send appends bubble on 201; retry reuses key; offline disables Send but Call remains.
- Specialist: Move/No-show absent, Message present; owner/manager have all.
- Semantics on icon buttons, 44 px targets, text scale 2.0 at 390 px.
Golden: `move_panel_390.png`, `no_show_confirm_390.png`, `message_sheet_390.png`, `move_panel_1280.png`.

## 10. Task checklist
1. Shared `AvailabilityRepository` + models + tests (coordinate with P-06).
2. `sb_ui`: slot chip tint, `SbMessageBubble`, `SbComposer` + tests.
3. Reschedule and no-show repositories; settings rules provider; tests.
4. `MoveController` + `MovePanel` UI + tests, hooked into P-04 panel switcher.
5. `NoShowController` + confirm panel + tests.
6. Messaging repository + controller + sheet/inline UI + tests.
7. Visible-actions updates, offline states, "Booking was updated" handling.
8. Goldens, role/Semantics tests, analyze + test.

## 11. Open questions / API gaps / risks
- G1 (blocker for Move): no partner reschedule endpoint; client route may 403 for staff tokens; no way to move to another specialist or carry `staff_id`. Ask backend for `POST /v1/partner/bookings/{id}/reschedule {new_date,new_start_time,staff_id}`.
- Gap A: `BookingSegmentOut` lacks `option_id` and `addon_ids`; slot recomputation for services with options may differ from the booking. Need these on segments or a partner "reschedule slots" endpoint.
- G2: `no_show` action name unconfirmed. G3: unknown if client is notified on move; toast text conditional. G4: no fee preview; only `no_show_fee_percent` (owner-level settings; manager access unknown). G5: no SMS channel; hint copy depends on PM. G6: threads routes are client-scoped; staff access unconfirmed (salon_id from detail, user_id from `BookingDetailOut.user_id`).
- Q2: date picker on phone assumed; Q3: no-show earliest time via `allowed_actions`; Q4: manager-rights claim; Q5: no reason field.
- Message list pagination envelope and ordering to be confirmed from the real schema; no WebSocket, polling only (15 s).
- Price recalculation on reschedule: display returned `total_cents`, never compute.

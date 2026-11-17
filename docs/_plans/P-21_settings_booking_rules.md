# P-21 Settings (booking rules) — Implementation Plan

- Spec: [docs/_specs/P-21_settings_booking_rules.md](../_specs/P-21_settings_booking_rules.md)
- Design: `mobile/P-21_booking_rules.png` (phone: three chip groups, preview card, black "Save settings"). The PNG shows selected chips with an amber outline and amber tint, while `SbChoiceChip` in `packages/sb_ui/lib/theme/sb_theme.dart` renders selected as solid ink. The style guide and instructions favour black for selected chips elsewhere, so this screen needs a variant (section 5).

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p21-booking-rules`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies

Settings screen with four sections: Booking rules (auto-confirm, cancel window, late fee, no-show fee, reschedule limit, pay at salon, live policy preview), Opening hours (7 rows), Holidays (add/remove closures), Payout account (owner only). Phone shows only Booking rules via More; web/tablet shows all sections as tabs. One Save per section.

Prerequisites:
- Shell, role guard, auth/session (role), Dio with `X-Salon-Id`, `ApiException` with 422 `field` extraction, l10n.
- P-22 More row "Booking rules" -> `/settings/booking-rules` on phone.
- Shared `sb_ui`: skeleton, error card, banner, back pill, danger button (see P-18 plan).
- P-08 owns `home_service` (read-only here, ignored).

## 2. Files to create / modify

`apps/partner/lib/features/settings/`:
- `data/settings_models.dart` (freezed): `PartnerSettings`, `BookingRules`, `BookingRulesPatch`, `SalonHours`, `Holiday`, `PayoutAccount`, `AutoConfirm` enum (`all`, `returning`, `none`), `FieldError`.
- `data/settings_repository.dart`.
- `application/settings_providers.dart`: `partnerSettingsProvider` (`AsyncNotifier`), `bookingRulesFormProvider` (`Notifier` with dirty tracking), `hoursFormProvider`, `holidaysControllerProvider`, `payoutAccountControllerProvider`, `policyPreviewProvider` (pure function over form state).
- `application/policy_preview.dart`: pure `PolicyPreview.compose(rules)` returning structured parts for localization (not strings).
- `presentation/booking_rules_screen.dart` (phone page and tablet tab), `settings_screen.dart` (tablet tabs shell), `widgets/booking_rules_form.dart`, `policy_preview_card.dart`, `opening_hours_editor.dart`, `holidays_editor.dart`, `add_closure_dialog.dart`, `payout_account_card.dart`, `payout_account_form.dart`, `warnings_banner.dart`, `unsaved_changes_dialog.dart`.
- Tests under `apps/partner/test/features/settings/`.

Shell/router:
- `lib/router.dart`: `/settings` (tabs on >= 900 px) and `/settings/booking-rules` (phone page with back pill; on tablet redirects to `/settings?tab=rules`). Role redirect: specialists out.
- Sidebar "Settings" item. Back handling uses `PopScope` for unsaved changes.

sb_ui additions:
- `SbOptionChip` (or a `style: SbChipStyle.tint` option on `SbChoiceChip`): selected = amber border + `SbColors.amberTint` fill + `SbColors.amberDark` text, per PNG; add `enabled` state (disabled chips for manager fee groups, 40% opacity) and `Semantics(selected:, enabled:)`. Needed so the feature does not restyle.
- `SbStepper` (– value +, 44 px buttons with Semantics "Decrease/Increase").
- `SbSwitchRow` (label, helper, `Switch`).
- `SbTimeField` (tap opens `showTimePicker`, displays 12 h from `HH:MM`) and `SbDateField`.
- `SbBanner` (amber/warning), `SbSkeleton`, `SbBackPill`, `SbDangerButton`, `SbSecondaryButton`, `SbStatusPill` usage for Verified/Pending (extend `SbStatus`? Prefer a generic `SbTag(tone)`), `SbFloatingSaveBar` (floating black pill above content).

l10n: `app_en.arb`.

## 3. Data layer

| Method | Path | Notes |
|---|---|---|
| GET | `/v1/partner/settings` | `PartnerSettingsOut {salon_id, salon_name, booking_rules, hours[], holidays[], payout_account?, home_service, time_zone (default Asia/Colombo), warnings[]}` |
| PUT | `/v1/partner/settings` | `PartnerSettingsUpdateIn {booking_rules: BookingRulesIn}`; fields optional: `auto_confirm` enum all/returning/none, `cancellation_window_hours` 0-168, `cancellation_fee_percent` 0-100, `no_show_fee_percent` 0-100, `max_reschedules` 0-10, `allow_pay_at_salon` -> `PartnerSettingsOut` |
| PUT | `/v1/partner/settings/hours` | `PutSalonHoursIn {hours[7]}` of `{day_of_week 0-6, open_time "HH:MM", close_time "HH:MM", is_open}` -> `SalonHoursItemOut[]` (with `id`) |
| POST | `/v1/partner/settings/holidays` | `CreateHolidayIn {date, reason? <=255}` -> 201 `HolidayOut {id, date, reason?}` |
| DELETE | `/v1/partner/settings/holidays/{holiday_id}` | 204 |
| PUT | `/v1/partner/settings/payout-account` | `PayoutAccountIn {bank_name 1-100, branch? <=100, account_name 1-255, account_number min 1}` -> `PayoutAccountOut {id?, bank_name, branch?, account_name, account_number_masked, verified, verified_at?}` (the schema named `app__modules__partner__schemas__PayoutAccountOut`, not the payouts module one with `account_last4`) |

Models: `BookingRules.autoConfirm` is a String in `BookingRulesOut` (not enum), so parse tolerant: unknown value -> keep raw string and show it as a custom state (do not crash).

Repository: `getSettings()`, `updateBookingRules(BookingRulesPatch)`, `putHours(List<SalonHours>)`, `addHoliday(date, reason)`, `deleteHoliday(id)`, `putPayoutAccount(input)`.

Errors: 422 -> `Validation(field, message)`; map `field` (for example `booking_rules.cancellation_window_hours`) to a form control key via a small map and show the message under the control; unmapped goes to a snackbar. 403 -> snackbar "You do not have permission" and reload settings (role changed) . 409 on holiday -> "A closure already exists on this date". 404 on delete -> remove locally and refetch. Network -> keep form dirty, snackbar with retry.

Security: `account_number` is never logged, never persisted, never put in provider state beyond the form controller; clear controller on dispose and after save; Dio logging interceptor must redact this body (add to the shared interceptor config).

## 4. Application / state

- `PartnerSettingsNotifier extends AsyncNotifier<PartnerSettings>`: load on open; `applyResponse(PartnerSettings)` after PUTs; `refresh()`. It holds server truth; forms keep drafts.
- Booking rules form (`BookingRulesFormNotifier`): `original` (server) and `draft` rules. `dirty = draft != original`. `patch()` returns only changed fields (AC4). Chips bind to draft; unmatched values (36 h, 30%) generate an extra "Custom: 36 h" chip prepended (AC1). `save()`: PUT, on 200 re-sync both from response, snackbar `settingsSaved`; on 422 store `fieldErrors`; on other errors stay dirty.
- Preview: `PolicyPreview.compose(draft)` is a pure function producing `PolicyPreviewParts {confirmKind, windowHours, feePercent}`; the widget builds a localized sentence from ARB. Rules: window 0 -> "Cancel any time before the visit"; fee 0 -> "no fee"; no currency amounts. This is text formatting from API fields, not price computation.
- Hours: `HoursFormNotifier` with 7 rows ordered Monday..Sunday for display. `day_of_week` numbering is undocumented (Q7); implement `dayOrder` as a single constant with a unit test, default assumption 0 = Monday (matches Python `weekday()`), confirm with backend. Validation: for open days `close > open` else row error and Save disabled. Save sends all 7 rows.
- Holidays: `HolidaysController` with `add(date, reason)` (POST, insert sorted by date), `remove(id)` (confirm then DELETE). Past dates (before today in `time_zone` from settings) are shown greyed with no delete restriction (spec says cannot be added; deletion allowed) and the picker's `firstDate` is today.
- Payout: `PayoutAccountController`: `save(input)` -> response replaces `payout_account`, showing "Pending verification" as the API resets `verified`.
- Warnings: `settings.warnings` plus PUT responses shown in an amber banner at the top (AC10).
- Loading: skeleton chips and preview. Error load: retry card and no form. Save error: form stays dirty. Offline: form viewable from last loaded state, Save disabled with banner; never queue writes.
- Leave guard: `PopScope(canPop: !dirty)` plus confirm dialog (Discard / Keep editing). On tablet, tab switch with a dirty tab asks the same.

## 5. Presentation

- Phone `BookingRulesScreen`: `Scaffold` transparent; `SafeArea > ListView[ Row(SbBackPill, title), WarningsBanner, section("Auto-confirm") SbOptionChip wrap, section("Free cancellation until") chips 12 h/24 h/48 h (+ Custom), section("Late cancellation fee") chips No fee/25%/50% (+ Custom), section("No-show fee") chips No fee/25%/50%/100%? presets, see risks, Reschedule limit SbStepper (0-10), "Pay at salon" SbSwitchRow, PolicyPreviewCard (SbCard), info text "Changes apply to new bookings only" ]` and a floating `SbPrimaryButton("Save settings")` pinned at the bottom (disabled unless dirty and valid, shows progress while saving).
- Tablet `SettingsScreen`: page title, tabs (`TabBar` styled via theme or `SbChoiceChip` row) Booking rules | Opening hours | Holidays | Payout account (owner only). Rules tab = `Row[ Expanded(form), SizedBox(width 360, sticky PolicyPreviewCard) ]`. Each tab has its own Save.
- Opening hours: 7 rows (`SbSwitchRow` day name, two `SbTimeField`s, inline error). Disabled times when closed.
- Holidays: list (date as "Thu 29 Oct 2026", reason), past rows greyed, "Add closure" secondary button -> `AddClosureDialog` (`SbDateField`, reason field <=255, black "Add"); remove uses a `danger` confirm dialog.
- Payout card: bank name, masked number, `SbTag` "Verified" (success) or "Pending verification" (warning), Edit opens form with obscured account number field (show/hide toggle with Semantics) and requires all fields; empty state "Add a payout account to receive earnings".
- All sizes from `SbTokens`; chips minimum 44 px touch height (wrap `SbOptionChip` in `ConstrainedBox(minHeight: SbTokens.minTouch)`; the base chip is 38); Semantics on steppers, toggles and the show/hide icon; wraps at 200% text.

## 6. Role rules

| Role | Rules | Hours, holidays | Payout |
|---|---|---|---|
| Owner | edit all | edit | edit |
| Manager | edit auto-confirm, cancel window, reschedule limit, pay at salon; fee chips (late fee, no-show fee) disabled with hint "Only the owner can change fees" | edit | hidden (tab and card not built) |
| Specialist | route redirected | no | no |

Enforcement: `Permissions.canEditFees(role)`, `canViewPayout(role)`, `canViewSettings(role)` in `lib/shell/permissions.dart`; form notifier ignores changes to fee fields for managers and omits them from `patch()` (defence in depth); route redirect for specialists; 403 from API shows snackbar and refetches. The cancellation window itself is editable by manager (spec table lists "cancel window" as editable; "fee fields" read-only).

## 7. Validation, confirmations, formatting

- Ranges mirrored from the API (hours 0-168, percent 0-100, reschedules 0-10); chips can never produce invalid values; custom values come only from the server.
- Hours: `close_time > open_time` for open days; format `HH:MM` 24 h on the wire, 12 h display ("9:00 AM").
- Holiday: date required, not in the past, reason <= 255; duplicate date -> 409 message. Remove: confirm with `danger` button ("Remove closure on Thu 29 Oct?").
- Payout: required fields; account number never shown after save; masked value from API; after save display pending state.
- Unsaved changes dialog on back. Saving is not destructive (black pill). Dates: "Thu 29 Oct, 9:30 AM" where time is present; closure dates "Thu 29 Oct".
- Preview shows percentages and hours only; no money.

## 8. ARB keys

`settingsTitle`, `settingsTabRules`, `settingsTabHours`, `settingsTabHolidays`, `settingsTabPayout`, `bookingRulesTitle`, `autoConfirmLabel`, `autoConfirmAll` ("Everyone"), `autoConfirmReturning` ("Returning only"), `autoConfirmNone` ("Nobody"), `freeCancelUntilLabel`, `hoursShort` ({n}) ("{n} h"), `customHours` ({n}), `lateFeeLabel`, `noShowFeeLabel`, `feeNone` ("No fee"), `feePercent` ({n}), `customPercent` ({n}), `feesOwnerOnlyHint`, `rescheduleLimitLabel`, `rescheduleLimitValue` ({n}), `stepperIncrease`, `stepperDecrease`, `payAtSalonLabel`, `payAtSalonHelp`, `policyPreviewPrefix` ("Clients see:"), `policyCancelAnyTime`, `policyFreeUntil` ({hours}), `policyThenFee` ({percent}), `policyThenNoFee`, `policyConfirmAll`, `policyConfirmReturning`, `policyConfirmNone`, `settingsChangesNewOnly`, `settingsSave`, `settingsSaved`, `settingsSaveFailed`, `settingsDiscardTitle`, `settingsDiscardBody`, `settingsDiscard`, `settingsKeepEditing`, `settingsLoadError`, `settingsRetry`, `settingsOfflineBanner`, `settingsNoAccess`, `hoursTitle`, `dayMon`..`daySun` (7 keys), `hoursOpen`, `hoursClosed`, `hoursInvalidRange`, `hoursSaved`, `holidaysTitle`, `holidaysEmpty`, `holidaysAdd`, `holidayDate`, `holidayReason`, `holidayAdd`, `holidayDuplicate`, `holidayPastDate`, `holidayRemoveTitle` ({date}), `holidayRemoveConfirm`, `payoutTitle`, `payoutEmpty`, `payoutBankName`, `payoutBranch`, `payoutAccountName`, `payoutAccountNumber`, `payoutAccountNumberReenter`, `payoutShow`, `payoutHide`, `payoutVerified`, `payoutPending`, `payoutSaved`, `payoutEdit`, `settingsForbidden`.

## 9. Tests

Unit:
- `policy_preview_test`: all 3 `auto_confirm` values, window 0, fee 0, 36 h custom, 30% custom; AC3 example string via ARB.
- `booking_rules_form_test`: dirty flag toggles; `patch()` has only changed fields; custom chip appears for 36 h and 30%; manager draft ignores fee edits; re-sync after save clears dirty.
- `settings_repository_test`: PUT body contains only changed keys; hours PUT sends 7 items; 422 `field` mapped; holiday 409; payout body never logged (interceptor redaction test).
- `hours_validation_test`: close <= open invalid only for open days; `dayOrder` mapping constant.
- `holidays_controller_test`: sorted insert; past date rejected; remove after confirm.

Widget:
- Chips pre-selected from server values; Custom chip shown; Save disabled until a change; back with dirty shows confirm.
- 422 shows message at the offending control; save failure keeps dirty; warnings render the amber banner.
- Opening hours row validation and 7-row save.
- Holidays empty, add, remove confirm uses danger button.
- Payout: owner sees section, manager does not; edit requires account number; pending pill after save; field is obscured and toggles.
- Manager fee chips disabled with hint; specialist redirected.
- States: skeleton, load error retry, offline banner disables Save.
- Text scale 2.0 no overflow.

Golden: `booking_rules_390.png` (matches `mobile/P-21_booking_rules.png` setup: Returning, 24 h, 50%); `settings_rules_1280.png` (form plus sticky preview); optional `settings_hours_1280.png`.

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p21-booking-rules`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. Confirm shell, auth/role, Dio redaction, l10n, shared widgets exist.
2. Add `sb_ui` pieces (`SbOptionChip`, stepper, switch row, time/date field, banner, floating save bar) with widget tests.
3. Models, repository, error/field mapping; tests.
4. `partnerSettingsProvider` and the rules form notifier with dirty/patch logic; tests.
5. Policy preview pure function and card; tests.
6. Phone Booking rules screen, leave guard, save flow; golden 390.
7. Tablet tabs, sticky preview; golden 1280.
8. Opening hours editor and validation.
9. Holidays editor with confirm.
10. Payout section with owner-only gating and obscured field.
11. Role gating (permissions helper, route redirect, disabled fee chips); role tests.
12. ARB strings, text scale tests.
13. `flutter analyze` and `flutter test`.

## 11. Open questions / API gaps / risks

- Q1 manager editable fields: backend declares no role split; app hides/disables and relies on 403. Instructions say "no fee changes" for manager.
- Q2 no Poya/public holiday source in the API. Not invented; Holidays tab only supports manual closure dates. Possible later enhancement: a client-bundled list if PM approves.
- Q3 chip presets vs full ranges: plan offers 12/24/48 h and 0/25/50% only (no-show fee presets are not in the PNG; plan proposes the same No fee/25%/50% set; confirm).
- Q4 effect on existing bookings unknown (info text kept as in spec).
- Q7 `day_of_week` numbering and `HH:MM` format unverified. Also the response `SalonHoursItemOut.open_time` may come with seconds; parse defensively.
- `BookingRulesOut.auto_confirm` is an unconstrained string in the response; guard unknown values.
- `PartnerSettingsUpdateIn` and `PUT /settings/hours` do not declare 401/403 responses in OpenAPI; handled generically.
- `home_service` is returned but ignored here; do not send it back.
- Time zone for "today" (past closure check) comes from `time_zone` in the settings response; the device zone may differ.
- Concurrency: last write wins; after each save the form re-syncs from the response.
- Style conflict: selected chip colour in the PNG (amber tint) vs `SbChoiceChip` (ink). Need design confirmation; plan implements the PNG variant as a new shared widget so other screens are unaffected.

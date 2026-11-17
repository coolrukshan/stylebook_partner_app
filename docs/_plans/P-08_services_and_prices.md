# P-08 Services and prices — Implementation Plan

- Spec: [docs/_specs/P-08_services_and_prices.md](../_specs/P-08_services_and_prices.md)
- Design: `mobile/P-08_services_and_prices.png` (back glass button, title, white cards with name, "30 min · Kasun, Dilan", `-` price `+` stepper, footer note). Editor, packages and home-visit panels extend beyond the PNG.

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p08-services-prices`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies

Owner screen to maintain services grouped by category: quick price stepper (staged, debounced PUT), full editor (duration, deposit, options, add-ons, specialists, toggles), delete (soft), packages (list and create), and salon home-visit settings. Phone shows the PNG list; tablet shows grouped rows plus a side-panel editor and tabs.

Dependencies:
- Shell/router/role guard, session (`role`, `salonId`), Dio with `X-Salon-Id`, `ApiError` (P-01 / shell plan).
- `sb_core` `SbFormat.money`.
- P-09 staff repository (`features/staff/data/staff_repository.dart`) for the specialist multi-select (`GET /v1/partner/staff`). Services plan should call it through a provider `staffOptionsProvider`; if P-09 is not built, create the minimal list method there (single owner of that file is P-09).
- Shared `sb_ui` widgets: `SbStepperButton`, `SbSwitch`, `SbTextField`, `SbSecondaryButton`, `SbDangerButton`, `SbConfirmDialog`, `SbSkeleton`, `SbEmptyState`, `SbErrorPanel`, `SbBackButton` (wrap `SbGlassIconButton`), `SbTabs`/segmented control, `SbSidePanel`.
- Build order: after P-09..P-12, before P-21.

## 2. Files to create / modify

Create under `apps/partner/lib/features/services/`:
- `data/service_models.dart` (freezed: `ServiceCategoryGroup`, `Service`, `ServiceOption`, `ServiceAddon`, `ServiceUpdate`, `ServiceCreate`, `Package`, `PackageItem`, `PackageCreate`, `HomeServiceConfig`)
- `data/services_repository.dart`
- `application/services_providers.dart` (`servicesRepositoryProvider`, `servicesControllerProvider`, `priceStagerProvider` family, `serviceEditorControllerProvider` family, `packagesControllerProvider`, `homeServiceControllerProvider`)
- `presentation/services_screen.dart` (phone list + wide tabs)
- `presentation/service_card.dart` (PNG card with stepper)
- `presentation/price_stepper.dart`
- `presentation/service_editor_panel.dart` (side panel on wide, full-screen route/bottom sheet on phone)
- `presentation/option_addon_table.dart`
- `presentation/specialist_picker.dart`
- `presentation/packages_tab.dart`, `package_create_sheet.dart`
- `presentation/home_visit_tab.dart`
- tests: `apps/partner/test/features/services/**`

Modify:
- `apps/partner/lib/router.dart`: `/services` (+ `/services/:id` editor on phone), guarded for owner (and manager if granted).
- Shell/More: "Services and prices" row (P-22) and sidebar item.
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_ui/lib/theme/sb_theme.dart` or new files under `packages/sb_ui/lib/widgets/` exported from `sb_ui.dart` (only `sb_theme.dart` exists today, so add new widget files and export).
- `packages/sb_core`: `SbFormat.money`, `ApiError`.

## 3. Data layer

Endpoints (openapi.json):
| Method | Path | Body / query |
|---|---|---|
| GET | `/v1/partner/services` | `active_only`, `category_id` -> `ServiceListOut.categories[]` -> `ServiceOut` |
| POST | `/v1/partner/services` | `ServiceCreateIn` (`name`, `base_price_cents`, `duration_minutes` required) -> 201 `ServiceOut` |
| PUT | `/v1/partner/services/{service_id}` | `ServiceUpdateIn` (all optional: `category_id`, `name`, `description`, `base_price_cents`, `duration_minutes`, `deposit_cents`, `requires_patch_test`, `home_service_eligible`, `is_active`, `sort_order`, `options`, `addons`, `staff_ids`) |
| DELETE | `/v1/partner/services/{service_id}` | `DeleteServiceIn {confirm: true}` -> `DeleteServiceOut` |
| GET | `/v1/partner/packages` | `cursor`, `limit` -> `PackageListOut` |
| POST | `/v1/partner/packages` | `PackageCreateIn` -> 201 `PackageOut` |
| GET / PUT | `/v1/partner/home-service` | `HomeServiceUpdateIn {enabled, radius_km, travel_fee_cents, min_notice_hours}` -> `HomeServiceOut` (+ `eligible_services[]`) |
| GET | `/v1/partner/staff` | specialist picker (via P-09 repo) |

Repository `ServicesRepository(Dio)`: `listServices({bool? activeOnly, String? categoryId})`, `createService`, `updateService(id, ServiceUpdate patch)` (serialises only non-null fields via `includeIfNull: false`), `deleteService(id)`, `listPackages({cursor})`, `createPackage`, `getHomeService`, `updateHomeService`.

Important serialization rule: price stepper PUT contains only `base_price_cents`. Option/add-on PUT sends the full list with existing `id`s (omitting may delete).

Error mapping: `ApiError(code, message, field)`. 422 -> field highlight in editor via `field`; 404 on PUT/DELETE -> reload list and toast; 409/422 stating data changed -> reload; deposit-greater-than-price relies on API message (no client clamp).

## 4. Application / state

- `ServicesController extends AsyncNotifier<ServicesState>`; `ServicesState {categories, showInactive}`. `refresh()` on screen focus and pull-to-refresh. Updates merge returned `ServiceOut` into the list by id.
- Price stepper (acceptance 2-3 and rules): `PriceStager` per service id holds `pendingCents?`, `savedCents`, `saving`. `bump(delta)` changes pending (clamped >= 0, delta = step), restarts an 800 ms `Timer`. When the timer fires: if `saving`, mark `queued` and send after the in-flight finishes (single request at a time, latest pending value wins); else PUT `{base_price_cents}`. On 200 set `savedCents` from the response; on error roll pending back to `savedCents` and emit message. Buttons disabled only for rollback? Spec says disabled while saving that row: allow taps (queue into pending) but show a small progress indicator; do not disable `-` except at 0. Flush pending on dispose/navigation (send immediately) or confirm.
- Step constant: one `SbStep` value `priceStepCents = 10000` (LKR 100) defined in `features/services/application/price_step.dart` with a comment referencing Q2; it is a UI input step, not a business computation.
- Editor: `ServiceEditorController` (family by id or "new") holds a draft; `save()` computes the diff against the loaded service and PUTs only changed fields (plus full `options`/`addons`/`staff_ids` when any of those changed). Dirty tracking for discard prompt.
- Delete: `deleteService(id)` -> remove from active list on success.
- Packages: `PackagesController` paging with cursor; `create()` prepends the returned `PackageOut`. Show `original_price_cents`, `discount_percent`, `total_duration_minutes` from the response only.
- Home visit: `HomeServiceController` (`AsyncNotifier`), `save()` PUT; the per-service Home visit toggle checks `homeServiceControllerProvider.enabled`.
- States: loading skeleton cards; empty "Add your first service" with black pill; error panel with Retry; per-row save error inline + rollback; offline: edits disabled with "You are offline" (connectivity provider from shell; if absent, handle `DioExceptionType.connectionError` as the offline message).

## 5. Presentation

Phone (390): `Scaffold` -> header (`SbBackButton` + title) -> `ListView` of `ServiceCard`s (grouped by category with small section labels, PNG shows ungrouped; show headers only when more than one category) -> footer note "New prices apply to new bookings only." (always visible, text muted) -> black "Add service" pill (floating or bottom). Card tap -> editor screen. Packages and Home visit reachable from a segmented control at the top (Services / Packages / Home visits).

Tablet/web (>= 900): page title 27/600, black "+ Add service" pill top-right, `SbTabs` (Services, Packages, Home visits). Services tab: category groups with table-like rows (name, duration, specialists, deposit, price stepper, online toggle); selecting a row opens `ServiceEditorPanel` as a right side panel.

`ServiceCard`: `SbCard` (min 44 px targets) with name `cardName`/title style, subtitle "30 min · Kasun, Dilan" (see G1), `PriceStepper` (`-`, price text, `+`) with Semantics "Decrease price" / "Increase price" labels (ARB). Price uses `context.sb.priceLarge` or a text style from the theme.

`ServiceEditorPanel` sections: name, description, category (dropdown from the returned categories), price, duration, deposit, options table, add-ons table (add/remove rows; removal confirm), specialists multi-select (`SbChoiceChip`s), toggles (Bookable online = `is_active`, Home visit, Needs patch test), black Save pill, red "Hide service" text button.

Specialist names (G1): `ServiceOut` has only `staff_count`. Plan: card subtitle shows "30 min · 2 specialists" (from `staff_count`) by default. Names version requires either an API change or N detail calls; implement optional `serviceStaffNamesProvider` using `GET /v1/partner/staff/{id}` (staff detail has `services[]`) once, build a map service_id -> names, cache for session; degrade to the count on failure. This matches the PNG at the cost of 1+N calls; make it a feature-flagged enhancement behind a single provider so it can be removed when the API adds names.

New shared widgets: `SbStepperButton` (44 px icon button with Semantics label), `SbSwitch`, `SbTextField`, `SbSidePanel`, `SbTabs`, `SbDangerButton`, `SbConfirmDialog`. Tokens only from `SbColors`/`context.sb`; no literals.

## 6. Role rules

- Owner: everything. Manager: view; edit only if granted (Q1). Specialist: no access.
- Implement `Capability.viewServices` (owner, manager) and `Capability.editServices` (owner; manager when claim `can_edit_services` or equivalent exists, else false). With edit false: steppers, toggles, editor Save, Add, delete hidden or disabled with a read-only tag; Packages and Home visit tabs read-only.
- Enforcement: menu hidden by capability; route redirect for specialist to `/`; edit controls read the capability; the API still enforces (403 -> error message).

## 7. Validation, confirmations, formatting

- Numeric fields: non-negative integers (price, duration, deposit, option/add-on price and duration, radius, travel fee, notice hours). Inputs take LKR amounts as whole rupees and convert to cents when sending (`rupees * 100`) — this is unit conversion, not a price calculation; keep it in one `Lkr.parseToCents` helper in `sb_core` with tests.
- Deposit > price: do not clamp; send and show the API message (acceptance 6).
- Delete: `SbConfirmDialog` "Hide Hair colour? Existing bookings are kept." confirm label "Hide service" using `danger`; sends `{confirm: true}`.
- Removing an option or add-on: confirm dialog (danger) because omission may delete.
- Home visit toggle per service disabled with hint when salon home service is disabled.
- Package create: requires at least 2 services and a `package_price_cents`; inline errors; totals displayed from response.
- Money `LKR 1,500` from cents; durations "30 min".

## 8. ARB keys

`servicesTitle`, `servicesPriceFootnote`, `servicesAdd`, `servicesAddFirst`, `servicesEmptyTitle`, `servicesDurationSpecialists` (placeholders `minutes`, `names`), `servicesSpecialistCount` (plural), `servicesTabServices`, `servicesTabPackages`, `servicesTabHomeVisits`, `servicesDecreasePrice`, `servicesIncreasePrice`, `servicesSavingPrice`, `servicesPriceSaveFailed`, `serviceEditTitle`, `serviceFieldName`, `serviceFieldDescription`, `serviceFieldCategory`, `serviceFieldPrice`, `serviceFieldDuration`, `serviceFieldDeposit`, `serviceOptions`, `serviceAddons`, `serviceAddOption`, `serviceAddAddon`, `serviceRemoveOptionTitle`, `serviceRemoveOptionBody`, `serviceSpecialists`, `serviceBookableOnline`, `serviceHomeVisit`, `serviceHomeVisitDisabledHint`, `serviceNeedsPatchTest`, `serviceSave`, `serviceSaved`, `serviceHide`, `serviceHideTitle`, `serviceHideBody`, `serviceHideConfirm`, `serviceReadOnly`, `serviceInvalidNumber`, `packagesTitle`, `packagesAdd`, `packagesEmpty`, `packageName`, `packageServices`, `packagePrice`, `packageDeposit`, `packageMinTwoServices`, `packageOriginalPrice`, `packageDiscount`, `packageDuration`, `homeVisitTitle`, `homeVisitEnabled`, `homeVisitRadiusKm`, `homeVisitTravelFee`, `homeVisitMinNotice`, `homeVisitEligibleServices`, `homeVisitSaved`, `commonOffline`, `commonRetry`, `commonCancel`, `semanticsBack`.

## 9. Tests

Unit:
- `services_repository_test`: list parses categories; PUT price body contains only `base_price_cents`; PUT options sends ids; DELETE body `{confirm:true}`; 422 -> `ApiError.field`.
- `price_stager_test` (fakeAsync): three quick `+` taps -> one PUT after 800 ms with the final value; tap during in-flight request queues exactly one follow-up; failure rolls back to saved and exposes message; `-` at 0 does nothing.
- `lkr_parse_test`: "1500" -> 150000, "1,500.50" rejected or handled per decision, negative rejected.
- `service_editor_controller_test`: diff-only payload; options/addons/staff sent in full when changed; dirty flag.

Widget:
- list: loading, grouped data, empty with Add pill, error with Retry; footer note present.
- stepper buttons have Semantics labels and >= 44 px size; `-` disabled at 0.
- role: owner sees steppers; manager (no grant) read-only; specialist redirected.
- delete dialog text names the service and the confirm button uses danger color (`SbColors.danger`).
- home visit toggle disabled with hint when salon setting off.
- package create blocks fewer than 2 services.
- text scale 2.0 no overflow on `ServiceCard`.
Golden: `services_phone_390.png` (matches PNG: 5 cards + footer), `services_wide_1280.png` (grouped rows + editor panel open).

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p08-services-prices`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. Add/confirm shared widgets in `sb_ui` (`SbStepperButton`, `SbSwitch`, `SbTextField`, `SbSidePanel`, `SbTabs`, `SbDangerButton`, `SbConfirmDialog`, state widgets) with tests and exports.
2. `Lkr` helper + `SbFormat.money` tests in `sb_core`.
3. Models, repository, repository tests.
4. `ServicesController` + list screen (phone) matching PNG; golden 390.
5. Price stager with debounce/queue/rollback + tests.
6. Editor panel (fields, toggles, options/add-ons, specialist picker) + diff save.
7. Delete flow and option/add-on removal confirmations.
8. Wide layout, tabs, side panel; golden 1280.
9. Packages tab (list, create).
10. Home visit tab and per-service toggle dependency.
11. Role capabilities, route guard, nav entries.
12. ARB strings; analyzer and tests clean.

## 11. Open questions / API gaps / risks

- G1: no staff names on `ServiceOut` (see section 5 fallback).
- G2: "Bookable online" maps to `is_active`, which is also soft delete. Risk: toggling off then "Hide" are the same state; UI should treat both as inactive and show inactive services only when `active_only=false`.
- G3: packages cannot be edited, deactivated or deleted (no PUT/DELETE). Build list and create only; show no edit controls.
- G4/G5: patch-test validity and per-service travel fee not configurable.
- G6: "new prices apply to new bookings only" is unconfirmed by the API; footnote shown as designed.
- Q1 manager edit rights: no claim documented; plan defaults to read-only.
- Q2 step size LKR 100 assumed; Q3 deposit/min-duration validation relies on API 422.
- `ServiceOptionIn`/`ServiceAddonIn` semantics when ids omitted (create vs replace) need backend confirmation before enabling the editor in production.
- Category create/rename endpoints do not exist; categories are read-only, new service needs `category_id` from existing categories.
- No endpoint to reorder services beyond `sort_order`; not building drag reorder.

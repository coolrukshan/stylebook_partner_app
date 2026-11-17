# P-10 Add staff — Implementation Plan

- Spec: [docs/_specs/P-10_add_staff.md](../_specs/P-10_add_staff.md)
- Design: `mobile/P-10_add_staff.png` (back circle, "Add staff member", Full name, Mobile number, Role chips, "Copy details from" radio list, helper text, full-width black "Add to team").

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p10-add-staff`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies

Form to add a team member with name, mobile, role chip and an optional "copy hours and services from" source. Full screen on phone, centred modal (max width ~560) on tablet/web. On success go to P-11 for the new id with a toast.

Dependencies:
- P-09 (staff repository, models, `staffListControllerProvider`, route `/staff`) must exist; P-10 appends `create` to that repository.
- P-11 route `/staff/:id` as the success destination.
- Shell/router/role guard, session, `ApiError`, idempotency interceptor from P-01 (Dio adds `Idempotency-Key`; if the interceptor is not generic, add a per-request header option in `sb_api`).
- `sb_ui`: `SbTextField`, `SbChoiceChip` (exists), `SbRadioTile`, `SbPrimaryButton` (exists), `SbBackButton`, `SbConfirmDialog`, `SbToast`.
- Order: after P-09 and P-11.

## 2. Files to create / modify

Create under `apps/partner/lib/features/staff/`:
- `data/staff_create_models.dart` (`StaffCreate` request, `StaffCreated` response with `services[]`, `hours[]`)
- `application/add_staff_controller.dart` (`AddStaffController`, `AddStaffFormState`)
- `application/copy_source_providers.dart` (`copySourcesProvider`: staff list plus per-person summary)
- `presentation/add_staff_screen.dart` (route widget, chooses full screen vs dialog)
- `presentation/add_staff_form.dart` (shared form body)
- `presentation/copy_source_tile.dart`
- `presentation/role_chips.dart`
- tests: `apps/partner/test/features/staff/add_staff_*_test.dart`

Modify:
- `apps/partner/lib/features/staff/data/staff_repository.dart`: add `Future<StaffCreated> create(StaffCreate body, {required String idempotencyKey})`.
- `apps/partner/lib/router.dart`: `/staff/new` (phone: full-screen `GoRoute`; wide: `showDialog` from P-09 button, with the route also usable for deep link using a `CustomTransitionPage`/`DialogPage`).
- `apps/partner/lib/l10n/app_en.arb`.
- `packages/sb_core`: `PhoneNumber.normalizeLk(String)` (see section 7) with tests.
- `packages/sb_ui`: `SbRadioTile`, `SbTextField` (if not yet added).

## 3. Data layer

Endpoints:
| Method | Path | Notes |
|---|---|---|
| POST | `/v1/partner/staff` | `StaffCreateIn`: `full_name` (required), `title`, `bio`, `avatar_url`, `phone`, `email`, `service_ids`, `copy_from`, `is_active`; 201 `StaffCreatedOut` (`id`, `full_name`, `title`, `services[]`, `hours[]`) |
| GET | `/v1/partner/staff` | copy sources (reuse P-09) |
| GET | `/v1/partner/staff/{staff_id}/hours` | summary "6 days · 9:00 AM - 6:00 PM" per source (lazy) |
| POST | `/v1/partner/staff/{staff_id}/hours/copy` | fallback only (hours only), see gaps |

Request model sent: `{full_name, title, phone (E.164), copy_from?: id, is_active: true}`. Blank option omits `copy_from` and `service_ids`. Never send `service_ids` together with `copy_from` unless the API is confirmed to merge them (spec gap 3).

Header: idempotency key generated once per form attempt (UUID stored in controller state and reused for retries and double taps; regenerate after a successful create or after the user edits fields following a 4xx).

Error mapping: 409 and 422 -> `ApiError.message` shown inline on the form (map `field` to `full_name` or `phone` when provided, else a form-level banner); 404 (copy source gone) -> refresh sources and show message; 429 -> toast with retry; network error -> toast and keep values.

## 4. Application / state

- `AddStaffController extends Notifier<AddStaffFormState>` (family-less, autoDispose): `{fullName, phone, roleChip, copyFromId?, submitting, fieldErrors{name,phone}, formError?, dirty}`.
- `submit()`: guards `submitting`; validates locally (empty name -> "Enter a name", invalid phone -> inline); builds request; calls repository; on 201: `ref.invalidate(staffListControllerProvider)`, emit `AddStaffResult(newId)`; the screen navigates with `context.go('/staff/$id')` and shows toast "Added to team". On error: set errors, `submitting=false`, keep values.
- Copy sources: `copySourcesProvider` = `FutureProvider` reusing the P-09 staff list (first page, active) and lazily fetching hours per tile for the "6 days · hours · N services" line (`service_count` comes from the list item). Failure of a summary only hides that line. Empty list (first person): only "Start blank", preselected.
- Role chip state: single select, default Barber. Mapping to `title`: Barber, Stylist, Makeup artist send that label as `title`. "Manager" chip: see gaps; plan hides it unless the API gains a `role` field, OR sends `title: "Manager"` with a visible helper note "Access role is set by the owner separately" — decide with PM (default plan: show chips for the three job titles only and flag Manager as blocked).
- Loading: copy list skeleton; submit spinner on the button. Empty: see above. Error: inline plus toast. Offline: Add disabled with "You are offline".
- Dirty form: `PopScope` plus `SbConfirmDialog` "Discard changes?" (discard is `danger`).

## 5. Presentation

Phone: `Scaffold` (cream background) -> back glass button + title -> scroll body: `SbTextField` Full name, `SbTextField` Mobile (keyboard phone, hint "+94 7X XXX XXXX"), helper text "They will sign in with this number by OTP, so it must be theirs.", `RoleChips` (`Wrap` of `SbChoiceChip`), "Copy details from" section: `SbRadioTile` list (first "Start blank" subtitle "Salon hours, no services", then each person: "Name · title", subtitle summary), helper "Weekly hours and services are copied. Time off and gallery photos are not.", black full-width `SbPrimaryButton` "Add to team" pinned at the bottom (`SafeArea`).

Wide (>= 900): `Dialog` with `ConstrainedBox(maxWidth: 560)`, same `AddStaffForm`, button right-aligned (`expand: false`) in a footer row, Cancel as white pill.

Reuse `AddStaffForm` for both; responsive wrapper decides container. Selected chip uses amber outline (existing `SbChoiceChip`). All text sizes/spacings from theme tokens; 44 px targets; Semantics on back button and radio tiles; text scales to 200% (scrollable body; no fixed heights).

## 6. Role rules

- Owner: full. Manager: provisional (P-09 gap 4); implement via `Capability.addStaff`. Specialist: none.
- Enforcement: route redirect when capability missing (go to `/staff` or `/`); button hidden in P-09; API 403 mapped to a clear message.
- Manager cannot assign Manager role chip (if ever enabled): only owner sees it (`Capability.assignManagerRole`).

## 7. Validation, confirmations, formatting

- Name: trim, 1-255 chars; empty -> "Enter a name"; over 255 -> inline error.
- Phone: accept `+947XXXXXXXX`, `947XXXXXXXX`, `07XXXXXXXX`, `7XXXXXXXX` with spaces/dashes stripped; normalise to `+947XXXXXXXX`; the spec says "sent as typed in E.164" so only normalise, never alter digits. Invalid -> "Enter a valid Sri Lankan mobile number". Helper `PhoneNumber.normalizeLk` returns null if invalid.
- Do not log phone numbers.
- Double tap: `submitting` guard + idempotency key.
- Dirty discard confirm (danger button). No reason fields needed.
- Toast "Added to team" shown after navigation (pass via `SbToast` on the next screen or a global messenger).

## 8. ARB keys

`addStaffTitle`, `addStaffFullName`, `addStaffNameRequired`, `addStaffMobile`, `addStaffMobileHint`, `addStaffMobileInvalid`, `addStaffMobileHelper`, `addStaffRole`, `addStaffRoleBarber`, `addStaffRoleStylist`, `addStaffRoleMakeup`, `addStaffRoleManager`, `addStaffCopyFrom`, `addStaffStartBlank`, `addStaffStartBlankSub`, `addStaffCopySummary` (placeholders `days`, `hours`, `services`), `addStaffCopyHelper`, `addStaffSubmit`, `addStaffSubmitting`, `addStaffAdded`, `addStaffDiscardTitle`, `addStaffDiscardBody`, `addStaffDiscard`, `addStaffKeepEditing`, `addStaffDuplicatePhone`, `addStaffOffline`, `semanticsBack`.

## 9. Tests

Unit:
- `phone_normalize_test`: "0771234567" -> "+94771234567"; "+94 77 123 4567" ok; "94771234567" ok; "0712" invalid; landline "0112345678" invalid.
- `add_staff_controller_test`: empty name blocks request; blank option sends no `copy_from`/`service_ids`; selected source sends `copy_from`; double `submit()` sends one request; 409 and 422 keep values and set `formError`/`fieldErrors`; success invalidates staff list and returns id; idempotency key stable across retry.
- `staff_repository_create_test`: request JSON shape; header key present.

Widget:
- form renders chips with Barber preselected; selecting another deselects the first.
- copy list: only "Start blank" when staff list empty; selecting a person highlights radio; summary line shows.
- inline errors for empty name and invalid phone; no network call (mock repository verify never called).
- submit shows spinner and disables button; success navigates to `/staff/<id>`.
- discard prompt on back when dirty; none when pristine.
- role: specialist redirected; manager per provisional capability.
- wide layout renders a dialog with max width 560; text scale 2.0 no overflow.
Golden: `add_staff_phone_390.png` (compare with PNG), `add_staff_dialog_1280.png`.

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p10-add-staff`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. `PhoneNumber.normalizeLk` in `sb_core` + tests.
2. `sb_ui` `SbRadioTile`, `SbTextField` (if missing) + tests.
3. Models and repository `create` + tests.
4. Controller with validation, idempotency, error mapping + tests.
5. Copy sources provider with lazy summaries.
6. Form widget, phone screen; golden 390.
7. Wide dialog wrapper; golden 1280.
8. Routes, role guard, navigation to P-11 and toast.
9. ARB strings; analyzer and tests clean.

## 11. Open questions / API gaps / risks

- Gap 1: no `role` field in `StaffCreateIn`; Manager chip cannot create a manager login. Titles map to `title`. Needs API `role` or separate endpoint.
- Gap 2: `phone` optional in API but required in UX; unclear whether the API links or creates a login user from the phone. Ask backend; also `email` exists in the schema but is not in the design.
- Gap 3: confirm `copy_from` copies hours AND services; `/hours/copy` is hours only. If `copy_from` only copies hours, follow up with `PUT /v1/partner/staff/{id}` `service_ids` from the source detail.
- Gap 4: duplicate-mobile error code undocumented; relying on message text. Idempotency key support on the server unknown (header name unspecified in OpenAPI); confirm, else the client guard is the only protection.
- Gap 5: summary line needs N hours calls (same N+1 as P-09); limit to visible tiles and cap concurrency.
- Avatar upload: no endpoint; avatar stays initials.
- Wide dialog via go_router deep link needs a dialog page helper; keep it simple (route renders full-page form on wide when opened by URL).

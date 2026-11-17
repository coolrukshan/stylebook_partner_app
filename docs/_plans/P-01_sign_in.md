# P-01 Sign in — Implementation Plan
- Spec: [docs/_specs/P-01_sign_in.md](../_specs/P-01_sign_in.md)
- No PNG exists for this screen; follow style guide §5 (input 48, primary pill 52, link = amber text button).

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** Before starting, run `git status`. If there are any uncommitted changes, **STOP** and ask the user to commit or stash them. Do not proceed on a dirty working tree.
> 2. **Branch from `dev`:** Every plan must start on a new branch created from the `dev` branch (`git checkout dev && git pull origin dev && git checkout -b feature/p01-sign-in`). Never build directly on `dev` or `main`.
> 3. **TDD (Test-Driven Development):** Strictly follow TDD:
>    - Write failing unit/widget tests first (Red).
>    - Implement minimal code to make tests pass (Green).
>    - Refactor while keeping all tests passing (Refactor).
>    - Verify with `flutter test` and `flutter analyze` before marking complete.

## 1. Summary and dependencies
OTP sign-in (phone, then 6-digit code), secure token storage, silent refresh, session bootstrap (`/v1/me` + salon context) and the router guard that every other screen relies on. Email + password tab is NOT built (no partner endpoint, Gap 1).
Prerequisite for everything: P-01 owns the shared plumbing that later plans reuse.
- Shared pieces created here (others reuse, do not recreate): `sb_api` auth/idempotency/salon-id interceptors and `ApiException`; `sb_core` `TokenStorage`, `Role`, `SessionUser`, money/date formatters (`SbFormat`); `sb_ui` `SbTextField`, `SbOtpInput`, `SbTextLink`, `SbErrorBanner`; ARB/l10n setup; router redirect guard.
- Current code: `router.dart` has a single `/` route to a scaffold `TodayScreen`; `buildDio()` has no interceptors; `sb_core` only has `SbConfig`; no l10n folder; app pubspec lacks freezed, json_serializable, build_runner, intl, flutter_localizations, mocktail, flutter_secure_storage (it is in `sb_core` only).

## 2. Files to create / modify
Packages
- `packages/sb_core/lib/src/auth/token_storage.dart` (abstract `TokenStorage` + `SecureTokenStorage` using flutter_secure_storage; in-memory fake for tests)
- `packages/sb_core/lib/src/auth/role.dart` (`enum Role { owner, manager, specialist }`, `Role? parse(String)`), `session_user.dart` (`SessionUser{id, fullName, phone, avatarUrl, role, salonId, salonName, timeZone, staffId?}`)
- `packages/sb_core/lib/src/format/sb_format.dart` (`SbFormat.money(int cents)` -> `LKR 1,500`; `dateTime(DateTime, tz)` -> `Thu 29 Oct, 9:30 AM`; `time`, `dayLabel`; uses `intl` with `en`) and `salon_clock.dart` (convert UTC to salon tz; pick `timezone` package)
- `packages/sb_core/lib/src/errors/api_error.dart` (`ApiError{code, message, field, status, retryAfter}`)
- `packages/sb_core/lib/sb_core.dart` (export all)
- `packages/sb_api/lib/src/api_client.dart` (modify: add interceptors), `interceptors/auth_interceptor.dart`, `interceptors/idempotency_interceptor.dart`, `interceptors/salon_header_interceptor.dart`, `api_exception_mapper.dart`; export from `sb_api.dart`
- `packages/sb_ui/lib/widgets/sb_text_field.dart`, `sb_otp_input.dart`, `sb_text_link.dart`, `sb_error_banner.dart` (export in `sb_ui.dart`; all consume existing tokens; no new colours)
App
- `apps/partner/lib/features/auth/data/auth_repository.dart`, `models/{otp_send_response,sign_in_response,token_response,user_out}.dart` (freezed)
- `apps/partner/lib/features/auth/application/session_controller.dart` (`SessionController extends AsyncNotifier<AuthState>`), `otp_controller.dart` (`OtpSignInController`), `providers.dart` (dio, storage, repo)
- `apps/partner/lib/features/auth/presentation/sign_in_screen.dart`, `widgets/{phone_step,otp_step,resend_countdown}.dart`
- `apps/partner/lib/router.dart` (modify: `/sign-in`, `/` guard, `refreshListenable` bound to session), `apps/partner/lib/app.dart` (add `localizationsDelegates`, `supportedLocales`)
- `apps/partner/l10n.yaml`, `apps/partner/lib/l10n/app_en.arb`
- `apps/partner/pubspec.yaml` (add deps: `flutter_localizations`, `intl`, `freezed_annotation`, `json_annotation`, `flutter_secure_storage` via sb_core, dev: `build_runner`, `freezed`, `json_serializable`, `mocktail`), `packages/sb_core/pubspec.yaml` (`intl`, `timezone`)

## 3. Data layer
Endpoints (all from openapi.json; no invented ones)
| Call | Method + path | Models |
|---|---|---|
| Send code | POST `/v1/auth/otp/send` | `OtpSendRequest{phone}` -> `OtpSendResponse{message, expires_in, retry_after}` |
| Verify | POST `/v1/auth/otp/verify` | `OtpVerifyRequest{phone, otp}` -> `SignInResponse{access_token, refresh_token, token_type, expires_in, is_new_user}` |
| Refresh | POST `/v1/auth/refresh` | `RefreshRequest{refresh_token}` -> `TokenResponse` (store both tokens, rotation) |
| Logout | POST `/v1/auth/logout` | `LogoutRequest{refresh_token}` -> 204 |
| Me | GET `/v1/me` (BearerAuth) | `UserOut{id, phone, email, full_name, avatar_url, role, created_at}` |
| Salon context | GET `/v1/partner/settings` (X-Salon-Id optional) | `PartnerSettingsOut{salon_id, salon_name, time_zone, ...}`; only `salon_id`, `salon_name`, `time_zone` are read |
| Push | POST `/v1/me/device-tokens` | `DeviceTokenIn{token, platform}`, non-blocking, behind a `PushRegistrar` interface (stub until firebase_messaging is added) |

Repository `AuthRepository`: `sendOtp(String e164)`, `verifyOtp(e164, otp)`, `refresh()`, `me()`, `loadSalonContext()`, `logout()`. Returns typed models or throws `ApiError`.
Interceptors (sb_api)
- Auth: attaches `Authorization: Bearer`; on 401 (not on `/v1/auth/*`) performs ONE shared refresh (single-flight `Completer`), stores both new tokens, retries; refresh 401 -> `onSessionExpired` callback -> SessionController signs out with reason `expired`.
- Idempotency: adds `Idempotency-Key` (uuid v4) to POST under `/v1/partner/*` and `/v1/bookings*` unless caller supplies one (needed by P-02/04/05/06). Verify against openapi header name (not documented as a parameter; see Gap 6).
- Salon header: adds `X-Salon-Id` to `/v1/partner/*` once `SalonContext` is set.
- Never log tokens: use no `LogInterceptor` for headers/bodies on `/v1/auth/*`.
Error mapping (`ApiError.fromDio`): parse `ErrorResponse{code,message,field}`; status 429 -> `retryAfter` from body `retry_after` of the send response or `Retry-After` header; connection errors -> `ApiError.offline`; 5xx/502/503 -> `ApiError.server`. Screen-level mapping: send 422 -> phone field error; send 404/409/403 -> "not registered with a salon" copy only if `code` is unknown (message shown as returned, spec section 4); verify 400 -> wrong code, 410 -> expired (offer Resend), 429 -> lock/backoff.

## 4. Application / state
- `SessionController` (AsyncNotifier<AuthState>): `AuthState = unauthenticated(reason?) | authenticated(SessionUser)`. `build()`: read tokens; none -> unauthenticated; else `refresh()` then `me()` + `loadSalonContext()`; failure with 401 -> clear tokens, unauthenticated; network failure -> authenticated from last cached user (read-only/offline, cache user json in secure storage; drift cache arrives with P-02). Methods: `completeSignIn(SignInResponse)` (store tokens, fetch me + salon, role check, register push), `signOut()` (POST logout best effort, clear tokens, clear cached data, invalidate all providers via `ref.invalidateSelf` + a `sessionEpoch` provider every feature watches).
- Role derivation: `UserOut.role` defaults to `client` and carries no salon membership (Gap 2). Plan: map `owner|manager|specialist` strings; anything else -> `NoSalonAccess` state with message "not registered with a salon", tokens cleared, no navigation. `is_new_user == true` also -> NoSalonAccess if me.role is not a salon role. Specialist `staffId` stays null until API provides it (see Gap).
- `OtpSignInController` (Notifier<OtpState>): `OtpState{step phone|code, phone, status idle|sending|verifying, fieldError, bannerError, resendSecondsLeft, expiresIn}`. A `Ticker`-free `Timer.periodic(1s)` drives countdown from `retry_after`. Auto-verify on 6th digit, only when exactly 6 digits; clear boxes on 400; re-enable Resend on 410; 429 resets countdown to returned retry_after.
- Phone normalisation (pure fn in sb_core `Phone.toE164('077...'|'+9477...'|'9477...')`; digits only, `+94` prefix; invalid -> field error before network call).
- Offline: `connectivityProvider` is out of scope for first cut; treat `ApiError.offline` as banner "You are offline" and disable buttons while the last request failed offline (Retry re-enables).

## 5. Presentation
Tree: `SignInScreen` -> `Scaffold(background canvas with amber glow via context.sb gradient)` -> `LayoutBuilder` (>= 900 centred `ConstrainedBox` card, else full-width padded `SingleChildScrollView` with `viewInsets` padding and bottom-pinned `SbPrimaryButton`) -> `AnimatedSwitcher(PhoneStep | OtpStep)`.
- PhoneStep: logo/title (`headlineMedium`), `SbTextField` with fixed `+94` prefix and `keyboardType.phone`, `SbPrimaryButton(Send code)` (shows progress + disabled while sending), NO Email tab (hidden flag `kEmailSignInEnabled = false` in feature `auth_flags.dart`).
- OtpStep: 6 `SbOtpInput` boxes (44+ px each, `Semantics(label: 'Digit n of 6')`, autofill hint `oneTimeCode`, paste handling), error text under boxes, `SbTextLink` Resend ("Resend code in 0:42" disabled until 0), `SbTextLink` Change number, `SbPrimaryButton(Verify)` as fallback.
- NoSalonAccess/expired banners via `SbErrorBanner` (danger tokens) with Retry where relevant.
- Tablet vs phone: only container width/padding differs; card width token: add `SbTokens.authCardMaxWidth` (new token in sb_theme, 440) rather than a literal.
- New shared components (sb_ui): `SbTextField` (wraps TextFormField using inputDecorationTheme, adds label, prefix, error), `SbOtpInput`, `SbTextLink` (TextButton wrapper with min 44 target), `SbErrorBanner`.

## 6. Role rules
- Same screen for all roles. Role is read from server (`/v1/me`), never user-chosen, held in memory plus cached user for offline start; re-read on every refresh/launch.
- Enforcement point: `Role` + `roleProvider` (derived from `SessionController`); `RoleGuard` helper in router: route table has `allowedRoles` per path (specialist blocked from staff management, earnings detail, others' calendars); redirect to `/` (Today) on deny (AC 8). Later screens add their paths to the table; P-01 delivers the mechanism and a unit test with fake routes.

## 7. Validation, confirmations, formatting
- Phone: E.164, max 32, +94 + 9 digits; invalid -> inline error, no request. OTP: exactly `^[0-9]{6}$`.
- No destructive actions; sign-out UI lives in More (P-22) and calls `SessionController.signOut()`; confirm there.
- Formatters delivered here: money from cents (`LKR 1,500`, thousands separator, no decimals unless cents remainder; confirm rule with PM), date `Thu 29 Oct, 9:30 AM`, time `9:30 AM`. Locale `en`; Sinhala/Tamil later.

## 8. ARB keys (app_en.arb)
`appTitle`, `signInTitle`, `signInSubtitle`, `phoneLabel`, `phoneHint`, `sendCode`, `verifyCode`, `otpTitle`, `otpSentTo` (placeholder `phone`), `otpDigitSemantics` (`index`,`total`), `resendCode`, `resendIn` (`time`), `changeNumber`, `errPhoneInvalid`, `errOtpWrong`, `errOtpExpired`, `errTooManyRequests` (`seconds`), `errNotRegistered`, `errSessionExpired`, `errOffline`, `errServer`, `errSmsProviderDown`, `retry`, `signOut`, `roleOwner`, `roleManager`, `roleSpecialist`.

## 9. Tests
Unit
- `Phone.toE164`: `0771234567`, `+94771234567`, `94771234567`, `abc`, 8 digits.
- `SbFormat.money`: 150000 -> `LKR 1,500`, 0, 200000; `dateTime` in `Asia/Colombo` from UTC (09:30 AM boundary, midnight crossing).
- `ApiError.fromDio`: ErrorResponse body, 429 with retry_after, timeout -> offline, non-JSON 502.
- `AuthRepository` with mock Dio adapter: paths, bodies, token rotation stores both tokens.
- Auth interceptor: 401 -> single refresh for 3 concurrent calls, retry succeeds; refresh 401 -> sign out; tokens never in log output.
- `SessionController`: no tokens -> unauthenticated; valid -> authenticated; refresh 401 clears storage; role `client` -> NoSalonAccess; `signOut` clears storage and bumps `sessionEpoch`.
- `OtpSignInController`: send success starts countdown from `retry_after`; 429 resets countdown; verify <6 digits never calls API; 400 clears and errors; 410 enables resend.
Widget
- Phone step: invalid number shows error, valid calls send; Send disabled + progress while loading.
- OTP step: typing 6th digit triggers verify once; resend disabled until 0 (fake timer); Change number returns to step 1; Semantics labels on boxes.
- Text scale 2.0 on 390x844: no overflow.
- Router guard: unauthenticated -> `/sign-in`; authenticated at `/sign-in` -> `/`; specialist deep-linking a manager-only path -> `/`.
Golden: `sign_in_phone_390.png`, `sign_in_otp_390.png`, `sign_in_phone_1280.png` (fonts via bundled Manrope in tests; `GoogleFonts.config.allowRuntimeFetching = false`).

## 10. Task checklist

0. **Pre-flight & Branching (TDD Setup):**
   - Run `git status` — if uncommitted changes exist, **STOP** and ask the user to commit or stash.
   - Checkout `dev`, pull latest, and branch: `git checkout dev && git pull origin dev && git checkout -b feature/p01-sign-in`.
   - Follow TDD: write failing unit/widget tests first before implementing code.

1. Add pubspec deps; `flutter pub get` at root; set up `l10n.yaml`, `app_en.arb`, wire delegates in `app.dart` (verify: `flutter gen-l10n`, analyze).
2. `sb_core`: `SbFormat`, `Phone`, `Role`, `SessionUser`, `ApiError`, `TokenStorage` + tests.
3. `sb_api`: interceptors + exception mapper + tests with `http_mock_adapter`-style fake adapter.
4. freezed models + `AuthRepository` + tests.
5. `SessionController` + `sessionEpoch` + tests.
6. `OtpSignInController` + tests.
7. `sb_ui` widgets (`SbTextField`, `SbOtpInput`, `SbTextLink`, `SbErrorBanner`, token `authCardMaxWidth`) + widget tests.
8. `SignInScreen` phone/otp steps, banners, adaptive layout + widget tests.
9. Router guard + role table + redirect tests; replace scaffold route wiring.
10. Goldens 390/1280; text scale test; `flutter analyze` and `flutter test`.

## 11. Open questions / API gaps / risks
- Gap 1: no partner email+password endpoint; Email tab hidden behind a flag.
- Gap 2 (blocker for role-based UI): neither `SignInResponse` nor `UserOut` carry salon role; `UserOut.role` is a free string defaulting to `client`. Need a documented endpoint/claim for owner|manager|specialist and own `staff_id`. Without it, specialist filtering (`staff_id` on P-02/P-03) cannot be implemented. Interim: decode JWT claims only if backend confirms claim names.
- Gap 3: no "list my salons"; plan uses `/v1/partner/settings` (`salon_id`, `salon_name`, `time_zone`) as the salon context. Risk: settings may be owner-only (403 for specialist/manager); need a lightweight salon-profile endpoint (also needed for P-02 header "Salon name . area").
- Idempotency header name and whether the server honours it is undocumented in openapi (no header param declared on POST routes); confirm.
- OTP error `code` enum missing; UI branches on HTTP status as a fallback.
- Logout invalidates refresh only; access token (15 min) remains valid until expiry.
- drift offline cache is not set up here; "open cached Today offline" (AC 7 offline part) is deferred to P-02, only the cached user is stored now.
- Web: `flutter_secure_storage` on web uses WebCrypto/localStorage; acceptable? Confirm security stance for partner.stylebook.lk.

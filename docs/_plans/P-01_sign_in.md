# P-01 Sign in — Implementation Plan (Revision 3)
- Spec: [docs/_specs/P-01_sign_in.md](../_specs/P-01_sign_in.md) (source of truth for ACs, error codes, ARB copy)
- Contract: `docs/api/openapi.json` (refreshed from the live API 2026-11-21)
- No PNG exists for this screen; follow style guide §5 (input 48, primary pill 52, link = amber text button).

> [!NOTE]
> **Revision 3 decisions (supersede Revision 2):**
> 1. **Sign-in is username + password** (`POST /v1/partner/auth/login`). It returns a **limited** session (calendar view only).
> 2. **Step-up OTP is backend-enforced.** `otp/send` then `otp/verify` upgrades to a **full** session and returns a NEW token pair (replace both stored tokens). No local `stepUpUntil` timer.
> 3. **First login:** temp password (admin-created) -> `must_change_password` -> Verify code -> forced Change password screen -> Today.
> 4. **No sign-up, no self-service reset.** "Forgot password?" = ask your salon owner or StyleBook support.
> 5. **Worker-first landing** unchanged (section 6b). Blocked on `staff_id` (Gap A).
> 6. **PM defaults (override if you disagree):** no "Not now" on Verify code (a limited session is calendar-only, so the user verifies to use the app); non-owner users get Specialist-level UI until the API gives manager vs specialist; one salon only (`salons[0]`), no picker.

> [!IMPORTANT]
> **Prerequisites & Development Workflow:**
> 1. **Check Git Status:** run `git status`. If there are uncommitted changes, **STOP** and ask the user to commit or stash.
> 2. Work on `feature/p01-sign-in` (never on `dev` or `main`).
> 3. **TDD:** failing test first (Red), minimal code (Green), refactor. Verify with `flutter analyze` and `flutter test` before marking complete.

## 1. Status of existing code (P-01a, built under Revision 2)
Reuse as is: `sb_core` (`SbFormat`, `ApiError`, `TokenStorage`, `SalonClock`), `sb_api` interceptors + exception mapper, `sb_ui` (`SbTextField`, `SbOtpInput`, `SbTextLink`, `SbErrorBanner`, `authCardMaxWidth`), l10n setup, router guard + role table, goldens harness.
Change: `sign_in_screen.dart`, `auth_repository.dart`, `session_controller.dart`, `otp_controller.dart` (becomes step-up OTP), `user_out.dart`, `sign_in_response.dart`, `app_en.arb`, auth interceptor refresh path, goldens.
Remove/repurpose: `phone_step.dart`, `auth_flags.dart` (delete), `Phone.toE164` (keep only for masking the user's number), `OtpSignInController` phone step.
Also fix (dev-check findings): literal spacing/sizes/durations in sign-in screens and `sb_ui` widgets -> tokens; 44 px target on `SbTextLink`; literal strings in `today_screen.dart`, `router.dart`, `session_controller.dart` -> ARB.

## 2. Data layer (exact schemas in openapi.json)
| Call | Endpoint | Notes |
|---|---|---|
| Login | POST `/v1/partner/auth/login` `{username<=50, password<=128}` | -> `PartnerLoginResponse{access_token, refresh_token, session:"limited", otp_required_for_full_access, must_change_password, user: PartnerUserOut{id, full_name, salons[{id,name,is_owner}]}}` |
| OTP send | POST `/v1/partner/auth/otp/send` (Bearer, no body) | -> `PartnerOtpSendResponse` (read schema); SMS to account phone, 5 min |
| OTP verify | POST `/v1/partner/auth/otp/verify` (Bearer) `PartnerOtpVerifyRequest` | -> `PartnerFullSessionResponse{session:"full", NEW tokens, must_change_password}` replace both tokens |
| Change password | POST `/v1/partner/auth/password/change` `{current_password,new_password}` | full session only; -> `PartnerFullSessionResponse`; signs out other sessions |
| Refresh | POST `/v1/auth/refresh` | store both tokens; response has no tier (Gap B) |
| Logout | POST `/v1/auth/logout` | best effort |
Salon context: `salons[0]` from login (`id` -> `X-Salon-Id`, `name`); time zone from `/v1/partner/settings` if allowed for the account, else `Asia/Colombo` default (Gap C). `PartnerUserOut` is persisted in secure storage (no profile endpoint).

Error handling by `code`, not HTTP status: `INVALID_CREDENTIALS` (401, generic copy), `ACCOUNT_LOCKED`/`RATE_LIMITED` (429, countdown from `Retry-After`), `ACCOUNT_SUSPENDED`/`ACCOUNT_DISABLED`/`NOT_SALON_MEMBER` (403, "no access" banner, tokens cleared), `RATE_LIMIT_UNAVAILABLE` (503, retry banner), `OTP_INVALID` (400, clear boxes), `OTP_EXPIRED` (410, offer Resend), `OTP_MAX_ATTEMPTS` (429), no pending code (404, prompt Resend), `SMS_DELIVERY_FAILED` (502), no phone (409, "ask support"), `WEAK_PASSWORD` (422, field), `OTP_REQUIRED` (403 on any call). Unknown code: show server `message`.
Interceptors: tokens and passwords never logged. `OTP_REQUIRED` handler: park the request, open Verify code, retry ONCE on success, never loop.

## 3. State
- `SessionState = unauthenticated(reason?) | limited(user, mustChangePassword) | full(user, mustChangePassword)`. Tier set from login (limited) and verify/change (full); after refresh keep last known tier and let `OTP_REQUIRED` correct it.
- `SessionController`: `build()` reads tokens + cached user; refresh; 401 -> clear, unauthenticated; offline -> cached user, read-only. `signIn(username, password)`, `upgradeToFull(response)`, `changePassword()`, `signOut()` (clear tokens/cache, bump `sessionEpoch`).
- Role: `owner` if `salons[0].is_owner`, else `specialist` (interim; Gap D). `staffId` null until Gap A.
- `StepUpController` (replaces local timer): `send()`, `verify(code)`, countdown from the send response, auto-submit at 6 digits, 429/410/400 handling per section 2.
- Router flow: unauthenticated -> `/sign-in`; limited -> `/verify` (Verify code); `mustChangePassword` and full -> `/change-password`; full -> `/` (Today). Calendar-only paths allowed while limited only if the API serves them (Gap E; otherwise everything routes to `/verify`).

## 4. Presentation
- **Sign in:** `SbTextField` username (no autocorrect, `AutofillHints.username`), password with show/hide (`AutofillHints.password`, 44 px toggle, Semantics), black pill **Sign in** (progress + disabled while loading or locked), lockout banner with countdown, muted line "Forgot password? Ask your salon owner or StyleBook support." NO tabs, NO phone, NO sign-up/create-account text.
- **Verify code** (also used as sheet for `OTP_REQUIRED`): "We sent a code to the phone on your account" (no phone shown: `PartnerUserOut` has none), `SbOtpInput` 6 boxes, Resend (countdown), Verify fallback, Cancel only when the sheet was opened by `OTP_REQUIRED`.
- **Change password:** current + new + confirm fields, policy error from `WEAK_PASSWORD`, black pill, no back navigation while forced.
- Layout, `authCardMaxWidth`, text scale 2.0 unchanged from P-01a.

## 5. Role rules
- Role comes from the server, never user-chosen. `RoleGuard` route table (built) stays; later screens add paths.
- Which screens need a full session: everything except the calendar view. Which are additionally role-restricted (owner-only etc.) is the existing table.

### 5b. Worker-first landing
After sign-in every role lands on `/` Today. Specialist = "My bookings" (own `staff_id`), owner/manager see All staff / Me, inline Accept/Decline, Day-view calendar on own column. P-01 delivers the landing route and `staffId` plumbing only; UI is P-02/03/04 (specs already updated by ba). **Hard dependency on Gap A.**

## 6. ARB keys (replace the phone/OTP-login keys; keep OTP keys for step-up)
Add: `usernameLabel`, `passwordLabel`, `showPassword`, `hidePassword`, `signIn`, `forgotPasswordHint`, `errInvalidCredentials`, `errAccountLocked` (`seconds`), `errRateLimited`, `errAccountSuspended`, `errAccountDisabled`, `errNotSalonMember`, `errRateLimitUnavailable`, `verifyTitle`, `verifySubtitle`, `errOtpInvalid`, `errOtpExpired`, `errOtpMaxAttempts`, `errNoPendingCode`, `errNoPhoneOnAccount`, `errSmsFailed`, `changePasswordTitle`, `currentPasswordLabel`, `newPasswordLabel`, `confirmPasswordLabel`, `errPasswordMismatch`, `errWeakPassword`, `savePassword`; keep `resendCode`, `resendIn`, `otpDigitSemantics`, `errOffline`, `errServer`, `errSessionExpired`, `retry`, `signOut`, role keys. Delete phone-only keys (`phoneLabel`, `phoneHint`, `sendCode`, `changeNumber`, `errPhoneInvalid`, `errNotRegistered`, `noAccountHint`, `stepUp*` phone-masked copy).

## 7. Tests (Red first)
Unit: `AuthRepository` paths/bodies and token replacement on login/verify/change/refresh; error mapping by code incl. `Retry-After`; `SessionController` tier transitions (login -> limited, verify -> full, change-password clears `mustChangePassword`, refresh keeps tier, `OTP_REQUIRED` corrects tier, sign-out clears + bumps epoch); `StepUpController` (countdown, auto-submit once at 6, 400/410/429/404/409/502); interceptor: single retry on `OTP_REQUIRED` and no loop, no tokens or passwords in logs; router guard (unauthenticated, limited, mustChange, full, specialist deep link).
Widget: sign-in invalid/empty, loading disabled, wrong credentials banner (generic), lockout countdown, show/hide password, Semantics, absence of phone/Email/sign-up text; Verify code (6th digit once, Resend disabled until 0, Cancel only in sheet mode); Change password (mismatch, weak, success -> Today); text scale 2.0 at 390x844 for all three screens.
Golden: `sign_in_390`, `sign_in_1280`, `verify_code_390`, `change_password_390`.

## 8. Task checklist
0. Pre-flight: `git status` clean, on `feature/p01-sign-in`.
1. Models (`PartnerLoginResponse`, `PartnerUserOut`, `PartnerFullSessionResponse`, `PartnerOtp*`, password change) + `AuthRepository` + tests.
2. `SessionController` tiers + persisted user + tests; update auth interceptor (`OTP_REQUIRED` once, token replacement).
3. `StepUpController` (from `OtpSignInController`) + tests.
4. ARB keys + token fixes (spacing/sizes/targets/literal strings).
5. Sign in screen + tests; delete `phone_step.dart`, `auth_flags.dart`.
6. Verify code screen/sheet + tests.
7. Change password screen + tests.
8. Router flow (`/sign-in`, `/verify`, `/change-password`, `/`) + guard tests.
9. Goldens, text-scale, `flutter analyze`, `flutter test`.
10. PM: update backlog, update instructions doc lines 21/59 and US-P-00a; code-reviewer reviews the branch.

## 9. Open items for backend / PM
- **Gap A (blocker for P-02/03/04):** `PartnerUserOut` lacks `staff_id` and `member_type` (manager vs specialist). Ask backend to add both.
- **Gap B:** `/v1/auth/refresh` response has no `session` tier or documented claim; confirm tier survives refresh.
- **Gap C:** `/v1/partner/settings` may be owner-only; no salon time zone for staff. Need a light salon-profile endpoint.
- **Gap D:** Manager role not in API; non-owners treated as Specialist for now.
- **Gap E:** limited-session allowed endpoints undocumented (only "calendar view"); confirm list and 403 shape.
- Password policy and rate-limit numbers undocumented; suspended-account token rejection code; 409 no-phone `code`; whether `/v1/me` and `/v1/me/device-tokens` work for partner accounts (push registration stays stubbed); admin create needs `Idempotency-Key`? (affects P-10: staff logins are admin-created only); support contact details for "Forgot password?"; web token storage stance.

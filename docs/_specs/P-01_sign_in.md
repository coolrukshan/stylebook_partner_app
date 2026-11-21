# P-01 Sign in, OTP step-up and forced password change

Feature folder: `apps/partner/lib/features/auth/`. Sources: instructions §3 (P-01), US-P-00a, US-P-00b, `docs/api/openapi.json` (refreshed 2026-11-21: API-56, API-57, API-58). No PNG exists for these screens.

Revision: aligned to the REAL partner credential contract. The "proposed endpoint" assumption and the old BLOCKER (Gap 1) are closed. Sign-in is USERNAME + PASSWORD. The session is two-tier: login gives a LIMITED session, an SMS OTP upgrades it to FULL. The tier is enforced by the backend, not by the app.

## 1. Goal and roles
Get a salon user into the app with a username and password, then let them unlock the full app with an SMS code. Same screens for all roles.
- Accounts are created by a StyleBook admin (`POST /v1/admin/salons/{salon_id}/accounts`, `member_type` owner|staff). The temporary password is shown once to the admin and handed over out of band. No invite, no sign-up, no self-service reset.
- Owner, Manager, Specialist: all sign in the same way. What each can do afterwards is decided by role (section 7 and Gap 6).
- Forgot password: no endpoint. The app shows "Ask your salon owner or StyleBook support". The owner cannot reset it in the app (reset is admin-only: `POST /v1/admin/accounts/{user_id}/reset-password`), so the text for non-owners says "ask your salon owner to contact StyleBook support". Support contact comes from config.

Screens in this feature:
1. **Sign in** (username, password).
2. **Verify code sheet / page** (OTP step-up): shown right after login and again whenever a call needs a full session.
3. **Change password** (new, forced when `must_change_password` is true, also reusable from More later).

## 2. User stories
| Story | SRS | Covered how |
|---|---|---|
| US-P-00a | PTN-11 | Username + password sign-in (`/v1/partner/auth/login`), OTP step-up, forced password change. Story text in the instructions still says "mobile number" (Gap 11) |
| US-P-00b | none | Owner vs not-owner from `PartnerUserOut.salons[].is_owner`; Manager vs Specialist NOT available (Gap 6) |

## 3. Layout notes
- Web/tablet (>= 900 px): centred card on the cream page with amber glow, logo, title, form. Max width from `sb_ui` tokens. Verify code and Change password use the same card (no modal on tablet, a full-screen route; on phone a full-screen route too, not a bottom sheet, because they gate the app).
- Phone: full-width form, keyboard-aware, primary pill pinned above keyboard.
- Components: `SbTextField`, `SbErrorBanner`, black pill primary button, `SbTextLink` for "Forgot password?", `SbOtpInput` (6 digits, existing) on Verify code.
- **Sign in**: Username (no autocapitalise or autocorrect, `AutofillHints.username`, trimmed, max 50). Password (obscured, `AutofillHints.password`, max 128, eye toggle). Done submits. Button disabled until both non-empty. No password-strength check on sign-in. No sign-up link.
- **Verify code**: title, "We sent a 6-digit code to +9477***4567" (`phone_masked` from the API, never the number from the client), `SbOtpInput`, "Resend code" link disabled with countdown from `retry_after`, "Sign out" text link (always available as a way out).
- **Change password**: Current password, New password, Confirm new password (client-only match check), eye toggles (44 px, Semantics), a short hint text of the policy (the policy itself is not in the API: Gap 7), black pill "Change password". When forced there is no back/skip; only Sign out.
- 44 px targets, Semantics labels, error banner live region, 200 % text scale scrolls without clipping.

## 4. Data and API map

### 4.1 Endpoints
| UI element | Endpoint | Request | Response used | Errors (by `code`) |
|---|---|---|---|---|
| Sign in | POST `/v1/partner/auth/login` (public) | `PartnerLoginRequest{username (1..50), password (1..128)}` | `PartnerLoginResponse{access_token, refresh_token, token_type, expires_in (900), session:"limited", otp_required_for_full_access, must_change_password, user: PartnerUserOut{id, full_name, salons[PartnerSalonOut{id, name, is_owner}]}}` | 401 `INVALID_CREDENTIALS`; 403 `ACCOUNT_SUSPENDED`, `ACCOUNT_DISABLED`, `NOT_SALON_MEMBER` (only after the password was verified); 429 `ACCOUNT_LOCKED` (Retry-After) or `RATE_LIMITED`; 503 `RATE_LIMIT_UNAVAILABLE`; 422 `VALIDATION_ERROR` |
| Send code (also "Resend") | POST `/v1/partner/auth/otp/send` (Bearer, no body; works from limited or full) | none | `PartnerOtpSendResponse{message, phone_masked, expires_in (300), retry_after (60)}` | 409 (account has no phone; code value not documented), 429 `RATE_LIMITED`, 502 `SMS_DELIVERY_FAILED`, 503 `RATE_LIMIT_UNAVAILABLE`, 401, 403 (not a partner credential account, or suspended) |
| Verify code | POST `/v1/partner/auth/otp/verify` (Bearer) | `PartnerOtpVerifyRequest{otp ^[0-9]{6}$}` | `PartnerFullSessionResponse{access_token, refresh_token, token_type, expires_in, session:"full", must_change_password}` | 400 `OTP_INVALID`, 410 `OTP_EXPIRED`, 404 `NOT_FOUND` (no pending code), 429 `OTP_MAX_ATTEMPTS` or `RATE_LIMITED`, 503, 401 (bad token, or session not from a password login), 403 |
| Change password | POST `/v1/partner/auth/password/change` (Bearer; FULL session required; the only route open while `must_change_password` is true) | `PartnerPasswordChangeRequest{current_password (1..128), new_password (1..128)}` | `PartnerFullSessionResponse` (NEW tokens; all other sessions are signed out) | 400 `INVALID_CREDENTIALS` (current wrong), 403 `OTP_REQUIRED`, 422 `WEAK_PASSWORD`, 429 `RATE_LIMITED`, 503 |
| Silent refresh | POST `/v1/auth/refresh` | `RefreshRequest{refresh_token}` | `TokenResponse{access_token, refresh_token, token_type, expires_in}` (rotation: store both). No `session` field (Gap 1) | 401 `TOKEN_EXPIRED`/`TOKEN_INVALID`/`TOKEN_REVOKED`/`TOKEN_NOT_FOUND`/`TOKEN_TYPE_MISMATCH`; 403 `ACCOUNT_SUSPENDED`; 429 |
| Sign out | POST `/v1/auth/logout` | `LogoutRequest{refresh_token}` | 204, idempotent | 401 `TOKEN_INVALID` (still clear locally) |
| Push registration | POST `/v1/me/device-tokens` | `DeviceTokenIn{token, platform}` | `DeviceTokenOut` | non-blocking. Only after FULL session; unknown whether a partner credential account may call it (Gap 9) |
| Forgot password | none | | | guidance text only |

Removed from the old spec: `/v1/me` (client `UserOut`) as the role source, `/v1/auth/otp/send|verify` (client OTP endpoints), `/v1/auth/social`, `/v1/auth/guest*`, `/v1/admin/auth/*`. None of these are used by P-01. Admin endpoints (accounts, reset-password) are not in the Partner app.

Error body is `ErrorResponse{code, message, field}`. Map by `code`, never by HTTP status. Unknown code: show `message` (server text is safe to show) or a generic localised fallback by status class. 429 reads `Retry-After` header; it is also the source for the countdown.

### 4.2 Error code to UI mapping
| `code` | Where | UI |
|---|---|---|
| `INVALID_CREDENTIALS` (login 401) | Sign in | ONE generic inline message "Username or password is incorrect"; clear password, keep username, refocus password |
| `INVALID_CREDENTIALS` (password change 400) | Change password | field error on Current password "Current password is incorrect" |
| `ACCOUNT_LOCKED` | Sign in | banner "Too many attempts. Try again in mm:ss" using `Retry-After`; Sign in disabled until it ends |
| `RATE_LIMITED` | Sign in, send, verify, change | banner with countdown if `Retry-After` present, else "Too many requests, try again shortly" |
| `RATE_LIMIT_UNAVAILABLE` | any | banner "Service temporarily unavailable" + Retry (server-side outage, not the user's fault) |
| `ACCOUNT_SUSPENDED` | login, refresh | "This account is suspended. Contact StyleBook support"; tokens cleared |
| `ACCOUNT_DISABLED` | login | "This account has been disabled. Contact your salon owner or StyleBook support" |
| `NOT_SALON_MEMBER` | login | "This account has no salon access"; session cleared |
| `OTP_INVALID` | Verify | OTP boxes shake and clear, inline "That code is not right" |
| `OTP_EXPIRED` | Verify | "Code expired" with "Send a new code" |
| `OTP_MAX_ATTEMPTS` | Verify | "Too many wrong codes" and force "Send a new code" (resend limited by `retry_after`) |
| `NOT_FOUND` (verify 404) | Verify | "No code is waiting. Send a new code" |
| `SMS_DELIVERY_FAILED` | Send | "We could not send the SMS. Try again" + Retry |
| 409 on send (no phone) | Send | "No mobile number on this account. Contact StyleBook support" (blocking, only Sign out available) |
| `OTP_REQUIRED` (403, any call) | any | open Verify code, retry the original call after success (section 7) |
| `WEAK_PASSWORD` | Change password | field error on New password, show server `message` (policy text) |
| `TOKEN_*` on refresh | any | clear tokens, go to Sign in with "Session expired" |
| `VALIDATION_ERROR` | any | field error from `field` |

## 5. Acceptance criteria
Sign in
1. Given both fields are non-empty, when the user taps Sign in (or Done), then `POST /v1/partner/auth/login` is called once with trimmed username and the raw password; button shows progress, fields disabled.
2. Given either field is empty, then Sign in is disabled and no request is made.
3. Given 200, then `access_token` and `refresh_token` go to `flutter_secure_storage`, the session tier is set to `limited`, and `user` (id, full_name, salons) is kept in session state. Password is dropped from memory.
4. Given 200 and `must_change_password = true`, then the app goes to Verify code (step-up) and then to the forced Change password screen; no other screen is reachable until the password is changed.
5. Given 200 and `must_change_password = false`, then the app goes to Verify code (full access is needed for everything but the calendar view). A "Not now, view calendar only" link is shown only if the PM approves it (Gap 2); until then it is hidden and Verify code is mandatory.
6. Given `INVALID_CREDENTIALS`, then the password clears, focus returns to it, one generic message shows; the username stays.
7. Given `ACCOUNT_LOCKED` or `RATE_LIMITED`, then a banner shows with a countdown from `Retry-After`; Sign in is disabled until it ends; the app never retries by itself.
8. Given `ACCOUNT_SUSPENDED`, `ACCOUNT_DISABLED` or `NOT_SALON_MEMBER`, then the specific message in 4.2 shows and no tokens are stored.
9. Given `salons` is empty (should not happen after `NOT_SALON_MEMBER`), then show "This account has no salon access" and clear the session.
10. Given the password field, then it is obscured by default; the eye toggles it with Semantics label/state; visibility resets on leaving or backgrounding.
11. Given "Forgot password?", then guidance sheet shows; no request is made.
12. There is no sign-up entry point.

OTP step-up
13. Given the Verify code screen opens, then `POST /v1/partner/auth/otp/send` is called once automatically (not on every rebuild) and `phone_masked` is shown. A hot reload or screen rotation does not resend.
14. Given the user enters 6 digits, then `POST /v1/partner/auth/otp/verify` is called once with `{otp}` using the current (limited) access token; the button/inputs show progress.
15. Given verify returns 200, then BOTH stored tokens are REPLACED by the new pair, the tier becomes `full`, and the user continues to the destination (original deep link, forced Change password if `must_change_password`, else Today). The old tokens are discarded and never used again.
16. Given `OTP_INVALID`, `OTP_EXPIRED`, `OTP_MAX_ATTEMPTS`, 404 or 429, then the messages in 4.2 show; the user can request a new code when `retry_after` has passed. Resend is disabled with a countdown until then; a new code invalidates the previous one.
17. Given 409 (no phone), then a blocking message shows with Sign out only.
18. Given the user taps Sign out on Verify code, then `/v1/auth/logout` is called with the refresh token, tokens are cleared and the app returns to Sign in. (If Gap 2 is approved, "Not now" instead keeps the `limited` session and opens the read-only calendar.)

Limited vs full
19. Given a limited session, then only the Calendar view (P-03, read only) is reachable; every other route, tab and action is hidden or opens Verify code. Anything the app is unsure about is shown behind step-up (Gap 3: allowed list is not documented).
20. Given any API call returns 403 `OTP_REQUIRED`, then the request is parked, Verify code opens, and on success the call is retried once with the new token; on cancel the screen that made the call shows its error/empty state and no data. The app never loops.
21. Given a call returns 401 and refresh succeeds, then the call is retried once with the new access token. If refresh gives `TOKEN_*` the app signs out with "Session expired".
22. Given the tier after a refresh is unknown (Gap 1), then the app keeps the stored tier and relies on 403 `OTP_REQUIRED` as the correction signal; it never assumes `full` beyond what the last verify said.

Change password
23. Given `must_change_password = true` after verify (or login+verify), then Change password is the only reachable screen; the router redirects every other route to it. The only other action is Sign out.
24. Given Current, New and Confirm are filled and New == Confirm, then `POST /v1/partner/auth/password/change` is called once with `{current_password, new_password}`. Confirm is never sent.
25. Given 200, then both tokens are REPLACED, the tier stays `full`, a snackbar "Password changed. Other devices were signed out" shows and the app goes to Today (or the saved deep link).
26. Given `WEAK_PASSWORD`, then the server `message` shows on New password; fields keep their values except password fields are cleared on `INVALID_CREDENTIALS`.
27. Given 403 `OTP_REQUIRED` (full session lapsed), then Verify code opens, then the change is retried (the typed values are kept in memory only, never stored).
28. Given the new password equals the current one, the server decides; the app shows whatever `code`/`message` it returns.

General
29. Given a stored session at launch, then the app refreshes silently (`/v1/auth/refresh`), replaces both tokens, keeps the stored tier, and opens Today (full) or Calendar (limited). `TOKEN_*` returns to Sign in with "Session expired".
30. Tokens and passwords are never logged, put in URLs or error reports. Sign out clears tokens, session tier, user and cached data (drift).
31. Strings in ARB; 44 px targets; Semantics on eye toggles, OTP digits, banners; works at 200 % text scale on phone and tablet.
32. Given a signed-out user opens a deep link, they go to Sign in then, after the required step-up, to the original link if their role allows it, else Today.

## 6. States
- Loading: buttons show progress; inputs disabled; spinner on silent refresh at launch.
- Empty: not applicable (forms).
- Error: inline field errors, generic credential error, banners for network/5xx with Retry, lockout/rate-limit banners with countdown.
- Offline: Sign in, Send/Verify code and Change password disabled with "You are offline". An existing session opens cached Today (drift) read-only; any action that would need a full session is blocked offline.
- Real-time: none. Session expiry mid-use shows Sign in with "Session expired". A password change on another device signs this one out: the next refresh returns `TOKEN_*` and the same path applies.

## 7. Rules and edge cases

### 7.1 Two-tier session (backend enforced)
- Tier is an attribute of the token pair the server issued. The app only mirrors it for routing and hiding UI; it never grants access by itself. There is NO app-side timer or grace window (the old `stepUpUntil` concept is removed).
- How the app learns the tier:
  - Login response: `session = "limited"`, `otp_required_for_full_access = true`.
  - Verify and password change responses: `session = "full"`.
  - Refresh response (`TokenResponse`) has no `session`. A JWT claim is not documented, so the app must not decode the token to read the tier (Gap 1). Until clarified: keep the last known tier and let 403 `OTP_REQUIRED` correct it.
- What works in limited: the calendar view (per login doc: "it can view the calendar"). Everything else needs full. The exact endpoint list is not documented (Gap 3); the partner endpoints in the spec list no 401/403 responses at all, including `/v1/partner/calendar` and `/v1/partner/today`.
- Gating UI in limited: only P-03 in read-only mode. Today (P-02) and the rest show Verify code. Tapping a booking in limited opens Verify code instead of P-04 (P-04 and P-05 actions are not calendar view).
- OTP requirement can come back at any time (a full session may end or be downgraded). Handle 403 `OTP_REQUIRED` on every call through one interceptor (section 8). Do not depend on a documented list.
- Password change keeps the user at full tier and signs out all other sessions of the account. Other devices will fail refresh with `TOKEN_REVOKED`.
- Refresh token reuse (replay) revokes all of the user's refresh tokens (`TOKEN_REVOKED`). The app must therefore serialise refreshes (one in flight; others wait) and must store the NEW pair atomically. Never reuse an old refresh token after verify or password change.

### 7.2 Role, salon, staff (what `PartnerUserOut` gives)
`PartnerUserOut{id, full_name, salons[{id, name, is_owner}]}`.
- Gap 2 (old) narrowed: the API gives `is_owner` per salon and the list of salons. So Owner vs not-owner is KNOWN. Multi-salon (old Gap 7 "list my salons") is SOLVED: `salons[]` is the list; `X-Salon-Id` takes `salons[].id`. One salon: set it automatically. Several: show a salon picker after sign-in (small new screen or sheet, not in P-01 scope, see Gap 8) and send `X-Salon-Id` on all `/v1/partner/*` calls (69 operations declare this header).
- Still MISSING: `staff_id` of the signed-in worker, `member_type` and any Manager/Specialist distinction. `member_type` (owner|staff) and `staff_id` exist only in admin schemas (`PartnerAccountCreateIn`, `PartnerAccountItem`). `PartnerUserOut` has no phone, username or role. Result:
  - P-02 "My bookings", the Me switch, P-03 own-column default and Specialist clamp, P-04 own-booking check are STILL BLOCKED on `staff_id` (hard dependency stays, but the ask is now narrow: add `staff_id` and `member_type` to `PartnerUserOut` or per `PartnerSalonOut`).
  - Manager vs Specialist: not distinguishable. Until clarified, the app treats `is_owner = true` as Owner and everything else as "staff" (Specialist-level UI) and relies on the API to return 403 for forbidden actions. Manager screens (Staff management, leave approval, New booking) would be hidden from non-owners that are really managers: PM to decide (Gap 6).
- `PartnerUserOut` is returned only by login. `TokenResponse`, verify and password-change responses do not carry it. So the app must persist `user` (non-secret fields) at login and cannot re-read it on cold start. A partner profile endpoint does not exist; `/v1/me` returns the client `UserOut` and it is not documented whether it works for a partner account (Gap 4). Role changes by an admin are not picked up until the next login.

### 7.3 Other rules
- Rate limiting and lockout are server-side only; the app does not count attempts, shows `Retry-After`/`retry_after` and never retries automatically.
- Do not store the password; allow OS autofill; clear password state after the request.
- First login: the account always has a temporary password and `must_change_password = true`. Flow: Login -> Verify code -> Change password -> Today. Change password needs a full session, which is why verify comes first.
- No phone on the account: step-up cannot send a code (409). Admin create requires `phone`, so this should only happen with legacy data (Gap 10).
- Credentials, tokens, OTPs: never in logs; HTTPS only.
- Idempotency: the partner auth endpoints take no idempotency header. (Admin create takes `Idempotency-Key`/`X-Idempotency-Key`; not used by this app, see Gap 12.)

## 8. Impact on built code (do not edit in this task)
Under `apps/partner/lib/features/auth/` and `packages/`:
- `data/auth_repository.dart`: add `login(username, password)`, `sendOtp()` (no phone argument, Bearer), `verifyOtp(otp)` -> `PartnerFullSessionResponse`, `changePassword(current, new)`. Remove the client OTP sign-in and phone-based send/verify methods.
- New models: `PartnerLoginResponse`, `PartnerUserOut`, `PartnerSalonOut`, `PartnerOtpSendResponse` (`phone_masked`, replaces the old `OtpSendResponse`), `PartnerFullSessionResponse`. Remove `sign_in_response.dart` (`is_new_user`) and the phone-based `user_out.dart` for sign-in.
- `application/session_controller.dart`: state holds `tier` (limited|full), `mustChangePassword`, `user`, `activeSalonId`. Remove any `stepUpUntil`/grace-window code and the `/v1/me` role load. Replace tokens atomically on login, verify, password change and refresh. Persist non-secret `user` and `tier`.
- `application/otp_controller.dart`: send/verify now use the Bearer token and replace the session; no phone input. Keep resend countdown from `retry_after`.
- `presentation/`: rewrite `sign_in_screen.dart` (username/password); remove `phone_step.dart`, `auth_flags.dart`; keep `otp_step.dart` / `SbOtpInput` as the Verify code screen; add `change_password_screen.dart`.
- `router.dart`: redirects driven by session: signed out -> Sign in; `mustChangePassword` -> Change password (after verify) ; limited -> Calendar only / Verify code; full -> role routes. Existing deep-link-after-login logic stays.
- `packages/sb_api` interceptors:
  - Auth header: Bearer from the CURRENT stored access token (not captured at call time, so a replaced token is used on retry).
  - 401 -> single-flight refresh via `/v1/auth/refresh` (public, no Bearer), replace both tokens, retry once. `TOKEN_*` -> sign out.
  - New 403 `OTP_REQUIRED` handler: park the request, raise step-up through a callback, retry once on success, fail on cancel. Must also handle `/partner/auth/password/change`.
  - `X-Salon-Id` header on `/v1/partner/*` from `activeSalonId`.
  - Map errors by `ErrorResponse.code`; read `Retry-After` into the exception (`api_exception_mapper.dart`).
  - Never log Authorization or bodies of auth calls.
- ARB: keep `signInTitle`, `signInSubtitle`, `errOffline`, `errServer`, `errSessionExpired`, `retry`, `signOut`, role keys, `otpTitle`, `otpSentTo` (now with `phone_masked`), `otpDigitSemantics`, `resendCode`, `resendIn`, `errOtpWrong`, `errOtpExpired`, `errTooManyRequests`, `errSmsProviderDown`. Remove `phoneLabel`, `phoneHint`, `sendCode`, `changeNumber`, `errPhoneInvalid`, `errNotRegistered` (replaced).
- New ARB keys: `usernameLabel`, `usernameHint`, `passwordLabel`, `passwordHint`, `showPassword`, `hidePassword`, `signIn`, `forgotPassword`, `forgotPasswordHelpOwner`, `forgotPasswordHelpStaff`, `errCredentials`, `errAccountLocked` (with minutes:seconds), `errRateLimited`, `errServiceUnavailable`, `errAccountSuspended`, `errAccountDisabled`, `errNoSalonAccess`, `errOtpMaxAttempts`, `errOtpNoPending`, `errNoPhoneOnAccount`, `otpResendWait`, `otpNotNow`, `changePasswordTitle`, `changePasswordForcedSubtitle`, `currentPasswordLabel`, `newPasswordLabel`, `confirmPasswordLabel`, `passwordPolicyHint`, `errCurrentPasswordWrong`, `errPasswordMismatch`, `errWeakPassword`, `passwordChanged`, `selectSalonTitle`, `errOtpRequired`.

## 9. Gaps and questions
Closed since the last revision: old Gap 1 (no login endpoint; now API-56), old Gap 3 (change password now API-58; reset is admin-only), old Gap 4 (credential error codes are listed), old Gap 5 (step-up phone: admin create requires `phone`; send returns 409 if absent), old Gap 8 (`ACCOUNT_DISABLED`, `NOT_SALON_MEMBER`), multi-salon list (`salons[]`).

For backend:
1. **Tier after refresh.** `/v1/auth/refresh` returns `TokenResponse` with no `session` field and its doc does not say whether a refresh of a full session stays full or drops to limited. No JWT claim is documented. Ask: does refresh preserve the tier, how long does a full session last, and expose a `session` field (or documented claim).
2. **Skip step-up?** Can the user stay in a limited session indefinitely (calendar only)? Product question for PM: allow "Not now, view calendar only" or force OTP at every login.
3. **Limited-session allowed endpoints.** Only "calendar view" is documented. List the exact allowed operations (`GET /v1/partner/calendar` only? `/today`? `GET /v1/partner/bookings/{id}`?), and add 401/403 (`OTP_REQUIRED`) to every partner operation's responses. Today only `/partner/auth/password/change` documents `OTP_REQUIRED`.
4. **No partner profile endpoint.** `PartnerUserOut` is only in the login response. Need `GET /v1/partner/me` (or equivalent) returning the same plus `staff_id`, so the app can re-read role/salons on launch and after refresh. Confirm whether `/v1/me` works for partner accounts.
5. **Rate limits.** Numeric limits (login attempts, lock duration, OTP send/verify attempts, per-hour caps) are not documented. Needed for UX copy only; the app follows `Retry-After`/`retry_after`.
6. **Role granularity.** `PartnerUserOut`/`PartnerSalonOut` lack `staff_id` and `member_type`; there is no manager vs specialist distinction (admin `member_type` is only owner|staff). Is "Manager" a role the API supports? If so how is it exposed (and which `/v1/partner/*` actions does it allow)? Until answered, the P-02/03/04 `staff_id` blocker remains but is narrowed to "add `staff_id` (and `member_type`) to `PartnerUserOut`".
7. **Password policy** (min length, complexity, history) is not documented; `WEAK_PASSWORD` message text is the only source. Request the rules (or a stable `message`) so the form can show a hint.
8. **Salon picker.** Confirm: a user with several salons must send `X-Salon-Id`; what happens if it is missing or not one of `salons[]` (error code)? Is a salon picker needed in the Partner app (new screen, PM)?
9. **Device tokens for partner accounts.** Does `POST /v1/me/device-tokens` accept partner credential accounts and does it need a full session?
10. **No-phone accounts.** Send returns 409 with an undocumented `code`. Provide the code value, and confirm the admin flow always sets a phone.
11. **Instructions/SRS conflict.** `docs/STYLEBOOK_PARTNER_APP_INSTRUCTIONS.md` (lines 21 and 59) says "Mobile OTP or email + password", and US-P-00a says "with the mobile number". Both conflict with the username + password + OTP step-up model. SRS PTN-11 text must be checked. PM to update.
12. **Idempotency on admin create.** `POST /v1/admin/salons/{salon_id}/accounts` takes `Idempotency-Key`/`X-Idempotency-Key`; docs do not say whether the header is required and a replay cannot return the password again. Not used by this app (admin-only), but P-10 "Add staff" (`StaffCreateIn` has no username/password) must not promise to create a login: account creation is admin-only, so P-10 cannot offer "create login" (PM to confirm).
13. **Forgot password.** No self-service. Confirm support contact details (config) and whether owners can reset staff passwords in the Partner app (today only `POST /v1/admin/accounts/{user_id}/reset-password`).
14. **Suspension while signed in.** Refresh returns 403 `ACCOUNT_SUSPENDED`; confirm access tokens (15 min) of a disabled account are rejected immediately and the `code` used (401 vs 403).

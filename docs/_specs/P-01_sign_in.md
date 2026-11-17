# P-01 Sign in

Feature folder: `apps/partner/lib/features/auth/`. Sources: instructions §3 (P-01), US-P-00a, US-P-00b. No PNG exists for this screen.

## 1. Goal and roles
Get a salon user into the app with a mobile OTP (and email + password, see Gaps). Same screen for all roles.
- Owner, Manager, Specialist: sign in with the mobile number the owner entered when adding them. There is no invite to accept (US-P-00a).
- After sign-in the role decides which menu items and actions are visible (US-P-00b). The API still checks every call.

## 2. User stories
| Story | SRS | Covered how |
|---|---|---|
| US-P-00a | PTN-11 | Mobile OTP sign-in for staff pre-created by the owner |
| US-P-00b | none | Role read after sign-in, stored in session, used by shell guard |

## 3. Layout notes
- Web/tablet (>= 900 px): centred card on the cream page with amber glow; logo, title, form. Max width token from `sb_ui`, no hard-coded sizes.
- Phone: full-width form, keyboard-aware, primary action pinned above keyboard.
- Components: `sb_ui` text field, black pill primary button, text link (orange accent) for "Use email instead" and "Resend code". Tabs/segmented toggle: Mobile | Email.
- Step 1: phone field with +94 prefix. Step 2: 6-box OTP input, resend countdown, "Change number".
- 44 px targets, Semantics on OTP boxes and resend.

## 4. Data and API map
| UI element | Endpoint | Request | Response used | Errors |
|---|---|---|---|---|
| "Send code" | POST `/v1/auth/otp/send` | `OtpSendRequest{phone}` (E.164, max 32, e.g. +94771234567) | `OtpSendResponse{message, expires_in, retry_after}` drives countdown | 404, 409, 422 (bad number, show on field), 429 (use `retry_after`), 403, 502/503 (SMS provider down) |
| "Verify" (auto on 6th digit) | POST `/v1/auth/otp/verify` | `OtpVerifyRequest{phone, otp}` (otp `^[0-9]{6}$`) | `SignInResponse{access_token, refresh_token, expires_in, is_new_user}` | 400 wrong code, 410 expired code, 429, 403, 404 |
| Silent session refresh | POST `/v1/auth/refresh` | `RefreshRequest{refresh_token}` | `TokenResponse` (rotation: always store both tokens) | 401 -> back to P-01 |
| Sign out (in More) | POST `/v1/auth/logout` | `LogoutRequest{refresh_token}` | 204 (idempotent) | none blocking |
| Load role and name | GET `/v1/me` | none | `UserOut{id, full_name, phone, avatar_url, role}` | 401 |
| Push registration after sign-in | POST `/v1/me/device-tokens` | `DeviceTokenIn{token, platform}` | `DeviceTokenOut` | non-blocking |
| Email + password | none in the spec | | | see Gaps |

Error body is always `ErrorResponse{code, message, field}`. Show `message` as returned unless a localised string exists for `code`; put it on the field when `field` is set. Exact `code` values are not enumerated in the spec.

## 5. Acceptance criteria
1. Given a valid +94 number, when the user taps Send code, then POST `/v1/auth/otp/send` is called and the OTP step shows with a countdown from `retry_after`.
2. Given the countdown is running, then Resend is disabled; at 0 it is enabled. A 429 re-disables it using the returned `retry_after`.
3. Given a correct 6-digit code, then tokens go to `flutter_secure_storage`, `/v1/me` is read and the user lands on Today (P-02).
4. Given a wrong code (400) the boxes clear and an inline error shows; entering fewer than 6 digits never calls the API.
5. Given an expired code (410) the user is offered Resend.
6. Given a number that belongs to no salon staff (see Gap 2), the user sees a clear "not registered with a salon" message and no app access.
7. Given a stored session, when the app launches, then it refreshes silently and goes straight to Today; a 401 on refresh returns to P-01 and clears tokens.
8. Given a Specialist, the shell hides Staff management, Earnings detail for others and other specialists' calendars (US-P-00b); a hidden route opened by deep link redirects to Today.
9. Tokens are never logged; sign out clears tokens and cached data (drift).
10. Strings in ARB; the screen works at 200 % text scale.

## 6. States
- Loading: buttons show progress and are disabled while a request runs.
- Error: inline field errors, banner for network/5xx with Retry.
- Offline: Send/Verify disabled with "You are offline". An existing session opens the cached Today (drift) read-only.
- Real-time: none. Session expiry mid-use (401 after failed refresh) shows P-01 with "Session expired".

## 7. Rules and edge cases
- Phone is normalised to E.164 before sending; the app does not decide if a number is a staff number.
- A new send invalidates the previous code; show only the latest.
- `is_new_user = true` for a partner app means the number is not a known client or staff. Treat as "no salon access" if `/v1/me` yields no salon role (Gap 2).
- Roles come from the server, not from user choice. Never cache a role longer than the session; re-read `/v1/me` on refresh.
- Multi-salon users: send `X-Salon-Id` on all `/v1/partner/*` calls once chosen (Gap 3).

## 8. Gaps and questions for the PM
1. **Email + password sign-in is in the instructions but not in the API.** Only `/v1/admin/auth/login` exists (admin console with TOTP). Is partner email/password planned? Until then, ship OTP only and hide the Email tab.
2. **No role or salon in the sign-in response.** `SignInResponse` has no role or claims, and `UserOut.role` defaults to `client`. The instructions say roles come from token claims (Owner, Manager, Specialist). Which endpoint returns the user's salon memberships and role? Needed for US-P-00b and for blocking pure clients.
3. **Salon selection**: `X-Salon-Id` is an optional header on partner endpoints, but there is no "list my salons" endpoint. Confirm single-salon per user or add the endpoint.
4. Error `code` values for OTP failures (wrong, expired, locked) are not listed. Request an enum so the UI can localise.
5. Can the backend tell the app a staff member was removed (soft-deleted) so sign-in fails clearly?

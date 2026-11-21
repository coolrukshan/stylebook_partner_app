# StyleBook Partner App — Backlog

## Backlog

| ID | Title | Priority | Phase | Status | Branch | Blockers | Owner |
|---|---|---|---|---|---|---|---|
| P-01a | Sign in core (OTP, tokens, session, interceptors, formatters, router guard, goldens) per plan steps 1-8, 10 | M | 1 | in-dev (built, uncommitted) | feature/p01-sign-in | Commit working tree; Email tab remnants (`auth_flags.dart`) still to remove | dev |
| P-01b | Plan Rev 2: step-up OTP (`StepUpPolicy/Controller/Sheet/Guard`), role table + `RoleGuard`, remove Email tab, no-signup copy test (steps 9, 9a). Also fix dev-check findings: literal spacing/sizes in sign-in screens and `sb_ui` widgets -> tokens, 44px target on `SbTextLink`, literal strings -> ARB (`errNotRegistered` copy, `noAccountHint`, `stepUp*` keys), "muted hint" line + absence widget test | M | 1 | todo | feature/p01-sign-in | P-01a committed | dev |
| P-01d | Username + password sign-in (replaces phone/OTP as primary login; OTP stays as step-up only). Spec updated by ba; plan sections 1-5, 8-11 stale and must be rewritten first | M | 1 | spec + plan Rev 3 ready | feature/p01-sign-in | P-01a commit approval; `staff_id`/`member_type` in `PartnerUserOut` (Gap A) for P-02/03/04 only | pm (plan), then dev |
| P-01c | Hand-off: update P-02/P-03/P-04 specs for worker-first landing, inline Accept/Decline, Day-view default (step 9b) | M | 1 | done (specs updated; plans P-02/03/04 still contradict, see Decisions 6) | docs only | None | pm |
| P-02 | Today (Home, stats, action tabs, check-in) | M | 1 | todo | feature/p02-today | P-01 | dev |
| P-03 | Calendar (Day/week/list, staff columns) | M | 1 | todo | feature/p03-calendar | P-01, P-02 | dev |
| P-04 | Booking detail (Side panel / bottom sheet) | M | 1 | todo | feature/p04-booking-detail | P-02 | dev |
| P-05 | Move / no-show / message | M | 1 | todo | feature/p05-move-noshow-message | P-04 | dev |
| P-06 | New booking (Walk-in/client modal/sheet) | M | 1 | todo | feature/p06-new-booking | P-03 | dev |
| P-09 | Staff list (Today's status) | M | 2 | todo | feature/p09-staff | P-01 | dev |
| P-10 | Add staff | M | 2 | todo | feature/p10-add-staff | P-09 | dev |
| P-11 | Staff detail (Hours, breaks, services) | M | 2 | todo | feature/p11-staff-detail | P-09 | dev |
| P-12 | Leave requests (Approve/decline) | M | 2 | todo | feature/p12-leave-requests | P-09 | dev |
| P-08 | Services and prices | M | 2 | todo | feature/p08-services-and-prices | P-01 | dev |
| P-21 | Settings (Booking rules, hours, holidays) | M | 2 | todo | feature/p21-settings | P-01 | dev |
| P-13 | Gallery (Grid, specialist filter, upload) | M | 3 | todo | feature/p13-gallery | P-01 | dev |
| P-14 | Photo detail (Tags, salon visibility, delete) | M | 3 | todo | feature/p14-photo-detail | P-13 | dev |
| P-15 | Orders (Fulfillment pipeline, pickup code) | M | 3 | todo | feature/p15-orders | P-01 | dev |
| P-16 | Inventory (Stock table, alerts, adjustments) | M | 3 | todo | feature/p16-inventory | P-01 | dev |
| P-17 | Earnings (Gross/fee/commission/net, chart) | M | 4 | todo | feature/p17-earnings | P-01 | dev |
| P-18 | Reviews (Rating, reply with AI draft) | M | 4 | todo | feature/p18-reviews | P-01 | dev |
| P-07 | Clients (Record, spend, visits, notes) | S | 4 | todo | feature/p07-clients | P-01 | dev |
| P-19 | AI Studio (Post builder, captions) | S | 5 | todo | feature/p19-ai-studio | P-01 | dev |
| P-20 | Clients due back (Nudge list) | S | 5 | todo | feature/p20-clients-due-back | P-07 | dev |
| P-22 | More (Phone navigation hub) | M | 1 | todo | feature/p22-more-phone | P-01 | dev |

---

## Decisions and Risks

1. **Gap 1 (closed by decision, plan Rev 2):** No email/password login and no sign-up. Accounts are admin-created on request. Remove `kEmailSignInEnabled` and all Email tab code (P-01b). Open: confirm admin request process with backend.
1b. **Decision (product owner, 2026-11-21): sign-in is username + password.** Reverses plan Rev 2 (OTP-only). Verified against openapi.json: no partner username/password endpoint, no `username` field, no password reset/change. `/v1/admin/auth/login` is admin-only (TOTP) and must not be used. Spec assumes proposed `POST /v1/partner/auth/login`. **Backend must provide:** endpoint + request/response, error codes (invalid credentials, locked, 429 `retry_after`, no salon access), who creates credentials, password policy, first-login/reset flow, lockout thresholds, and OTP verify for a signed-in user without issuing new tokens (step-up). Also: instructions doc lines 21, 59 and US-P-00a still say OTP/email; `UserOut.phone` is nullable so step-up fails for users without a phone. Do not build P-01d until the contract is confirmed; P-01b (step-up, role table, cleanup) can proceed.
1c. **Update 2026-11-21: backend contract now live** (`docs/api/openapi.json` refreshed; only additions). `POST /v1/partner/auth/login` (username+password) returns a LIMITED session (calendar view only); `POST /v1/partner/auth/otp/send` + `/otp/verify` upgrade to a FULL session with a NEW token pair (replace stored tokens); `POST /v1/partner/auth/password/change` (full session; forced when `must_change_password`). Accounts and temp passwords are admin-created (`/v1/admin/salons/{id}/accounts`). Consequences: step-up is now backend-enforced (closes Gap 7 below; replaces local `stepUpUntil`); new first-login change-password screen; error branching by `code` (INVALID_CREDENTIALS, ACCOUNT_LOCKED, NOT_SALON_MEMBER, OTP_INVALID/EXPIRED...). Decision 1b blocker is lifted. Still to confirm: refresh keeps tier?, role granularity (owner|staff vs manager/specialist), `staff_id` in `PartnerUserOut`.
1a. **Gap 7 (superseded by 1c) (step-up enforcement):** Step-up OTP gate is UX-only until backend adds a step-up token/claim. SMS cost per step-up to be confirmed.
2. **Gap 2 (Salon Role & Staff ID in User Response):** `/v1/me` role string defaults to `client` and lacks explicit salon tenancy/role claims. Plan falls back to checking `owner|manager|specialist` strings; non-salon roles yield `NoSalonAccess`.
3. **Gap 3 (Salon Context):** Using `/v1/partner/settings` to bootstrap salon ID, name, and timezone.
4. **Idempotency Header:** Not documented in openapi.json. Client will add standard `Idempotency-Key` (UUIDv4) on mutation calls.
6. **Plans vs specs (from P-01c):** `docs/_plans/P-02`, `P-03`, `P-04` still say specialists have no Accept/Decline, P-02 has no All staff / Me switch or "My bookings" title, P-03 defaults to Everyone and has no phone Week/List switch. Plans must be updated before dev starts those items.
7. **New API gaps:** (a) own `staff_id` + salon role is a HARD blocker for P-02/03/04 (Gap 2); (b) `/v1/partner/today` `staff_id` filter semantics (does it filter `needs_action`?); (c) can a specialist call `POST /v1/partner/bookings/{id}/{action}` (accept/decline)? Specs handle 403; (d) phone Week/List layout has no design, needs UX input.
5. **Token Refresh Rotation:** Refresh response issues both new access and refresh tokens; `TokenStorage` persists both.

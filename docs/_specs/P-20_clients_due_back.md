# P-20 Clients due back

Refs: US-P-25, SRS ENG-*. No PNG (web). API: `/v1/partner/engagement/*`.

## 1. Goal and roles
List clients who are due or overdue for a return visit and send them a nudge message.

| Role | Access |
|---|---|
| Owner | View, nudge |
| Manager | View, nudge (assumed, Q1) |
| Specialist | No access |

## 2. User stories
US-P-25 (see clients due back, send a nudge), ENG-*.

## 3. Layout
- Web: title "Clients due back"; summary chips from `summary` (All, Tier 1, Tier 2, Tier 3 counts); table with checkbox, avatar and name, last service, last visit, usual interval, days overdue (amber when over), visits, spend, status ("Nudged 3 days ago" or "Not eligible: reason"); sticky action bar: "N selected" + black "Send nudge" pill.
- Phone: not in More (instructions: Web). If reached on small width, render the list as cards with a bottom action bar.
- Nudge dialog: message textarea (optional, prefilled template), channel chips, count, black "Send".

## 4. Data and API map
| UI element | Endpoint | Request | Response fields | Errors |
|---|---|---|---|---|
| List and summary | GET `/v1/partner/engagement/due` | `salon_id` (required query, uuid), `min_overdue_days`, `sort`, `cursor`, `limit` | `DueListOut`: `summary` (`total_due_back`, `tier1_count`, `tier2_count`, `tier3_count`), `items[]` `DueClientOut`: `user_id`, `user_name`, `user_avatar_url`, `phone_last4`, `last_visit`, `last_service`, `total_visits`, `total_spend_cents`, `avg_interval_days`, `days_since_last_visit`, `days_overdue`, `nudge_tier`, `eligible`, `ineligible_reason`, `last_nudge_at`; `next_cursor` | 401, 403, 422 |
| Send nudge | POST `/v1/partner/engagement/nudge` | `NudgeRequest {salon_id, user_ids (1..50), message, channels}` | 202 `NudgeResponse {nudge_batch_id, queued_count, skipped[], warnings[]}` | 422 (over 50), 429 |

## 5. Acceptance criteria
1. Given the page opens, then the list loads sorted by most overdue, with `days_overdue` shown as "12 days overdue".
2. Rows with `eligible=false` are not selectable and show `ineligible_reason`.
3. "Select all" selects only eligible rows on the loaded page, capped at 50; at 50 further checkboxes are disabled with a hint.
4. When I send, then POST is sent with the selected `user_ids`; the result toast says "Queued N" and lists skipped clients (`skipped`) and each `warnings` item.
5. After success, selected rows show "Nudged just now" via refetch (`last_nudge_at`).
6. Phone numbers appear only as `... last4` (API masks); there is no call or copy action on the number.
7. Filter by minimum overdue days (7, 14, 30) re-queries with `min_overdue_days`.
8. Send is disabled when no client selected. Dialog confirm button is a black pill (not destructive).

## 6. States
- Loading: table skeleton.
- Empty: "No clients are due back. Nice work."
- Error: retry card. Nudge failure keeps selection.
- Offline: list read-only from cache, send disabled.
- Real-time: none required.

## 7. Rules and edge cases
- Caps, opt-out, quiet hours and holdout are enforced by the server; the app only reports `skipped` and `warnings`.
- Max 50 users per request; larger selections must be split by the user, not silently.
- Message optional: if empty, server template is used; show hint. Message length limit is undocumented.
- Duplicate sending: disable button while request is in flight; server rate limits.

## 8. Gaps and questions
- Q1: Role matrix undefined.
- Q2: Endpoint takes `salon_id` as required query/body field while other partner endpoints use the `X-Salon-Id` header. Confirm both are accepted.
- Q3: Allowed `channels`, `sort`, and `SkippedUser` reasons undocumented.
- Q4: Instructions say "Due / overdue list": API only returns overdue (`days_overdue`); a "due soon" list is not supported. Ask PM.
- Q5: Meaning of nudge tiers 1 to 3 needs text for UI labels.

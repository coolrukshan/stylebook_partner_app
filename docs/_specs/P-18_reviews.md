# P-18 Reviews

Refs: US-P-26, SRS PTN-04. Mockup: `mobile/P-18_reviews.png`. API: `/v1/partner/reviews*`.

## 1. Goal and roles
See client reviews and rating spread, reply (optionally with an AI draft), edit a reply, and report a fake or abusive review.

| Role | Access |
|---|---|
| Owner | View, reply, edit, draft, report |
| Manager | Same (assumed, Q1) |
| Specialist | No access (assumed; may see own reviews later) |

## 2. User stories
US-P-26 (reply with AI draft, report spam), PTN-04.

## 3. Layout
- Phone (PNG): back pill, title "Reviews"; white cards: `user_name` + 5 amber stars, comment, then either "Your reply:" block (sand fill, `reply`) or outlined button "Reply with AI draft". More row subtitle "N waiting for a reply" with black badge (`summary.unreplied_count`).
- Web/tablet: top card with average rating, total, and 5 rating bars (`rating_distribution`); filter chips (All, Needs reply, 1..5 stars) and sort; list of review cards with a right-side reply composer (or inline). Overflow menu on each card: "Edit reply", "Report as fake".
- Reply composer: multiline field, "Draft with AI" outlined pill, black "Post reply".
- Report: dialog with reason field, `danger` confirm.

## 4. Data and API map
| UI element | Endpoint | Request | Response fields | Errors |
|---|---|---|---|---|
| Summary header, badge | GET `/v1/partner/reviews` | | `PartnerReviewListOut.summary` (`ReviewSummary`: `average_rating`, `total_count`, `rating_distribution`, `unreplied_count`) | 401, 403 |
| List | GET `/v1/partner/reviews` | `rating` (int), `replied` (bool), `sort` (string, values undocumented), `cursor`, `limit` | `PartnerReviewOut`: `id`, `user_name`, `user_avatar_url`, `staff_name`, `rating`, `comment`, `reply`, `replied_at`, `tip_cents`, `reported`, `report_reason`, `services[]`, `created_at`; `next_cursor` | 422 |
| Post reply | POST `/v1/partner/reviews/{review_id}/reply` | `ReplyIn {reply}` | `ReplyOut {id, reply, replied_at}` | 404, 409 (already replied), 422 |
| Edit reply | PUT `/v1/partner/reviews/{review_id}/reply` | `ReplyIn` | `ReplyOut` | 404, 409, 422 |
| AI draft | POST `/v1/partner/reviews/{review_id}/draft` | `DraftIn {tone, context}` | `DraftOut {draft, model_used, generated_at}`; not posted | 429, 409/402-like if no credits (undocumented, Q3) |
| Report | POST `/v1/partner/reviews/{review_id}/report` | `ReportIn {reason}` | `ReportOut {id, reported, report_reason}` | 404, 409, 422 |

## 5. Acceptance criteria
1. Given reviews exist, then each card shows name, stars (full and outline per `rating`), comment, and `services`/`staff_name` as small meta; reviews without a comment show "No comment".
2. Given a review has `reply`, then the sand "Your reply:" block shows it with `replied_at` date and an Edit action; else the "Reply with AI draft" button shows.
3. When I tap "Reply with AI draft", then POST draft runs (button shows spinner), and the composer opens pre-filled with `draft`; the reply is NOT posted until I tap "Post reply".
4. Given a draft is shown, I can edit it, regenerate (choose tone: Warm, Professional, Apologetic; optional context), or write from scratch.
5. When I post, then POST reply is sent; on 200 the card shows the reply and `unreplied_count` decreases locally after refetch.
6. Editing a posted reply sends PUT; on 200 the text updates.
7. "Report as fake" requires a reason (non-empty), confirm button is `danger`; on 200 the card shows a "Reported" tag with `report_reason` and the report action disappears.
8. Reply text cannot be empty or whitespace only; Post is disabled otherwise.
9. Filters "Needs reply" (`replied=false`) and star chips (`rating`) re-query the list.
10. The rating bars use `rating_distribution` values only and do not recompute the average.

## 6. States
- Loading: skeleton cards and bars.
- Empty: "No reviews yet. Reviews appear after completed visits."; filtered empty: "No reviews match".
- Error: retry card; reply post failure keeps the typed text.
- Offline: list readable from cache; reply and report disabled with banner. Unsent reply text is kept in memory.
- Real-time: new review notification (push, not specified in API; Q4). Refetch on resume.

## 7. Rules and edge cases
- Replies are public; show a one-line hint "Your reply is visible to everyone".
- AI draft is a suggestion; never auto-post.
- Drafting may cost AI credits (instructions: AI-*); show remaining balance if the API says so (Q3).
- Reporting is irreversible from the app; confirm first. Reported reviews stay visible until moderation.
- Names are shown as supplied (e.g. "Kavindu H."); no PII beyond that.
- Max reply length unknown (Q5): enforce server error text.

## 8. Gaps and questions
- Q1: Role matrix undefined.
- Q2: `sort` values undocumented (propose newest, oldest, lowest).
- Q3: Does the draft consume AI credits, and what is the error when credits are exhausted? Not in OpenAPI (see also P-19).
- Q4: No WebSocket or push contract for new reviews.
- Q5: Max reply length and `tone` allowed values undocumented.
- Q6: Review report reasons: free text in API; instructions say "report as fake". Proposal: chips (Fake, Abusive, Spam, Other) mapped to the text sent.

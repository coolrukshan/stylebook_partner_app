# P-19 AI Studio

Refs: US-P-27, SRS AI-*, PTN-15. No PNG (phone "Opens on web"). API: `/v1/partner/ai/*`.

## 1. Goal and roles
Generate promo posts (caption text and/or image) using credits, view past posts, buy credits. Blocked when credits run out.

| Role | Access |
|---|---|
| Owner | Generate, history, buy credits, delete |
| Manager | Generate and history; buying credits owner only (assumed, Q1) |
| Specialist | No access |

## 2. User stories
US-P-27 (AI promo posts, blocked when credits run out), AI-*, PTN-15.

## 3. Layout
- Web/tablet: two columns. Left "Post builder": What to promote (multiline, max 1000), Platform chips (Instagram, Facebook, TikTok, Generic), Tone chips, Language (English, Sinhala, Tamil), Goal chips, include hashtags toggle, output type (Text, Image, Text + image), credit balance card, black pill "Generate · N credits". Right "Result": generated text with Copy and Share, image preview, Delete. Below: history grid of recent posts.
- Phone: More row "AI Studio, Promo posts, opens on web" (`mobile/P-22_more.png`). Opens the web app; no native screen in v1.
- Components: `sb_ui` chip group, stat card (credits), black pill button, skeleton for generating state.

## 4. Data and API map
| UI element | Endpoint | Request | Response fields | Errors |
|---|---|---|---|---|
| Credit card, button cost | GET `/v1/partner/ai/credits` | | `CreditsOut`: `balance`, `cost_per_text_post`, `cost_per_image_post`, `cost_per_text_and_image_post`, `recent_usage[]` (`post_id`, `credits_used`, `type`, `created_at`) | 403 |
| Generate | POST `/v1/partner/ai/posts` | `PostCreateIn {type (default text), prompt (1..1000), style, platform (default generic), include_hashtags (default true), language (default en)}` | `PostCreatedOut {post_id, status, credits_reserved, estimated_seconds}` (202) | 402/409/422 for no credits (undocumented, Q2), 429 |
| Poll result | GET `/v1/partner/ai/posts/{post_id}` | | `PostOut {status, generated_text, generated_image_url, credits_used, model_used}` | 404 |
| History | GET `/v1/partner/ai/posts` | `status`, `cursor`, `limit` | `PostListOut.items[]`: `id`, `prompt`, `generated_text`, `generated_image_url`, `credits_used`, `status`, `created_at` | |
| Delete | DELETE `/v1/partner/ai/posts/{post_id}` | | 204 (no refund) | 404 |
| Buy credits | POST `/v1/partner/ai/credits/purchase` | headers `Idempotency-Key`; `PurchaseIn {pack, payment_method}` | `PurchaseOut {payment_intent_id, client_secret, amount_cents, credits_to_add}` | 422 |

Mapping of instructions fields to `PostCreateIn`: what to promote -> `prompt`; platform -> `platform`; tone -> `style` (max 50 chars); language -> `language`; goal -> appended to `prompt` text by the app (no field, Q3); hashtags -> `include_hashtags`.

## 5. Acceptance criteria
1. Given the page opens, then balance and per-type costs load; the black button reads "Generate · {cost} credits" where cost is the matching `cost_per_*` for the chosen type (never hard-coded 6).
2. Given `balance < cost`, then the button is disabled, a banner says "Not enough credits" and a "Buy credits" action shows. No generate request is sent.
3. Given an empty `prompt`, generate is disabled; over 1000 chars is blocked with counter.
4. When I tap Generate, then POST is sent, the button shows progress, the result pane shows a skeleton, and GET `/posts/{id}` is polled (every 2 s, up to 60 s, using `estimated_seconds` as hint) until `status` is terminal.
5. On success the text shows with "Copy" and "Share" (system share sheet) and any image appears; balance is refetched.
6. On failure status, the pane shows "Could not generate" and the API message; the app refetches balance (reserved credits may be released by server, Q4).
7. Delete shows a confirm (`danger`, text: "Credits are not refunded") then DELETE; the item disappears.
8. Buy credits: choose pack, confirm, POST with a fresh `Idempotency-Key`, complete payment with `client_secret`, then refetch balance.
9. A 429 shows "Too many requests, try again shortly".

## 6. States
- Loading: skeleton cards, balance shimmer.
- Empty history: "No posts yet. Describe what to promote and tap Generate."
- Error: retry banner; builder values kept.
- Offline: builder disabled with banner; history from cache read only.
- Generating: polling state, can leave page; result in history when ready.
- Real-time: none documented; polling covers it.

## 7. Rules and edge cases
- Credits are decided by the server: never compute or deduct locally.
- Text generated may include the salon phone or prices; owner reviews before sharing. Show hint "Check the text before posting".
- No refund on delete.
- Language chip default follows app locale.
- Payment errors during purchase leave balance unchanged.

## 8. Gaps and questions
- Q1: Role matrix undefined.
- Q2: Error code and HTTP status for insufficient credits are undocumented.
- Q3: Instructions list "goal" and "tone" fields and "captions" (plural) with share. API has `style` (tone) but no goal, returns one `generated_text`, and has no share/publish endpoint (system share only). Asked PM to confirm.
- Q4: Whether `credits_reserved` is released when status is failed.
- Q5: Allowed `type` (`text`, `image`, `text_and_image` inferred from cost fields), `platform`, `status`, `pack` values are undocumented.
- Q6: Instructions say phone "Opens on web". Confirm no phone UI.

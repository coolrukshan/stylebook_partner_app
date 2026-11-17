# P-22 More (phone)

Refs: US-P-00b, plus entry points for US-P-18, 22, 26, 27, 30, 31, 32. Mockup: `mobile/P-22_more.png`. Phone only; web/tablet uses the sidebar instead.

## 1. Goal and roles
A menu tab (5th item of the floating nav) that links to screens that do not fit in the nav, with count badges. Items are filtered by role.

| Row | Subtitle | Badge | Owner | Manager | Specialist |
|---|---|---|---|---|---|
| Orders | Marketplace orders to pack and hand over | orders needing action | Yes | Yes | No |
| Services and prices | "N services, prices and who does them" | none | Yes | Yes (price edit rules in P-08) | No |
| Booking rules | Auto-confirm, cancellation and fees | none | Yes | Yes (limited, P-21) | No |
| Reviews | "N waiting for a reply" | `unreplied_count` | Yes | Yes | No |
| Inventory | "N products low on stock, opens on web" | low stock count | Yes | Yes | No |
| AI Studio | Promo posts, opens on web | none | Yes | Yes | No |
| Earnings and payouts | Owner only, see the Today tab for a summary | none | Yes | Hidden | Hidden |

Manager and Specialist columns are assumptions (Q1). The Specialist sees an empty-state More page with only Settings items they can use (Sign out, Language), see section 7.

## 2. User stories
US-P-00b (role-filtered menu). Entry to: P-15 (US-P-30), P-08 (US-P-18), P-21 (US-P-22), P-18 (US-P-26), P-16 (US-P-31), P-19 (US-P-27), P-17 (US-P-32).

## 3. Layout
- Title "More" 27/600, a single white grouped card (`SbCard`) with divider rows. Each row: title (16/600), subtitle (muted), and on the right an optional black count pill (circle, white digits, soft shadow). Row min height 44 px, whole row tappable, chevron not shown (matches PNG).
- Floating black nav at bottom with More selected (white label).
- Rows with "opens on web" open the external URL in the browser (`https://partner.stylebook.lk/<path>`), using `url_launcher` with `LaunchMode.externalApplication`.
- Earnings row: owner only, subtitle as in PNG; tap goes to Today tab (summary there) (Q3).

## 4. Data and API map
| UI element | Endpoint | Fields used | Notes |
|---|---|---|---|
| Orders badge | GET `/v1/partner/orders` (`limit=1`) | `counts` | Which keys count as "needs action" undocumented (Q2) |
| Services subtitle | See P-08 services list endpoint | number of services | Defined in P-08 spec, not repeated |
| Reviews badge | GET `/v1/partner/reviews` (`limit=1`) | `summary.unreplied_count` | |
| Inventory badge | GET `/v1/partner/inventory` (`limit=1`) | `summary.low_stock` | |
| Role filter | token claims | role | API still returns 403 |
| Booking rules, AI Studio, Earnings | none | | static rows |

No aggregate "badges" endpoint exists. Four small calls on opening More, each failing independently.

## 5. Acceptance criteria
1. Given I am an Owner, when I open More, then I see 7 rows in the PNG order.
2. Given badges loaded, then Orders shows the API count (2 in PNG), Reviews shows `unreplied_count`, Inventory shows `summary.low_stock`; a count of 0 hides the pill; counts above 99 show "99+".
3. Subtitles with counts are pluralised: "1 waiting for a reply", "2 waiting for a reply", "1 product low on stock".
4. When I tap Orders, Booking rules, Reviews, Services and prices, then the matching screen opens with a back pill (P-15, P-21, P-18, P-08).
5. When I tap Inventory or AI Studio, then the web app opens in the external browser; if it cannot open, a snackbar shows "Could not open the web app".
6. Given I am a Manager, the Earnings row is hidden; Given a Specialist, only rows they are allowed are shown (none of these), so the page shows account items only.
7. Badge fetch failure does not block the page: rows render without pills; no error dialog.
8. Badges refresh when returning to More, on pull to refresh, and when a related push or WebSocket event arrives.
9. Each badge has a Semantics label ("2 orders need action"), rows have Semantics button role, 44 px target.

## 6. States
- Loading: rows render immediately; badges show nothing (no spinner), subtitle text fixed.
- Empty: not applicable for Owner; Specialist sees "Nothing here for your role" plus account rows.
- Error: silent, with a small "Pull to retry" footer only if all badge calls fail.
- Offline: rows tappable only for screens with cached data; banner "You are offline"; "opens on web" rows disabled.
- Real-time: new order, review and low-stock events update pills (contract missing, Q4).

## 7. Rules and edge cases
- The row list is built from a role-to-items map in `shell`, tested per role (golden tests at 390 px).
- Account items for all roles (not in PNG, proposed): Language, Sign out (confirm dialog). PM to decide placement (Q5).
- Deep links from push (low stock, new order) open the target screen directly and still show the back pill.
- Do not cache badge counts across salon switches.

## 8. Gaps and questions
- Q1: Role matrix for the menu is not defined beyond "Owner only" for Earnings in the PNG.
- Q2: `counts` keys on orders are undocumented; no batch badge endpoint exists. Propose backend adds one, else 3 calls as above.
- Q3: Instructions: "Earnings: Summary on Today" on phone. The Today API (`PartnerTodayStats`) has `revenue_today_cents` only, with no stock summary even though the instructions mention "earnings and stock summary" on web Today. Flag to the P-02 spec.
- Q4: No WebSocket contract in OpenAPI for orders, reviews, stock.
- Q5: Sign out, language and salon switcher have no place in the PNG.
- Q6: Instructions list the "Clients" (P-07) as "More (web first)"; the PNG omits it. No row added here.

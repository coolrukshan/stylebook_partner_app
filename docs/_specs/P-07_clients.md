# P-07 Clients

Refs: instructions §3 (P-07), US-P-24 (PTN-05). No PNG exists; layout follows the style guide and other list/detail screens. Opens from More (web first). Feature folder `features/clients/`.

## 1. Goal and roles
List salon clients and show a client record: visits, spend, usual interval, notes, preferences, with shortcuts to new booking and message.

| Role | Access |
|---|---|
| Owner | full list and record, edit notes |
| Manager | full list and record, edit notes |
| Specialist | per the story, a record "with visits, spend, usual interval, notes, preferences"; scope (all clients or own) unclear, see Q1 |

## 2. User stories
- US-P-24 (PTN-05): specialist wants a client record with visits, spend, usual interval, notes and preferences.
- Supports US-P-08 (new booking from client) and US-P-11 (message), US-P-25 (P-20 nudge, separate).

## 3. Layout notes
- Web/tablet (primary): two panes. Left: search field, sortable list rows (avatar, name, visits, spend, last visit). Right: client record. Page title 27/600.
- Phone: "opens on web" is not stated for P-07, so provide a simple list, tapping opens a full-screen record. Under More.
- Record sections: header (avatar, name, phone, `Usually every N weeks`), stat cards (visits, total spend, first/last visit), preferences (usual specialists and services), private notes (editable text with Save), visit history, upcoming bookings, action pills: black "New booking", white "Message", "Call".
- Components: `sb_ui` stat card, status pill, list tile, text field, black/white pills.

## 4. Data and API map
| UI element | Endpoint | Request | Response / fields used | Errors |
|---|---|---|---|---|
| Client list and search | `GET /v1/partner/clients` | `q`, `sort`, `order`, `cursor`, `limit` | `ClientListOut`: `items[]` `ClientListItemOut` (`user_id`, `full_name`, `phone`, `avatar_url`, `visit_count`, `total_spend_cents`, `average_interval_days`, `last_visit_date`, `last_service_names`, `last_staff_name`, `is_favourite`, `has_notes`), `total_count`, `next_cursor` | 409, 422 |
| Record | `GET /v1/partner/clients/{user_id}` | - | `ClientDetailOut`: `full_name`, `phone`, `visit_count`, `total_spend_cents`, `average_interval_days`, `first_visit_date`, `last_visit_date`, `preferred_staff[]` (`ClientStaffStat`), `preferred_services[]` (`ClientServiceStat`), `notes`, `hair_type`, `visits[]` (`ClientVisitOut`: `date`, `services[]`, `total_cents`, `status`, `rating`, `tip_cents`), `upcoming_bookings[]` (`ClientUpcomingOut`) | 404, 422 |
| Save notes | `PUT /v1/partner/clients/{user_id}/notes` | `ClientNotesIn`: `notes` | `ClientNotesOut`: `notes`, `updated_at` | 404, 422 |
| New booking | opens P-06 with `user_id`, `client_name`, `phone` prefilled | - | - | - |
| Message | `POST /v1/threads` (`salon_id`, `user_id`) then `POST /v1/threads/{thread_id}/messages` | `MessageCreateRequest` | `ThreadCreatedOut`, `MessageOut` | 401, 403, 409, 422 |
| Upcoming booking tap | opens P-04 sheet for `booking_id` | - | - | - |

## 5. Acceptance criteria
1. Given the screen opens, the list loads 20+ rows with cursor paging on scroll; `total_count` shown ("124 clients").
2. When the user types in search (300 ms debounce), the list reloads with `q`; name and mobile both searchable.
3. Sort by last visit (default), spend, visits, name via `sort`/`order` using values from the API (G2).
4. Selecting a row loads `ClientDetailOut`; sections with no data show nothing or an empty line, not blanks.
5. "Usually every 4 weeks" displays from `average_interval_days` (days rounded to weeks when divisible, else "every N days"); hidden when null.
6. Money `LKR 12,500` from cents; dates `Thu 29 Oct`; spend and visits not recomputed in the app.
7. Notes: Save sends the full text; success toast; 422 shows `message`. Unsaved edits prompt before leaving.
8. Notes are private and never shown to the client; label "Private to your salon".
9. "New booking" opens P-06 prefilled; "Message" opens the thread as in P-05; "Call" uses `tel:`.
10. Only roles allowed see the screen (menu item hidden otherwise); direct URL for a disallowed role redirects.
11. Phone numbers and notes are not logged or cached in plain text beyond the drift offline cache policy (Q4).

## 6. States
- Loading: list skeleton rows; record skeleton cards.
- Empty: no clients -> "Clients appear here after their first completed visit". Search with no match -> "No clients match".
- Error: list/record error with Retry using `ErrorResponse.message`.
- Offline: show last cached list read-only; notes save disabled.
- Real-time: none specified; refresh the record on pull-to-refresh and when a booking is completed (event from WebSocket, if available).

## 7. Rules and edge cases
- Only clients with completed visits are listed (per endpoint summary); walk-ins with no `user_id` never appear (G1).
- `hair_type` is read-only (no field to edit it) (G3).
- Notes: empty string clears; unknown max length (use API 422).
- A client who blocked/deleted their account: API behaviour unknown.

## 8. Gaps and questions
- G1: List includes only clients with completed visits; clients with only upcoming bookings or walk-in phone bookings (no `user_id`) are not shown. Confirm.
- G2: `sort` and `order` accepted values are not documented in OpenAPI.
- G3: "Preferences" in the story = `preferred_staff`, `preferred_services`, `hair_type`; no endpoint to edit preferences or hair type.
- G4: No client-level "send message" endpoint; uses the generic threads API (see P-05 G5, G6).
- G5: No tags, birthday, email or no-show count in `ClientDetailOut`.
- Q1: Specialist scope: all clients or only those they served? API (`/v1/partner/clients`) has no staff filter.
- Q4: Offline caching of client PII allowed?
- Q5: Is the layout intended for phone at all (instructions say "More (web first)")?

# Curling App Data Model Research

## Research basis and modeling stance

No project-specific notes were supplied in the prompt, so this synthesis relies on current World Curling rules and official live-scoring/report structures, then cross-checks those against curling-specific club/event platforms and generic sports-management products. The common denominator is clear: a solid curling record-keeping model needs stable identity data, event/season structure, roster and lineup control, schedule/sheet assignment, game results, and end-by-end scoring. Advanced shot analytics, mixed-doubles power-play detail, payments, waivers, and facility operations are commonly present in production systems, but they are not necessary to make a useful v1 results database. citeturn19search1turn20view0turn9view0turn34view0turn35view0turn6search0turn30view0turn31view1

A key curling-specific design takeaway is that four-player assumptions are not safe. World Curling distinguishes traditional team play, mixed doubles, mixed curling, wheelchair formats, Last Stone Draw logic, extra ends, and per-game team line-up submissions. That means a durable schema should separate **stable profile data** from **event roster data** and from **game lineup data**, and should store **end-level results** rather than only final score totals. citeturn14view0turn14view2turn20view0turn20view1turn20view2turn20view4turn20view6

## Core entities

| Entity | Purpose | Required properties | Optional properties | Notes |
|---|---|---|---|---|
| Club | The owning or affiliated organization for members, events, sheets, and settings. | `club_id`, `name`, `timezone` | `website`, `primary_email`, `primary_phone`, `membership_association`, `supported_languages` | Curling systems commonly store club identity, contact info, season settings, and sheet configuration at club level. citeturn17search5turn32view1 |
| Venue | A schedulable place, usually a sheet, but possibly lounge or other facility. | `venue_id`, `club_id`, `venue_type`, `display_name` | `sheet_number`, `sheet_prefix`, `is_public`, `is_bookable`, `notification_email`, `hourly_rate` | Curling platforms distinguish sheets from other facilities and map draw schedules to sheet-type venues. citeturn33view1turn32view1 |
| Season | Historical boundary for leagues and bonspiels so results are not overwritten year to year. | `season_id`, `club_id`, `label`, `start_date`, `end_date` | `is_current`, `notes` | Curling IO explicitly advises not to reuse leagues/competitions across seasons and to preserve history. citeturn24view0turn24view1 |
| Event | The main container for a bonspiel, league, championship, or competition. | `event_id`, `club_id`, `season_id`, `name`, `event_type`, `discipline`, `start_date`, `end_date`, `registration_open_at`, `registration_close_at`, `status` | `summary`, `description`, `min_age`, `max_age`, `spots_available`, `max_teams`, `publish_results` | Modern curling systems attach registration, teams, schedules, standings, and scores to the event/competition object. citeturn24view2turn8search3turn6search0 |
| Registration | Captures how a person or team entered the event before final assembly into teams. | `registration_id`, `event_id`, `registration_type`, `submitted_at`, `status` | `order_id`, `payment_status`, `waitlist_status`, `discount_total`, `notes` | Curling apps support individual registration, team registration, waitlisting, payments, and required event-specific info. citeturn15search3turn17search11turn32view1 |
| PersonProfile | Stable curler/person identity reused across seasons and events. | `person_id`, `first_name`, `last_name`, `birth_date` | `email`, `phone`, `gender`, `city`, `province_state`, `country`, `accessibility_notes` | Profile fields are intended for durable personal data; temporal answers should stay at event level instead. citeturn18view0turn18view2 |
| Team | The competitive unit that appears in draws, standings, and results. | `team_id`, `event_id`, `display_name`, `short_name` | `affiliation_name`, `coach_name`, `contact_name`, `contact_email`, `contact_phone`, `stone_color_preference` | Curling systems store team/skip name, short name for draws, contact info, coach, and affiliation. citeturn10view0turn25view0turn25view3turn25view4 |
| TeamMembership | Event-specific roster membership for players, alternates, coaches, or officials. | `team_membership_id`, `team_id`, `person_id`, `role`, `roster_status` | `declared_position`, `is_spare`, `joined_at`, `left_at` | Team rosters need a junction entity because one person can appear on different teams/events, and curling supports alternates, coaches, and spares. citeturn14view0turn26view0turn20view0 |
| Stage | A competitive phase such as round robin, pool, qualifier, championship round, or playoff bracket. | `stage_id`, `event_id`, `name`, `stage_type`, `sequence` | `iterations`, `ranking_method`, `tiebreaker_method`, `carry_over_stage_id`, `group_label` | Curling event tools support multiple stages, pools, carry-over results, and separate bracket groups. citeturn27view0turn29view0turn28view0 |
| DrawSlot | The scheduled time-and-sheet slot to which a game is assigned. | `draw_slot_id`, `event_id`, `start_at`, `venue_id`, `draw_label` | `end_at`, `broadcast_flag`, `notes` | Curling scheduling is draw-based and sheet-based; templates optimize repeats, conflicts, byes, and fairness across sheets. citeturn28view0turn28view2turn28view3 |
| Game | A single matchup/result inside an event stage. | `game_id`, `event_id`, `stage_id`, `discipline`, `team_a_id`, `team_b_id`, `status`, `scheduled_ends` | `draw_slot_id`, `winner_team_id`, `result_type`, `initial_last_stone_method`, `team_a_stone_color`, `team_b_stone_color` | Official and commercial curling systems expose games under sheets, standings, brackets, and shot-by-shot/reporting. citeturn9view0turn12search8turn6search0 |
| GameLineup | The official per-game lineup and role assignment for each team. | `game_lineup_id`, `game_id`, `team_id`, `submitted_at`, `delivery_rotation`, `skip_person_id`, `vice_skip_person_id` | `alternate_person_id`, `coach_person_id`, `submitted_by_person_id` | World Curling requires original and game team line-up forms, including delivery rotation, skip, vice-skip, alternate, and coach. citeturn20view0 |
| EndScore | The authoritative end-by-end record. | `end_score_id`, `game_id`, `end_number`, `scoring_team_id`, `points_scored` | `hammer_team_id_start`, `is_blank`, `is_extra_end`, `measure_required`, `power_play_used`, `positioned_stones_mode` | Curling scoring is end-based, not possession-based; hammer/blank/extra-end behavior is essential, especially for mixed doubles. citeturn20view1turn20view2turn20view4turn20view5turn14view2 |

## Required v1 data points

For v1, the safest target is “officially useful without becoming an analytics warehouse.” That means enough data to register teams, assign rosters, schedule draws, submit lineups, record ends, and publish results/standings. citeturn6search0turn25view5turn27view0

| Property | Entity | Required? | User-entered / derived / imported | Reason |
|---|---|---:|---|---|
| `name` | Club | Yes | User-entered | Needed for club identity, communication, and event ownership. citeturn17search5turn32view1 |
| `timezone` | Club | Yes | User-entered | Scheduling and draw times need a consistent time base. citeturn32view1 |
| `label` | Season | Yes | User-entered | History should be season-scoped, not overwritten in place. citeturn24view0turn24view1 |
| `start_date` | Season | Yes | User-entered | Season boundaries drive filtering and historical separation. citeturn17search5turn24view1 |
| `end_date` | Season | Yes | User-entered | Keeps event history bounded and queryable. citeturn24view2 |
| `display_name` | Venue | Yes | User-entered | Needed for sheet/facility assignment in schedules. citeturn33view1turn32view1 |
| `venue_type` | Venue | Yes | User-entered | Systems treat sheets differently from other club facilities. citeturn33view1 |
| `name` | Event | Yes | User-entered | Primary public identifier for registration and results. citeturn24view2turn8search5 |
| `event_type` | Event | Yes | User-entered | Needed to distinguish league vs bonspiel vs championship-style competition. citeturn15search1turn8search3 |
| `discipline` | Event | Yes | User-entered | Curling rules differ materially across traditional play, mixed, and mixed doubles. citeturn14view0turn20view6 |
| `start_date` | Event | Yes | User-entered | Required for event lifecycle and public schedule display. citeturn24view2 |
| `end_date` | Event | Yes | User-entered | Required for event lifecycle and filtering. citeturn24view2 |
| `registration_open_at` | Event | Yes | User-entered | Registration systems explicitly separate play dates from open/close dates. citeturn24view2 |
| `registration_close_at` | Event | Yes | User-entered | Needed to control and explain registration availability. citeturn24view2 |
| `first_name`, `last_name` | PersonProfile | Yes | User-entered / imported | Minimum usable identity for rostering, lineups, and history. citeturn15search3turn18view0 |
| `birth_date` | PersonProfile | Yes | User-entered / imported | Age restrictions and some waiver/eligibility logic depend on it. citeturn18view0turn21view3 |
| `display_name` | Team | Yes | User-entered | Teams may be identified by team name or skip name. citeturn25view0 |
| `short_name` | Team | Yes | User-entered | Explicitly useful for draw schedules and compact scoreboards. citeturn10view0 |
| `role` | TeamMembership | Yes | User-entered / imported | Needed to distinguish player, alternate, coach, and official. citeturn14view0turn20view0 |
| `roster_status` | TeamMembership | Yes | User-entered / derived | Supports active, alternate, spare, withdrawn, etc. citeturn26view0turn20view0 |
| `name` | Stage | Yes | User-entered | Public-facing competition phases need names like Pool A or Regular Season. citeturn27view0turn29view0 |
| `stage_type` | Stage | Yes | User-entered | Needed to separate round robin, qualifier, and bracket behavior. citeturn27view0turn29view0 |
| `start_at` | DrawSlot | Yes | User-entered / generated | Curling schedules are draw-based by time. citeturn28view0turn33view1 |
| `venue_id` | DrawSlot | Yes | User-entered / generated | A game needs a sheet/facility assignment to become meaningful operationally. citeturn9view0turn32view1 |
| `draw_label` | DrawSlot | Yes | User-entered / generated | Draws are a first-class scheduling concept in curling. citeturn28view0 |
| `team_a_id`, `team_b_id` | Game | Yes | User-entered / generated | Core matchup definition. Unassigned slots may start as TBD but must resolve before play. citeturn27view3turn29view1 |
| `status` | Game | Yes | User-entered / derived | Needed for scheduled, in-progress, final, conceded, forfeit, etc. citeturn31view0turn12search8 |
| `scheduled_ends` | Game | Yes | User-entered / derived from discipline | Ten-end and eight-end formats both exist and matter. citeturn14view1turn20view3turn20view6 |
| `delivery_rotation` | GameLineup | Yes | User-entered / imported | Official line-up control is per game, not only per roster. citeturn20view0 |
| `skip_person_id` | GameLineup | Yes | User-entered / imported | Skip role is explicit in the rules and in line-up forms. citeturn14view0turn20view0 |
| `vice_skip_person_id` | GameLineup | Yes | User-entered / imported | Vice-skip is also explicitly tracked. citeturn14view0turn20view0 |
| `end_number` | EndScore | Yes | User-entered | The score structure is fundamentally end-by-end. citeturn20view4turn0search1 |
| `scoring_team_id` | EndScore | Yes | User-entered | Only one team scores in an end. citeturn20view4turn14view3 |
| `points_scored` | EndScore | Yes | User-entered | This is the legal scoring unit. citeturn20view4 |
| `is_blank` | EndScore | Yes | Derived | Blank-end logic affects hammer behavior and reporting. citeturn14view3turn20view5 |
| `is_extra_end` | EndScore | Yes | Derived | Tied games continue through extra ends until a team scores first. citeturn20view1 |
| `winner_team_id` | Game | Yes | Derived | Standings, brackets, and final results depend on a winner once complete. citeturn27view0turn29view1 |

## Optional or later data points

These are valuable, but they either add substantial complexity, depend on a stronger v1 foundation, or belong more to event-operations and analytics than to core result keeping. citeturn34view0turn35view0turn30view3turn30view5

| Property | Entity | Why defer? | Dependency |
|---|---|---|---|
| `shot_events` | ShotEvent | Shot-by-shot storage is expensive and only used in a minority of events; official systems expose it, but many clubs will not input it consistently. citeturn34view4turn29view1 | Requires stable `Game`, `GameLineup`, and usually `EndScore`. |
| `shot_type`, `turn`, `attempt_grade` | ShotEvent | Useful for analytics, not required to publish official results. citeturn12search11turn13view0 | Requires `shot_events`. |
| `shot_success_pct_by_position` | PlayerGameStats | Purely analytical; official reports publish it, but it is derived from shot data. citeturn34view0turn35view1 | Requires `shot_events` plus position mapping. |
| `draw_shot_challenge_distance` | PregameMetric | Important for competitive events, but many recreational leagues do not use or preserve LSD/DSC formally. citeturn20view2turn34view0turn35view1 | Requires `Game` or `Session` plus per-team pregame entries. |
| `hammer_team_id_start` | EndScore | Strongly recommended soon, but can be derived in simpler leagues if every end is entered in order and no manual correction occurs. citeturn14view2turn20view2 | Depends on reliable end sequence and first-end last-stone method. |
| `power_play_used` | EndScore | Mixed-doubles specific; not needed if v1 launches on traditional four-person curling first. citeturn14view2turn21view2turn35view0 | Requires `discipline = mixed_doubles`. |
| `positioned_stones_mode` | EndScore | Same reason as power play; only meaningful in mixed doubles. citeturn21view2turn20view6 | Requires `discipline = mixed_doubles`. |
| `timeout_count`, `timeout_timestamps` | GameAdminStats | Official reports track time-out statistics, but this is operational detail rather than core scoring. citeturn20view7turn34view3turn35view0 | Requires `Game`. |
| `advances_to_win_game_id`, `advances_to_loss_game_id` | BracketLink | Necessary for rich playoff automation, but not for a plain results database. citeturn29view1 | Requires `Stage` and `Game`; more valuable once brackets are in scope. |
| `standings_snapshot` | StandingsSnapshot | Better as derived data first; storing it too early risks drift from source-of-truth game results. citeturn27view0turn6search0 | Depends on clean `Game` outcomes and stage rules. |
| `waiver_snapshot`, `accepted_at` | WaiverAcceptance | Valuable for club operations and compliance, but not required to record curling results. citeturn17search4turn15search0 | Requires user account / registration flows. |
| `order_total`, `invoice_status`, `payment_method` | Order / Payment | Helpful if the app grows into club management, but separate from the scoring domain. citeturn15search3turn32view1turn31view2 | Requires commerce flows. |
| `availability_rsvp` | Availability | Common in generic sports apps, but not a core curling results need. citeturn30view0turn30view3 | Requires messaging/team participation workflows. |
| `facility_booking_rules` | VenueBooking | Practice ice and rentals are valuable club features, but they expand the app into operations software. citeturn33view1turn30view5 | Requires `Venue`, calendar, and payment support. |
| `first_time_curler`, `special_requests`, `travel_notes` | EventCustomFieldAnswer | These are often event-specific and should remain flexible custom fields rather than hard-coded profile columns. citeturn18view0turn17search0turn17search7 | Requires custom-field framework. |

## Risks

- **Hardcoding a four-player schema will break quickly.** Traditional team curling uses four players plus possible alternate, while mixed doubles uses two players, no alternate, five delivered stones, positioned stones, and power play logic. citeturn14view0turn20view6turn21view2
- **Treating the roster as the same thing as the game lineup will lose official accuracy.** World Curling distinguishes original team line-up information from a game team line-up form with delivery rotation, skip, vice-skip, alternate, and coach details. citeturn20view0
- **Storing only final game score is not enough for curling.** Official scoring is end-based; only one team scores in an end, blank ends matter, and extra ends decide tied games. citeturn20view1turn20view4turn14view3
- **Encoding one tournament shape directly into the Event table will not survive real bonspiels.** Current curling systems support multiple pools, crossovers, qualification games, relegation games, A/B/C style bracket groups, and carry-over standings. citeturn27view0turn29view1turn35view0
- **Putting temporary answers into the player profile will create stale data.** Curling IO explicitly warns that temporal fields such as age context or “first time curler” are better captured as event-specific custom data, not permanent profile fields. citeturn18view0turn17search7
- **Combining schedule slot and game identity can make rescheduling messy.** Curling scheduling tools treat draws/sheets as manipulable schedule objects with fairness constraints, byes, and conflict detection. citeturn28view2turn28view3

## Recommended property decisions

- **Use `PersonProfile` + `TeamMembership` + `GameLineup`, not “player1/player2/player3/player4” columns on Team.** That structure matches official lineup behavior and protects you from mixed doubles, alternates, spares, and per-game rotation changes. citeturn20view0turn26view0turn14view0
- **Make `discipline` a first-class property on Event and Game.** Do not infer format from roster size, because rules for ends, stones, hammer, and positioned stones change by discipline. citeturn14view0turn20view3turn20view6
- **Store end scores as source of truth and derive final totals.** That is the most curling-native approach and best matches official scoreboards and reporting. citeturn20view4turn0search1turn25view5
- **Separate `Stage`, `DrawSlot`, and `Game`.** This gives you room for pools, crossovers, schedule templates, sheet moves, byes, and knockout brackets without rewriting the schema later. citeturn27view0turn28view0turn29view1
- **Keep seasons immutable and copy forward.** Historical results are a real product feature in curling systems, so do not recycle the same event rows every year. citeturn24view0turn13view0
- **Keep stable personal data in the profile; keep event-specific answers in registration/custom-field records.** That avoids polluted profiles and makes bonspiel-specific capture flexible. citeturn18view0turn17search0
- **Treat standings and bracket advancement as derived first, persisted second.** Start from clean game outcomes and stage rules; only materialize snapshots when you need performance or auditing. citeturn27view0turn29view1turn6search0
- **Defer shot-by-shot analytics until after v1, but leave extension hooks now.** Official systems clearly support game shot reports, lineups, scoring analysis, and position-based percentages, so adding nullable extension tables later is the lowest-risk path. citeturn34view0turn34view4turn35view0
- **If bonspiels are a priority, add bracket-link tables before adding commerce features.** Curling-specific competition flow is more central to the sport domain than payments, waivers, or facility booking. citeturn29view1turn35view0turn33view1
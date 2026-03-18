# CurlPlan — Brand Bible

> Precise, unhurried, rink-smart. Built for curlers, not spectators.

---

## Positioning

CurlPlan is a personal curling organizer for people who already know the sport. It does not explain curling. It does not market curling. It speaks the language of the sheet: ends, hammers, speed readings, rink names, draw weight.

The brand personality comes from the sport itself: deliberate, precise, and calm under pressure. The app should feel like a well-kept prep notebook — the kind a skip flips through between ends.

**Audience:** Active curlers who track games, plan practice, and log ice conditions.
**Not for:** Casual fans, people who need curling explained, sports-app tourists.

---

## Color System

All colors are derived from the playing surface and equipment. Nothing decorative.

### Primary Pair

| Token | Hex | Role | Source |
|-------|-----|------|--------|
| `--ice` | `#e8f4f8` | Page background, card surface wash | The sheet surface |
| `--ice-mid` | `#daeef6` | Subtle background differentiation | Mid-tone ice |
| `--ice-dark` | `#c9e4ef` | Hover states, selected row bg | Shaded ice near boards |
| `--stone` | `#2c3e4a` | Primary text, headings | Granite curling stone |
| `--stone-mid` | `#3d5464` | Secondary text | Lighter granite |
| `--stone-light` | `#5a7a8a` | Tertiary text, disabled states | Worn granite |

### Semantic Colors

| Token | Hex | Role | Usage Rule |
|-------|-----|------|------------|
| `--granite` | `#b44a2c` | Red Handle — destructive, loss, alert | Win/loss indicators, delete buttons, validation errors. **Never as a general accent.** |
| `--gold` | `#c9882a` | Skip Gold — position status only | Skip position badge, gold-tier highlights. **Not a general accent.** Reserved for skip. |
| `--leaf` | `#3a7d5c` | Win, success, positive state | Win badges, success toasts, positive trends |
| `--sky` | `#1a6fa0` | Interactive — links, focus, active nav | Primary action buttons, active tab, link text, focus rings |
| `--sky-soft` | `rgba(26,111,160,0.12)` | Interactive background wash | Button hover background, soft selection highlight |
| `--pebble` | `#8ba8b5` | Warm neutral — metadata, timestamps | Timestamps, secondary labels, card footer text. Warms up the ice palette without feeling clinical. |
| `--white` | `#fafcfd` | Card surface, modal background | Cards, modals, elevated surfaces |

### Borders & Shadows

| Token | Value | Role |
|-------|-------|------|
| `--border` | `rgba(44,62,74,0.12)` | Default card/section border |
| `--border-mid` | `rgba(44,62,74,0.20)` | Input border, dividers |
| `--shadow-sm` | `0 2px 8px rgba(44,62,74,0.08)` | Cards at rest |
| `--shadow` | `0 6px 24px rgba(44,62,74,0.12)` | Elevated cards, dropdowns |
| `--shadow-lg` | `0 16px 50px rgba(44,62,74,0.16)` | Modals, overlays |
| `--shadow-focus` | `0 10px 30px rgba(26,111,160,0.14)` | Focused interactive element |

### Color Rules

1. `--granite` (Red Handle) is **never** used as a general accent. It means danger, loss, or destructive action. Period.
2. `--gold` (Skip Gold) is **position-locked** to skip. Do not use it for generic highlights, stars, or badges.
3. `--sky` is the only general interactive color. Links, focus rings, active states, primary CTAs.
4. `--leaf` means something went right. Wins, successful saves, positive trends.
5. `--pebble` is the workhorse neutral. Use it where you'd reach for gray but want warmth.

---

## Typography

Three fonts, three jobs. No overlap.

### Font Stack

| Token | Family | Fallback | Role |
|-------|--------|----------|------|
| `--font-serif` | Fraunces | Playfair Display, Iowan Old Style, Georgia, serif | Display headings, score numbers, section titles |
| `--font-sans` | DM Sans | Avenir Next, Segoe UI, system-ui, sans-serif | All body prose, UI labels, button text, form inputs |
| `--font-mono` | DM Mono | SFMono-Regular, Menlo, Consolas, monospace | Ice speeds, rink tags, chip labels, stat values, timestamps |

### Weight Map

| Context | Font | Weight | Size |
|---------|------|--------|------|
| Page title | Fraunces | 600 | 1.6rem |
| Section heading | Fraunces | 600 | 1.15rem |
| Score number | Fraunces | 700 | 1.8rem |
| Body text | DM Sans | 400 | 15px (base) |
| Button label | DM Sans | 500 | 0.82rem |
| Chip / tag | DM Mono | 500 | 0.72rem |
| Stat value | DM Mono | 400 | 0.9rem |
| Timestamp | DM Mono | 400 | 0.72rem |
| Input text | DM Sans | 400 | inherit |

### Typography Rules

1. Fraunces is **display only**. Never use it for body paragraphs, labels, or form inputs.
2. Score numbers always use Fraunces at weight 700 — they are the most important data on screen and should anchor visually.
3. DM Mono is the **data layer**. Anything that reads like a stat sheet uses mono: ice speed readings, rink abbreviations, shot percentages, end scores.
4. DM Sans is everything else. If you're not sure, it's DM Sans.
5. No font size below 0.72rem. Small text uses DM Mono at 0.72rem, not DM Sans shrunk to illegibility.

### Current State

The CSS currently references Playfair Display as the serif fallback. Fraunces is the intended primary. Migration: add Fraunces to the Google Fonts import and move Playfair Display to fallback position in `--font-serif`.

---

## Voice & Copy

### Tone

Terse. Rink-smart. No exclamation marks. No emoji in UI copy.

The app talks like a teammate, not a coach and not a brand. It assumes you know what a hammer is, what a peel means, and why ice speed matters.

### Empty States

Empty states are the voice's primary surface. They should feel like a teammate noting what's missing:

| View | Empty State | Not This |
|------|------------|----------|
| Games | "No games logged yet." | "Start tracking your curling journey!" |
| Practice | "No sessions recorded." | "Log your first practice to get started!" |
| Ice Notes | "No rink notes." | "Add your first ice reading to build your rink memory!" |
| Planner | "Nothing planned for today." | "Plan your next game day!" |
| Calendar | "No events this month." | "Your schedule is wide open — add something!" |

### Labels & Actions

| Pattern | Use | Avoid |
|---------|-----|-------|
| Button text | "Log Game", "Add Event", "Export" | "Create New Game Entry", "Submit Your Event" |
| Confirmation | "Game logged." | "Your game has been successfully saved!" |
| Deletion | "Delete this game?" | "Are you sure you want to permanently delete?" |
| Error | "Save failed. Export your data." | "Oops! Something went wrong." |

### Position Names

Always use curling vocabulary. Never genericize.

| Position | Abbreviation | Color association |
|----------|-------------|-------------------|
| Skip | SK | `--gold` |
| Vice | VS | `--sky` |
| Second | 2nd | `--stone` |
| Lead | LD | `--stone` |

---

## UI Components

### Cards

- Background: `--white` (`#fafcfd`)
- Border: `1px solid var(--border)`
- Radius: `var(--r)` (12px)
- Shadow: `var(--shadow-sm)` at rest, `var(--shadow)` on hover/focus
- Padding: 16px–20px

### Chips & Badges

- Background: `var(--ice)` or semantic color at 12% opacity
- Border-radius: 999px (pill)
- Font: DM Mono, 500 weight, 0.72rem
- Padding: 4px 10px
- Result badges: `--leaf` bg for win, `--granite` bg for loss, `--pebble` bg for draw/pending

### Stat Cards

- Ice-surface background: `var(--ice)` or `var(--ice-mid)`
- Value: DM Mono, prominent size
- Label: DM Sans, `--pebble` color, small
- No heavy borders — stat cards float on the ice background

### Buttons

| Type | Background | Text | Border |
|------|-----------|------|--------|
| Primary | `var(--sky)` | white | none |
| Secondary | transparent | `var(--sky)` | `1px solid var(--border-mid)` |
| Danger | `var(--granite)` | white | `var(--granite)` |
| Ghost | transparent | `var(--stone-mid)` | none |

### Nav

The nav should feel like tabs in a physical notebook — you're flipping between sections, not navigating a website.

- Background: `var(--white)` or transparent
- Active tab: `var(--sky)` text, bottom border accent
- Inactive tab: `--stone-light` text
- No heavy dividers between tabs

### Modals

- Background: `var(--white)`
- Shadow: `var(--shadow-lg)`
- Radius: `var(--r-lg)` (20px)
- Overlay: `rgba(44,62,74,0.5)`
- Entry: 300ms ease-out slide up

---

## Iconography

### Style

- Outline only, 1.2px stroke weight
- Color: `var(--stone)` default, `var(--sky)` for interactive
- Size: 18px default, 24px for nav
- No filled icons. No multi-color icons.

### Core Icons

| Icon | Usage | Notes |
|------|-------|-------|
| House target | Rink/venue indicator | Concentric rings, curling-specific |
| Stone | Game/match indicator | Granite stone profile |
| Position triangle | Position badge | Directional, references delivery stance |

### Rules

1. Only use sport-specific icons where possible. A curling stone, not a generic ball. A house, not a generic target.
2. Generic icons (calendar, clock, export) are fine for utility actions — use the same outline style.
3. Never use filled icon variants. The outline treatment is the brand.

---

## Motion

### Directive: Glide

Motion in CurlPlan should feel like a well-delivered draw: smooth, deliberate, arriving exactly where intended. Nothing bouncy, nothing springy, nothing that overshoots.

### Duration Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `--dur-fast` | 140ms | Chip state changes, hover feedback, input focus |
| `--dur-med` | 220ms | View transitions, card expansion, dropdown open |
| `--dur-slow` | 320ms | Modal entry/exit, overlay fade, page-level transitions |

### Easing

| Token | Value | Usage |
|-------|-------|-------|
| `--ease-out` | `cubic-bezier(0.22, 1, 0.36, 1)` | All motion. No other easing curve. |

### Rules

1. **One easing curve.** `--ease-out` everywhere. No ease-in, no spring, no bounce.
2. **200ms for chips**, 300ms for modals. These are the two numbers that matter most.
3. **No animation on data changes.** Score updates, stat recalculations, and count changes are instant. Motion is for UI state changes (open/close, show/hide, hover/focus), not data.
4. **Reduced motion kills everything.** Under `prefers-reduced-motion: reduce`, all transitions are `none !important`, `scroll-behavior` is `auto`. No exceptions.

---

## Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

This is non-negotiable. The app must be fully functional with zero motion.

---

## Accessibility

### Focus

- All interactive elements: `:focus-visible` with `3px solid rgba(26,111,160,0.32)` outline, `3px` offset
- Focus shadow on elevated focus: `var(--shadow-focus)`
- Skip link present on all pages

### Contrast

- Body text (`--stone` on `--ice`): 9.1:1
- Secondary text (`--stone-mid` on `--ice`): 6.8:1
- Tertiary text (`--pebble` on `--white`): 3.2:1 — use only for non-essential metadata at ≥0.82rem
- Interactive (`--sky` on `--white`): 4.7:1
- Danger (`--granite` on white): currently 3.5:1 at small sizes — **requires attention** (darken to `#8a2e15` or use white-on-granite)

### Keyboard

- All views reachable by Tab
- Modals trap focus
- Escape closes modals and dropdowns
- No shortcut conflicts with screen readers

---

## File Reference

| File | Purpose |
|------|---------|
| `assets/css/app.css` | All tokens, layout, and component styles |
| `index.html` | Single-page app shell |
| `assets/js/app/core.js` | State, persistence, normalization |
| `assets/js/app/render.js` | All DOM rendering |
| `assets/js/app/actions.js` | Event handlers, CRUD operations |
| `assets/js/app/bootstrap.js` | Init, wiring, demo data |
| `assets/js/app/utils.js` | Shared utilities, escapeHtml |

---

## What This Bible Does Not Cover

- Content strategy (event types, game log fields, ice note schema)
- Data model (see `CLAUDE.md` for storage schema)
- Feature roadmap (see `docs/IMPLEMENTATION_PLAN_*.md`)
- Deployment (static hosting, no build step, no CI)

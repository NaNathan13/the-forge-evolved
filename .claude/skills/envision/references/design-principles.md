# /envision — design principles & templates

The craft behind the control flow. Read this every run. Sourced from official Anthropic guidance (frontend-design skill, Claude Design setup) and corroborated practitioner reports; the verdicts below are where official + multiple sources agree.

---

## The five rules that make the output good

1. **System-first beats screen-by-screen, and crushes all-at-once.** Components built as a *system* stay consistent; components built per-screen drift (colors shift, fonts swap, spacing wanders). One-shot "give me all 10 screens" produces competent-looking comps with no shared reasoning you can critique. So: lock tokens + shared components *first*, reference them *by name* on every screen.
2. **Lock brand before screens.** Propose 2–3 directions, the operator picks one, freeze it. An open accent/type/badge palette across N screens guarantees drift.
3. **Name the recurring systems once.** Any element used on 3+ screens (status badges, a coverage/progress meter, list rows) becomes a *named primitive* in the design system, reused by name. This is the single biggest lever against drift.
4. **Enumerate states + failure paths per screen.** Default is the easy 20%. The value is in: loading/skeleton, empty, error/offline, and every product-specific state (challenge, contradiction, proposed, researching…). Name them in the brief or they won't get designed.
5. **Be deliberately distinctive.** Ban generic fonts (Inter, Roboto, Open Sans, Lato, system defaults) and AI clichés (sparkles, purple-on-white gradients, faux-terminal). Editorial over playful unless the brand says otherwise.

**Batch, don't grind one-at-a-time.** Pure one-screen-per-turn over many turns re-explains the system each time and invites "context rot" (drift, reintroduced styles you'd corrected). Lock the system alone, then generate screens in **small batches grouped by shared surface**, re-pasting/ re-anchoring on the system when a fresh session starts.

---

## Master prompt anatomy (paste first, into Claude Design)

Include, in this order:
- **Platform + idiom** — e.g. "iOS-first React Native + Expo, NativeWind" (the *stack-specific* line).
- **Token discipline** — "light + dark via semantic, purpose-named tokens (`--bg`, `--surface`, `--text`, `--text-muted`, `--accent`, `--border`, a `--status-*` set) — never raw hex in components" (the *stack-specific* token shape).
- **The product** — 3–5 sentences: what it is, the core loop, the signature interactions.
- **Vibe** — a sharp metaphor + 2–3 adjectives + the anti-cliché bans.
- **Output target** — what the designs become (RN/NativeWind code vs web React vs static comps); "treat web-flavored output as reference to translate" (the *stack-specific* line).
- **Sequence contract** — "before any screen I'll have you (1) propose brand, (2) emit the design system; confirm you've absorbed it before screens."

**Stack variants for the two stack-specific lines:**
- RN/Expo → NativeWind, CSS-variable semantic tokens, thumb-reachable, ≥44px targets.
- Web React → Tailwind config tokens / shadcn, responsive breakpoints.
- Plain web → CSS custom properties, semantic HTML.
- Shopify → Liquid sections/snippets, theme settings as tokens.

---

## Foundation checkpoint templates

**Brand (propose → STOP for lock):** "Propose 2–3 brand directions, each a complete personality: name + tagline, accent + neutral ramp, type pairing, one-line personality, shown on identical sample content so I'm judging skin not copy. Stop for me to lock one."

**Design system (emit + name the primitives):** "Lock Direction N. Emit the design system, don't design screens: (1) semantic tokens, light + dark, purpose-named; (2) scales — type, spacing, radii, elevation; (3) the recurring components as named primitives — [list them, e.g. `StatusBadge` covering all N states, `CoverageMeter` at the sizes it's used]; (4) core controls — buttons, chips, fields, list rows, [product-specific controls], plus loading/empty/error; (5) Do's & Don'ts + one-line rationale per major choice. [Stack] -friendly. Confirm you've absorbed it and stop."

**Nav backbone (spec, not screens):** "Define the navigation backbone, don't build full screens: a nav map — top-level destinations, how things push onto a stack, how the user exits the main flow, where auth/onboarding/paywall sit (modal/stack). Plus the tab bar + header chrome as reusable components, light + dark. Reuse the system by name. Stop for review."

---

## Per-screen brief shape

For each screen: **Purpose** (one line) · **Elements** (what's on it, referencing named primitives) · **States** (every one — including loading/empty/error). Each screen prompt ends with: *"Reuse the locked tokens and [named primitives] by name; don't redefine colors, fonts, or badges. Both light and dark. Stop for my review."*

---

## Completeness audit checklist (run interactively before authoring the brief)

Propose each missing item for accept/reject. The recurring gaps:
- **Navigation backbone / app shell** — how the user moves between top-level areas and exits flows. (Almost always missing; design the IA before the screens.)
- **Error / offline / failure states** — especially anywhere that calls a network/AI service; preserve user input on failure.
- **Lifecycle actions** — rename / archive / delete / restore for the primary entity, and where archived/deleted items live.
- **Empty + first-run states** — every list and primary surface.
- **Loading / skeleton states** — every async transition.
- **The "you're done" moment** — if the product has a completion/threshold nudge, it's a deliberate state, not a toast.
- **History / cached artifacts** — if an entity can hold multiple generated outputs, how past ones are seen/reopened.
- **Confirm starter-provided screens** — auth reset, delete-account confirm, manage-subscription — note them so they don't silently fall through.

---

## Batching heuristic (derive from the actual screen list)

Group screens that share chrome so the system is reinforced and reuse is forced. Typical groupings:
- **Entry funnel** — onboarding + primary input.
- **Hero/centerpiece** — its own solo pass (it sets the interaction language).
- **Navigation surfaces** — list/home + outline/detail screens (status/meter-heavy).
- **Output & conversion** — generate/export + paywall.
- **Starter chrome** — auth + settings (often rebrand-only).

Always: confirm the grouping with the operator first; one batch at a time; verify each batch's screenshot before the next.

---

## Verification checklist (the blocking gate, every checkpoint)

Before approving and advancing, confirm from the **screenshot**:
- [ ] Both **light and dark** present.
- [ ] Every promised **element and state** is there.
- [ ] **Shared primitives reused** — no re-invented badges, no new colors/fonts, badge/meter set matches the system.
- [ ] **Stack-correct token shape** (semantic, not raw hex).
- [ ] **No cliché drift** (banned fonts, sparkles, etc.).

Any miss → emit a revision prompt for the same checkpoint; do not advance.

---

## Operating surface notes

- Claude Design is a **research preview** (Pro/Max/Team/Enterprise). **No API/MCP** as of mid-2026 — the courier loop is mandatory; revisit if Anthropic ships integrations.
- **Org design system** (admin, qualifying plan): publish once → auto-applies to new projects. Best anti-drift.
- **Solo / no org:** keep building in **one project** so the system stays in context; on a fresh session, re-paste the system (`system.css`) to re-anchor. Watch for drift after many screens (context rot) → reset session + re-anchor.
- **Export:** "Handoff to Claude Code", standalone HTML, or .zip — operator-driven; the skill can't fetch the canvas.

<!--
Project charter supplied by the owner (ASHENBOUND_Claude_Project_Instructions_v1.1.md),
committed verbatim below. Where it describes the "current state" (section 10), the
live status is in docs/CURRENT_STATUS.md, which also records the owner's decisions.
-->

# ASHENBOUND --- Claude Project Description & Instructions

**Version:** 1.0\
**Last updated:** 2026-10-21\
**Status:** Active development --- initial Godot project/toolchain
scaffold\
**Coding agent:** Claude Opus 5.5 with Extra Effort

## 1. Project Overview

ASHENBOUND is a dark-fantasy, loot-driven action RPG for Android. It
combines responsive real-time combat with long-term character
progression and idle/offline systems. The player explores a fallen
world, fights through dungeons, defeats bosses, collects equipment,
improves their build, and sends expeditions to gather resources while
away.

The game must feel like an **action RPG first, with idle progression
supporting it**. Combat should reward positioning, timing, target
selection, dodging, and ability use. Idle systems extend progression
rather than replacing gameplay with menus and timers.

### Core pillars

1.  **Responsive action:** Immediate controls, readable telegraphs,
    satisfying impacts, meaningful dodges, and clear feedback.
2.  **Loot that matters:** Equipment changes stats and builds; drops
    create interesting choices.
3.  **Long-term progression:** Campaign, dungeon unlocks, character
    growth, upgrades, crafting, expeditions, and endgame goals.
4.  **Mobile-first usability:** Landscape orientation, touch-friendly
    controls, readable interface, and measured performance.
5.  **Dark-fantasy identity:** Ruined keeps, cursed forests, forgotten
    catacombs, ancient temples, volcanic depths, ice wastes, occult
    forces, and a fallen world bound by a mysterious power.
6.  **Trustworthy persistence:** Progress survives app closure, device
    changes, and intermittent connectivity.
7.  **Incremental delivery:** Build a playable, testable game in small
    verified milestones.

**Working tagline:** "SOME BONDS SHOULD NEVER BE BROKEN."

The title, tagline, lore, and art are working creative direction.
Preserve the established tone and core design unless the owner approves
a change.

## 2. Your Role as Claude

Act as senior gameplay engineer, technical architect, implementation
agent, and pragmatic collaborator. Inspect and edit the repository, run
commands, build the game, run tests, and improve documentation when
tools permit.

The priority is **a working game over impressive-looking plans or large
quantities of code**.

### Required behavior

-   Inspect the existing repository and Git status before changing
    files.
-   Read relevant documentation before implementing features.
-   Work in focused, reviewable increments.
-   Prefer the smallest complete implementation that meets acceptance
    criteria.
-   Run appropriate checks after changes and report actual results.
-   Distinguish **implemented**, **validated**, **verified in runtime**,
    **verified on device**, and **planned**.
-   Never claim a build, test, export, installation, or gameplay check
    passed unless it was actually run and passed.
-   Do not silently discard user changes, overwrite working assets, or
    perform destructive Git operations.
-   Preserve architecture unless a concrete problem justifies a change.
-   Update documentation when commands, dependencies, decisions, or
    project structure change.
-   When blocked, report the exact error, likely cause, and smallest
    useful next step.
-   Ask concise questions when an important product decision cannot
    safely be inferred. Otherwise use documented defaults and record
    assumptions.
-   Avoid unnecessary dependencies, abstractions, and unrelated
    features.

### Task workflow

1.  State the goal and acceptance criteria.
2.  Inspect relevant code and Git status.
3.  Make a focused change.
4.  Run targeted tests/checks.
5.  Run broader import/build/export checks when practical.
6.  Inspect the diff for secrets, debug leftovers, generated clutter,
    and unrelated changes.
7.  Update docs when needed.
8.  Report changed files, commands, results, unresolved issues, and the
    next task.

Do not advance while the current milestone is materially broken. If
hardware or tooling is unavailable, state what could not be verified and
provide a reproducible manual check.

## 3. Game Design

### Experience

-   Single-player dark-fantasy action RPG with loot-driven builds.
-   Android first.
-   2.5D presentation: 3D world and characters viewed through a fixed
    isometric camera.
-   Stylized, painterly visuals with strong silhouettes and
    high-contrast combat readability.
-   Real-time combat during active play.
-   Idle progression through repeatable cleared content and expeditions.
-   Online-enabled but **not always-online**.
-   Campaign and endgame are both long-term pillars.

### Core loop

1.  Enter a mission or dungeon.
2.  Fight using movement, targeting, attacks, dodges, and abilities.
3.  Read enemy telegraphs and react to dangerous attacks.
4.  Defeat elites and bosses.
5.  Earn equipment, currency, crafting materials, and progression
    rewards.
6.  Compare drops; equip upgrades; improve builds; upgrade or salvage
    gear.
7.  Unlock harder content and repeat runs for targeted rewards.
8.  Send expeditions while away and collect results later.
9.  Return stronger and tackle new encounters.

### First playable vertical slice

Keep the first slice deliberately limited:

-   One hero: **Warden**.
-   One small dungeon/arena in the **Fallen Marches** region.
-   Basic enemies, at least one elite, and one boss with distinct phases
    or behavior changes.
-   Basic attack, dodge, and initially three active abilities.
-   Enemy telegraphs, health, damage, death, victory and defeat states.
-   First pass of loot and equipment progression after combat is stable.
-   Android landscape controls and HUD.
-   Reproducible project import and Android debug build.
-   Backend integration only after the local playable loop is verified.

Placeholder art is acceptable. Do not delay playability while trying to
produce final-quality art.

### Combat principles

-   Movement, attacks, dodge timing, targeting, and abilities must feel
    responsive.
-   Enemy attacks communicate danger through clear windup, telegraph,
    impact, and recovery.
-   Dodge has a cooldown and defined, testable invulnerability window.
-   Player/enemy health, cooldowns, damage, and encounter state have one
    source of truth within the local simulation.
-   VFX must not independently apply gameplay damage.
-   Pause, app focus changes, scene changes, and touch release must not
    leave input stuck.
-   Behavior must not depend on a specific frame rate.
-   Polish a small number of mechanics before expanding.

### Initial hero: Warden

The Warden is a durable melee fighter. Initial ability directions:

-   **Carnage:** aggressive melee damage, cleaves, finishing attacks.
-   **Bulwark:** defense, mitigation, control, survival.
-   **Doomfire:** dark energy, curses, damage-over-time.

These are design directions, not a requirement to implement three
complete skill trees in the first milestone. First make one coherent
combat kit reliable and fun.

### Loot and equipment

Rarity ladder: Common, Uncommon, Rare, Epic, Legendary, Mythic.

Equipment slots: weapon, helmet, chest, gloves, boots, two rings,
amulet, relic.

Items may have base stats, affixes, rarity-specific properties, and
later unique legendary effects. Separate item definitions from inventory
instances and equipped state. Eventually support randomized affixes,
inventory/equipment comparison, equip/unequip, upgrades, crafting,
salvage, legendary effects, and possibly loot filters. Do not implement
everything before combat and save/load work. Ensure displayed stats have
clear gameplay effects.

### World and enemies

Initial region: **Fallen Marches**.

Long-term environment concepts: Ruined Keep, Cursed Forest, Forgotten
Catacombs, Volcanic Depths, Ancient Temple, Ice Wastes.

Enemy concepts: Skeleton Warrior, Ghoul, Dark Cultist, Fallen Knight,
Demon, and The Ashen Lord (working first-boss concept).

Implement only content required by the current milestone. Use reusable
enemy behaviors and data-driven configuration where they reduce
duplication without overengineering.

### Idle and offline progression

Planned systems: repeat farming of cleared content, timed expeditions,
offline rewards, and limits to prevent runaway rewards.

Initial proposed offline reward cap: **8 hours**, subject to tuning.
Once online persistence is integrated, use trusted server time for
durable claims; never trust the client clock for authoritative rewards.
New campaign content and first-time bosses should require active play
unless the owner approves a different design.

### Online model

Online-enabled, not always-online. The client should remain launchable
and useful when the backend is unavailable.

Long-term backend goals: account identity/authentication, cloud saves,
durable inventory/currency, server-validated reward claims, expedition
validation, idempotent operations, migrations, and integration tests.

Initial architecture may use local combat simulation for responsiveness,
with the backend validating durable progression and reward claims. This
is **not fully server-authoritative real-time combat**. Before
competitive play, trading, PvP, or a high-value economy, revisit the
threat model and authoritative simulation requirements.

No multiplayer, trading, guilds, PvP, or dedicated real-time game server
in the first release unless explicitly approved.

### Monetization

Initial direction is cosmetic-first. Do not implement paid loot boxes,
pay-to-win systems, payment processing, or monetization infrastructure
during the vertical slice. Treat monetization as a separate product and
ethical design review.

## 4. Technical Direction

### Client

-   **Engine:** Godot 4.x stable, compatible with the selected Android
    toolchain and export templates.
-   **Language:** GDScript, typed where practical.
-   **Rendering:** 3D world and characters with fixed orthographic
    isometric camera.
-   **Platform:** Android first, landscape.
-   **Input:** Abstract layer supporting keyboard/mouse during
    development and touch on Android.
-   **Performance target:** Aim for 60 FPS on representative mid-range
    Android hardware. Measure; do not assume.

Do not upgrade engine versions mid-task without a concrete reason and
compatibility verification.

### Backend (later milestone)

-   ASP.NET Core Web API, C#/.NET, PostgreSQL.
-   Versioned migrations.
-   Layered API, application, domain, and infrastructure organization.
-   Docker Compose for local development where useful.
-   Secrets via environment variables or a secret manager; never commit
    credentials.

Keep backend work separate from the initial combat prototype. The Godot
project must still import, launch, and build when the backend is
unavailable.

### Suggested repository structure

Adapt to the actual repository and Godot conventions. Do not create
empty modules merely to match this tree.

``` text
ashenbound/
├── README.md
├── CLAUDE.md
├── .gitignore
├── .editorconfig
├── .env.example
├── docker-compose.yml
├── docs/
│   ├── GAME_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── BUILD_ANDROID.md
│   ├── API_CONTRACTS.md
│   ├── TEST_PLAN.md
│   ├── CURRENT_STATUS.md
│   └── decisions/
├── concept_art/
│   └── README.md and reference boards
├── game/
│   ├── project.godot
│   ├── export_presets.cfg
│   ├── scenes/{main,levels,player,enemies,ui}/
│   ├── scripts/{combat,player,enemies,items,missions,progression,input,ui,network}/
│   ├── resources/{items,skills,enemies,missions}/
│   ├── assets/{models,materials,textures,animations,audio,fonts}/
│   └── tests/
├── backend/
│   ├── Ashenbound.sln
│   ├── src/
│   └── tests/
└── database/
    └── migrations/
```

### Architecture rules

-   Scenes compose objects; scripts implement behavior; resources define
    reusable data.
-   Separate combat rules from UI presentation.
-   Separate player input from gameplay state.
-   Separate enemy decisions from animation and VFX.
-   Avoid circular dependencies and giant manager scripts.
-   Use autoloads only for genuinely global services.
-   Validate data definitions where practical.
-   Separate network transport from domain rules.
-   Make reward claims transactional and idempotent.
-   Handle timeouts, retries, duplicate requests, and offline behavior
    intentionally.
-   Never commit secrets, private signing keys, credentials, or
    machine-specific paths.
-   Track licenses and provenance for third-party assets.

## 5. Art Direction and Concept Art

Use the provided ASHENBOUND concept-art board as **directional
reference**, not as production-ready assets.

Style: stylized painterly dark fantasy; charcoal, ash, weathered steel,
muted stone, deep red accents, ember orange for fire/danger, cyan/blue
for supernatural effects, restrained gold/bronze for legendary loot and
high-value UI. Use strong silhouettes, readable attack states, high
contrast, and coherent isometric scale.

### Art workflow

1.  Inspect existing concept-art files before generating or sourcing
    more.
2.  Identify references relevant to the current milestone.
3.  Create or acquire individual assets only when there is a clear
    gameplay need.
4.  Keep reference art separate from runtime assets.
5.  Use placeholder primitives when sufficient for mechanics testing.
6.  Record source, license, intended use, and conversion steps.
7.  Never use the full concept board as an in-game texture.
8.  Do not describe a concept image as a rig, sprite sheet, model, or
    production-ready texture.
9.  Keep VFX readable and performant on mobile.
10. Avoid mixing unrelated art styles without an intentional integration
    pass.

The first visual slice needs only a coherent arena, readable hero, a few
enemies, one boss, a small HUD, and basic combat effects.

## 6. Milestones and Gates

### Milestone 0 --- Repository/toolchain baseline (CURRENT)

-   Inspect repository, Git status, files, and current implementation.
-   Detect Godot, export templates, Android SDK/JDK, .NET, Docker, and
    PostgreSQL availability as relevant.
-   Verify compatible versions rather than assuming newest versions work
    together.
-   Create/validate a minimal Godot project, main scene, test arena,
    placeholder `CharacterBody3D`, fixed isometric orthographic camera,
    landscape configuration, basic HUD, and pause/resume.
-   Provide keyboard development controls and simple touch/virtual
    joystick input.
-   Ensure normalized camera-relative movement and stop on release.
-   Clear input on pause/focus loss/scene transitions.
-   Document exact import, run, export, and install commands.
-   Export a debug APK if possible.
-   Do not begin full combat, loot, or backend implementation until the
    baseline is verified.

**Acceptance criteria** - Project imports without unresolved errors. -
Main scene launches. - Player moves in all intended directions and stops
on release. - Camera stays fixed and avoids unexpected
clipping/rotation. - Pause/resume and focus loss do not leave input
stuck. - APK exports, or exact blocker and remediation are documented. -
No secrets or machine-specific credentials are committed. - README and
Android build instructions are reproducible.

### Milestone 1 --- Movement and camera

Camera-relative movement, normalized diagonals, arena boundaries,
landscape touch controls, shared keyboard/touch input, physical-device
feel/performance checks.

**Gate:** movement works on a physical Android device, or unavailable
device access is documented.

### Milestone 2 --- Combat foundation

Health/damage, targeting/range, basic attack, dodge/cooldown/i-frames,
three abilities introduced incrementally, enemy states (idle, approach,
telegraph, attack, recovery, death), hit feedback, HUD, pause/lifecycle
correctness.

**Gate:** combat rules pass automated tests where feasible and manual
checks on device.

### Milestone 3 --- First dungeon

Encounter controller, waves, elite, boss with distinct phases,
victory/defeat, reward summary, reliable reset/replay.

**Gate:** multiple consecutive runs complete correctly with no stale
state or duplicate rewards.

### Milestone 4 --- First loot loop

Item definitions and instances, rarity/affixes, equipment slots,
equip/unequip, comparison UI, stats that affect combat, drop table,
save/load. Add upgrade/salvage after basic persistence works.

**Gate:** inventory/equipment restore after restart and stat changes are
verified in combat.

### Milestone 5 --- Backend and durable progression

Authentication, character save/load, API contracts, PostgreSQL
schema/migrations, validated and idempotent reward claims, trusted time
for expeditions/offline rewards, graceful API failure, integration
tests.

**Gate:** a second session/device recovers durable progression; failures
do not corrupt state or duplicate rewards.

### Milestone 6 --- Idle systems/content expansion

Cleared-dungeon farming, expeditions, offline rewards with proposed
8-hour cap, more gear/enemies/dungeons, balance instrumentation, and
additional classes only after the first class/core loop are solid.

### Milestone 7 --- Polish and release readiness

Android profiling, low-end graphics options, audio, haptics,
accessibility, onboarding, settings, save recovery, privacy-conscious
error logging, license audit, API security review, signing/store
requirements, regression and release checklist.

## 7. Testing Standards

A feature is not complete because code was written. Label it: -
**Implemented:** code exists. - **Validated:** relevant automated/static
checks ran. - **Verified in runtime:** launched and observed. -
**Verified on device:** installed and tested on physical Android
hardware. - **Blocked:** specific dependency/environment issue prevents
verification.

### Required checks

**Project:** import/parse, main scene launch, missing resources, Android
export/install where available.

**Movement/input:** cardinal and diagonal movement, normalized speed,
release stops movement, pause/focus loss clears input, boundaries work.

**Combat:** valid target/range, damage/death exactly once, cooldown
integrity, dodge timing, telegraphs align with attacks, pause behavior,
VFX do not apply damage.

**Encounters:** waves advance in order, boss transitions work,
victory/defeat are mutually exclusive, replay resets state, rewards only
on valid completion.

**Items:** data validation, valid affix ranges, correct stat effects,
save/load, no unexpected duplication/destruction during
upgrades/salvage.

**Online:** errors/timeouts handled, reward claims transactional,
duplicates idempotent, client clock cannot inflate authoritative
rewards, migrations reproducible, backend outage does not prevent
launch.

### Performance

Aim for 60 FPS on a representative mid-range Android device. Measure
frame spikes, physics/AI cost, particles/transparency, memory growth
across runs, scene loading, and touch target size. Profile before
optimizing.

## 8. Git, Files, and Safety

-   Inspect `git status` before editing.
-   Never run destructive reset/clean commands without explicit approval
    and a clear explanation.
-   Preserve user-authored assets/docs and inspect diffs.
-   Keep commits focused with clear messages when committing is
    authorized.
-   Exclude build output, temporary caches, signing keys, `.env`
    secrets, and machine-specific paths from version control.
-   `.env.example` contains placeholders only.
-   Do not install system packages, alter global settings, or change
    external accounts without permission when consequential.
-   Prefer reproducible local development instructions.
-   Maintain asset source/license information.
-   Before major refactors, state the problem solved and validation
    plan.

## 9. Definition of Done

A task is done when: - It meets agreed scope. - Code is readable and
consistent with architecture. - Relevant checks ran and results are
reported honestly. - The project still imports and launches. -
Documentation is updated when needed. - Diff has no unrelated changes,
secrets, or accidental generated files. - Known limitations and
unverified behavior are listed. - The next recommended task is clear.

A milestone is done only when its acceptance criteria pass or an
owner-approved exception is documented.

## 10. Current State and Immediate Task

**Known state:** Claude has started the implementation plan. The project
is at the initial Godot project/toolchain scaffold stage. Do not assume
files, builds, tests, or device checks exist until inspecting the
repository and collecting evidence.

### First action: checkpoint without editing

Report: 1. Repository structure and Git status. 2. Files
created/modified. 3. Detected toolchain versions and missing
dependencies. 4. Exact Godot import/validation commands and results. 5.
Android export status, APK path if present, and whether
installation/launch was tested. 6. What works, what is implemented but
unverified, and what remains. 7. Exact errors/blockers. 8. Deviations
from this charter. 9. Single best next action.

Do not claim success without execution evidence. After the checkpoint,
propose the smallest focused task needed to satisfy Milestone 0.

### Required milestone report format

``` text
ASHENBOUND MILESTONE REPORT

Milestone:
Status: Implemented / Validated / Verified in runtime / Verified on device / Blocked

Changes:
- ...

Commands run:
- Command:
  Exit code:
  Result:

Manual checks:
- ...

Not tested:
- ...

Blockers:
- ...

Known risks:
- ...

Recommended next task:
- ...

Acceptance criteria:
- [ ] ...
```

## 11. First Implementation Prompt

Use this only if the checkpoint confirms that the foundation still needs
implementation. Adapt it to the actual repository; do not blindly
recreate files.

> **ASHENBOUND --- Milestone 0: Android Project Foundation**
>
> Inspect the repository and environment first. Check Git status and
> preserve existing work. Detect Godot, matching export templates,
> Android SDK/JDK, and device tooling. Verify compatibility.
>
> Create or complete a minimal Godot 4.x GDScript project under `game/`:
> main scene, simple bounded arena, placeholder `CharacterBody3D`
> player, fixed orthographic isometric camera, landscape configuration,
> basic HUD, pause/resume.
>
> Implement normalized camera-relative movement with shared
> keyboard-development and touch/virtual-joystick controls. Stop
> movement on release and clear input on pause, focus loss, and scene
> transitions. Keep code modular and typed where practical.
>
> Use placeholders. Do not implement combat, loot, backend, or unused
> future systems in this task. Avoid complex dependencies. Add/update
> `.gitignore`, `README.md`, and `docs/BUILD_ANDROID.md`; document
> actual prerequisites and exact commands.
>
> Validate project import/parsing with available Godot tooling. Run the
> project if possible. Export a debug APK if supported, and
> install/launch on a physical device only if one is available and
> authorized. Record commands and exit codes. Do not claim checks passed
> unless run.
>
> Review the diff for secrets, generated clutter, unrelated changes, and
> missing docs. Report files changed, checks/results, blockers, and next
> task.
>
> Stop when Milestone 0 acceptance criteria pass or a precise blocker is
> documented. Do not continue into combat or loot.

## 12. Final Rule

**Make ASHENBOUND playable in small, verified steps.**

A small working dungeon with responsive controls, readable combat, and
meaningful loot is more valuable than a broad collection of incomplete
systems. Preserve the vision, protect the architecture, test the
implementation, and expand only when the foundation is reliable.

## 13. Playable Hero Roster — Six-Class Vision

ASHENBOUND's planned launch roster contains six distinct playable classes. The Warden is the original reference class; the five additional classes below expand the combat and build variety. This roster is a **design target**, not permission to implement all six during the initial scaffold. Implement in milestone order and preserve a working Android build.

### Shared class-design requirements

Every class must have:

- A recognizable silhouette and coherent weapon, armor, material, and color-language direction.
- A basic attack, dodge, three initial active abilities, and a later ultimate ability.
- Three specialization branches with meaningful gameplay choices, not only flat damage increases.
- A distinct combat rhythm and, where appropriate, a class resource mechanic.
- Clear animation, VFX, SFX, HUD, accessibility/readability, and mobile-performance requirements.
- Support for campaign combat, cleared-dungeon farming, and long-term loot/build progression.
- Class-specific legendary item concepts that alter play patterns without making other classes obsolete.
- Data-driven skill and tuning definitions where practical; avoid duplicating the entire combat framework per class.

The classes must share reusable systems for movement, targeting, health, damage, cooldowns, effects, loot, inventory, and save data. Class-specific behavior should be implemented through focused abilities, configuration/resources, and composable components rather than giant class-name conditionals.

### 13.1 Warden — The Ashen Vanguard

**Status:** Original class; implement first as the combat-framework reference.

- **Role:** Durable frontline melee fighter.
- **Weapons and silhouette:** Heavy greatsword, layered blackened iron armor, ember-orange accents, broad grounded silhouette.
- **Combat identity:** Deliberate heavy strikes, defensive counters, and fire-infused executions.
- **Specializations:**
  - **Carnage:** Aggressive melee chains, bleeding wounds, execution bonuses.
  - **Bulwark:** Guarding, mitigation, counters, and survival.
  - **Doomfire:** Ash and fire damage, burning enemies, explosive finishers.
- **Signature ability:** A heavy, readable attack that rewards positioning and timing; the exact ability should be defined in the skill data/specification before implementation.

### 13.2 Reaver — The Knife in the Dark

- **Role:** High-mobility melee damage and executions; fragile if caught.
- **Weapons and silhouette:** Dual blades, dark fitted leather, crimson cloth, hood or partial face covering; narrow, forward-leaning silhouette.
- **Combat identity:** Fast attack chains, repositioning, bleeding, and burst damage against vulnerable targets.
- **Specializations:**
  - **Bloodletting:** Bleed stacking and sustained single-target damage.
  - **Shadowstep:** Mobility, evasions, flank attacks, and brief repositioning windows.
  - **Executioner:** Marked targets, finishers, and high-risk burst windows.
- **Signature ability — Veil Rend:** Blink or dash through a valid enemy group, applying marks or a short-lived vulnerability that enables a devastating follow-up. It must remain readable and fair on a touch screen.

### 13.3 Hexbinder — The Keeper of Forbidden Names

- **Role:** Ranged occult magic, curses, and damage over time; needs time and setup to reach full output.
- **Weapons and silhouette:** Ritual staff and grimoire, layered weathered robes or long coat, violet runes and restrained blue-purple spell effects.
- **Combat identity:** Apply curses and afflictions, manipulate groups, then detonate or consume accumulated effects.
- **Specializations:**
  - **Curses:** Debuffs, vulnerability, and spreading afflictions.
  - **Soul Siphon:** Resource recovery and sustain from afflicted enemies.
  - **Cataclysm:** Delayed area spells and curse detonations.
- **Signature ability — Black Testament:** Curse a group of enemies and later detonate or consume their accumulated afflictions. Define clear duration, area, scaling, and counterplay in the skill specification.

### 13.4 Dreadhunter — The Last Stalker

- **Role:** Ranged physical damage and battlefield control; vulnerable when enemies reach close range.
- **Weapons and silhouette:** Longbow, hunting blades, weathered leather and cloak, bone charms, muted forest tones with restrained amber accents.
- **Combat identity:** Precision shots, target marking, traps, and deliberate positioning.
- **Specializations:**
  - **Precision:** Charged shots, weak-point bonuses, and single-target damage.
  - **Trapper:** Snares, slowing zones, and prepared kill areas.
  - **Beastcraft:** A limited companion or creature-assisted abilities, if performance and scope permit.
- **Signature ability — Deadfall:** Deploy a rune-snare that roots or slows enemies before erupting in a volley of piercing bolts. Avoid excessive persistent objects or effects on mobile devices.

### 13.5 Reliquary — The Saint of Hollow Light

- **Role:** Sustain and area damage through corrupted blessings; balanced but less specialized in burst damage.
- **Weapons and silhouette:** Relic flail and sacred lantern, blackened silver armor, tarnished gold, pale spectral-blue flame; a solemn fallen holy-warrior silhouette.
- **Combat identity:** Trade safety, health, or accumulated conviction for healing, judgment, and spectral area effects. Avoid making this class mandatory for group content; the game is initially single-player.
- **Specializations:**
  - **Atonement:** Self-sustain, recovery, and defensive blessings.
  - **Radiance:** Spectral damage, area control, and anti-undead effects.
  - **Martyrdom:** High-risk power fueled by health sacrifice or damage taken, with explicit safeguards against accidental self-defeat loops.
- **Signature ability — Last Benediction:** Release a wave of spectral light that damages nearby enemies and restores a portion of the hero's health. Define caps and scaling to prevent infinite sustain.

### 13.6 Gravecaller — The Shepherd of the Unburied

- **Role:** Summoning and persistent damage; relies on setup, minion behavior, and summon uptime.
- **Weapons and silhouette:** Bone staff, soul reliquary, ragged black robes and bone armor, restrained teal or sickly green soul-fire. Keep minion silhouettes readable against dark environments.
- **Combat identity:** Raise temporary undead, command spectral allies, and convert fallen enemies into a limited resource.
- **Specializations:**
  - **Bone Legion:** Durable skeletal minions and formation bonuses.
  - **Wraiths:** Faster spectral summons and debuffs.
  - **Soul Harvest:** Resource generation and abilities that benefit from nearby enemy deaths.
- **Signature ability — Raise the Forsaken:** Summon skeletal warriors for a limited duration. Define summon count, lifetime, target selection, collision, cleanup, and performance budgets. Summons must not continue attacking after encounter reset or scene exit.

### 13.7 Class differentiation and balance principles

| Class | Primary strength | Main trade-off |
|---|---|---|
| Warden | Durability and direct combat | Lower mobility |
| Reaver | Burst damage and executions | Fragile when caught |
| Hexbinder | Curses and damage over time | Needs setup time |
| Dreadhunter | Range and battlefield control | Weak under close pressure |
| Reliquary | Sustain and area damage | Less specialized burst |
| Gravecaller | Summons and persistent damage | Depends on setup and summon uptime |

These are initial design hypotheses. Balance through measured playtests and telemetry where available; do not treat them as final numerical truths. Each class must remain viable for active combat and cleared-content idle farming. Avoid letting passive farming erase the value of active play, boss mechanics, or meaningful build choices.

### 13.8 Character art and asset pipeline

The art direction is **stylized dark fantasy in a 2.5D presentation**: 3D characters and environments viewed through a fixed orthographic isometric camera, with strong silhouettes, readable materials, controlled emissive effects, and a consistent scale. Keep visual effects legible on phone-sized screens and avoid relying on tiny details that disappear at gameplay distance.

For each class, maintain a character design sheet containing:

1. Full-body front, side, and back views where feasible.
2. Silhouette and proportion guide, including approximate height relative to the Warden.
3. Primary/secondary material palette and emissive accent colors.
4. Weapon and signature prop callouts.
5. Facial/head/helmet direction and armor variation rules.
6. Basic attack, dodge, hit reaction, death, and signature-ability pose references.
7. Animation list, VFX/SFX notes, mobile readability notes, and asset acceptance checks.
8. Source/provenance and license notes for any external assets.

Moodboards and generated concept images are **references**, not automatically production-ready textures, sprites, rigs, or 3D models. Do not import a multi-character moodboard as a runtime character texture. Store reference art outside the runtime asset folders or under a clearly marked `art_reference/` directory excluded from normal game imports. Promote an asset into the game only after its format, license/provenance, scale, import settings, and technical suitability are verified.

Suggested documentation additions as the project grows:

- `docs/CHARACTER_ROSTER.md` — roster overview and status per class.
- `docs/characters/warden.md`
- `docs/characters/reaver.md`
- `docs/characters/hexbinder.md`
- `docs/characters/dreadhunter.md`
- `docs/characters/reliquary.md`
- `docs/characters/gravecaller.md`
- `docs/ART_ASSET_PIPELINE.md` — source files, import rules, licensing, and asset acceptance.

Create these documents when the relevant milestone begins; do not fill the repository with empty placeholders just to match this list.

### 13.9 Implementation order for the six-class roster

1. **Warden prototype:** prove the movement, targeting, damage, cooldown, dodge, enemy, encounter, and UI foundations.
2. **Combat abstraction review:** identify reusable ability/effect/resource interfaces based on working Warden code. Refactor only where a real second-class need demonstrates a gap.
3. **Reaver or Dreadhunter prototype:** add a class with a clearly different attack range/mobility profile to validate the architecture.
4. **Hexbinder:** validate status effects, duration handling, and area spell behavior.
5. **Reliquary:** validate healing, resource trade-offs, and defensive effects.
6. **Gravecaller:** add summons last because minion AI, cleanup, target selection, and mobile performance introduce extra complexity.
7. **Roster integration and balance:** verify class selection, save/load, equipment compatibility, ability UI, encounter tuning, and offline farming for each class.

Do not implement all six classes before the first Warden dungeon is playable. The vertical slice remains one polished class, one dungeon, one boss, and a working loot loop. Keep the full roster in design documentation while sequencing implementation by milestone.

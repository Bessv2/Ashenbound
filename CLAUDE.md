<!--
Project charter v2.0 supplied by the owner on 2026-10-22, committed verbatim below.
It replaces v1.0. The live status is in docs/CURRENT_STATUS.md, which also records
the owner's decisions.
-->

# ASHENBOUND — Claude Project Charter & Development Directive

**Version:** 2.0  
**Last reconciled against repository:** 2026-10-22  
**Project:** https://github.com/Bessv2/Ashenbound  
**Engine:** Godot 4.7.2-stable (standard build, not .NET)  
**Primary platform:** Android phones, landscape  
**Language:** GDScript  
**Working tagline:** *Some bonds should never be broken.*  
**Core promise:** Loot. Upgrade. Conquer.

This document is the project's creative north star and working agreement for Claude. It consolidates the established game philosophy with the actual repository state. It does not replace detailed design documents: when they contain more precise mechanics or current status, read them and keep them consistent with this charter.

---

## 1. What ASHENBOUND is

ASHENBOUND is a stylized, painterly 2.5D isometric dark-fantasy action RPG for Android. It combines real-time action combat, distinct classes, skill trees, a deep loot-and-equipment loop, escalating dungeons, bosses, and progression that can continue while the player is away.

The long-term ambition is **the build variety and loot chase associated with Diablo IV, combined with the approachable class breadth and adventurous energy of Torchlight**—adapted for a mobile-first game that can be built and maintained by a small team with AI-assisted development.

It must feel like an action RPG first. Idle and offline progression should extend the experience, not replace it with menus and timers.

### Product pillars

1. **Responsive action.** Movement, targeting, attacks, dodges, skills, hit feedback, and enemy tells should feel immediate and fair.
2. **Distinct heroes.** Classes must differ in rhythm, tactical choices, resources, visual identity, and build possibilities—not merely in damage type or appearance.
3. **Loot that matters.** Equipment, affixes, upgrades, and skill interactions should create meaningful decisions and change builds.
4. **Long-term mastery.** Campaign, dungeon tiers, bosses, character levels, skill trees, crafting, and endgame provide clear goals.
5. **Progress that respects time.** Active play is engaging and skillful; cleared content and expeditions can provide useful offline progress without making active play irrelevant.
6. **Mobile-first usability.** Landscape touch controls, readable UI, safe-area awareness, performance, and interruption recovery are fundamental requirements.
7. **Dark-fantasy identity.** The world should feel ruined, ancient, dangerous, mysterious, and occasionally defiant or hopeful.
8. **Trustworthy progression.** Saves, inventory, currency, and rewards must not be duplicated, silently lost, or casually exploitable.
9. **Incremental delivery.** Prefer a small, polished, tested game loop over many half-built systems.

## 2. Design philosophy: rules that should not drift

### 2.1 Action RPG first; idle systems second

The player's decisions during active play must matter. Positioning, timing, target choice, dodge use, cooldowns, and skill combinations should influence the result.

Automation is for cleared content, repeat farming, and expeditions—not a substitute for first-time discovery, core boss learning, or the entire game. Active play should remain the most engaging way to experience combat and should offer meaningful control and mastery.

**Test:** If removing direct control changes almost nothing about the experience, combat needs more depth.

### 2.2 A meaningful loot chase

Loot is a core pillar, not an inventory spreadsheet. A drop should create a decision: equip it, save it for another build, upgrade it, salvage it, or use it to unlock a new interaction.

Avoid endless junk drops, unreadable comparisons, and upgrades that only add invisible numbers. Make stats' gameplay effects clear. Rarity should create anticipation, but rarity alone must not make an item automatically useful.

The established rarity ladder is **Common, Uncommon, Rare, Epic, Legendary, Mythic**. The established equipment slots are **weapon, helmet, chest, gloves, boots, two rings, amulet, relic**. Treat `docs/LOOT.md` as the detailed implementation source of truth.

### 2.3 Classes must feel different

A class is a complete combat fantasy, not a skin over a shared generic kit. Distinguish its combat rhythm, tactical choices, skill-tree identity, silhouette, effects, sound, and preferred engagement patterns.

Shared infrastructure is good; identical class design is not. Build the framework so classes can express different mechanics without forcing every skill into the same mold.

### 2.4 Challenge teaches

Enemy attacks need a readable windup, telegraph, impact, and recovery. Bosses should test what players have learned through patterns, phases, positioning, and prioritization—not merely inflated health.

Defeat should offer information about what to change. Avoid surprise damage, inconsistent hit detection, invisible rules, or unavoidable spikes that feel unfair.

### 2.5 Visual clarity beats visual clutter

Combat effects should feel powerful, but the player must still understand enemy threats, targets, hit confirmation, damage, healing, status, cooldowns, and reward events. Use effects to reinforce gameplay feedback, never as a replacement for reliable gameplay rules.

### 2.6 Respect the player's time

Support short check-ins and longer sessions. Avoid mandatory chores, punitive streaks, artificial waiting, unnecessary currencies, and friction whose only purpose is to stretch playtime.

Offline rewards should be transparent, bounded, and useful. Do not make active play worse to justify automation.

### 2.7 Build depth without needless friction

A few well-connected systems are better than many disconnected ones. The player should understand the immediate purpose of a skill, stat, currency, upgrade, or quest. Complexity should reward curiosity and mastery rather than demand constant wiki research.

### 2.8 A coherent world, not generic fantasy wallpaper

The Ashenbound world should have a consistent history, tone, enemy logic, architecture, magic language, and visual palette. Tell stories through environments, enemy behavior, boss mechanics, relics, and consequences—not only exposition.

Preserve established names and canon in the project's docs. Do not silently invent replacements when documents disagree; surface the conflict and propose a decision.

---

## 3. Core gameplay loop

### Active loop

1. Choose a class, skills, equipment, and dungeon.
2. Enter an atmospheric, readable combat space.
3. Move, target, attack, dodge, and use skills.
4. Learn enemy patterns and overcome normal enemies, champions, elites, and bosses.
5. Earn experience, gold, equipment, crafting/salvage resources, and progression rewards.
6. Compare loot and decide how to improve the build.
7. Unlock harder dungeon tiers and pursue new goals.
8. Return stronger and test the build against more demanding encounters.

### Away-from-game loop

1. The player chooses eligible, previously cleared content or an expedition.
2. The game explains the expected duration, rewards, and limitations.
3. Progress resolves without requiring constant attention.
4. On return, the player receives a clear summary of XP, gold, loot/resources, and outcomes.
5. The player decides how to spend rewards and what to tackle next.

New campaign content and first-time bosses should require active play unless the owner explicitly changes this rule. Automated progress should not silently consume valuable items or make irreversible choices.

### Dungeon progression

The initial region is the **Fallen Marches**. The first dungeon is the **Ashen Crypt**. Dungeon tiers should give players a clear mastery ladder: each clear unlocks the next challenge, while enemy difficulty and rewards scale in a controlled, testable way.

Do not confuse increased enemy health with interesting difficulty. Higher tiers should make builds, enemy priorities, resource use, and encounter knowledge more important.

---

## 4. World, tone, and content direction

### Established world anchors

- A fallen dark-fantasy realm shaped by the Ashen Blight and mysterious supernatural bonds.
- Initial region: **Fallen Marches**.
- First dungeon: **Ashen Crypt**.
- First boss: **The Ashen Lord**, with distinct phases.
- Initial enemy roster: **Skeleton Warrior** (basic), **Dark Cultist** (ranged), and **Fallen Knight** (elite).
- Other long-term environment concepts: **Ruined Keep, Cursed Forest, Forgotten Catacombs, Volcanic Depths, Ancient Temple, Ice Wastes**.
- Other enemy concepts include Ghouls and Demons. Implement only what serves the current milestone.

### Narrative tone

- Grim, atmospheric, and human; not relentlessly bleak for its own sake.
- Use mystery, but keep the world's rules consistent.
- Avoid generic fantasy exposition and modern quips that break the tone.
- Give memorable enemies and bosses a distinct identity, motive, and combat language.
- Make victories matter through access, knowledge, resources, safety, or a change in the world.

Do not create a full lore bible before the playable loop needs it. Record canon as it becomes necessary and keep `docs/` as the place to resolve and preserve detailed creative decisions.

---

## 5. The six classes

The established roster is **Warden, Reaver, Hexbinder, Dreadhunter, Reliquary, Gravecaller**. The first three have received the most development so far; the remaining class trees should become full designs as their implementation milestones arrive.

### 5.1 Warden — The Ashen Vanguard

**Role:** Durable frontline melee fighter.  
**Fantasy:** A broad, grounded warrior in blackened iron with ember-orange accents, wielding a greatsword.  
**Combat rhythm:** Deliberate heavy strikes, a defensive counter, and fire that finishes what the sword starts.

Starter kit:
- **Basic attack:** A forward melee strike with aim assist.
- **Dodge:** A directional dash with a short, explicit invulnerability window and cooldown.
- **Cleave — Carnage:** A heavy, broad greatsword sweep.
- **Bulwark Guard — Bulwark:** Briefly brace, mitigate incoming damage, and counter the first hit.
- **Ember Brand — Doomfire:** Set a nearby enemy burning.

The three starter abilities are entry points into later specialization directions: **Carnage, Bulwark, Doomfire**. They are not a requirement to implement three full skill trees immediately. `docs/characters/warden.md` is the detailed mechanics authority.

### 5.2 Reaver

**Role:** Fast, aggressive dual-blade fighter.  
**Fantasy:** Relentless pressure, shadowed movement, bleeding wounds, and executions.  
**Current documented skills:** Twin Slash, Veil Rend, Fan of Blades, Hemorrhage.  
**Design goal:** Speed should create a different rhythm and risk profile from the Warden, not merely a smaller damage number and faster animation.

### 5.3 Hexbinder

**Role:** Curse-focused spellcaster.  
**Fantasy:** Manipulates enemies through occult marks, soul siphoning, and catastrophic magical release.  
**Current documented skills:** Hex Bolt, Black Testament, Grasp of the Grave, Unmake.  
**Design goal:** Make curse interactions and payoff windows legible. Reward planning without forcing players to inspect tiny status icons constantly.

### 5.4 Dreadhunter

**Role:** Ranged physical damage, traps, and marks.  
**Fantasy:** A prepared predator who controls distance and turns the battlefield against enemies.  
**Near-term direction:** Develop after the current champions/potions work, following `docs/characters/` conventions.  
**Design goal:** Ranged combat must work with touch controls and real encounter geometry; do not require pixel-perfect mobile aiming.

### 5.5 Reliquary

**Role:** Corrupted blessings, spectral power, sustain, and protective/restorative effects.  
**Fantasy:** A vessel caught between sacred relics and profane forces.  
**Design goal:** Sustain should have a distinct rhythm and clear limits. Avoid making the class passive or impossible to threaten.

### 5.6 Gravecaller

**Role:** Summoner and commander of the dead.  
**Fantasy:** Skeletons, wraiths, soul harvesting, and battlefield control through minions.  
**Design goal:** Summons must be legible and reliable. Their AI should help the player, not require constant micromanagement or obscure incoming threats.

### Class-wide standards

Every class should eventually have:
- A recognizable silhouette, animation language, and VFX palette.
- A distinct basic attack and combat rhythm.
- A starter kit that teaches its fantasy.
- A skill tree with meaningful branching choices and synergies.
- Several viable build directions rather than one mandatory solution.
- Clear strengths, weaknesses, and mastery opportunities.
- Tooltips and feedback that explain what skills actually do.

Do not present a class-tree preview as a fully implemented and balanced class. Keep that distinction clear in docs and reports.

---

## 6. Combat rules and feel

Combat must be responsive, consistent, and testable.

- Gameplay state is authoritative for local combat; VFX must not independently apply damage.
- Keep one source of truth for health, damage, cooldowns, and encounter state.
- Define attack windup, active hit timing, recovery, range, arc, and target rules explicitly.
- Dodge timing, cooldown, and invulnerability frames must be deterministic and tested.
- Respect action priority and cancellation rules documented for each class.
- Enemy states should have a clear, testable order such as idle, approach, telegraph, attack, recovery, death.
- Attack telegraphs must align with the actual attack and remain visible on a phone.
- Behavior must not depend on a particular rendering frame rate.
- Pause, app focus loss, scene changes, and touch release must not leave input stuck or cooldowns advancing unexpectedly.
- Death and rewards must resolve exactly once.
- Encounter restart must reset enemies, timers, boss phases, and rewards without stale state.
- Avoid animation locks that feel unresponsive unless the commitment is intentional and communicated.
- Camera shake and impact effects must be readable, configurable where appropriate, and mindful of mobile comfort and performance.

Do not change established damage values, timings, or action priority casually. Check the class specification and tests; update them deliberately if a balance change is warranted.

---

## 7. Loot, equipment, and buildcraft

Loot is a major long-term pillar, but must be built on a stable combat and persistence foundation.

### Established equipment model

Rarity: Common, Uncommon, Rare, Epic, Legendary, Mythic.  
Slots: weapon, helmet, chest, gloves, boots, two rings, amulet, relic.

Long-term systems include:
- Item definitions separated from item instances and equipped state.
- Base stats and randomized affixes.
- Rarity-appropriate properties and potential unique legendary effects.
- Inventory and equipment comparison.
- Equip/unequip, upgrades, crafting, salvage, and clear resource costs.
- Drop tables and targeted reward opportunities.
- Persistent bag, equipment, currency, and stat effects.
- Potential loot filters once item volume justifies them.

### Loot quality rules

- Every displayed stat must have a clear gameplay effect.
- Equipment comparison should be fast and readable on mobile.
- Preserve meaningful trade-offs among damage, survivability, utility, and synergy.
- Prevent accidental loss or duplication of valuable items.
- Make upgrade/salvage costs and outcomes clear before confirmation.
- Avoid excessive duplicate drops and inventory clutter.
- Avoid adding a currency without a distinct purpose.
- Do not implement obsolete loot work just because it exists on an old branch. `docs/LOOT.md` defines the current model; the old draft PR #6 is explicitly obsolete and kept for reference.

---

## 8. Progression, champions, potions, and offline rewards

### Character progression

Experience, levels, skill points, and skill trees should give players meaningful build decisions. Avoid a skill tree where every node is a tiny mandatory percentage increase. Use trade-offs, synergies, and class identity.

The Warden tree is playable. Trees for the other five classes have existed as previews; check current code and status before describing them as complete.

### Champions

Champions are ordinary enemies elevated with affixes such as **Hasted, Stoneskin, Vampiric, Ember-wreathed, and Vengeful**. Their effects must be readable and alter the encounter, not simply inflate stats. The current design calls for a guaranteed Rare drop. Verify `docs/CHAMPIONS.md` for exact rules and current implementation.

### Potions

The documented current design provides three health potions per run, refilled by kills. They should be a tactical safety valve, not a replacement for dodging, positioning, or class sustain. Communicate charges, refill rules, and use feedback clearly.

### Offline rewards

The current provisional model is based on the highest dungeon tier cleared, earning half a run per hour, capped at eight hours. It currently relies on the device clock and must be treated as provisional until server-trusted time is available.

- Never describe device-clock rewards as secure or exploit-proof.
- Keep reward calculations bounded and testable.
- Avoid allowing offline progress to complete first-time campaign content or bosses.
- Clearly summarize XP, gold, items/resources, and reward caps.
- Do not trust client time for authoritative claims once backend persistence exists.

The owner has explicitly authorized developing offline rewards before the backend. Preserve this as a documented, provisional deviation rather than blocking all work on the backend.

---

## 9. Art direction

**Style:** Stylized, painterly dark fantasy; fixed isometric 2.5D presentation; clear silhouettes; high contrast and strong gameplay readability.

The concept sheet in `docs/art/` is a reference for mood, palette, and layout—not a shipping asset and not a literal specification for every stat or price. Inspect it and `docs/ART_DIRECTION.md` before changing the look.

### Established palette

| Color | Hex | Intended role |
|---|---|---|
| Charcoal | `#262D37` | Panels, HUD backgrounds, deep shadow |
| Blood red | `#6F191A` | Health, danger, enemy accents |
| Ember orange | `#DB6028` | Fire, highlights, selected/pressed states, player attacks |
| Teal | `#1C859C` | Magic, mana, enchanting |
| Pale blue | `#7DAECA` | Cold light, secondary accents, undead eyes |
| Bone | `#E2CBB4` | Body text and titles |

Rarity frames: Common `#838488`, Uncommon `#529B4D`, Rare `#259FD2`, Epic `#7B4289`, Legendary `#D9A44C`. Mythic's final color is not established by the concept sheet; choose and document one when needed, with sufficient phone contrast.

### Art pillars

- Dark stone, ruined keeps, old iron, ash, worn leather, bone, weathered cloth, corrupted organic matter.
- Restrained environmental colors with selective ember-orange, blood-red, teal, and pale-blue accents.
- Strong silhouettes and readable attack states at gameplay camera distance.
- Layered atmosphere and environmental life where performance allows.
- Cohesive materials, lighting, scale, and stylization; avoid unrelated asset styles mixed without an integration pass.

### Asset pipeline

- The current first art pass uses free **KayKit CC0** assets; keep Godot and the existing pipeline.
- Track source, license, intended use, and any conversion steps.
- Keep concept/reference art separate from runtime assets.
- Do not describe concept art as a model, rig, sprite sheet, or production-ready texture.
- Use placeholders when they let gameplay progress sooner.
- Do not replace the approved art direction with a new visual language without explaining the benefit and obtaining owner direction for significant changes.
- Make visuals feel dramatically better through coherent lighting, materials, effects, animation, composition, and UI—not by indiscriminately stacking particles and post-processing.
- Profile the result; visual quality must remain viable on Android.

---

## 10. UI and mobile experience

The game targets **Android in landscape**. A browser preview is a convenient playtest route, not a platform change.

### HUD conventions from the concept and current build

- Health in the upper-left area.
- Movement stick in the lower-left.
- Attack and skill controls in the lower-right.
- Pause in the upper-right.
- Damage feedback near targets.
- Clear class selection and a readable title/menu flow.

The UI should feel alive and atmospheric while remaining functional. Use controlled transitions, state changes, outlines, button feedback, health trails, banners, and purposeful effects. Do not sacrifice contrast, touch accuracy, or performance for decoration.

- Respect safe areas and common Android screen shapes.
- Make touch targets comfortable and independent.
- Ensure simultaneous movement and combat inputs work where intended.
- Clear held input on interruption, pause, focus loss, or orientation/viewport changes.
- Communicate cooldowns, potion charges, health, skill points, loot rarity, and rewards clearly.
- Keep text readable and screens navigable without hover.
- Support pause/resume and app lifecycle changes reliably.
- Do not add screens that have no working system behind them; label placeholders honestly.

---

## 11. Technical architecture and boundaries

### Current stack

- Godot **4.7.2-stable**, standard build (not .NET).
- GDScript.
- Android landscape target.
- Repository layout: `game/`, `docs/`, `tools/`, `.github/`.
- `tools/test.sh` runs headless import and the Godot test suite.
- `tools/export-android-debug.sh` creates the Android debug APK when the environment is configured.
- CI runs tests and exports a debug APK.

Do not upgrade the engine or export toolchain mid-task without a concrete reason and a compatibility plan. Opening the project with a newer Godot version can upgrade it; isolate that change and commit it separately if approved.

### Architecture principles

- Inspect actual scenes, scripts, resources, tests, and conventions before changing structure.
- Scenes compose objects; scripts implement behavior; resources define reusable data where appropriate.
- Separate input from gameplay state, combat rules from UI, and enemy decisions from animation/VFX.
- Avoid giant manager scripts, circular dependencies, and unnecessary abstractions.
- Keep one authoritative source for gameplay values.
- Use typed GDScript where practical.
- Avoid new dependencies unless they solve a real problem.
- Preserve existing working code and user changes.
- Keep test helpers and test-only content out of production exports as configured.
- Do not commit secrets, keystores, passwords, tokens, or machine-specific configuration.
- Keep asset license/provenance records.
- Inspect `git status` and the diff before editing or declaring work complete.
- Never run destructive Git commands or discard changes without explicit approval.

### Backend (later)

The planned backend direction is ASP.NET Core Web API, C#/.NET, and PostgreSQL. The long-term goals include accounts, cloud saves, durable inventory/currency, validated reward claims, trusted expedition time, migrations, and integration tests.

Do not build backend infrastructure merely because it is planned. The game must remain launchable and useful when the backend is unavailable. Before server persistence is introduced, define API contracts, ownership boundaries, idempotency, error handling, migration strategy, and a test plan.

The current offline reward implementation is provisional and device-clock based. Do not imply that the current system is server-authoritative.

### Online scope

Online-enabled, not always-online. No multiplayer, trading, guilds, PvP, or dedicated real-time server in the first release unless the owner explicitly approves a scope change. Monetization is a separate product decision; do not add pay-to-win, paid loot boxes, payment processing, or monetization infrastructure during the current gameplay work.

---

## 12. Milestone discipline and actual project status

The repository's `docs/CURRENT_STATUS.md` is the live status source. Read it at the start of every substantial session and update it when status, owner decisions, or the next task changes. Do not let this charter's snapshot become stale.

### Status at the 2026-10-22 reconciliation

According to the current status document:

- **Milestones 0–1:** verified in runtime; Android physical-device verification remains open because a device/emulator suitable for visual testing was not available in the development environment.
- **Milestone 2 — Combat foundation:** implemented and verified in runtime except for the device check.
- **Milestone 3 — First dungeon:** validated and verified in runtime; Ashen Crypt loop and repeated-run reward gate pass automated checks; device check open.
- **Milestone 4 — First loot loop:** validated and verified in runtime; persistence of bag/gear/currency and combat stat effects pass documented automated gates; device check open.
- **Progression:** Warden skill tree playable; the other five trees have preview-level work, so inspect before describing them as complete.
- **Dungeon tiers:** ten tiers documented and validated in runtime.
- **Gold, salvage, upgrades:** validated in runtime.
- **Offline rewards:** validated in runtime but provisional because they rely on device time.
- **Reaver and Hexbinder:** validated and verified in runtime, with playable class trees.
- **Visual/UI pass:** effects and a more animated UI/title/class-selection experience validated in runtime.
- **Champions and health potions:** current status says implemented/validated/verified in runtime; check `docs/CHAMPIONS.md` and the live status before changing or repeating the work.
- **Dreadhunter:** documented as the next class task in `docs/CURRENT_STATUS.md`.
- **Reliquary and Gravecaller:** future class work.
- **Backend and later milestone 5–7 scope:** not started as a complete milestone.

These labels are not interchangeable. “Verified in runtime” in the current notes means rendered under Xvfb with software Vulkan; it does **not** mean tested on a physical Android device. The web preview has been playtested on a phone, but it is not the native Android app and does not close the device-test gate.

### Immediate development direction

Continue autonomously through useful gameplay milestones, as the owner has authorized, but keep the loop coherent and tested.

The current status points to the **Dreadhunter as the next class**, after champions and potions. Before coding:
1. Read `docs/CURRENT_STATUS.md`, `docs/CHAMPIONS.md`, `docs/SKILL_TREES.md`, `docs/UI.md`, `docs/ARCHITECTURE.md`, the Dreadhunter class spec if it exists, and the current test coverage.
2. Check Git status and open PR/branch state.
3. Confirm champions and potions are actually merged into the checked-out branch.
4. Identify what is missing for the Dreadhunter to be a playable, coherent class—not just a class-selection button or preview tree.
5. Implement the smallest complete class slice using shared infrastructure where appropriate.
6. Add or update tests, run `tools/test.sh`, and verify the build/preview where available.
7. Update `docs/CURRENT_STATUS.md` and relevant class/design documentation.

After the Dreadhunter, assess whether the highest-value next step is another dungeon, Reliquary/Gravecaller, or backend persistence. Base the choice on playtest feedback, current defects, and milestone value—not novelty alone.

### Device verification remains a real gap

Do not hide the difference between headless tests, software-rendered runtime checks, browser playtests, and native Android device testing. Keep a concise reproducible manual checklist in the relevant docs. When device testing is blocked, continue safely on other work, but leave the gate visibly open.

---

## 13. Testing and definition of done

A feature is not done because code was written or a screen looks convincing.

### Standard checks

Use the repository's configured commands, including:

```bash
tools/test.sh
tools/export-android-debug.sh
```

Run the relevant checks for the change; do not blindly run an export if prerequisites are missing. The test script performs headless import and the Godot test suite. Check actual exit codes and output.

### Test behavior that matters

- Import/parse and resource loading.
- Main scene and encounter startup.
- Movement, normalized diagonals, stop-on-release, collision/boundaries.
- Pause/focus-loss/touch cancellation behavior.
- Damage/death exactly once.
- Targeting, range, attack arcs, cooldowns, dodge timing and invulnerability.
- Telegraphs align with attacks.
- Champion affixes are deterministic where required, readable, and affect gameplay.
- Potion charges/refills follow documented rules.
- Boss phase transitions and encounter completion.
- Rewards only once after valid completion.
- Dungeon replay resets state with no stale enemies or duplicate payouts.
- Loot/equipment save/load, stat effects, and upgrade/salvage safety.
- Offline reward cap, calculation, and clock-tampering limitations.
- UI legibility and touch control behavior at supported viewports.
- Regression tests for every bug fixed.

### Report truthfully

Use these labels accurately:
- **Implemented:** code exists.
- **Validated:** relevant automated/static checks passed.
- **Verified in runtime:** launched and observed in a stated runtime environment.
- **Verified on device:** installed and tested on a physical Android device.
- **Blocked:** a specific environment or dependency prevents verification.
- **Planned:** not implemented.

Never claim an Android device test, successful export, performance target, passing suite, backend integration, or gameplay result unless it was actually run and the result is known.

A completed task should:
1. Meet agreed scope and acceptance criteria.
2. Keep the project importing and launching.
3. Pass relevant checks or document a concrete blocker.
4. Avoid unrelated diffs, secrets, debug leftovers, and accidental generated clutter.
5. Update affected docs and the live status.
6. State what remains untested.
7. Recommend one concrete next step.

---

## 14. Claude's working method

Act as the senior game designer, gameplay engineer, technical lead, and implementation partner. Use deep reasoning for architecture and game-design trade-offs, but do not turn every task into a broad redesign.

For every substantial task:

1. **Re-establish context:** read this charter, current status, relevant design docs, and affected code.
2. **Inspect before editing:** check Git status, branches/PR context when available, conventions, dependencies, and existing tests.
3. **Define the result:** state a concise goal and acceptance criteria.
4. **Make a coherent change:** prefer an integrated playable slice over scaffolding for many future features.
5. **Protect existing work:** do not overwrite or restructure unrelated code/assets.
6. **Test:** run targeted tests, the broader suite when practical, and the relevant runtime/build check.
7. **Evaluate the experience:** check whether the change improves class identity, combat readability, mobile usability, and the loot/progression loop.
8. **Document:** update the class/design spec, current status, decisions, and known limitations as needed.
9. **Report plainly:** summarize files changed, commands run, results, known issues, and the next task.

### Collaboration rules

- The owner has authorized autonomous development across milestones. Do not stop to ask permission for every reversible implementation detail.
- Ask only when a product decision is genuinely blocking, costly to reverse, or changes scope materially.
- Use established decisions and current docs instead of repeatedly asking the owner to restate them.
- Do not silently convert a guess into canon.
- Present trade-offs clearly where there are materially different good options.
- Keep working on useful tasks when device testing is blocked, but do not pretend the gate is closed.
- Keep the owner informed at milestone boundaries rather than narrating every small operation.
- Do not claim repository changes if only a plan or code snippet was produced.

### Required milestone handoff

```text
ASHENBOUND MILESTONE REPORT

Milestone / feature:
Status: Implemented / Validated / Verified in runtime / Verified on device / Blocked

What changed:
- ...

Files changed:
- ...

Commands and tests:
- Command:
  Exit code:
  Result:

Runtime/device checks:
- ...

Not tested:
- ...

Known issues / risks:
- ...

Design impact:
- ...

Current status docs updated:
- ...

Recommended next task:
- ...
```

---

## 15. Scope protection

Unless the owner explicitly approves a change, do not:

- Replace Godot or convert the project to a browser-first game.
- Treat the web preview as a change from the Android target.
- Rebuild working combat, UI, class, dungeon, loot, or progression systems from scratch without evidence they need replacement.
- Add multiplayer, PvP, guilds, trading, or always-online requirements.
- Add monetization, pay-to-win, paid loot boxes, or payment infrastructure during gameplay development.
- Add currencies, timers, chores, or menu layers without a clear player benefit.
- Present preview class trees as fully implemented and balanced.
- Call provisional device-clock offline rewards secure.
- Import assets without provenance/license checks.
- Change the engine/toolchain version casually.
- Run destructive Git operations or overwrite user work without approval.
- Claim physical-device performance based only on CI or desktop/browser observations.

---

## 16. Final decision filter

Before adding a major feature or making a significant refactor, ask:

1. Does it improve the action RPG experience or strengthen the world/class fantasy?
2. Does it create a meaningful player decision?
3. Does it preserve active combat while supporting long-term progression?
4. Is the result clear on a phone?
5. Can the player understand danger, success, failure, and reward?
6. Does it fit the established art direction and canon?
7. Does it work with existing architecture instead of duplicating systems?
8. Can it be implemented and tested coherently now?
9. Does it respect the player's time?
10. Is there a test or playtest that can demonstrate the improvement?

If most answers are no, defer the feature.

## Final directive

**Build the game we are making, not a different game that happens to share its name.**

Protect the core: a dangerous and atmospheric dark-fantasy world, six genuinely distinct classes, satisfying action combat, meaningful skill trees and loot, escalating dungeons and bosses, and offline progression that respects the player's time.

Make it playable before making it enormous. Make it readable before making it flashy. Make every system earn its place. Keep moving forward, test what you build, and tell the truth about what is and is not verified.

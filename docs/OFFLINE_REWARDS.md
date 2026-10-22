# Offline rewards

Owner's vision (2026-10-21): "being offline still earns you XP and other
things like gold and loot resources". The charter (Milestone 6) plans offline
rewards with a proposed **8-hour cap**, using trusted server time once the
backend exists, and keeps new campaign content and first-time bosses for
active play.

**Status:** built, **provisional**. Until the Milestone 5 server gives trusted
time, the device clock is used, so the rewards are local and can be inflated
by changing the clock. The server will validate them later; the rules below
stay. Numbers are first-pass tuning, in
`game/scripts/progression/offline_rewards.gd`.

## Rules

- Time away counts only after the first crypt clear. The hero "farms" the
  **highest tier cleared** (docs/dungeons/tiers.md).
- Earned per hour away: **half a crypt run's worth** of that tier's XP, gold
  and Ash (a tier 1 run: 790 XP, 170 gold, 76 Ash; higher tiers scale them
  like kills do). Active play clears a run in about six minutes, so offline
  is about a twentieth of the active pace: it helps, it does not replace play.
- At most **8 hours** are banked; absences under **5 minutes** earn nothing.
- No items and no new tiers offline: those need active play.
- "Away" means since the profile was last saved (it is saved on every change
  and when the app goes to the background). Time is banked when the game
  starts and when the app comes back from the background.
- A clock that went backwards banks nothing and restarts the count from the
  new time.
- The bank is saved, so closing the app without collecting loses nothing.
- **While you were away** shows the time, the tier and the rewards, pauses
  the game, and pays once on **Collect**. Unpausing without collecting keeps
  the bank for later.

## Acceptance checks

1. Rewards follow the time away and the tier, up to the cap; nothing before a
   tier is cleared or for short absences.
2. Time is banked once; a backwards clock banks nothing; the bank stops at
   8 hours.
3. Collecting pays once and empties the bank.
4. The bank, the last-seen time and the cleared tier survive a save; older
   saves load with nothing banked.
5. The screen appears only with something to collect, pauses the game, and
   resumes on Collect.

## Milestone 5 (server)

Replace the device clock with server time for banking and claiming, make the
claim a server request (idempotent, like run rewards), and keep this screen
as the client side of it.

# Steal An Egg — Nyx

Obsidian-UI script, same Nyx skin as [anime-dice](https://github.com/dylankirkgirg/anime-dice).
This game's codebase is a Brainrot-family engine under the hood (see
`BRAINROT_MAX_HATCH_PER_REQUEST` in its Constants module) — much heavier
anti-cheat surface than Anime Dice.

## What's built

**Farm** — Auto Collect Away Earnings, Auto Claim Rewards (onboarding/boss
mastery/group perk), Redeem Code / Redeem All Codes.

**Pets** — Sell Every Pet, Auto Sell (native), Wear Best (manual + auto).

**Player**
- **CFrame Escape Speed** — see "How the escape speed works" below. Off by default, starts conservative.
- FPS Boost / GPU Saver / Anti-AFK — cosmetic-only, safe.

**Settings** — config save/load/autoload + theme picker.

## Deliberately NOT built

**WalkSpeed / Fly / NoClip via the normal route.** This game has a dedicated
`WalkSpeedGovernor` and `GuardEscapePrediction.ResolvePlayerWalkSpeedRequirement`
module — Guards chase egg-thieves and the chase speed check is core gameplay,
not incidental. Setting `Humanoid.WalkSpeed` directly is watched here in a way
it wasn't in Anime Dice.

**Hatch / Scramble (steal) automation.** `EggWorld/AskHatch` and
`Scramble/Request` need an egg/pet ID argument we don't have yet. Getting it
safely needs a narrower spy (hook only those 2-3 remotes, not everything) —
not done yet after the session's one kick from a broad namecall hook.

## How the escape speed works (and its real risk)

`WalkSpeedGovernor` watches the `Humanoid.WalkSpeed` **property**. So instead
of raising WalkSpeed, the escape toggle moves the `HumanoidRootPart`'s CFrame
directly, scaled by frame delta-time (`speed * dt` per tick) — WalkSpeed never
changes, only position does, and the per-frame step stays small so it reads as
fast walking rather than a teleport.

**This is not guaranteed to work.** The game also has `RigSync`
(`Reconcile`, `CorrectionBegan`, `AskRigWipe`, a `ProbeSatchel` heartbeat) —
almost certainly a *separate* server-side position-integrity check that
doesn't care about WalkSpeed at all, just where your character actually is
each tick. If it catches the movement, expect rubber-banding (snapped back)
or a repeat of the kick we already saw once this session. Start the slider
low, watch for snap-back, raise gradually. There is no way to verify this is
safe without live testing — that risk is yours to take.

## Recon tools (`tools/`)

Same method as Anime Dice: `dump.lua` (safe, read-only, used to build this)
+ `argspy.lua` (namecall hook — **caused a kick once this session**, avoid
broad use in this game; a narrowed version scoped to 2-3 remotes is the next
safer step for Hatch/Scramble args).

## Remote map

See `reference/StealAnEgg_dump.txt` for the full 300+ remote list. Key ones
wired above live under `ReplicatedStorage.Packages.Networking.<RE|RF>/<Category>/<Name>`.

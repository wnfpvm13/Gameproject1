# Phase 1 Hunting contracts

Foundation PR #1 was merged into `main` at `a8b3ad0fbd9beda30a1e73dfa84affc58c805648` before these branches were created. All 176 existing test groups passed at that baseline. This document records implementation decisions for the two Phase 1 instructions; it does not extend their scope.

## Scope and branch ownership

Only the shared Greenwood field, Starter Cleaver combat, Hornboar, personal drops, and ingredient/material inventory are implemented. Restaurant/Cooking, other monsters, actual Expedition combat, Gold rewards, and Quick Match stay outside this phase. Config keys, Party/ReadyCheck/Expedition payloads, DataService locking, restaurant escrow, and settlement receipts remain compatible.

The integration branch first defines common contracts. `feature/combat`, `feature/monsters`, and `feature/inventory` start at that common commit and own their respective services, presentation, and tests. They are integrated into `integration/hunting`; `main` receives no direct edits.

## Authority and attacks

Clients submit only a monotonically increasing sequence, action (`Basic`, `Heavy`, `Dodge`), and optional facing/target hint. The server derives the actor, weapon, combo, windows, range, hitboxes, body damage, part power, and cooldown. A sequence is consumed even when rejected, so replays cannot become valid later. One accepted server attack can damage a given encounter only once, including overlapping body/horn contacts. A horn contact applies one body hit plus separate configured part power; destroying the horn does not set body HP to zero.

The existing default `EquippedWeaponId = "StarterCleaver"` remains the built-in starter entitlement. Owned instance IDs are resolved through `Equipment.Weapons` and their `WeaponConfigId`; arbitrary client/config IDs grant no equipment. No profile reset or invented ownership collection is needed.

## Encounters, contribution, and rewards

Every spawn has a new server encounter ID. Body and part damage record meaningful contribution and its server time. Merely standing nearby or belonging to a party grants no loot. Normal-monster contribution thresholds are deliberately low and configurable; expired participation is excluded.

Hornboar has one logical `Horn` HP pool, matching the existing Monster Bible. Art may contain multiple horn pieces, but they bind to this one pool. Intact and broken visuals are tagged through an asset binder, not fixed gameplay paths.

Horn breaking immediately snapshots current eligible contributors and queues their personal `HornCore` award under `encounter:Part:Horn`. Death independently snapshots contributors and rolls normal ingredients under `encounter:Death`. Later contributors cannot retroactively claim an earlier horn break. Rolls are sampled once per recipient before a persistence attempt, retained for retries, and never requested by clients. No physical loot pickup or Gold path exists.

Inventory stacks use the existing `Inventory.Ingredients` and `Inventory.Materials` numeric maps. A grant atomically adds stacks and its optional `HuntingReceipts` entry with `DataService.Update`. These receipts are independent of `SettlementReceipts` and restaurant SessionId. Presentation follows successful persistence. Retry lifetime is shorter than receipt retention; only expired receipts may be pruned. Unrecognized legacy collection entries are preserved rather than reset.

## Runtime and art

The World runtime is injected with the existing profile service and authenticated actor/location functions. Combat is disabled while traveling or outside World. Hornboar uses a budgeted configurable spawner, no Humanoid, separate invisible hitboxes, and telegraphed server movement/hit windows. Visual assets are selected by Config and bound by tags, allowing later mesh replacement.

The additional art instruction strengthens the base instruction: Hornboar and Cleaver must have real V1 outputs, not greybox-only completion. Blender generation is executed, exported, and inspected; native Roblox model equivalents are included for immediate Studio QA without requiring unpublished mesh IDs. Blender triangles and Roblox primitive counts are reported separately. A runtime primitive model is not claimed to be an imported Blender mesh. Uploaded mesh/animation playback and actual Studio QA remain separately verifiable.

## Acceptance and reporting

Keep all 176 existing groups unchanged and add meaningful combat, monster, contribution, loot, persistence, and presentation tests. Generate a Studio QA `.rbxlx` with assets. Report real automatic checks separately from Studio 2–4 client, PC/Touch, rig/hitbox, and visual checks. Combine the base and additional report requirements, including asset status, measured triangles, rig/animation status, known issues, and Phase 2 effects. No full-source PC ZIP is required. Stop at Phase 1.

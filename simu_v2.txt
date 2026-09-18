# Simu V2 Game Design Draft

## 1. Core Concept

- Genre: 2D pixel-art mercenary guild / frontier settlement simulation / defense / RPG
- Platform: Mobile-first
- Camera: Top-down observation view
- Core philosophy:
  - The player does not directly control mercenaries.
  - Mercenaries live, socialize, train, accept or reject work, fight, retreat, and build relationships autonomously.
  - The player influences them as guild leader through recruitment, settlement development, gifts, equipment, contracts, directives, and emergency orders.
  - The central fantasy is: "Mercenaries move on their own, and the player understands why."

## 2. World Setting

### World
- Name: Ardenia
- Catastrophe: The Abyssal Calamity
- Cause:
  - Massive rifts called "Abyssal Fissures" opened across the continent.
  - Abyssal energy leaked out and transformed living creatures, environments, and in some cases brought creatures directly from the Abyss.
  - The resulting monsters invaded civilization and destroyed most regions.

### Current Civilization
Only two major civilized zones remain during the prototype:
- Erdian Central Territory: the main surviving multi-racial civilization
- Lastra Frontline: the frontier settlement and main game area

All other major regions are considered monster territory for the prototype.

## 3. Races

### Human
- Broadest cultural and occupational diversity
- Values family, origin, social ties, and former homeland
- Many humans lost their homeland during the calamity
- Design direction: balanced and varied rather than specialized

### Elf
- Long-lived, magically sensitive, culturally tied to memory, history, and nature
- Their homeland forests were heavily corrupted by Abyssal energy
- More likely to have affinity for archery, magic, nature-related backgrounds
- Race does not lock class choice

### Dwarf
- Traditionally lived in mountain strongholds and underground cities
- Strong culture of oaths, contracts, family, honor, craftsmanship, mining, and forging
- Many settlements fell after Abyssal corruption spread underground
- More likely to have traits related to resilience, forging, or heavy combat

### Beastkin
- Prototype subtypes: wolf, cat, fox
- Tribal and group-oriented cultural roots, though younger generations may differ
- Often associated with hunting, tracking, sensory ability, or agility
- Race affects tendencies, not hard restrictions

### Demonkin
- Not included in the prototype
- Reserved for post-prototype world expansion

## 4. Religion

Religion is not race-locked. Any race may follow any faith.

### Lumea
- Goddess of life, light, healing, and resurrection
- Core belief: life deserves another chance
- Strongly connected to temple resurrection systems

### Valteron
- God of war, courage, honor, and martial spirit
- Popular among knights and mercenaries
- Courage is framed as acting despite fear, not mindless aggression

### Sylvara
- Goddess of nature and the cycle of life
- Popular among elves and some beastkin
- Abyssal corruption is viewed as a violation of the natural cycle

### Karon
- God of fire, craftsmanship, labor, and rebuilding
- Especially popular among smiths and dwarves
- Associated with rebuilding ruined civilization

### No Faith
- Mercenaries may have no religion
- Some may have lost faith after the calamity

## 5. Destroyed Regions

### Belheim Plains
- Former human heartland
- Ruined farmland, villages, and castles
- Typical monsters: goblins, orcs, mutated wolves, abyssal hounds
- Example boss: Grokan, "The Bloodied King"

### Eilin Great Forest
- Former elven homeland
- Ancient forest heavily corrupted
- Typical monsters: giant spiders, mutated plants, corrupted spirits, carnivorous trees
- Example boss: Arachne, "The Forest Devourer"

### Kardum Mountains
- Former dwarf mountain and underground civilization
- Abyssal rifts spread through mines and deep tunnels
- Typical monsters: stone golems, abyss bats, trolls, mutated insects
- Example boss: Molgar, "The Mountain Eater"

### Lucana Wastes
- Former beastkin grasslands and wild territories
- Water and ecology heavily corrupted
- Typical monsters: mutated hyenas, giant scorpions, abyssal lions, predatory birds
- Example boss: Barkan, "Black Mane"

### Arken Ruined City
- Former mixed-race trade metropolis
- Once housed a major market and mercenary guild
- Now a large monster nest
- Designed as a later high-difficulty region with backgrounds tied to all races

## 6. Mercenary Generation Pipeline

Mercenaries are generated in the following order:

1. Race
2. Homeland / origin region
3. Family background
4. Calamity-related past events
5. Religion
6. Personality
7. Preferences / dislikes
8. Personal goal
9. Class
10. Base stats
11. Hidden potential
12. Starting equipment
13. Current combat rating
14. Star grade
15. Appearance
16. Inn appearance and stay duration

After generation, the mercenary appears at the inn and may be recruited.

## 7. Background Reveal by Affinity

Mercenary backstories are not fully visible from the start.

Example reveal flow:
- Early relationship: name, race, class
- Moderate affinity: homeland revealed
- Higher affinity: family and past-event details revealed
- Deep trust: personal goal and major trauma or motivation revealed

The purpose is to create a reason to build long-term relationships beyond numerical bonuses.

## 8. Mercenary Cap and Related Residents

The player cannot recruit unlimited mercenaries.

Prototype direction:
- Initial cap around 10 mercenaries
- Expandable through guild/settlement upgrades
- Later cap can grow, but should never be unlimited

Reason:
- Avoid quest overload
- Keep individual mercenaries memorable
- Preserve the value of personal stories and relationships

### Related Residents
Some personal quests may introduce family members or acquaintances.

Example:
- A mercenary's missing sister is rescued
- She becomes a settlement resident
- She may take a role such as smith assistant, trader, or civilian

These NPCs are "related residents" linked to the mercenary.

If the mercenary permanently leaves:
- The related resident also leaves naturally

If the mercenary dies permanently or can no longer remain:
- The related resident stays briefly for funeral / farewell events
- Then leaves the settlement

This prevents permanent population clutter while preserving emotional continuity.

## 9. Star Grade System

Recruitable mercenaries can start at:
- 1 star
- 2 stars
- 3 stars
- 4 stars

5-star mercenaries never appear directly as recruits.

### Visual Star Presentation
- 1 star: dark, almost unlit star
- 2 stars: slightly brighter
- 3 stars: clear luminous star
- 4 stars: strong bright star
- 5 stars: brilliant star with aura and special visual effect

The player should recognize prestige visually without reading numbers.

## 10. Potential

Star grade represents current power, not ultimate potential.

- A 1-star mercenary may have very high hidden growth potential.
- A 4-star mercenary may already be close to their natural ceiling.
- Exact potential should not be shown as an obvious S/A/B grade.
- Hints may appear through training speed, dialogue, NPC comments, or unusual growth.

## 11. Five-Star Awakening

A 5-star is a legendary veteran created through long-term play.

Requirement:
- Must already be 4-star
- Must reach Lv.MAX
- Must participate in qualifying combat
- Awakening occurs probabilistically

Prototype awakening rates:
- Normal hunting contract success: 0.2%
- Monster wave boss kill: 0.5%
- Raid boss kill: 1.0%

These are balancing draft values.

A hidden pity / cumulative correction system may be used to prevent extreme bad luck.

### Awakening Presentation
When awakening occurs:
- Combat moment pauses or is emphasized
- Dedicated visual effect
- 4-star -> 5-star animation
- Brilliant star and aura
- Event recorded in mercenary history
- Settlement-wide news / dialogue may react
- Strong skill evolves to a legendary version

Example:
- Guardian's Oath -> Hero's Oath
- Meteor Fall -> Celestial Meteor
- Shadow Assassination -> Death's Shadow

## 12. Core Stats

Six core stats:

### Strength
- Physical damage
- Physical force
- Heavy equipment effectiveness

### Vitality
- HP
- Durability
- Injury resistance

### Agility
- Movement speed
- Dodge
- Attack speed
- Reaction speed

### Intelligence
- Learning ability
- Magical understanding
- Skill mastery
- Efficiency in complex techniques

### Magic
- Magical power
- Mana capacity
- Healing and spell output

### Wisdom
- Situational judgment
- Threat recognition
- Combat decision-making
- Target priority
- Retreat timing
- Skill timing

Key distinction:
- Intelligence = how well a mercenary understands and performs techniques
- Wisdom = how well a mercenary judges what should be done now

## 13. Classes and Stat Weights

### Warrior
Role: melee offense
Weight example:
- Strength 35%
- Vitality 25%
- Agility 15%
- Intelligence 5%
- Magic 5%
- Wisdom 15%

### Knight
Role: defense / protection
- Strength 25%
- Vitality 35%
- Agility 5%
- Intelligence 5%
- Magic 5%
- Wisdom 25%

### Rogue
Role: ambush / mobility / evasion
- Strength 20%
- Vitality 10%
- Agility 40%
- Intelligence 10%
- Magic 5%
- Wisdom 15%

### Archer
Role: ranged target selection
- Strength 15%
- Vitality 10%
- Agility 35%
- Intelligence 10%
- Magic 5%
- Wisdom 25%

### Mage
Role: magical damage
- Strength 5%
- Vitality 5%
- Agility 10%
- Intelligence 30%
- Magic 40%
- Wisdom 10%

### Priest
Role: healing / support
- Strength 5%
- Vitality 15%
- Agility 5%
- Intelligence 15%
- Magic 30%
- Wisdom 30%

Star grade should be based on the mercenary's own ability, not temporary equipment bonuses.

Suggested split:
- Star grade: base stats + skill mastery + combat experience
- Actual combat power: mercenary ability + equipment + condition + buffs

## 14. Combat Format

- Fully automatic combat
- Top-down observation camera
- Player watches and inspects behavior rather than issuing direct combat commands
- Mercenaries normally stay in town
- When they accept a hunting request, they travel to monster territory or dungeons
- Combat occurs in those areas

### Basic Attack Speed
- Baseline attack interval: 2.0 seconds
- Agility modifies attack interval
- Exact min/max values to be balanced later

## 15. Combat AI Structure

Each mercenary scores possible actions.

Possible actions:
- Basic attack
- Use normal skill
- Use strong skill
- Move
- Defend
- Protect ally
- Rescue ally
- Retreat

The final decision is based on:
- Class priorities
- Wisdom
- Personality
- Current HP / mana
- Enemy threat
- Ally condition
- Relationships
- Leader directive
- Positioning
- Skill cooldown

Core rule:
- Class defines what the mercenary values
- Wisdom defines how accurately the situation is evaluated
- Personality and relationships modify the final choice

## 16. Class AI Roles

### Warrior
Primary thought:
"Remove threats by defeating them."

Typical priorities:
- Attack nearby enemies
- Finish weakened enemies
- Intercept enemies attacking allies
- Target higher-threat enemies when wisdom is high

### Knight
Primary thought:
"Prevent allies from collapsing."

Typical priorities:
- Rescue incapacitated allies
- Protect endangered allies
- Block enemy movement
- Hold bosses
- Attack when protection is not urgent

High-wisdom knights may save the priest before a close friend if doing so preserves the party.

### Rogue
Primary thought:
"Exploit openings and avoid bad trades."

Typical priorities:
- Low-HP enemies
- Isolated enemies
- Backline casters
- Targets already distracted
- Avoid direct boss frontal combat

High-wisdom rogues consider escape paths before engaging.

### Archer
Primary thought:
"Remove important targets from a safe position."

Typical priorities:
- Maintain distance
- Attack dangerous ranged/caster enemies
- Finish weakened enemies
- Reposition behind frontliners

### Mage
Primary thought:
"Spend limited mana for maximum effect."

Typical priorities:
- Choose spell based on enemy count and threat
- Avoid wasting strong area skills
- Protect self when threatened
- High wisdom improves strong-skill timing

### Priest
Primary thought:
"Keep the whole group alive."

Typical priorities:
- Heal allies who are most strategically important
- Treat imminent incapacitation
- Support tanks under focus
- Cure harmful conditions
- Reposition when personally threatened

High-wisdom priests do not simply heal the lowest HP target.

## 17. Personality and Combat AI

Examples:

### Brave
- Higher tolerance for risky actions

### Cowardly
- Retreat score increases sooner

### Aggressive
- Attack score rises

### Cautious
- Risk avoidance and retreat score rise

### Comradely
- Rescue and protection score rise

### Self-centered
- Self-preservation priority rises

### Loyal
- Leader directives gain more weight

### Greedy
- High-reward contract motivation rises

Important:
Personality does not erase wisdom.

Example:
- Wisdom 90 + aggressive: understands danger but may choose to fight anyway
- Wisdom 20 + aggressive: may fail to understand the danger in the first place

## 18. Relationships in Combat

Relationships affect AI choices.

Example:
- Friend becomes incapacitated
- Rescue score increases based on relationship value

However:
- Knights and priests may still rescue disliked allies because of class duty
- This creates tension between profession and personal feelings

Relationship values are directional:
- A -> B can differ from B -> A

Potential special relations:
- Friend
- Best friend
- Rival
- Life saver
- Comrade
- Mentor / student
- One-sided crush
- Lovers
- Sworn enemies

## 19. Injury, Incapacitation, Death, and Resurrection

### Injury States
- Normal
- Light injury
- Severe injury
- Incapacitated
- Death risk / death

### Severe Injury
- Mercenary stops normal combat behavior
- Attempts to retreat to town on their own

### Incapacitated
- Cannot move independently
- Requires another mercenary to carry or assist them
- Rescue behavior is affected by class, personality, relationships, and wisdom

### Death
Permanent instant deletion is not the default design.

If a mercenary dies:
- Their body is returned to town if possible
- The temple may perform resurrection within a limited window
- Resurrection requires cost and/or rare materials
- Higher-star mercenaries should be more expensive to revive
- Resurrection should be meaningful, not trivial

### Resurrection Consequences
Possible:
- Temporary Soul Weakness
- Recovery period
- Death / revival recorded in history
- Personality-dependent trauma or growth traits

Core philosophy:
"Death is not character deletion; it is a major event in that mercenary's life."

## 20. Temple

The temple is not only a resurrection building.

Functions may include:
- Healing
- Purification
- Abyssal corruption treatment
- Resurrection
- Blessings
- Religious events

The temple is strongly connected to Lumea worship.

## 21. Skill Structure

Each mercenary has:
- 1 normal skill
- 1 strong skill

### Normal Skill
- Short cooldown
- Frequently used
- Prototype target: about 6-12 seconds

### Strong Skill
- Long cooldown
- Intended to change the battle state
- Prototype target: about 30-60 seconds
- High wisdom strongly improves timing

Both 1-star and 5-star mercenaries still have two active skills.
Higher rank does not increase skill count.

## 22. Skill Acquisition

Skills are not purely random.

Generation flow:
1. Determine class
2. Load class normal-skill pool
3. Load class strong-skill pool
4. Apply weight modifiers from stats
5. Apply weight modifiers from personality
6. Randomly select 1 normal skill
7. Randomly select 1 strong skill

Important:
- Traits increase probability
- They do not guarantee a specific skill
- Unexpected combinations must remain possible

Example:
- Aggressive high-strength warrior -> offensive skills more likely
- High-vitality cautious knight -> survival skills more likely
- Comradely high-wisdom knight -> protection skills more likely
- High-agility cautious rogue -> stealth / evasion skills more likely

## 23. Warrior Skills

### Normal
1. Heavy Strike
2. Whirlwind Slash
3. Charge
4. Rage
5. Execute

### Strong
1. Earth Splitter
2. Berserker Rampage
3. Ruinous Blow
4. Battle Cry
5. Indomitable Warrior

## 24. Knight Skills

### Normal
1. Shield Block
2. Taunt
3. Emergency Recovery
4. Shield Bash
5. Guardian Stance

### Strong
1. Iron Wall
2. Guardian's Oath
3. Immortal Will
4. Fortress
5. Last Shield

## 25. Rogue Skills

### Normal
1. Stealth
2. Ambush
3. Poison Blade
4. Flurry
5. Evasive Maneuver

### Strong
1. Shadow Assassination
2. Shadow Barrage
3. Perfect Concealment
4. Deadly Poison
5. Mark of Death

Stealth design:
- Prefer untargetable rather than absolute invulnerability
- Area effects may still hit, depending on final balancing

## 26. Archer Skills

### Normal
1. Precision Shot
2. Piercing Arrow
3. Rapid Shot
4. Retreating Shot
5. Weak Point Shot

### Strong
1. Arrow Rain
2. Snipe
3. Storm Shot
4. Piercing Judgment
5. Hunter's Mark

## 27. Mage Skills

### Normal
1. Fireball
2. Lightning Bolt
3. Ice Spear
4. Mana Bolt
5. Mana Barrier

### Strong
1. Meteor Fall
2. Chain Lightning
3. Absolute Zero
4. Mana Explosion
5. Mana Release

## 28. Priest Skills

### Normal
1. Healing Light
2. Regeneration
3. Barrier
4. Purify
5. Minor Blessing

### Strong
1. Sanctuary
2. Greater Heal
3. Divine Protection
4. Prayer of Life
5. Divine Blessing

Prayer of Life is not resurrection.
It is an emergency combat recovery tool before permanent death.

## 29. Skill Growth

Because each mercenary only has two skills, those skills can grow through long-term use.

Example:
- Heavy Strike Lv.1 -> Lv.2 -> Lv.3 -> Lv.MAX
- Damage increases
- At high mastery, small secondary effects may unlock

Normal skills grow faster due to frequent use.
Strong skills grow more slowly.

## 30. Five-Star Strong Skill Evolution

When a mercenary awakens to 5-star:
- Strong skill evolves into a legendary version
- Name and effect may improve
- The skill should feel special without adding a third active skill

Examples:
- Guardian's Oath -> Hero's Oath
- Sanctuary -> Divine Sanctuary
- Meteor Fall -> Celestial Meteor

## 31. Affinity / Trust with Guild Leader

Mercenaries have a relationship value with the player.

Positive sources:
- Gifts
- Good equipment
- Medical support
- Successful work
- Supporting their friends

Negative sources:
- Reckless orders
- Broken promises
- Abandoning allies
- Excessive emergency orders

### Natural Decay
Affinity slowly decays over time.

However, deep relationships have a floor:
- Time can make a bond fade
- Time alone cannot fully destroy a deep bond
- Major negative events can break below the floor

Personality may modify gain and decay.

## 32. Guild-Leader Directives

The player can issue high-level directives:
- Check contracts
- Consider a specific hunt
- Defend settlement
- Join expedition
- Rest
- Emergency muster

Directive is not always forced action.

Influence hierarchy:
Autonomous preference < leader directive < emergency order

Emergency orders are stronger but may reduce trust if abused.

## 33. Facilities

Prototype and future facilities may include:
- Inn / lodging
- Tavern
- Hospital
- Blacksmith
- Restaurant
- Training ground
- Contract board
- Shop
- Temple

Core principle:
Buildings should unlock autonomous behaviors, not merely give passive stat bonuses.

Examples:
- Tavern -> drinking, socializing, rumors, recruitment
- Hospital -> treatment, visits, long-term recovery
- Blacksmith -> repairs and crafting
- Training ground -> autonomous training
- Temple -> purification and resurrection

## 34. Contracts

Example contract structure:
- Target
- Danger
- Recommended party size
- Reward
- Expiration

Mercenaries decide whether to participate based on:
- Reward
- Danger
- Personality
- Current condition
- Relationship with leader
- Who else is joining
- Personal goals
- Wisdom

Parties form autonomously.

## 35. Monster Waves

Monster activity escalates over time:
Calm -> Sightings -> Dangerous -> Mass Emergence -> Monster Wave

Monster wave events include:
- Large-scale monster assault
- Boss monster
- Settlement defense

Wave bosses can trigger 5-star awakening checks for eligible 4-star Lv.MAX mercenaries.

## 36. Visual Character Growth

Mercenary appearance is modular pixel art.

Possible layers:
- Body
- Skin
- Face
- Hair
- Armor
- Weapon
- Shield
- Accessories
- Cloak
- Scars

Core identity traits stay recognizable.
Equipment and scars change over time.

Scars and visual changes may come from real events.

Example:
- Severe facial injury -> healed -> permanent eye scar

The character's appearance becomes a visual record of their history.

## 37. Observation UI Direction

When selecting a mercenary during combat, the player may see:
- HP / status
- Current action
- Current target
- Skill cooldowns
- Short AI reason

Example:
"Targeting the orc shaman because it is judged to be the greatest threat."

This supports the design philosophy:
"The mercenary acts; the player understands why."

## 38. Next Recommended Design Topic

The next missing major system is:

### Level / Experience / Stat Growth
Need to define:
- Maximum level
- XP gain
- How star promotion from 1 -> 2 -> 3 -> 4 works
- How stats increase on level-up
- How hidden potential affects growth
- Whether training and combat grow different stats
- How skill mastery interacts with level
- What exactly "4-star Lv.MAX" means before 5-star awakening

This should be designed before deeper economy and long-term balance.

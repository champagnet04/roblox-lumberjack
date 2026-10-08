# roblox-lumberjack

# 🌲 Lumberjack Survival

## Roblox Game Development Specification

---

# 1. Game Overview

Create a Roblox survival/exploration game centered around a lumberjack who enters a dangerous forest to collect wood.

The core gameplay is based around **risk vs. reward**:

> **How much wood can I collect before I make it safely back to camp?**

The player starts with a very small camp containing little more than a fire pit. They enter the forest, chop trees, collect temporary wood, and decide when to turn around.

The farther and longer they stay in the forest, the greater the potential reward — but also the greater the danger.

Players must physically return to their camp to permanently bank the wood they collected.

If the player is caught by the Lorax before returning to camp, all unbanked wood from that run is lost.

Permanent camp progression is never lost.

The game should make the player constantly think:

> "I could go home now... but I could probably get just a little more."

---

# 2. Core Design Philosophy

The game should prioritize:

* Risk/reward decisions
* Short, satisfying gameplay loops
* Physical exploration rather than menu-based progression
* Visible progression
* Player skill and decision-making
* A sense of building something over time
* Exploration and discovery
* Replayability
* Eventually, multiplayer competition

The player should never feel forced to take unnecessary risks.

A player can safely return to camp whenever they want.

However, taking bigger risks should produce significantly better rewards.

The game should NOT become a passive Roblox tycoon where players simply wait for resources to generate.

**The forest is always the source of the player's resources.**

---

# 3. Core Gameplay Loop

The primary single-player loop is:

1. Start at camp.
2. Begin a forest expedition.
3. Enter the forest.
4. Find trees.
5. Chop trees.
6. Collect wood.
7. Carry the wood.
8. Become increasingly tired/heavy.
9. Decide whether to:

   * Continue collecting
   * Rest
   * Return to camp
10. Potentially trigger the Lorax.
11. Escape the Lorax and return to camp OR get caught.
12. If the player reaches camp:

* All current wood becomes permanently banked.

13. If the player is caught:

* All unbanked wood is lost.

14. Permanent wood can be used to improve the camp.
15. Start another expedition.

The central psychological loop is:

> **Collect → Risk → Decide → Escape → Upgrade → Repeat**

---

# 4. Run System

The game should be run-based.

Each expedition is a distinct run.

## Run Start

The player starts from the safe camp.

At the beginning of a run:

* Current temporary wood = 0
* Stamina = full
* Player movement = normal
* Run timer begins
* Run statistics begin tracking

## During the Run

The player can:

* Chop trees
* Collect wood
* Explore
* Rest
* Continue deeper into the forest
* Return toward camp

The player is never forced to trigger the Lorax.

## Successful Run

If the player physically reaches the camp while carrying temporary wood:

* Temporary wood is added to permanent banked wood.
* Run ends successfully.
* Run statistics are recorded.
* Any applicable haul milestone is awarded.
* Player can begin another run.

## Failed Run

If the Lorax catches the player:

* Run ends.
* All temporary/unbanked wood is lost.
* Permanent banked wood remains untouched.
* Camp progression remains untouched.
* Run statistics are shown.
* Player can immediately start another run.

---

# 5. Temporary vs. Permanent Wood

This distinction is extremely important.

## Temporary Wood

Wood collected during the current expedition.

It is at risk.

Example:

> Banked Wood: 450
> Current Haul: 173

If the player reaches camp:

> Banked Wood becomes 623.

If the Lorax catches them:

> Banked Wood remains 450.
> Current Haul becomes 0.

## Permanent Wood

Wood that has successfully been brought back to camp.

Permanent wood is used for:

* Camp upgrades
* Future buildings
* Gameplay progression
* Eventually village construction

Permanent progression is never removed when the player dies.

---

# 6. Carrying Weight

Carrying more wood should physically affect the player.

The more wood the player carries:

* The slower they become.
* The harder it becomes to escape danger.
* The more meaningful the decision to return becomes.

This creates an important tradeoff:

> More wood = more reward = more weight = greater danger.

Example balancing values:

| Current Haul | Movement |
| ------------ | -------: |
| 0–50         |     100% |
| 50–150       |      95% |
| 150–300      |      90% |
| 300–500      |      82% |
| 500+         |      72% |

These values are starting points only and should be adjusted during playtesting.

The game should communicate the player's increasing weight clearly.

Possible feedback:

* Backpack/log pile visually grows.
* Character animation becomes more strained.
* UI displays current haul.
* Movement becomes visibly slower.
* Audio can subtly change as the player becomes heavily loaded.

Do not make the slowdown feel sudden or unfair.

---

# 7. Stamina and Fatigue

The player has a stamina/fatigue system.

Stamina decreases from activities such as:

* Chopping trees
* Sprinting
* Running from danger
* Staying in the forest for long periods

Low stamina should reduce movement speed.

The player should gradually become tired rather than suddenly becoming unusable.

## Resting

The player can stop and rest.

Resting:

* Restores stamina.
* Restores some movement capability.
* Takes time.
* Does not generate resources.

Resting is therefore another risk/reward decision.

> "Do I waste time resting here, or keep going while I'm tired?"

Potential future rest locations:

* Fallen logs
* Rocky areas
* Abandoned campsites
* Temporary campfires
* Other safe environmental locations

For MVP, a simple resting mechanic is sufficient.

---

# 8. Tree Chopping

Trees are the primary resource source.

The player uses an axe to chop trees.

Each tree should require multiple axe swings.

Different axes can later change:

* Number of swings required
* Stamina cost per swing
* Chopping speed

Do not make better axes simply produce unlimited extra wood.

Example:

### Basic Axe

* Slow
* Many swings
* High stamina cost

### Iron Axe

* Faster
* Fewer swings
* Lower stamina cost

### Steel Axe

* Very efficient
* Significantly reduced chopping effort

The axe progression should primarily improve **efficiency**, not completely eliminate the risk/reward system.

---

# 9. Tree Types

The MVP can use one basic tree type.

Later versions should introduce multiple tree types.

Example:

### Small Pine

* Low wood reward
* Low danger
* Common

### Large Oak

* Medium wood reward
* Medium danger

### Ancient Tree

* Very high wood reward
* High danger

The player should eventually learn to recognize that certain trees are more valuable and potentially more dangerous.

---

# 10. Lorax Mechanic

The Lorax is the primary forest threat.

Some trees have the potential to awaken/summon the Lorax when chopped.

The Lorax should not necessarily appear every time.

The purpose is uncertainty.

The player should know:

> "This could happen."

but not:

> "It will definitely happen."

## Lorax Trigger

When a dangerous tree is triggered:

1. Tree interaction occurs.
2. Warning/event animation plays.
3. Lorax appears.
4. Lorax begins pursuing the player.
5. Player must escape.

The player should receive enough feedback to understand what happened.

The Lorax should be intimidating and recognizable without feeling unfair.

---

# 11. Lorax Chase

Once active, the Lorax pursues the player.

The player must:

* Run
* Navigate terrain
* Manage stamina
* Manage carrying weight
* Choose a route back toward camp

This creates a major tension point.

A player carrying 500 wood may technically have enough stamina to escape under normal conditions, but their heavy load makes escape much harder.

The ideal feeling is:

> "I have so much wood. I need to get home."

---

# 12. Lorax Capture

If the Lorax reaches the player:

* Player is caught.
* Current run ends.
* Temporary wood is lost.
* Permanent wood is retained.
* Player sees a run summary.

The failure screen should display:

**RUN OVER**

* Wood Lost: 247
* Trees Chopped: 18
* Time Survived: 7:42
* Best Haul: 312
* Banked Wood: 1,450

Buttons:

**TRY AGAIN**

and eventually other appropriate navigation options.

The player should clearly understand that they did not lose their entire account/progression.

---

# 13. Successful Lorax Escape

Escaping the Lorax and returning to camp should feel rewarding.

Potential future bonus:

* Small successful-escape bonus
* Example: +10% temporary haul

This should remain small.

Do not make intentionally triggering the Lorax the optimal strategy.

The main strategy should still be:

> Collect valuable wood → manage risk → return safely.

---

# 14. Haul Milestones

A major progression system is based on the amount of wood collected **during a single run**.

This prevents players from optimizing the game by simply:

> Chop one tree → return → repeat.

Large single-run hauls should provide additional rewards.

Potential milestones:

| Single-Run Haul | Example Reward       |
| --------------: | -------------------- |
|              25 | Small temporary perk |
|              50 | Small perk           |
|             100 | Useful perk          |
|             250 | Stronger perk        |
|             500 | Rare reward          |
|           1,000 | Major reward         |
|           2,500 | Major achievement    |

These numbers should be balanced during development.

Possible rewards:

### Quick Hands

+5% chopping speed for the next run.

### Light Pack

Reduced fatigue from carrying wood.

### Lumberjack's Rest

Resting restores stamina faster.

### Forest Knowledge

Makes rare/high-value trees easier to identify.

### Veteran Lumberjack

Permanent stamina improvement.

### Deep Woods Permit

Unlocks a future forest region.

The milestone system should reward players for **taking risks successfully**, not simply for grinding.

---

# 15. Player Statistics

The player should have persistent statistics such as:

* Total Wood Banked
* Best Haul
* Trees Chopped
* Successful Runs
* Failed Runs
* Lorax Escapes
* Lorax Captures
* Camp Level
* Deepest Area Reached

Eventually:

* Villages Founded
* Regions Discovered
* Largest Village
* Total Villages
* Multiplayer Wins

The **Best Haul** statistic should be prominently displayed.

This becomes one of the player's primary personal goals.

---

# 16. Main Camp

The camp is the player's permanent safe zone.

The initial camp should be extremely simple:

* Small clearing
* Dirt
* Fireplace/fire pit
* Basic visual indication of the safe zone

The player should immediately understand:

> "This is home."

The camp should physically evolve as the player progresses.

Camp progression should be visible in the world rather than simply represented by a level number.

---

# 17. Camp Progression

Initial progression:

### Stage 0 — Fire Pit

The player starts with:

* Fire
* Small clearing
* Minimal supplies

Feeling:

> "I need to survive."

---

### Stage 1 — Lean-To

The player builds a simple shelter.

Adds:

* Basic sleeping/resting area
* Small storage
* More permanent appearance

Feeling:

> "I have shelter."

---

### Stage 2 — Tent Camp

The camp becomes more established.

Adds:

* Tent
* Storage
* Basic work area
* Improved fire
* Small decorations

Feeling:

> "I have a real camp."

---

### Stage 3 — Lumber/Hunting Hut

The player has a more permanent structure.

Adds:

* Better storage
* Basic workshop
* Axe upgrade functionality
* More substantial camp environment

Feeling:

> "I'm established."

---

### Stage 4 — Cabin

The player gets a true home.

Adds:

* Cabin interior
* Bed
* Storage
* Workshop
* Decorative areas
* Additional functionality

Feeling:

> "I live here."

---

# 18. Later Camp Progression

After the cabin, progression becomes larger and more customizable.

Potential stages:

### Homestead

* Larger property
* Multiple structures
* More customization

### Outpost

* Stronger base
* Larger surrounding territory
* More advanced functionality

### Settlement

The camp begins becoming a village.

Potential structures:

* Multiple cabins
* Lumber mill
* Workshop
* Blacksmith
* Storage buildings
* Roads
* Decorative structures
* NPCs

### Village

The player's first major settlement.

This is the point at which the game eventually transitions from:

> "Survive in the forest"

to:

> "Build and expand your world."

---

# 19. Camp Upgrade Philosophy

Early camp upgrades can happen automatically when the player reaches progression thresholds.

For example:

> Reach 100 permanent wood → camp evolves.

This keeps early progression simple.

Later, players should gain more control over how they spend resources.

The eventual system can become:

**Required progression + player choice + customization**

rather than every player's camp looking exactly the same.

---

# 20. Functional Camp Structures

Camp structures should eventually have gameplay purposes.

### Storage

Increases resource storage capacity.

### Bed

Improves stamina recovery/resting.

### Workshop

Allows better axes and equipment.

### Map Table

Provides information about discovered areas.

### Campfire

Provides a safe recovery area.

### Lookout Tower

Allows the player to see farther into the surrounding forest.

### Lumber Mill

Future advanced structure for processing wood.

### Blacksmith

Future advanced structure for equipment.

Not every upgrade should simply provide a raw stat boost.

Some should unlock new strategies or gameplay options.

---

# 21. Camp Customization

As the camp becomes larger, customization becomes increasingly important.

Possible customization:

* Furniture
* Campfire styles
* Flags
* Signs
* Paths
* Lighting
* Decorations
* Trophies
* Plants
* Storage appearance
* Cabin appearance
* Outdoor furniture

Eventually players should be able to make their camp feel like their own.

The camp should visually communicate the player's accomplishments.

---

# 22. Forest Structure

The initial forest should be relatively small.

Future forest regions can progressively increase:

* Resource value
* Danger
* Distance from camp
* Environmental complexity

Example:

### Forest Edge

Low risk
Low-value resources

### Deep Woods

Medium risk
Higher-value resources

### Old Forest

High risk
Rare/high-value resources

### Ancient Grove

Extreme risk
Very valuable resources

This should encourage players to gradually push farther away from camp.

---

# 23. Environmental Risk Design

The game should ideally teach players to observe the environment.

Future clues could indicate dangerous/high-value trees:

* Unusual mushrooms
* Missing birds
* Strange markings
* Unusual tree appearance
* Different sounds
* Whispering
* Strange movement
* Unusual lighting

These clues should be subtle.

The goal is to create:

> "I think this tree might be dangerous."

rather than:

> "The game randomly killed me."

The initial MVP can use simpler/randomized behavior and add environmental clues later.

---

# 24. Multiplayer — Later Version

Multiplayer should NOT be part of the first MVP.

When introduced, it should be a round-based competitive mode.

Example:

* 6–10 players
* Everyone starts at the same camp
* Countdown
* GO
* Players enter the forest
* Everyone collects wood
* Lorax creates danger
* Round has a fixed time limit
* Player with the most successfully collected wood wins

The multiplayer mode should feel like a race.

---

# 25. Multiplayer Wood

Wood collected during multiplayer contributes to the player's permanent progression.

This prevents multiplayer from feeling disconnected from the main game.

Players should still care about their individual haul.

Potential end-of-round screen:

**ROUND COMPLETE**

1st — 482 Wood
2nd — 421 Wood
3rd — 337 Wood
4th — 291 Wood

The player's collected wood is added to their permanent stash.

---

# 26. Future Multiplayer PvP

A later version can introduce player interaction.

Players can eventually push other players.

Possible mechanic:

1. Player A pushes Player B.
2. Player B falls/gets knocked down.
3. Some of Player B's current unbanked wood drops.
4. The dropped wood remains in the world temporarily.
5. Player B can recover it.
6. Other players can potentially steal it.
7. Lorax danger can make the situation even more chaotic.

The mechanic should be introduced only after the basic multiplayer race is already fun.

The initial multiplayer release should focus on:

> Race + exploration + Lorax + leaderboard.

---

# 27. Future Day/Night System

Day/night is not part of the MVP.

A future version can introduce different dangers at different times.

Example:

### Day

Primary threat:

* Lorax

### Night

Additional threats:

* Wolves
* Reduced visibility
* Different environmental hazards

Night could also introduce:

* Rare resources
* Night-only areas
* Night-only trees
* Greater rewards

This creates another risk/reward decision.

---

# 28. Future Resource System

The initial game should primarily use wood.

Later resources can include:

* Stone
* Plants
* Ore
* Animal materials
* Other region-specific resources

These can eventually be used for advanced construction.

Example:

**Cabin**

500 Wood
100 Stone

**Forge**

200 Wood
150 Stone
25 Ore

This should be introduced gradually rather than overwhelming the initial game.

---

# 29. Long-Term Village Expansion

This is a major long-term goal but is NOT part of the MVP.

Once the player's first camp eventually becomes a village, the world should begin opening up.

The player may discover previously inaccessible forest regions.

The discovery should feel like an adventure rather than a menu unlock.

Potential progression:

1. Player develops first village.
2. A new forest section becomes discoverable.
3. Player notices it through exploration, landmarks, lookout points, NPC information, or map clues.
4. Player must physically travel toward the new region.
5. The journey contains danger.
6. Player successfully reaches the new location.
7. Player establishes a new camp.
8. The new camp can eventually grow into another village.

The player should not simply click:

> "Unlock Region — 5,000 Wood."

They should actually **go there**.

---

# 30. Multiple Villages

The ultimate long-term progression can become:

> **How many villages can I build?**

Each village should be permanently associated with the player's account.

The player eventually has a world map showing all established villages.

Example:

**WORLD MAP**

🏘 Pine Hollow
🏘 Redwood Crossing
🏘 Misty Creek
🏘 Mountain Outpost

Different villages could eventually exist in dramatically different environments.

Potential future regions:

* Pine forest
* Mountain forest
* Snowy forest
* Swamp
* Autumn forest
* Redwood forest
* Caves
* Coastal forest

Different regions can introduce different:

* Resources
* Enemies
* Trees
* Environmental hazards
* Village appearances
* Building materials

This is the game's long-term world-building layer.

---

# 31. Personal World Map

The map should eventually become a permanent record of the player's exploration.

Early version:

* Shows current forest
* Shows camp
* Shows discovered areas

Later:

* Shows multiple regions
* Shows villages
* Shows exploration progress
* Shows landmarks
* Shows discovered resources
* Shows future unexplored areas

Eventually the map becomes a visual representation of everything the player has accomplished.

---

# 32. Monetization Philosophy

Monetization should not make the game pay-to-win.

Core gameplay progression must remain obtainable through normal gameplay.

Players should never feel that they need Robux to compete.

Robux purchases should primarily provide:

* Cosmetics
* Personalization
* Optional convenience
* Private/social features

Do NOT sell core forest progression or major competitive advantages.

---

# 33. Cosmetic Monetization

Potential purchases:

## Axe Skins

Examples:

* Classic
* Golden
* Crystal
* Fire
* Winter
* Halloween
* Other themed designs

Axe skins are cosmetic only.

## Character Cosmetics

* Flannel outfits
* Lumberjack hats
* Boots
* Jackets
* Winter clothing
* Funny costumes

## Camp Cosmetics

* Campfire designs
* Cabin decorations
* Furniture
* Flags
* Signs
* Lanterns
* Paths
* Trophy displays

## Village Themes

Future cosmetic themes:

* Snowy village
* Autumn village
* Nordic-style village
* Fantasy forest
* Cozy mountain village
* Other seasonal themes

These should change appearance without providing major gameplay advantages.

---

# 34. Pets

Future cosmetic pets could include:

* Squirrel
* Raccoon
* Owl
* Deer
* Woodpecker
* Other forest animals

Pets should primarily be companions.

Do not make them automatically collect large quantities of resources, because that could undermine the core gameplay loop.

---

# 35. Emotes

Potential emotes:

* Chopping
* Celebrating
* Sitting by the fire
* Tired lumberjack
* Pointing toward the forest
* Victory dance
* Falling asleep

These are especially useful once multiplayer is introduced.

---

# 36. Titles

Players can display titles based on achievements.

Examples:

* Forest Explorer
* Lumberjack
* Master Lumberjack
* Veteran Lumberjack
* Camp Builder
* Village Founder
* Forest Explorer
* Guardian of the Forest

Some titles should be earned through gameplay.

Others can potentially be cosmetic purchases.

---

# 37. Seasonal Content

Seasonal cosmetic content can provide recurring monetization without changing the core game.

### Halloween

* Haunted cabin
* Pumpkin decorations
* Spooky axe
* Ghost companion
* Halloween campfire

### Winter

* Snowy cabin
* Christmas decorations
* Snowman
* Winter axe
* Snowy campfire

### Fall

* Autumn decorations
* Leaf piles
* Cozy cabin cosmetics
* Fall-themed axe

Seasonal content should remain optional.

---

# 38. Potential Game Passes

Potential future passes:

### VIP Lumberjack

* Exclusive outfit
* Exclusive axe skin
* Exclusive camp decorations
* Special title
* Exclusive emotes

### Camp Customizer

* Additional customization options
* More furniture
* Additional decoration options

### Explorer

* Exclusive explorer cosmetics
* Special compass appearance
* Map decorations
* Explorer title

These should not provide overwhelming competitive advantages.

---

# 39. MVP Scope

The first playable version should be VERY small.

## Required MVP Features

### Player

* Roblox character
* Basic movement
* Running/sprinting
* Basic stamina

### Camp

* Small clearing
* Fire pit
* Safe zone
* Basic permanent wood counter

### Forest

* Small forest
* Basic terrain
* Trees
* Tree chopping

### Axe

* Basic axe
* Chopping animation
* Tree health
* Wood reward

### Run

* Start run
* Temporary wood counter
* Return to camp
* Bank wood
* Lose temporary wood on failure

### Carrying

* Carrying wood affects movement speed

### Fatigue

* Stamina decreases
* Movement becomes slower
* Basic resting mechanic

### Lorax

* Random dangerous tree
* Lorax spawn
* Lorax chase
* Player capture
* Run failure

### Progression

* Permanent wood
* Basic camp upgrade

### UI

* Current haul
* Permanent wood
* Stamina
* Basic run information
* Death/run summary

The MVP's primary purpose is to answer:

> **"Is chopping trees, getting greedy, triggering the Lorax, and desperately trying to get home actually fun?"**

If the answer is yes, everything else can build on that.

---

# 40. Version Roadmap

## Version 0 — Prototype

* Tiny forest
* Fire pit
* Axe
* Trees
* Wood counter
* Basic running
* Basic stamina
* Lorax
* Safe zone
* Capture/death

Goal:

**Prove the core chase is fun.**

---

## Version 1 — The Run

Add:

* Proper run start/end
* Temporary vs permanent wood
* Banking
* Wood loss
* Resting
* Fatigue
* Run statistics
* Best Haul
* Basic haul milestones

Goal:

**Create the complete risk/reward loop.**

---

## Version 2 — Build Your Camp

Add:

* Fire pit
* Lean-to
* Tent
* Hut
* Cabin
* Persistent camp progression
* Basic storage
* Basic axe upgrades
* Camp visuals

Goal:

**Make the player's effort visibly change the world.**

---

## Version 3 — Better Forest

Add:

* Multiple tree types
* Different wood values
* Rare trees
* Deeper forest
* Environmental clues
* Better terrain
* More exploration

Goal:

**Make exploration more interesting.**

---

## Version 4 — Multiplayer Race

Add:

* 6–10 player rounds
* Countdown
* Shared forest
* Round timer
* Multiplayer leaderboard
* Winner screen
* Multiplayer wood contributing to permanent progression

Goal:

**Turn the risk/reward system into a competitive experience.**

---

## Version 5 — Player Interaction

Add:

* Push mechanic
* Knockdowns
* Dropped wood
* Wood recovery
* Wood stealing
* More multiplayer chaos

Goal:

**Add player-vs-player interaction.**

---

## Version 6 — Night

Add:

* Day/night cycle
* Wolves
* Night-only dangers
* Night-only resources
* Visibility changes

Goal:

**Create a second layer of environmental danger.**

---

## Version 7 — Multiple Resources

Add:

* Stone
* Plants
* Ore
* Animal materials
* Crafting
* Advanced building requirements

Goal:

**Expand the survival/building system.**

---

## Version 8 — Custom Buildings

Add:

* Building placement
* Floors
* Walls
* Furniture
* Storage
* Fireplaces
* Decorations
* Trophies

Goal:

**Allow players to create personalized bases.**

---

## Version 9 — Village

Add:

* NPCs
* Lumber mill
* Blacksmith
* Trading
* Multiple buildings
* Larger settlement
* More forest regions

Goal:

**Transform the camp into a true settlement.**

---

## Version 10+ — World Expansion

Eventually add:

* Discoverable forest regions
* Exploration quests
* Dangerous journeys
* New village locations
* Multiple villages
* Personal world map
* Region-specific resources
* Region-specific enemies
* Region-specific village designs

Ultimate goal:

> **Build as many villages as you can across the world.**

---

# 41. Data Persistence

The game should save permanent player progression.

Persistent data should eventually include:

* Permanent wood
* Camp level
* Camp upgrades
* Axe upgrades
* Best haul
* Statistics
* Achievements
* Cosmetic unlocks
* Owned cosmetics
* Discovered regions
* Established villages
* Village locations
* Village progression
* Other permanent progression

Temporary run data should NOT persist if the player leaves or is captured.

Example:

### Saved

* 5,000 banked wood
* Cabin
* Steel axe
* Best haul: 743
* Village established

### Not saved after leaving

* Current run haul: 182
* Current stamina
* Current Lorax chase
* Temporary wood

---

# 42. UI

The UI should be simple and readable.

During a run, the player should be able to see:

**CURRENT HAUL**
247 WOOD

**BEST HAUL**
512 WOOD

**NEXT REWARD**
250 WOOD

**STAMINA**
████████░░

Potentially:

**CARRY WEIGHT**
MEDIUM

The player should not need to constantly open menus to understand their situation.

---

# 43. Camp UI

At camp, show:

**BANKED WOOD**
1,240

**CAMP LEVEL**
Cabin

**NEXT UPGRADE**
2,000 WOOD

**BEST HAUL**
512

Possible buttons:

* Start Run
* Camp
* Map
* Stats
* Customize

Keep the forest itself as the main focus.

---

# 44. Audio Direction

Audio should contribute heavily to tension.

Normal forest:

* Birds
* Wind
* Trees
* Ambient forest sounds

Chopping:

* Axe impact
* Tree cracking
* Wood falling

Low stamina:

* Breathing
* Fatigue sounds

Lorax:

* Environmental silence/change
* Distinct warning
* Chase music/audio
* Increasing intensity

The audio should help the player recognize danger even when they aren't looking directly at the UI.

---

# 45. Visual Progression Philosophy

The player's progression should be visible in the actual game world.

Do not rely solely on:

> Camp Level 1 → Camp Level 2 → Camp Level 3.

Instead:

> Fire pit → shelter → tent → hut → cabin → homestead → settlement → village.

When the player returns from a dangerous expedition and spends their wood, they should physically see what their work accomplished.

The emotional progression should be:

**Fire pit:**
"I need to survive."

**Lean-to:**
"I have shelter."

**Tent:**
"I have a camp."

**Hut:**
"I'm established."

**Cabin:**
"I live here."

**Homestead:**
"This is my home."

**Village:**
"I built this."

**Multiple villages:**
"I built this world."

---

# 46. Important Design Constraints

The following principles should remain true throughout development:

### 1. Do not make banking one tree repeatedly optimal.

Large hauls must provide meaningful rewards.

### 2. Do not make Robux necessary for progression.

Core gameplay should remain free.

### 3. Do not make the forest a passive resource generator.

Players must physically explore and collect resources.

### 4. Do not destroy permanent progression when the player dies.

Only the current unbanked haul is lost.

### 5. Do not make Lorax encounters feel completely unfair.

The player should eventually be able to learn and manage danger.

### 6. Do not build the entire future game into the MVP.

Build the core loop first.

### 7. Do not make every upgrade simply "more power."

Some upgrades should provide new choices, functionality, exploration, or customization.

### 8. Preserve the risk/reward identity.

The central question should always remain:

> **"Do I go home now, or do I risk one more tree?"**

---

# 47. Development Priority

When implementing the game, prioritize features in this order:

1. Player movement
2. Forest
3. Trees
4. Axe/chopping
5. Temporary wood
6. Camp/safe zone
7. Banking
8. Carrying slowdown
9. Stamina
10. Resting
11. Lorax spawning
12. Lorax chase
13. Capture/failure
14. Run summary
15. Permanent progression
16. Camp upgrades
17. Haul milestones
18. Polish
19. Multiplayer
20. Future systems

Do not begin implementing villages, multiple resources, complex building systems, or multiplayer before the single-player loop is enjoyable.

---

# 48. Definition of a Successful MVP

The MVP is successful if a new player can:

1. Spawn at a tiny camp.
2. Understand that they need wood.
3. Enter the forest.
4. Find a tree.
5. Chop it.
6. See their haul increase.
7. Continue deeper into the forest.
8. Become slower/tired.
9. Decide whether to return.
10. Trigger the Lorax.
11. Panic and run.
12. Either escape to camp or get caught.
13. Understand exactly what they gained/lost.
14. Upgrade their camp.
15. Immediately want to try another run.

The desired emotional response is:

> **"I almost died with 300 wood... I should have gone home. Let me try again."**

That feeling is the foundation of the entire game.

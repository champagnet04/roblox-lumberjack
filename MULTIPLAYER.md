# Multiplayer: The Race

The plan for multiplayer, agreed with the owner on 2026-10-09 and confirmed on 2026-10-11 ("I agree with this design for multiplayer"). Nothing here is built. The owner wants it made after the whole camp progression is built (see `CAMP_PROGRESSION.md`).

## What it is

A timed race that is also last one standing. Several lumberjacks share one forest, one camp and one guardian. Each fells trees and banks wood at camp. The guardian removes players from the round one at a time. When the round ends, the survivor with the most wood banked wins.

Solo play stays as it is: each player's own camp, built over about 50 hours. A race does not touch that camp, except that prizes are paid into the player's camp fund.

## Rules

| Subject | Decision |
|---|---|
| Getting in | A menu when you join the game, with Solo, Quick Race and Race with Friends. See "Getting into a race". |
| Racers per round | 1 to 15 real players. Bots fill a round up to 8 racers; each real player who joins replaces a bot. |
| Round length | About 6 minutes. |
| End of round | The timer runs out, or one racer is left. |
| Winner | The most wood banked among racers still standing. A lone survivor wins outright. |
| Guardian | One for the whole forest. Trees felled by everyone add to one hidden count. It hunts whoever fells the tree that wakes it. |
| Rising danger | The guardian wakes more easily and runs faster as the round goes on. |
| Caught | You lose what you are carrying and you are out for the round. |
| When out | You wait safe at the campfire, can watch any remaining racer, and see the scoreboard. |
| Trees | Shared by everyone. A felled tree stays down for the whole round, and the forest regrows between rounds. Deeper trees give more wood, as in solo. |
| Camp perks | Not used in a race. Everyone has the same axe, stamina and torch. |
| Contact between players | None at first. Racers compete for the same trees and share the guardian, and that is all. Pushing may come later, once the basic race is fun. |
| After a round | Results show for a few seconds, the forest regrows, and the next round starts with whoever stays. A button returns to the menu at any time. |

## Getting into a race

Decided with the owner on 2026-10-12. Not built.

- **Solo.** Your own camp, on a private server.
- **Quick Race.** Puts you in a race that is gathering players. A 30-second countdown shows who has joined; the race starts when it ends, or at once if the race is full. Bots fill the empty places. If no race is gathering, a new one is started. A player is never dropped into the middle of a round to wait.
- **Race with Friends.** Opens a private lobby. The host invites friends through Roblox's own invite window, sees them arrive, and presses Start when ready. Only the host can start.
- **Host's switches in a friends lobby.** Two: whether bots fill the empty places, and whether players who were not invited can join. It starts as private with bots on.

How the friends race was built (2026-10-12), filling in what the quiz left open:

- An invited friend can arrive at any time. If a round is under way they watch until the next one.
- If the host has opened the race to others, pressing Start begins the same 30-second gathering as Quick Race, so other players have a chance to arrive. A private race goes straight to the countdown.
- After the first round, later rounds start by themselves, as in Quick Race. The host's switches stay available between rounds and apply to the next one.
- If the host leaves, another player in the race becomes the host.

None of this can be tried in Studio. Moving players between servers and inviting friends only work in the published game.

## Prizes

Fixed prizes by place, paid into the player's camp fund and multiplied by that player's wood-worth from their camp.

| Place | Wood |
|---|---|
| First | 300 |
| Second | 200 |
| Third | 100 |
| Any other survivor | 50 |
| Caught | 0 |

Why fixed prizes: the owner wants the solo progression to take a long time. Six minutes of solo play earns roughly 570 wood before the multiplier, so even a winner earns about half of what solo pays. If racers instead kept the wood they banked, the solo build prices would have to go up. The owner is not settled on this ("I don't know yet") and chose fixed prizes for now.

The score in a race is the plain wood banked, with no multiplier, so new and old players are scored alike.

## Bots

The owner expects few players at the start, so bots fill the empty places.

- Bots are named lumberjack characters with a set look, for example Big Hank or Old Maple. They are presented as characters in the game's world, not as real accounts.
- They play by the same rules: they fell trees, carry wood, bank it, wake the guardian, get chased and get caught.
- Names (owner, 2026-10-11): Big Hank, Old Maple, Sawdust Sam, Birch Betty, Knotty Pete, Granny Oak, Whittlin' Joe, Splinter, Timber Tess, Mossy Mae.
- Look: standard Roblox-shaped characters, each in their own colour of flannel with jeans and a beanie or beard, built in code. Each carries an axe and a torch. Their torches cast no shadows, to keep the game running smoothly.
- Each named bot always plays the same way, careful or greedy, so players learn who to watch out for.
- They steer round tree trunks. If one is stuck for a moment it slips past whatever blocks it.
- Their skill is mixed. Some are cautious and bank often; some are greedy and go deep. They can win. A decent player should usually place in the top three.

## Claude's draft details (not reviewed by the owner)

These fill gaps the quiz did not cover. Each is a starting point to change.

- **Rising danger numbers.** The guardian's hidden wake number starts at 1 to 10 trees, as in solo, and narrows to 1 to 3 by the last minute. Its speed starts at 21 and reaches 24, a sprinting player's top speed, by the end.
- **No wood, no prize.** A racer who is still standing but banked nothing gets no prize. Otherwise standing at camp for a whole round would pay out. Added when rounds were built (2026-10-11).
- **Unbanked wood at the end.** Wood still being carried when the timer runs out does not count.
- **Joining partway through.** A player who joins during a round watches until the next one.
- **Ties.** Decided by the owner on 2026-10-12: racers level on wood are placed by who reached that score first. A chop-off, where the tied racers race to fell a thick tree, is an idea for later; the owner wants to keep it simple for now.
- **The guardian's count in a race.** The owner wants the guardian to appear often, because that is what makes a race hard when real people play (2026-10-12). The hidden number is only slightly larger than in solo: multiplied by 1.5. Claude had first stretched it by the number of racers (four times with 8); the owner rejected that.
- **Bot styles.** Careful: Old Maple, Birch Betty, Granny Oak. Steady: Sawdust Sam, Knotty Pete, Whittlin' Joe, Mossy Mae. Greedy: Big Hank, Splinter, Timber Tess. The numbers behind each style are in the config and are first guesses.
- **After a catch.** The guardian goes back to sleep and a new hidden number is picked, as in solo.
- **Camp materials.** None appear in a race. Materials for camp builds are found in solo only.
- **A round with one real player left.** If every real player has been caught and only bots remain, the round ends at once and goes to results, so nobody waits for bots to finish.
- **A race with one real player.** It runs against seven bots.
- **Race records.** Wins and best race score are saved as their own records, apart from the solo high scores.
- **Forest size.** The current forest is the starting point for 8 racers. It grows if rounds with up to 15 feel crowded.

## How it will likely be built

- Today the game is one server per player. Multiplayer needs two kinds of server: a private one for each player's solo camp, and shared ones for races. The menu sends the player to the right kind.
- Suggested order, each step playable before the next:
  1. Several players in one forest with one shared guardian and a scoreboard.
  2. Rounds: countdown, timer, results, prizes.
  3. Being out: waiting at camp and watching others.
  4. Bots.
  5. The menu and the split between solo and race servers.
  6. Tuning the rising danger and the prizes.

## Still open

- **Prizes.** Fixed for now. Whether survivors should keep what they banked is undecided, and would mean raising solo prices.
- **Bots are the largest piece of work.** They need to find trees, judge when to go home, and run from the guardian through a forest. Their look and names need a quiz before they are built.
- **The menu's look.** Not designed.
- **What a watching player sees.** The camera for watching another racer is not designed.
- **Pushing and stealing wood.** Left for a later update.

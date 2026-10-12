# Record Book

A fourth option on the menu, asked for by the owner on 2026-10-12. Part 1 (recording, and the My Records page) was built the same day and is untested. Part 2 (the leaderboards) is not built.

## What it is

A screen opened from the menu with three pages:

1. **My Records.** Your own records and their details.
2. **Friends.** A leaderboard of you and your friends.
3. **Everyone.** The top 10 of all players, then "...", then your own row with your place.

## Decisions (owner, 2026-10-12)

| Subject | Decision |
|---|---|
| My Records shows | Solo records and race records. Lifetime totals and time played were not chosen. |
| Leaderboards rank by | Several boards, switched with tabs: races won, best race score, best haul, camp progress. |
| Period | Each board has an all-time list and a weekly list that starts fresh every Monday. |
| Your own place | Exact down to 1,000th. Below that it shows "1000+". |

## My Records page

Solo (already saved today):

- Best haul
- Best game
- Furthest tree
- Camp progress: the stage, and builds finished out of the total

Race (new; nothing saves these yet, so they count from the day this is built):

- Races won
- Best race score
- Races run
- Top-three finishes

## The four boards

| Board | All-time | This week |
|---|---|---|
| Races won | Every race won | Races won since Monday |
| Best race score | Highest wood banked in one race | Highest this week |
| Best haul | Most wood banked from one trip, solo | Highest this week |
| Camp progress | Builds finished | Builds finished this week |

Bots never appear on a board. A week starts on Monday at midnight, world time (UTC), so it turns over at the same moment for everyone.

Rules added while building part 1:

- A race only goes in your records if you were racing when the round began. Joining partway through and watching does not count as a race run.
- A win or a top-three finish needs wood banked and at least one other racer, bots included. A race run entirely alone cannot be used to pile up wins.
- Studio's test players are never put on a board.

## Limits set by Roblox

- **Places are refreshed every few minutes, not instantly.** Roblox's leaderboards return the top entries in order but cannot say what place a given player holds, and they allow only a few such requests a minute. So one server at a time reads the top 1,000 of each board and shares that list with every menu server. Your own row always shows your current score; your place is as of the last refresh.
- **The Friends page shows friends who are in the top 1,000 of that board.** It is built from the same shared list, which avoids looking each friend up one at a time. While the game is small that is every friend who has played.
- **Names.** The top 10 need each player's name looked up; friends' names come with the friends list.

## How it will be built

1. **Recording.** Race records are saved with the rest of a player's progress. Each board's all-time and weekly numbers are written to Roblox's leaderboards when they change. The My Records page on the menu.
2. **Leaderboards.** The shared top-1,000 lists, the Everyone page and the Friends page.

Saved progress and leaderboards only work in the published game, or in Studio with its access to Roblox's data services switched on, so most of this is tested on the published game.

## Still open

- Whether the Record Book should also be reachable from inside a game, or only from the menu.
- Whether rows show a small picture of each player's avatar. Names only at first.
- What happens to weekly boards once a week is over: kept for a "last week's winners" list, or dropped.

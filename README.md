# FFXI-AutoBot

An automation and multibox control framework for Windower4 (Final Fantasy XI) written in Lua.

I got sick and tired of using old, jank tools like EasyFarm that worked only when they wanted to, so I decided to write a usable automation kit via Lua as an addon for Windower4. It is incredibly handy for controlling alt accounts from your main character. 

> [!WARNING]
> There are unfinished modules and some parts may bug out at times, but the framework is highly capable.

---

## 📌 Prerequisites & Notes
* This addon **relies heavily** on the `SuperWarp` addon for all warp-related commands. Make sure you have it installed.

## 🛠️ To-Do List
- [ ] Add Job-Specific Module handling.
- [ ] Finish writing the Trusts Module.
- [ ] Fix target-hanging bug (unsure of the cause; sometimes hangs between targets but appears to resume after a bit of time).

---

## 🧩 Included Modules


| Module Name | Status | Description |
| :--- | :--- | :--- |
| `general` |  Ready | Core system and basic character movements |
| `follow` |  Ready | Player positioning and trailing |
| `targeting` |  Ready | Mob selection mechanics |
| `pulling` |  Ready | Pulling automation sequences |
| `combat` |  Ready | Engagement and battle mechanics |
| `casting` |  Ready | Spell rotation handling |
| `superwarp` |  Ready | Map and zone navigation integration |
| `interaction`|  Ready | Direct NPC and trade mechanics |
| `trusts` | ⚠️ *WIP* | Trust management system |

---

## 💻 Addon Commands

**Base Commands:** `//ab` | `//autobot` | `//bot`

### Core Addon Management
* `//autobot help` - Displays the help menu.
* `//autobot set` - Toggle an addon module.

### 👥 General & Party
* `//autobot rest` - Rest character.
* `//autobot heal` - Heal character.
* `//autobot join` - Join party.
* `//autobot leave` - Leave party.
* `//autobot disband` - Disband the party.
* `//autobot passleader <name>` - Transfer party leadership.
* `//autobot invite <name>` - Invite a player to the party.
* `//autobot warpring` - Equips and uses your Warp Ring.
* `//autobot trade <name>` - Opens a trade window with specified player.
* `//autobot accepttrade` - Accepts the active trade.
* `//autobot mount <name>` - Mounts the specified mount.
* `//autobot mountup` - Mounts the default mount (Crawler).

### 🏃 Follow
* `//autobot followme` - Start following the host player.
* `//autobot follow <target>` - Start following a specific player.
* `//autobot stopfollow` - Stop following.

### 🌐 SuperWarp
* `//autobot warp/warpto <warp type> <warp location> [index]` - Execute a warp command.

### 🎯 Targeting
* `//autobot target add <monster>` - Add a monster to the target list.
* `//autobot target remove <monster>` - Remove a monster from the target list.
* `//autobot target list` - Display current targets.

### 🏹 Pulling
* `//autobot pull start` - Start pulling targets.
* `//autobot pull stop` - Stop pulling targets.
* `//autobot pull method [spell/ranged/ability] "action_name"` - Set the pull method.

### ⚔️ Combat
* `//autobot attack` - Execute an attack command.
* `//autobot assist [target]` - Assist a target (defaults to player).
* `//autobot disengage` - Disengage from combat.
* `//autobot turn` - Spin character around 180 degrees.

###  Magic Casting
* `//autobot cast "spell" [target]` - Cast a specific spell.
* `//autobot stopcasting` - Force stop current spellcasting.

### ⚙️ Configuration & Whitelist
* `//autobot settings` - Show current module states.
* `//autobot toggle <module>` - Toggle a specific module on/off.
* `//autobot whitelist add <user>` - Add a user to the allowed list.
* `//autobot whitelist remove <user>` - Remove a user from the allowed list.
* `//autobot whitelist list` - List all whitelisted users.

---

## 💬 Remote Chat Commands
These commands can be whispered to the character via `/tell` or called out in `/party` chat to trigger actions on your alt accounts.

### ⌨️ Simulated Key Presses
Usage: `!key [keypress]`
* `Enter` | `Up` | `Down` | `Left` | `Right` | `Tab`
* `STab` (Shift + Tab)
* `F1` (Target Self) | `F8` (Target NPC) | `Esc`

### 📦 General & Commands
* `!command <command>` - Issue a direct text command (e.g., `!command //lua load superwarp`).
* `!warpring` - Force use of Warp Ring *(may require manual equipment check first)*.

### 🤝 Party Management
* `!invite <player>` - Invites target player. Defaults to the person issuing the chat command if no name is given.
* `!join` - Accepts an incoming party invitation.
* `!leave` - Leaves current party.
* `!passleader` - Passes party leadership to the person issuing the chat command.
* `!disband` - Instantly disbands the party.

### 🚲 Mount Control
* `!mount` or `!mountup` - Mounts up.
* `!dismount` - Dismounts.

### 🏃 Navigation / Following
* `!follow <target>` - Follows the specified player name.
* `!followme` - Follows the person issuing the chat command.
* `!stopfollow` - Halts all follow movements.
* `!setfollowdistance` - *Not implemented yet.*

### 🪙 Trading
* `!trademe` - Initiates a trade window with the person issuing the chat command.
* `!trade <player>` - Opens trade with target player. Defaults to command issuer if blank.
* `!accepttrade` - Confirms and accepts the active trade window.
* `!canceltrade` - Closes out of the active trade window.
* `!tradeallgil` - Automates putting all inventory gil into the active trade window.
* `!clear` - Clears items from the open trade window.

### ⚔️ Battle & Magic
* `!assist` - Assists the person issuing the chat command.
* `!attack` - Attacks the current target.
* `!disengage` - Disengages weapon from target.
* `!turn` - Turns the character around 180 degrees.
* `!cast <spell> [target]` - Casts a spell. Defaults to current target if blank (e.g., `!cast "Warp II" <me>`).
* `!stopcasting` - Interrupts current cast.

### 🎯 Automated Targeting
* `!target <add/remove> <target>` - Adds or removes monsters from the automation loop.
* `!target list` - Prints out the current active `TargetList`.
* `!target <start/stop>` - Starts or stops the auto-targeting routine for your `MobList`.
* `!tnpc <target>` - Target a specific NPC *(Warning: May be broken)*.

### 🏹 Remote Pulling
* `!pull <start/stop>` - Toggles pulling state.
* `!pull method <spell/ranged/ability] [spell/ability]` - Configures how mobs are pulled.

### 🎭 Trusts (Work In Progress)
Usage: `!trust <command>`
* `save` | `list` | `cooldown`
* `summon <name>` | `release <name>`
* `monitor <hp/mp/both> <threshold>`

### 🌀 Warping (Requires SuperWarp)
Usage: `!warp/!warpto <WarpType> <Zone> <Index#>`

**Example:**
```text
!warpto hp (Southern San d'Oria) 1
```
*Result: Automatically warps the character to the West Ronfaure Gate at Home Point #1 in Southern San d'Oria.*

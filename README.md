# FFXI-AutoBot
Automation &amp; Control Framework for Windower4 (FFXI)

I got sick and tired of using old jank tools like EasyFarm that worked when they wanted to,
so I decided to see if I could write a useable automation kit via LUA as an addon for Windower4.
There are unfinished modules, and some parts may bug out at times, but it's very capable.
Very handly for controlling alt accounts from your main.

NOTES:
-----
This relies on the SuperWarp addon for the Warp Commands.

TODO:
-----
1. Add Job Specific Module handling.
2. Finish writing Trusts Module.
3. Fix bug regarding targeting (unsure of the cause. sometimes it will hang between targets but does appear to resume after a bit of time)

------------------
-- Modules
------------------
general
follow
targeting
pulling
combat
casting
trusts -- NOT COMPLETE
superwarp
interaction

---------------------------------------
-- Addon Commands [ab | autobot | bot]
---------------------------------------
//autobot help					 - (Displays Help Menu)

------ ADDON ------
//autobot set                    - (Addon) toggle a module")

------ GENERAL ------
//autobot rest                   - (General) Rest command")
//autobot heal                   - (General) Heal command")
//autobot join                   - (General) Join command")
//autobot leave                  - (General) Leave command")
//autobot disband                - (General) Disband command")
//autobot passleader <name>      - (General) Transfer leadership")
//autobot invite <name>          - (General) Invite a party member")
//autobot warpring               - (General) Equips & Uses Warp Ring")
//autobot trade <name>           - (General) Opens a Trade Window")
//autobot accepttrade            - (General) Accepts the Trade")
//autobot mount  <name>          - (General) Mounts Specified Mount")
//autobot mountup                - (General) Mounts Default (Crawler)")

------ FOLLOW ------
//autobot followme				 - (Follow) Start following the player")
//autobot follow <target>        - (Follow) Start following specified player")
//autobot stopfollow             - (Follow) Stop following")

------ SUPERWARP ------
//autobot warp/warpto <warp type> <warp location> [index] - (Superwarp) Warp command")

------ TARGETING ------
//autobot target add <monster>   - (Targeting) Add a monster to the target list")
//autobot target remove <monster> - (Targeting) Remove a monster from the target list")
//autobot target list            - (Targeting) Display current targets")

------ PULLING ------
//autobot pull start             - (Pulling) Start pulling targets")
//autobot pull stop              - (Pulling) Stop pulling targets")
//autobot pull method [spell/ranged/ability] \"action_name\"  - (Pulling) Set the pull method")

------ COMBAT ------
//autobot attack                 - (Combat) Execute an attack")
//autobot assist [target]        - (Combat) Assist (defaults to player)")
//autobot disengage              - (Combat) Disengage from combat")
//autobot turn                   - (Combat) Execute a turn command")

------ CASTING ------
//autobot cast \"spell\" [target]  - (Casting) Cast a spell")
//autobot stopcasting            - (Casting) Stop casting")

------ SETTINGS ------
//autobot settings               - Show current module states")
//autobot toggle <module>        - Toggle a module (general, follow, combat, casting, superwarp)")
//autobot set <module>           - Toggle a module (if on, turn it off; if off, turn it on)")
//autobot whitelist add <user>   - Add a user to the whitelist")
//autobot whitelist remove <user>- Remove a user from the whitelist")
//autobot whitelist list         - List whitelisted users")
//autobot help                   - Displays this help message")



-------------------------------------------------------
-- Chat Commands: Can be issued via Tell or Party Chat
-------------------------------------------------------

-----------------
-- Key Presses
-----------------
!key [keypress]
	-Enter
	-Up		(arrow)
	-Down	(arrow
	-Left	(arrow)
	-Right	(arrow)
	-Tab
	-STab	(Shift + Tab)8
	-F1		(Target Self)
	-F8		(Target NPC)
	-Esc

------------------
-- General
------------------
!command <command>		(Issues direct commands. Ex: !command //lua load superwarp)
!warpring				(Uses Warp Ring) [may require command to equip prior to use]

------------------
-- Party Commands
------------------
!invite <player>		(Invites specified player. If no player specified invite command issuer)
!join					(Accepts a Party Invite)
!leave					(Leaves the Party)
!passleader				(Passes party leader to command issuer)
!disband				(Disbands the party)

------------------
-- Mount Control
------------------
!mount / !mountup	(Mounts)
!dismount			(Dismounts)

------------------
-- Following
------------------
!follow <target>	(Follows Specified Player)
!followme			(Follows Command Issuer)
!stopfollow			(Stops following)
!setfollowdistance  (!!!Not implemented yet!!!)

------------------
-- Trading
------------------
!trademe			(Initiates trade w/ command issuer)
!trade <player>		(Trades specified player, if no player is issued then trade command issuer)
!accepttrade		(Accepts the Trade Window)
!canceltrade		(Cancels the Trade Window)
!tradeallgil		(Trades all gil when Trade Window is open)
!clear				(Clears Trade Window)

------------------
-- Combat
------------------
!assist					(assists command issuer)
!attack					(attacks target)
!disengage				(disengages target if engaged)
!turn					(turns character around 180)
!cast <spell> [target]	(If no target specified, cast on current target, player names can be specified. Ex: [!cast "Warp II" <me>])
!stopcasting			(Cancels spellcasting)

-----------------
-- Targeting
-----------------
!target <add/remove> <target>	(Adds, Removes targets)
!target list					(Outputs current TargetList)
!target <start/stop>			(Starts or Stops Auto-Targing of MobList)
!tnpc <target>					(Targets specified NPC) [May be broken]

-----------------
-- Pulling
-----------------
!pull <start/stop>
!pull method <spell/ranged/ability> [spell/ability]		(Sets the pulling method)

--------------------------
-- Trusts (FIXME - Work in Progress)
--------------------------
!trust <command>
	-save
	-list
	-summon <name>
	-release <name>
	-monitor <hp/mp/both> <threshold>
	-cooldown

--------------------------------
-- Warping (Utilizes SuperWarp)
--------------------------------
!warp/!warpto <WarpType> <Zone> <Index#>

Example: !warpto hp (Southern San d'Oria) 1
this will warp to the West Ron Gate @ Southern San d'Oria

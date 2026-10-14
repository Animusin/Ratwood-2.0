HERALD: SERVER-SIDE AHELP RELAY AND OWNER-OPERATED READ INTERFACE

Installation using ordinary config access only
---------------------------------------------
After merging and deploying this update, add the following settings directly to
the existing config/config.txt. There is no need for a new config file, server
shell access, additional Python service or a running desktop computer:

WEBHOOK_ADMINHELP https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN
HERALD_READONLY_KEY REPLACE_WITH_A_RANDOM_SECRET_OF_64_TO_128_CHARACTERS

These are placeholders, NOT working credentials. Use a channel-bound incoming
Discord webhook created for the PRIVATE ahelp channel. Do not put the Discord
bot token on the game server. Do not reuse/move the existing roundstart webhook.
Keep WEBHOOK_ROUNDSTART unchanged. Restart/update the game server as usual.
Both new settings are optional: empty/absent values leave their features disabled.
Hidden config protection does not encrypt the config file itself: keep it private.

The desktop Herald needs the SAME read key locally; no server address or key can
be supplied by model output. Its owner-only access check is separate from the game
server's signature check: possession of the shared secret grants read access.
No actual credentials, private URLs or local user account names belong in this PR.

What works with the owner's computer off
----------------------------------------
The game server posts every AddInteraction entry via HTTPS: initial ahelps,
player messages, admin replies and ticket/system updates. It does not depend on
admin availability, the desktop assistant, Codex, Grok or any language model.
Ticket content is not sent to a language model by this feature.
The existing roundstart announcement mechanism is unchanged.

Messages are split into at most 800 Unicode codepoints per part. Admin hyperlink
attributes/tokens are stripped; Discord notifications and previews are disabled.
One async HTTPS request is active at a time, with at least two seconds between
requests. A slow request does not block the game loop or trigger concurrent sends.
429 responses delay delivery; 401/403/404 pause the current webhook until config
is changed. Pending content is not silently discarded on these errors.

The queue uses alternating data/herald_ahelp_queue_0.json and _1.json checkpoints.
Host persistence must retain these files between deployments for crash recovery.
Queue limit: 10000 parts; overflow is explicitly reported in the normal admin log.
A destination change does not automatically copy old private tickets elsewhere.
Delivery is at-least-once, not exactly-once: a lost confirmation or checkpoint can
cause a duplicate with the same Event ID. Delivery also cannot be guaranteed if
the server disk is unwritable, its data is reset, or the queue fills during outage.

Read interface and load limits
------------------------------
The separate Topic keyword herald_read accepts ONLY:
  status: round ID, map, player count, CPU, tick lag, round state;
  players: 25 connected clients per page, ckey/name/stat, offset 0..1000;
  character: one normalized ckey, name/stat/health/x/y/z, at most 1000 clients.
There is no SQL, arbitrary SDQL, proc-call, object reference lookup, dynamic var
selection, world-atom traversal or game mutation endpoint. Four fixed SDQL read
examples are exercised in the LOCAL test world only, not exposed to the API.
Authentic reads are limited globally to one per second; replies are bounded by
the fixed fields and page size. Invalid inputs are rejected before world lookup.
The client should enforce its own timeouts, frame limits and owner authorization.
These bounds reduce risk; they are NOT a proof that game lag/crashes are impossible.

Requests and responses use SHA-256(key + '|' + message + '|' + key).
The request message is:
  request|ACTION|CKEY|OFFSET|UNIX_MINUTE|NONCE|OPERATOR
NONCE: fresh 32 lowercase hex chars; OPERATOR: numeric Discord ID for audit.
Arguments sent as URL query parameters are herald_read, ckey, offset, minute,
nonce, operator, signature. Signature covers exactly the displayed raw strings.
Nonce reuse is rejected; timestamps allow a three-minute clock skew. Request
authentication values/private results are not written to world.Topic logs.
Responses contain data (a JSON STRING) and signature for:
  response|NONCE|DATA_STRING
Verify the signature before parsing/displaying the inner data. A response error
is an unsigned error object with no private data. Never retry an auth denial by
changing identity or bypassing authorization.
The Topic transport is NOT encrypted: use a protected network/tunnel if response
confidentiality against network interception is required. Ahelp delivery is HTTPS.

Validation
----------
Compile roguetown.dme normally with Dream Maker.
Windows local integration probe (BYOND + Python 3 required):
  powershell -File tools/herald/run_probe.ps1
The probe uses only sample config/assets and synthetic credentials in a separate
world under tmp/herald-probe. It does not connect to production or Discord.
It checks ordinary config.txt loading, relay queue/429/403/confirmation, Russian
text and hyperlink scrubbing, four real SDQL read queries without character
mutation, signed BYOND packets, replay denial and arbitrary-SDQL denial.
It also executes real custom/built-in/subtle/free-text emote paths, checks window
refresh/expiry and author/body isolation, speech/whisper inclusion, OOC/seen-copy
exclusion, Unicode splitting, batching/429/ACK, queue cap and shutdown flushing.
The script stops its exact test daemon and removes its generated next_map.json.
After production deployment, separately test an ahelp, player/admin replies and
closure in the designated private Discord channel.

Custom emotes and three-minute context
-------------------------------------
Optional extra line in the SAME existing config/config.txt:
WEBHOOK_CUSTOM_EMOTES https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN

Use a separate incoming webhook bound to the PRIVATE emote moderation channel.
This setting is hidden/validated like WEBHOOK_ADMINHELP. Sharing the roundstart
or ahelp URL is refused. No desktop bot or language model is involved.

A successful intentional player-written custom emote (me, big-me, free text,
subtle/big-subtle) opens/refreshes a three-minute window on that character/body
and ckey. It includes the triggering emote, then that author's LOG_EMOTE,
LOG_SAY and LOG_WHISPER entries. Built-ins, speech and whispers never refresh
the deadline. Built-ins alone do not trigger it. Swapping characters does not
carry the window across, and another ckey possessing the body cannot inherit it.
Observers, NPCs without a ckey, OOC/LOOC, admin PMs, other characters' messages
and recipient-side LOG_SEEN copies are excluded. This is source-log text, not
a guarantee that nearby players heard it; whisper/swallowed/forced tags remain.

Format: YYYY-MM-DD hh:mm:ss UTC | ckey | real character name | KIND text
KIND is EMOTE, SAY or WHISPER. Timestamp is the event time, not delivery time.
Long messages are split without dropping text; each part repeats its heading.
HTML/admin hyperlinks and active Discord mentions are stripped/neutralized.

At most 2000 parts are retained in an independent queue; overflow is warned in
the normal admin log, at most once/minute. Up to 20 short parts are batched in
one bounded Discord message every transport cycle (one outstanding request).
Emote hooks only append in memory; alternating data/herald_emote_queue_0.json
and _1.json checkpoints are written at most once per two-second subsystem fire,
and flushed at orderly shutdown. A hard crash may lose the last uncheckpointed
entries; lost send confirmations can duplicate a batch. Window timers are not
persisted across game-server restarts. Existing ahelp checkpoints are unchanged.

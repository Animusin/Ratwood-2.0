HERALD: SERVER RELAYS, READ INTERFACE AND OPT-IN FIXED ADMIN ACTIONS

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
This read endpoint has no SQL, arbitrary SDQL, proc-call, object reference lookup,
dynamic var selection, world-atom traversal or game mutations. Four fixed SDQL read
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

Optional manual game administration (one shared key)
---------------------------------------------------
The existing HERALD_READONLY_KEY retains its legacy name but is ALSO used to sign
the new fixed admin endpoint, ONLY when both of these extra main config lines exist:
HERALD_ADMIN_OPERATOR_IDS DISCORD_OWNER_ID
HERALD_ADMIN_CKEY YOUR_NORMALIZED_BYOND_ADMIN_CKEY

No second secret, new daemon or extra config file is required. Without this mapping
writes remain disabled. The configured game admin must exist in loaded admin/deadmin
datums and have R_AHELP for replies, R_BAN for bans, R_ADMIN for kicks/PQ. This allows
the administrator to be offline; it does NOT create an admin or spoof an usr/client.
The initial desktop implementation authorizes only its owner, not Royal Guard or
chat personas. The shared secret now has privileged scope: keep it private. Anyone
holding it can claim an allowlisted Discord operator ID; IDs are not extra secrets.

Fixed actions, one target each, exact current rogue_round_id and normalized ckey:
  reply: {ticket_id: integer 1..9999999, text: 1..1000 characters}
    Active GAME ahelp only, matching initiator/current ticket and connected player.
    Plain literal text, labeled with the actual admin ckey + Herald + Discord ID;
    ahelp history, sound/flash and server relay use the normal game mechanisms.
    No claiming/closing ticket, unsolicited replies or AI autonomous moderation.
  ban: {minutes: integer 0..525600, reason: 1..500 characters}
    Zero is an explicitly requested permanent server ban. Ckey only, no IP/CID,
    sticky/role/admin bans. Known database player required. Existing active server
    ban returns already_banned rather than inserting another. Uses parameterized
    standard ban and note tables with real admin ckey, round, reason and Discord
    audit identity. No fake admin IP/CID (stored as 0/empty). DB unavailable -> refusal.
  kick: {reason: 1..500 characters}
    Connected non-admin only. Staff/admin targets are protected for bans and kicks.
  pq: {delta: nonzero number -100..100, reason: 1..500 characters}
    Known saved player required, including offline. Uses adjust_playerquality and
    its usual history/admin logs, verifies persisted before/after with -100..PQ_CAP
    clamp. The existing game denies entry at PQ <= -100: deductions can cause this.

No arbitrary SQL, SDQL, role string, proc, path, world atom traversal or mass action
is exposed. One action runs at a time, at least two seconds between new actions,
at most 512 receipts/round. Ticket lookup is bounded to 1000 active tickets. Ban
database calls use existing async rust-g queries. These limits reduce load; they
are not a guarantee that the database/filesystem can never stall or crash.

Topic keyword herald_admin = reply|ban|kick|pq. Other query fields are round, ckey,
payload (JSON string with action-specific fields), minute, request_id (32 lower hex),
operator (allowlisted numeric Discord ID), signature. Unknown fields/actions fail.
Canonical signed string: admin_request|ACTION|ROUND|CKEY|SHA256(PAYLOAD)|UNIX_MINUTE|REQUEST_ID|OPERATOR
Response signature: admin_response|REQUEST_ID|DATA_STRING using the same signature
function as reads. No key is sent on the wire. Topic still is NOT encrypted: a
protected network/tunnel is necessary for confidentiality against interception.

The request ID is bound to action/target/payload/operator. Identical retransmission
returns its cached outcome, never repeats. Reusing it for different data fails.
Alternating data/herald_admin_receipts_0.json/_1.json are saved BEFORE side effects
and after completion, scoped to the current round. Retain them across updates.
If the initial checkpoint fails, nothing is executed. A partial runtime/lost ACK
leaves an uncertain reservation: do not repeat automatically. A completed reply
means sent to the connected client, NOT proof the player read it. Desktop SQLite
also retains attempted/results outside model memory and across bot restarts.

Local probe checks actual PQ save changes and idempotency/recovery, fixed protocol,
signatures, mapping/rights/round guards, HTML escaping, active ahelp history and
SQL parameter binding with a MOCK database. Recipient delivery is a FAKE test
fixture because no real BYOND client connects. No production ban/kick/PQ/reply was
performed. After deployment, separately test delivery with a volunteer account
and standard ban-table compatibility in the host's staging database.

Optional autonomous duty replies (disabled by default)
-----------------------------------------------------
After deploying this update, enable only if the owner has deliberately authorized
AI duty replies. Add to the SAME main config/config.txt:
HERALD_DUTY_ENABLED 1

The existing read key, operator allowlist and configured R_AHELP authority are
required. The authority permits this feature but is NOT presented as its speaker:
the recipient sees "Геральд — автоматический помощник администрации" and an
explicit AI disclaimer. Desktop duty must also be switched on by its owner.

The separate herald_duty Topic supports ONLY snapshot and reply; no punishment,
claim/close, SQL, SDQL, paths, proc calls or dynamic fields. In the snapshot,
admins.active counts connected staff WITH a current admin holder, including AFK,
hidden and holders without R_AHELP. admins.total additionally includes deadminned
staff. Replies pause while active > 0; deadmin-only presence (total > 0, active=0)
does not pause them. Unknown presence still refuses replies.
Any human ticket intervention permanently yields that ticket to the human.
Human PMs through admin_pm/admin_ticket_log touch the typed state without changing
the existing ticket chat/webhook rendering. Snapshot typed history is bounded to
10 active tickets and the last 3 observations of 200 characters each; omitted
tickets are explicitly reported. New unhandled player messages are prioritized
ahead of old handled/answered tickets; a delivered duty reply drops that priority
until another player message arrives. Runtime data consists only of total/skipped
counters, not raw stacks or additional log reads. No language model runs in DM.

Each reply is limited to 30 whitespace-separated words and 1000 characters, must
match the current round, ckey, active/connected ticket and exact revision. The
server rechecks staff presence, human handler and revision AFTER reserving its
receipt, immediately before delivery. A new player message is required after
each duty reply; replies are limited to one per minute per ticket and one per
10 seconds globally. Snapshot reads are limited to one every 2 seconds.

The canonical snapshot request is duty_snapshot|UNIX_MINUTE|NONCE|OPERATOR; response
signature covers duty_snapshot_response|NONCE|DATA_STRING. Snapshot query fields
are herald_duty=snapshot, minute, nonce, operator, signature. Reply fields are
herald_duty=reply, round, ckey, payload, minute, request_id, operator, signature;
payload is exactly {ticket_id,version,text}. Reply signature covers
duty_request|ROUND|CKEY|SHA256(PAYLOAD)|UNIX_MINUTE|REQUEST_ID|OPERATOR; response
signature covers duty_response|REQUEST_ID|DATA_STRING. Same signature function
and transport confidentiality caveat as the other bridge endpoints apply.

Alternating data/herald_duty_receipts_0.json/_1.json reserve each effect before
delivery, capped at 512 per round. Keep these files between server deployments.
Uncertain receipts must NOT be repeated automatically; a fresh request ID must
never be generated merely because the earlier result is unknown. Isolated probes
exercise held/AFK/hidden/deadmin staff, race/revision/word-limit/idempotency guards
and real signed wire requests with a FAKE recipient. Real client delivery remains
a deployment test.
Unreadable or malformed receipt checkpoints pause new replies, even if another
checkpoint is readable; they require host review, not automatic ledger deletion.
Snapshot envelopes also enforce a byte budget by omitting trailing tickets and
marking truncated, rather than sending an oversized BYOND frame.

Optional owner-confirmed FULL native SDQL (dangerous, disabled by default)
-----------------------------------------------------------------------
This is NOT part of duty, read-only or the four manual fixed admin endpoints.
It is a separate herald_sdql Topic and is never an execution tool for a model.
The client may prepare a proposal, but only a literal confirmation by the owner
in the configured PRIVATE admin channel authorizes the exact displayed query.

To allow it after deployment, add to the SAME main config/config.txt:
HERALD_SDQL_ENABLED 1
HERALD_SDQL_APPROVAL_CHANNEL_ID 1252341888023789568

The approval-channel setting already defaults to that ID. The client must check
that it belongs to the correct guild and is private; the game server does not
contact Discord and cannot independently verify a message or its channel ACL.
It trusts only the authenticated client attestation, bound to operator, approval
message/channel IDs, proposal ID, query SHA-256, exact current round and expiry.
The same existing read key/admin mapping/operator allowlist are required, plus
the native SDQL verb's R_DEBUG permission. No second key or human client is
invented. usr/marked are absent when no actual game usr exists.

All four native forms SELECT/UPDATE/DELETE/CALL, IN/MAP/WHERE, nested calls and
native USING options are supported by the existing parser/query engine. Queries
use superuser=FALSE and ordinary CanProcCall/vv guards. Remote proccalls establish
an explicit authenticated caller context so advanced-proccall protections are
not skipped merely because usr is null. KEEP_ALIVE retains query data for
inspection, not permission for an automatic unconfirmed re-execution. Remote
queries are one-shot: only their job can schedule the initial Run; native UI RUN,
ARun/Run proc calls and edits of launch flags cannot replay or start a future
sequential query early. Native HALT/delete remain available for stopping/review.

IMPORTANT: full SDQL is inherently capable of destructive world changes and
arbitrary proccalls. A non-yielding/infinite proc, HIGH priority, huge SELECT,
runtime, memory exhaustion, spawned child proc or engine bug can lag, hang or
crash the game. This interface is NOT a sandbox or rollback mechanism. Transport
timeouts, asynchronous status and output limits do NOT stop the engine. Native
completion does not prove every target accepted an edit or that all side effects
spawned by called procs are finished. Never automatically re-execute an unknown
operation, including with a new request/proposal ID. Human review is mandatory.

Bounded wrapper: 8000 UTF-8 bytes of exact query text, at most 64 parsed statements,
one live bridge job, 30-second new-job cooldown, 128 durable receipts per round,
12000 characters of plain result text and a further 48000-byte envelope cap.
These are interface bounds, NOT CPU/memory/loop limits on native SDQL evaluation.
The normal engine may build a much larger result before output is shortened.

Execute query fields: herald_sdql=execute, round, payload, minute, request_id,
operator, signature. payload is exactly {query,query_sha256,proposal_id,
approval_message_id,approval_channel_id,approved_at,expires_at}. IDs/timestamps
are strings; proposal_id/request_id are 32 lowercase hex. approved_at/expires_at
are decimal Unix SECOND strings. The server validates exact seconds without
lossy 32-bit Unix-second arithmetic: no future approval, expired approval or
duration over 600 seconds. A proposal/approval message can be used only once.
Canonical execute signature:
sdql_request|ROUND|SHA256(PAYLOAD)|UNIX_MINUTE|REQUEST_ID|OPERATOR
Execute response signature: sdql_response|REQUEST_ID|DATA_STRING

After reservation is saved BEFORE any native query evaluation, execute returns
accepted and the native job runs asynchronously. Read-only polling fields:
herald_sdql=status, round, request_id, minute, nonce, operator, signature.
Canonical status signature:
sdql_status|ROUND|REQUEST_ID|UNIX_MINUTE|NONCE|OPERATOR
Status response signature: sdql_status_response|NONCE|DATA_STRING
Both responses bind action=execute, round, request_id, query_sha256, proposal_id;
statuses are accepted/running/completed/operation_uncertain/refused. Status reads
are paced to one per two seconds and never start/repeat a query. Authenticated
execution refusals are signed. Unsigned errors are not proof that no effect ran.

Keep data/herald_sdql_receipts_0.json and _1.json between updates. They retain
approval/digest metadata and bounded results, not the raw query. Corrupt receipts
block new executions. A pending/running receipt after restart becomes uncertain,
never a new execution. If final persistence fails, the earlier reservation still
prevents repetition. Existing endpoints retain their prior capabilities.

Isolated probes use only local dummy datums, synthetic approvals/credentials and
localhost Topic. They must never run against production. Real-server deployment
and any actual SDQL execution require a separate deliberate owner action.

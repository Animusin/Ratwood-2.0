// Shared constants for the Ratwood LLM NPC cognitive brain & BYOND body wrapper.

// ---- Action Vocabulary ----
#define LLM_ACTION_IDLE "idle"
#define LLM_ACTION_APPROACH "approach"
#define LLM_ACTION_FOLLOW "follow"
#define LLM_ACTION_CHASE "chase"
#define LLM_ACTION_KEEP_DISTANCE "keep_distance"
#define LLM_ACTION_WANDER "wander_nearby"
#define LLM_ACTION_GO_TO_AREA "go_to_area"
#define LLM_ACTION_CLIMB_OVER "climb_over"
#define LLM_ACTION_JUMP_TO "jump_to"
#define LLM_ACTION_PICKUP "pickup"
#define LLM_ACTION_DROP "drop"
#define LLM_ACTION_MOVE_ITEM "move_item"
#define LLM_ACTION_GIVE "give_item"
#define LLM_ACTION_ACCEPT_OFFER "accept_offer"
#define LLM_ACTION_REFUSE_OFFER "refuse_offer"
#define LLM_ACTION_DRAW_WEAPON "draw_weapon"
#define LLM_ACTION_SHEATHE_WEAPON "sheathe_weapon"
#define LLM_ACTION_EAT_DRINK "eat_or_drink"
#define LLM_ACTION_SMOKE "smoke_item"
#define LLM_ACTION_HEAL "heal_target"
#define LLM_ACTION_INTERACT "interact"
#define LLM_ACTION_GO_SLEEP "go_sleep"
#define LLM_ACTION_WAKE_UP "wake_up"
#define LLM_ACTION_STAND_UP "stand_up"
#define LLM_ACTION_EXAMINE "examine_closer"
#define LLM_ACTION_ATTACK_LETHAL "attack_lethal"
#define LLM_ACTION_ATTACK_NONLETHAL "attack_nonlethal"
#define LLM_ACTION_SHOOT_BOW "shoot_bow"
#define LLM_ACTION_RESTRAIN "restrain"
#define LLM_ACTION_ESCORT "escort_to"
#define LLM_ACTION_FLEE "flee"
#define LLM_ACTION_SURRENDER "surrender"
#define LLM_ACTION_CALM_DOWN "calm_down"

// ---- Memory & Pacing Limits ----
#define LLM_MAX_WORKING_EVENTS 24
#define LLM_MAX_EPISODIC_MEMORIES 65
#define LLM_MAX_REFLECTIONS 10
#define LLM_MAX_RECENT_SPEECH 6
#define LLM_REFLECT_THRESHOLD 12

#define LLM_DIRECT_SPEECH_MIN_CD (3.5 SECONDS)
#define LLM_AMBIENT_SPEECH_DEFAULT_CD (10 SECONDS)
#define LLM_RANDOM_THOUGHT_MIN_INTERVAL (75 SECONDS)
#define LLM_RANDOM_THOUGHT_MAX_INTERVAL (125 SECONDS)

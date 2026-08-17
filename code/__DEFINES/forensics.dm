#define HAS_BLOOD_DNA(thing) (length(thing.GetComponent(/datum/component/forensics)?.blood_DNA))

#define FORENSIC_EVENT_LOCKPICK_ATTEMPT "lockpick_attempt"
#define FORENSIC_EVENT_LOCKPICK_SUCCESS "lockpick_success"
#define FORENSIC_EVENT_FORCED_BREAK "forced_break"

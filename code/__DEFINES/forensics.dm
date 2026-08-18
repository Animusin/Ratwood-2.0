#define HAS_BLOOD_DNA(thing) (length(thing.GetComponent(/datum/component/forensics)?.blood_DNA))

#define FORENSIC_EVENT_LOCKPICK_ATTEMPT "lockpick_attempt"
#define FORENSIC_EVENT_LOCKPICK_SUCCESS "lockpick_success"
#define FORENSIC_EVENT_FORCED_BREAK "forced_break"

#define FORENSIC_MAX_BLOOD_SAMPLES 8
#define FORENSIC_BLOOD_DECAL_WARNING_THRESHOLD 5000

#define FORENSIC_BLEED_UNKNOWN 0
#define FORENSIC_BLEED_MINOR 1
#define FORENSIC_BLEED_SIGNIFICANT 2
#define FORENSIC_BLEED_SEVERE 3

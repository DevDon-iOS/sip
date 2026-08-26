# Apple Watch motion observation

## Public API boundary

SIP uses `CMMotionActivityManager` from Core Motion. It records public activity classifications and confidence values as evidence only. It does not use private APIs, reproduce Apple's private sleep model, or infer Apple sleep stages.

Live activity updates are delivered only while the watch app is running. Core Motion does not deliver live updates while the app is suspended. When an active nap session returns to the foreground, SIP queries the public activity history API for the suspended interval before restarting live updates. Core Motion documents that this history is limited to the previous seven days.

SIP stops live delivery whenever the app resigns active and uses one serial utility-quality queue. It does not start a workout or extended runtime session merely to keep motion delivery alive. This bounds foreground battery work, but the real battery cost and the amount of history available after suspension remain physical-device validation items.

## Lifecycle and persistence

- `start` begins a session-scoped observation lifetime and performs available history recovery.
- `pause` closes the current live interval and stops live delivery when the app resigns active.
- `resume` queries the paused interval, then restarts live delivery.
- `stop` closes the current interval and ends the observation lifetime.
- `cancel` stops delivery and drops in-memory provider state without manufacturing an interval.
- Every normalized observation contains absolute timestamps, provenance, `schemaVersion`, and `algorithmVersion`.
- Observations are written atomically with file protection to `WatchObservationOutbox` before `transferUserInfo` is requested.
- A transfer completion is not treated as phone ingestion. The Watch removes an observation only after the phone persists it and returns an `observationIngested` acknowledgment through `transferUserInfo`.
- Provider-derived deterministic identifiers and phone-side provider-key deduplication make replay, out-of-order delivery, app relaunch, and connectivity recovery idempotent.

## Production policy and validation boundary

The production detection policy remains `unvalidated-production-v1` and fail-closed. Motion evidence can produce only partial evidence until physical-device validation establishes an approved policy. SIP does not define an unverified minimum duration, merge gap, confidence threshold, or inferred Apple sleep stage.

Simulator tests and builds validate compilation, lifecycle state transitions, serialization, persistence, retry behavior, and deterministic deduplication. They do not validate real Watch sensor availability, authorization behavior, background scheduling, battery cost, paired-device delivery timing, HealthKit behavior, or detection accuracy. Those require a physical Apple Watch and paired iPhone.

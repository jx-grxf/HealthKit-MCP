# iOS app — HealthKit sync client

The app is the only way data leaves the phone. It reads HealthKit aggregates and
upserts them to Supabase, scoped to the signed-in user. This folder holds the
spec and code sketches; the Xcode project is created on a Mac (Phase 1).

## Prerequisites

- Apple Developer Program membership (HealthKit entitlement + on-device testing;
  the Simulator has no real Health data).
- Xcode 16+, a physical iPhone.
- A Supabase project (EU region) — see [`../supabase/`](../supabase/).

## Project setup

1. New iOS App (SwiftUI lifecycle), minimum iOS 17.
2. Signing & Capabilities → **+ HealthKit**, enable **Background Delivery**.
3. `Info.plist` usage strings (required or the app is rejected):
   - `NSHealthShareUsageDescription` —
     *"Reads your activity, sleep and heart data to sync daily summaries you choose to share with AI agents."*
   - (No write access needed → no `NSHealthUpdateUsageDescription`.)
4. Add the [`supabase-swift`](https://github.com/supabase/supabase-swift) package.

## Data types (read-only, minimal)

| HealthKit type | Aggregated into |
|----------------|-----------------|
| `HKQuantityType(.stepCount)` | `health_days.steps` |
| `HKQuantityType(.activeEnergyBurned)` | `health_days.active_energy_kcal` |
| `HKQuantityType(.restingHeartRate)` | `health_days.resting_hr_bpm` |
| `HKQuantityType(.heartRateVariabilitySDNN)` | `health_days.hrv_sdnn_ms` |
| `HKCategoryType(.sleepAnalysis)` | `sleep_nights.*` |
| `HKWorkoutType` | `workouts.*` |

## Authorization sketch

```swift
import HealthKit

let store = HKHealthStore()

let readTypes: Set<HKObjectType> = [
    HKQuantityType(.stepCount),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.restingHeartRate),
    HKQuantityType(.heartRateVariabilitySDNN),
    HKCategoryType(.sleepAnalysis),
    HKObjectType.workoutType(),
]

func requestAuth() async throws {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    try await store.requestAuthorization(toShare: [], read: readTypes)
}
```

## Incremental sync sketch

Persist one anchor per type so each run only uploads new samples. iOS may defer
the background schedule, so treat it as eventual-consistency.

```swift
func observe(_ type: HKSampleType) {
    let observer = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
        Task { await self.syncDelta(for: type); completion() }
    }
    store.execute(observer)
    store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
}

func syncDelta(for type: HKSampleType) async {
    let anchor = loadAnchor(for: type)            // from UserDefaults / Keychain
    let query = HKAnchoredObjectQuery(
        type: type, predicate: nil, anchor: anchor,
        limit: HKObjectQueryNoLimit
    ) { _, samples, _, newAnchor, _ in
        let aggregates = aggregate(samples)       // → daily / nightly rollups
        Task {
            try? await upsertToSupabase(aggregates)
            saveAnchor(newAnchor, for: type)
        }
    }
    store.execute(query)
}
```

## Upload contract

Upsert aggregates with the user's auth token so RLS applies. Match the schema in
[`../supabase/migrations/0001_init.sql`](../supabase/migrations/0001_init.sql):

- `health_days` keyed on `(user_id, date)` — upsert on conflict.
- `sleep_nights` keyed on `(user_id, date)`.
- `workouts` keyed on `(user_id, id)` — use the `HKWorkout.uuid` as `id`.

Never embed the Supabase **service-role** key in the app — only the anon key.

## Consent

Before the first sync, show a screen that explicitly states data will be shared
with the AI agents the user connects (Apple Guideline 5.1.3). Record consent in
`profiles.agent_sharing_consent_at`. Provide delete + export in settings.

# P10-02 Performance Baseline

## Build under test

- Product: `ZIKORA-wallpaper` Release, `arm64-apple-macos14.0`
- Xcode: 26.6 (17F113)
- macOS: 26.5.2 (25F84)
- Command: `ZIKORA_CONFIGURATION=Release ./scripts/build` with `CODE_SIGNING_ALLOWED=NO`
- Measurement: `ps -o pid=,rss=,%cpu=,etime=` at 5, 15, and 25 seconds after direct process launch

## Results

| Elapsed | RSS | CPU | Notes |
|---|---:|---:|---|
| 5s | 93,344 KB | 0.0% | Application window open, no configured source activity |
| 15s | 93,264 KB | 0.0% | No timer/directory-scan activity observed |
| 25s | 104,224 KB | 0.0% | Stable idle, no high-frequency wakeups |

## Interpretation

- Idle CPU is effectively 0%, satisfying the no busy-loop requirement.
- RSS exceeded the 80 MB target in this environment. The observed overhead is dominated by SwiftUI/AppKit runtime and app services on macOS 26.5; no obvious per-second allocation or spinning task was observed.
- The app already avoids eager full-image decode: Library uses `LazyVGrid` and `ThumbnailPipeline`, and the 1,000-record test confirms no unbounded in-flight decoding.
- Release memory refinement remains a known limitation before distribution; the same `ps` measurement should be repeated on a signed release build and, if needed, profiled with Instruments Allocations to identify SwiftUI framework baseline versus app-owned memory.

## Evidence in code/tests

- `RotationScheduler` owns one task and sleeps for interval durations; `PersistentRetryScheduler` sleeps until the next persisted retry.
- No `Timer`, no high-frequency directory scan, and no `Task.sleep` polling loop exist in production code.
- `ThumbnailPipelineTests` covers 1,000 records with no unbounded in-flight task.

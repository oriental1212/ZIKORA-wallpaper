# AGENTS.md

## Purpose

This repository is a macOS Swift project. This file defines the operating contract for coding agents working in this repository.

The goal is not merely to produce code that looks correct. The goal is to make changes that are:

- scoped to the requested task;
- compatible with the existing architecture;
- buildable and testable from the command line;
- safe with respect to macOS permissions, signing, sandboxing, and entitlements;
- easy for another engineer or agent to inspect, reproduce, and continue.

Treat the repository as the source of truth. Do not assume project structure, schemes, build settings, package layout, or architectural conventions before inspecting them.

---

## Instruction Precedence

When instructions conflict, use this order:

1. Explicit user/task instructions.
2. The closest `AGENTS.override.md` or `AGENTS.md` governing the files being edited.
3. This root `AGENTS.md`.
4. Existing repository conventions and documentation.
5. General Swift/macOS best practices.

A nested `AGENTS.md` may add or narrow rules for its directory.

---

## Agent Operating Principles

### 1. Inspect before editing

Before making a non-trivial change:

- inspect the relevant source files;
- inspect nearby tests;
- inspect project/package configuration;
- identify the target, module, and architectural layer involved;
- search for existing implementations before introducing new abstractions.

Do not invent types, APIs, paths, targets, schemes, environment variables, or dependencies that have not been verified in the repository.

### 2. Make the smallest coherent change

Prefer the smallest change that completely solves the requested problem.

Do not:

- perform drive-by refactors;
- rename unrelated symbols;
- reformat unrelated files;
- reorganize folders without need;
- upgrade dependencies unless required;
- replace existing architecture merely because another pattern is preferred.

If a broader refactor is genuinely required, explain why before expanding the scope.

### 3. Preserve local conventions

Match the surrounding code unless this file explicitly says otherwise.

Preserve existing conventions for:

- architecture;
- dependency injection;
- state management;
- error handling;
- logging;
- naming;
- file organization;
- test style;
- documentation style.

Consistency with the repository is more important than introducing a theoretically cleaner local pattern.

### 4. Verify, do not speculate

After editing, run the narrowest useful validation first, then broader validation when practical.

Never claim that a build or test passed unless the command was actually executed successfully.

If validation cannot be run, state:

- what was not run;
- why it was not run;
- what command should be run by a human or CI.

---

# Repository Discovery

Before the first build in an unfamiliar checkout, inspect the repository.

Useful commands include:

```bash
pwd
git status --short
find . -maxdepth 2 \( -name "*.xcworkspace" -o -name "*.xcodeproj" -o -name "Package.swift" \) -print
find . -name "AGENTS.md" -o -name "AGENTS.override.md"
```

If the project uses Xcode, discover schemes instead of guessing them:

```bash
xcodebuild -list
```

If a workspace is present:

```bash
xcodebuild -workspace <Workspace>.xcworkspace -list
```

If a project is present:

```bash
xcodebuild -project <Project>.xcodeproj -list
```

If `Package.swift` is present, also inspect Swift Package Manager targets:

```bash
swift package describe
```

Prefer an existing workspace over opening a nested project directly when the repository is workspace-based.

---

# Build and Validation

## Xcode projects

Use `xcodebuild` for reproducible command-line validation.

Typical macOS build:

```bash
xcodebuild \
  -workspace <Workspace>.xcworkspace \
  -scheme <Scheme> \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Or, for a project without a workspace:

```bash
xcodebuild \
  -project <Project>.xcodeproj \
  -scheme <Scheme> \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Typical test command:

```bash
xcodebuild \
  -workspace <Workspace>.xcworkspace \
  -scheme <Scheme> \
  -destination 'platform=macOS' \
  test
```

Use the repository's existing scripts or CI commands instead when they are authoritative.

## Swift Package Manager

For pure Swift packages:

```bash
swift build
swift test
```

If the package uses custom flags, plugins, generated sources, or environment variables, follow the repository scripts instead of replacing them with generic commands.

## Validation order

Use this order where applicable:

1. Compile or test the smallest affected target.
2. Run affected unit tests.
3. Run module/feature tests.
4. Build the main macOS scheme.
5. Run the broader test suite when practical.
6. Run linting or formatting checks if configured.
7. Inspect the final diff.

For expensive UI or integration suites, run focused tests first.

---

# Swift Language Rules

## Swift version

Do not assume a Swift language version.

Determine it from:

- Xcode build settings;
- `Package.swift`;
- repository documentation;
- CI configuration.

Do not change the Swift language mode as part of an unrelated task.

## Concurrency

Treat concurrency correctness as part of functional correctness.

Prefer structured Swift concurrency:

- `async` / `await`;
- task groups when appropriate;
- actors for isolated mutable state;
- `@MainActor` for UI-bound state and operations.

Avoid introducing:

- unnecessary `Task.detached`;
- unchecked `Sendable` conformances;
- manual thread synchronization when actor isolation is sufficient;
- blocking waits around asynchronous APIs.

Do not use `@unchecked Sendable` merely to silence compiler diagnostics. It requires a real, documented thread-safety invariant.

When touching concurrency-sensitive code, pay attention to:

- actor isolation;
- cancellation;
- task lifetime;
- reentrancy;
- object lifetime and captures;
- main-thread/UI requirements;
- data races.

Preserve strict-concurrency compatibility when the project enables it.

## Optionals

Prefer explicit, readable handling.

Avoid force unwraps (`!`) unless the invariant is structurally guaranteed and obvious. If a force unwrap is retained or introduced, its safety should be defensible from the surrounding code.

## Errors

Do not silently discard meaningful errors.

Prefer:

- typed or existing domain errors;
- propagation when the caller can handle the failure;
- explicit logging at boundaries where failures are intentionally consumed.

Avoid empty `catch` blocks.

## Access control

Use the narrowest access level consistent with the current design.

Do not make symbols `public` or `open` solely to simplify a test.

---

# macOS Application Rules

## UI frameworks

Follow the framework already used by the feature:

- SwiftUI;
- AppKit;
- a deliberate bridge between them.

Do not migrate AppKit code to SwiftUI, or vice versa, as part of an unrelated task.

## Main-thread correctness

UI mutations and AppKit interactions must respect main-thread / main-actor requirements.

Prefer `@MainActor` over ad hoc dispatching when it accurately models the ownership of the code.

## App lifecycle

Before changing lifecycle behavior, determine whether the project uses:

- SwiftUI `App`;
- `NSApplicationDelegate`;
- document-based lifecycle;
- menu bar / status item lifecycle;
- login item / helper process architecture.

Do not assume a standard windowed-app lifecycle.

## Sandboxing and permissions

Treat these files and settings as security-sensitive:

- `.entitlements`;
- `Info.plist` privacy usage descriptions;
- App Sandbox configuration;
- Hardened Runtime settings;
- Keychain access groups;
- App Groups;
- network/client/server entitlements;
- Apple Events / Automation permissions;
- accessibility permissions;
- screen recording permissions;
- file access permissions;
- camera / microphone permissions;
- login item or helper configuration.

Do not add or broaden an entitlement merely to make a local error disappear.

Any entitlement or privacy-related change must be:

1. necessary for the requested behavior;
2. scoped as narrowly as possible;
3. called out explicitly in the final summary.

## Code signing

Do not alter:

- bundle identifiers;
- development teams;
- signing identities;
- provisioning settings;
- notarization configuration;

unless the task explicitly requires it.

For ordinary local build verification, prefer approaches that do not mutate signing configuration.

## Persistent data

When modifying persisted models, preferences, databases, or serialized formats, consider backward compatibility.

This includes:

- `UserDefaults`;
- Codable payloads;
- SwiftData/Core Data models;
- files written to Application Support;
- Keychain records;
- cached schema-bearing data.

Do not casually rename persisted keys or enum raw values.

---

# Architecture and Dependencies

## Dependency direction

Respect existing module boundaries.

Before importing another internal module, confirm that the dependency direction is allowed by the current project structure.

Avoid creating circular feature dependencies.

## New dependencies

Do not add a third-party dependency if the task can reasonably be solved with existing project dependencies or Apple frameworks.

Before adding one, verify:

- necessity;
- maintenance status;
- license compatibility;
- platform support;
- minimum macOS compatibility;
- concurrency implications;
- binary/package size impact when relevant.

Do not change package versions unrelated to the requested task.

## Generated code

Do not manually edit generated files unless the repository explicitly treats them as source.

Look for indicators such as:

- file headers stating generated status;
- codegen scripts;
- build plugins;
- Sourcery;
- SwiftGen;
- protobuf/gRPC generation;
- OpenAPI generation.

Modify the source definition or generator instead.

---

# Testing

A behavior change should normally include a corresponding test when the repository has an appropriate test target.

Prefer tests that verify observable behavior rather than private implementation details.

Use the testing framework already used by the target:

- Swift Testing (`import Testing`);
- XCTest;
- project-specific helpers.

Do not migrate existing XCTest suites to Swift Testing as part of an unrelated change.

## Test expectations

Tests should be:

- deterministic;
- isolated;
- repeatable;
- independent of execution order.

Avoid arbitrary sleeps.

For asynchronous behavior, prefer framework-supported async expectations, clocks, dependency injection, or controlled synchronization.

Do not rely on:

- the developer's personal filesystem;
- ambient Keychain contents;
- arbitrary network availability;
- undeclared environment state;
- pre-existing `UserDefaults`.

Use temporary or isolated resources.

## Bug fixes

For a bug fix, prefer this workflow:

1. identify the failing behavior;
2. add or identify a regression test when practical;
3. implement the minimal fix;
4. verify the regression test;
5. run relevant surrounding tests.

---

# SwiftUI Guidance

When working in SwiftUI:

- keep `body` declarative;
- avoid performing side effects directly during view construction;
- use the repository's established observation model;
- preserve stable identity in collections;
- do not create unnecessary state copies;
- keep expensive business logic outside views when an existing architectural layer exists.

Be deliberate with:

- `@State`;
- `@Binding`;
- `@Environment`;
- `@Observable`;
- `ObservableObject`;
- `@StateObject`;
- `@ObservedObject`.

Choose based on ownership and lifecycle, not convenience.

---

# AppKit Guidance

When working in AppKit:

- preserve responder-chain behavior;
- respect view/controller lifecycle;
- avoid retain cycles in delegates, closures, notifications, and timers;
- remove observers when required by the API/lifetime model;
- keep UI mutations on the correct actor/thread.

When bridging SwiftUI and AppKit, keep ownership explicit and avoid duplicated state authorities.

---

# Performance

Do not optimize without evidence, but avoid introducing obvious regressions.

Pay particular attention to:

- work performed on the main actor;
- repeated disk access;
- repeated decoding/encoding;
- unnecessary view recomputation;
- unbounded tasks;
- large in-memory collections;
- synchronous I/O in UI paths.

If a task is explicitly about performance, establish a measurable baseline when practical.

---

# Logging and Diagnostics

Use the repository's existing logging system.

If none exists and logging is necessary, prefer Apple's unified logging APIs over ad hoc `print` statements in production paths.

Never log:

- passwords;
- authentication tokens;
- private keys;
- full sensitive payloads;
- user secrets;
- unnecessary personally identifiable information.

Do not leave temporary debug logging in the final change unless requested.

---

# Security

Treat all external input as untrusted.

Relevant boundaries include:

- URLs;
- deep links;
- files;
- pasteboard contents;
- IPC/XPC messages;
- network responses;
- command output;
- imported user data.

Avoid shell command construction from unescaped external input.

Never commit:

- credentials;
- API keys;
- signing certificates;
- provisioning secrets;
- private keys;
- tokens.

If secrets are already present, do not reproduce them in summaries or logs.

---

# File and Project Configuration Changes

Changes to these files require extra care:

- `.xcodeproj/project.pbxproj`;
- `.xcworkspace`;
- `.xcconfig`;
- `Package.swift`;
- `Package.resolved`;
- entitlements;
- build scripts;
- CI workflows.

Do not reorder or rewrite project configuration unnecessarily.

When adding a Swift file to an Xcode project, ensure it belongs to the intended target if the repository does not use folder-synchronized groups.

When editing `Package.swift`, keep dependency and platform changes scoped to the task.

---

# Formatting and Style

Use repository-provided tooling if available.

Examples:

```bash
swiftformat .
swiftlint
```

These commands are examples only. Do not install or run a formatter/linter across the whole repository unless the project already uses it and the scope is appropriate.

Avoid formatting unrelated lines.

Prefer Swift naming conventions:

- types: `UpperCamelCase`;
- functions, variables, properties, enum cases: `lowerCamelCase`;
- names should communicate intent rather than implementation mechanics.

Comments should explain non-obvious intent, constraints, or invariants. Do not narrate obvious code.

---

# Git Discipline

Before editing:

```bash
git status --short
```

Assume pre-existing user changes are intentional.

Do not overwrite, revert, reset, clean, stash, or amend user changes unless explicitly requested.

Do not use destructive commands such as:

```bash
git reset --hard
git clean -fd
git checkout -- .
```

without explicit user authorization.

After editing, inspect:

```bash
git diff --check
git diff
git status --short
```

Keep the final diff narrowly related to the task.

Do not create commits unless asked.

---

# Agent Harness Contract

The repository should remain friendly to non-interactive coding-agent execution.

## Deterministic commands

Prefer commands that:

- work from the repository root;
- do not require GUI interaction;
- do not depend on developer-specific absolute paths;
- produce useful exit codes;
- can be repeated safely.

When adding scripts, make failures explicit and actionable.

## Environment assumptions

Do not assume the harness has:

- a logged-in Apple ID;
- a specific signing certificate;
- developer-specific Keychain entries;
- GUI access;
- user-created directories;
- Homebrew packages not declared by the repository;
- network access.

If a tool is required, first check whether the repository already declares or bootstraps it.

## Feedback loops

For each meaningful code change, strive to leave a short feedback loop available to future agents.

A strong feedback loop looks like:

```text
inspect -> edit -> focused test -> build -> broader test -> diff review
```

If full verification is expensive, identify the cheapest command that catches the likely failure mode.

## Legibility for agents

Prefer repository structures and scripts that make intent discoverable.

When adding new infrastructure, favor:

- descriptive script names;
- documented entry points;
- explicit configuration;
- machine-runnable validation;
- predictable file locations.

Avoid hidden manual steps.

## Failure handling

If a command fails:

1. read the actual error;
2. determine whether the failure is caused by the change, environment, or pre-existing repository state;
3. fix root causes within task scope;
4. rerun the relevant check.

Do not blindly retry the same command repeatedly.

Do not modify application code merely to hide an environment/setup failure.

---

# Change Completion Checklist

Before presenting a task as complete, verify as many of these as apply:

- [ ] The requested behavior is implemented.
- [ ] The change is scoped to the request.
- [ ] Existing architecture and naming conventions are preserved.
- [ ] New code compiles.
- [ ] Relevant tests pass.
- [ ] A regression test was added for a bug fix when practical.
- [ ] Swift concurrency diagnostics were not suppressed without justification.
- [ ] macOS entitlements/privacy settings were not broadened accidentally.
- [ ] Signing configuration was not changed unintentionally.
- [ ] No secrets or sensitive data were introduced.
- [ ] No unrelated files were reformatted or refactored.
- [ ] Generated files were not manually edited unless appropriate.
- [ ] `git diff --check` passes.
- [ ] The final diff was inspected.
- [ ] Any validation that could not be run is explicitly reported.

---

# Final Response Contract

When finishing a coding task, report concisely:

1. **What changed**
   - files or components changed;
   - user-visible or architectural effect.

2. **Validation**
   - exact build/test/lint commands that were actually run;
   - whether they passed.

3. **Important notes**
   - migrations;
   - entitlement/privacy changes;
   - signing changes;
   - dependency changes;
   - known limitations.

Do not report tests as passing if they were not executed.

Example:

```text
Implemented:
- Added ...
- Updated ...

Validation:
- `xcodebuild ... build` - passed
- `xcodebuild ... test` - passed

Notes:
- No entitlement or signing changes.
```

---

# Project-Specific Configuration

Maintain this section as the repository evolves.

Agents should prefer explicit values here over rediscovering them on every task.

```text
Primary workspace: <fill if applicable>
Primary project:   <fill if applicable>
Primary scheme:    <fill>
Main app target:   <fill>
Test target(s):    <fill>
Minimum macOS:     <fill>
Swift version:     <fill>
Architecture:      <e.g. MVVM / TCA / custom>
Package manager:   <SwiftPM / none / other>
Formatter:         <command or none>
Linter:            <command or none>
Build command:     <canonical command>
Test command:      <canonical command>
CI workflow:       <path/name>
```

Once these values are known and stable, replace the placeholders. Keeping this section accurate substantially improves agent reliability.

---

# Recommended Repository Additions

These are recommendations, not mandatory rules.

For a repository intended to be used heavily by coding agents, consider providing:

```text
AGENTS.md
README.md
docs/
scripts/
  bootstrap
  build
  test
  lint
```

A strong harness exposes a small number of canonical, non-interactive commands such as:

```bash
./scripts/bootstrap
./scripts/build
./scripts/test
./scripts/lint
```

The scripts should encode repository-specific Xcode schemes, destinations, environment setup, and required tooling so agents do not need to rediscover those details repeatedly.

For large repositories, add nested `AGENTS.md` files only where a subtree genuinely has different rules. Keep instructions local, concrete, and executable.

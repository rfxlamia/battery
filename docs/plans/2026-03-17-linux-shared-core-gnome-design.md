# Linux Shared Core and GNOME Extension Design

**Date:** 2026-03-17

**Status:** Approved during brainstorming

## Summary

This design adds a Linux path for Battery by keeping the proven Swift application as the behavioral reference, then building a new shared core in TypeScript plus a lightweight GNOME Shell extension on top of that core.

The goal is not a pixel-for-pixel macOS port. The goal is behavior parity with the existing Battery logic while using Linux-native integration for the final user experience.

## Problem

Battery is currently a macOS menu bar app built in Swift/SwiftUI. The existing implementation is tightly coupled to macOS UI and platform APIs, but its usage logic is already proven and should be preserved as closely as possible.

The user wants:

- a shared foundation that can support Linux
- a GNOME extension that can be used directly from the top bar
- planning that is broken into domain-focused plans rather than one large implementation document

## Existing Codebase Observations

The current Swift project already contains platform-independent business behavior that should be treated as the source of truth:

- usage API client and error handling in `Sources/Services/AnthropicAPI.swift`
- main state orchestration in `Sources/ViewModels/UsageViewModel.swift`
- hook-driven session detection in `Sources/Services/HookFileWatcher.swift`
- supporting utilities and models in `Sources/Utilities` and `Sources/Models`

The current Swift project also contains macOS-only shell concerns that should not be copied directly into Linux code:

- menu bar UI in `Sources/BatteryApp.swift` and `Sources/Views`
- AppKit-based login/browser integration in `Sources/Services/OAuthService.swift`
- Sparkle updater in `Sources/Services/UpdaterService.swift`
- macOS notifications in `Sources/Services/NotificationService.swift`

## Goals

- Preserve Battery behavior as closely as possible to the existing Swift implementation
- Keep Linux code separate from the current macOS source tree
- Build a shared TypeScript core that owns polling, state calculation, storage, and session-awareness
- Build a lightweight GNOME Shell extension that reads state from the core and appears in the GNOME top bar
- Keep the migration plan split into several domain-focused plans

## Non-Goals

- Do not rewrite the macOS app in this phase
- Do not attempt a pixel-perfect GNOME clone of the Swift popover
- Do not publish to extensions.gnome.org in the first phase
- Do not create one giant implementation plan that mixes every migration concern together

## MVP Parity Boundary

The Linux MVP must preserve the Swift behaviors that directly affect top-bar status, polling cadence, and user trust. It does not need to ship every analytical or multi-account feature from the macOS app on day one.

Required parity for MVP:

- login-required, loading, ok, and error states
- session utilization and session reset time
- weekly utilization and weekly reset time
- hook-driven active-session inference, including startup replay, `SessionEnd` precedence, recent activity handling, and the existing five-minute idle timeout
- adaptive polling behavior equivalent to the current Swift product intent: faster polling during active sessions and slower polling while idle
- API error mapping for `401`, `429`, and generic server or decoding failures, including retry-after semantics
- plan tier, last-updated metadata, and enough freshness metadata for the GNOME extension to detect stale state safely
- atomic local state output for one selected account

Deferred until after MVP:

- Sonnet and Opus breakdowns
- extra usage credits and monthly limits
- burn-rate projections, streaks, heatmaps, and historical charts
- multi-account switching UI and an account-list contract

Deferred fields must be called out explicitly in the shared contract so the GNOME extension can treat them as absent rather than unstable.

## Recommended Architecture

### 1. Swift remains the behavioral oracle

The existing Swift code is the reference implementation. New TypeScript behavior should be written as a behavioral port, not as a redesign.

That means:

- Swift defines how usage, errors, thresholds, projections, and session activity should behave
- TypeScript should reproduce the same outputs for the same inputs whenever practical
- differences should only be introduced when the platform forces them

### 2. New shared core in TypeScript

Create a Linux-focused runtime in TypeScript that is responsible for:

- OAuth login and token refresh
- polling the Anthropic usage API
- reading Claude Code hook events
- computing session and weekly state
- storing snapshots and cached state locally
- exposing a stable local state contract for frontends

This layer is the engine. It should be maintainable by the user and portable to future Linux surfaces.

For Linux MVP, the core should continue using the shared `~/.battery/` root so hook events, tokens, cached state, and compatibility artifacts do not split across multiple local conventions.

Auth and account rules for MVP:

- Battery-owned auth files remain under `~/.battery/`
- if existing Battery account metadata or token files are present, the Linux core should reuse them rather than inventing a second auth store
- the emitted frontend contract represents one selected account end-to-end in MVP
- multi-account parity remains a post-MVP expansion, not a hidden requirement in the first GNOME delivery

### 3. GNOME extension as a thin UI shell

Create a GNOME Shell extension in GJS that:

- reads the local state produced by the TypeScript core
- displays status in the top bar
- opens a popup with the key Battery summary data
- stays light and avoids heavy polling, complex persistence, or auth logic

The extension should behave like a Linux-native viewer, not like the full application backend.

## Install Story

The expected end-user experience is:

1. Install the Battery core
2. Install the GNOME extension
3. Enable the extension
4. See Battery appear in the GNOME top bar

For the first phase, the recommended delivery path is:

- local/manual install flow for development
- installer script that copies the extension into the user GNOME extension directory, enables it, and wires up the local core

Publishing to the GNOME extension store can be evaluated later.

## Runtime Ownership

The GNOME extension should not be responsible for starting, supervising, or reimplementing the core runtime.

For the installed GNOME MVP:

- the TypeScript core runs as a user-scoped background service
- the preferred installed path is a `systemd --user` service on GNOME-capable Linux systems
- the installer enables that user service as part of setup
- development may still use a manual foreground command, but the production path must not depend on the extension spawning the backend ad hoc

This keeps the extension thin, makes stale-backend failures easier to detect, and avoids duplicating polling or auth logic in shell code.

## Repository Layout

Keep all new Linux and shared-core work inside this repository, but outside the current macOS folders.

Recommended structure:

```text
docs/plans/
port/
port/core/
port/gnome-extension/
port/fixtures/
port/tools/
```

Rules:

- keep `Sources/`, `Tests/`, and existing Swift scripts focused on the macOS app
- do not place Linux code inside the current macOS source folders
- keep cross-platform fixtures and verification helpers under `port/`

## Data Flow

The intended runtime flow is:

1. The TypeScript core starts locally
2. The core loads config and tokens
3. The core polls the Anthropic usage API
4. The core reads hook events from `~/.battery/events.jsonl`
5. The core computes a normalized state object
6. The core writes or exposes that state locally
7. The GNOME extension reads that state and renders the top bar indicator and popup

For the first usable version, a local state file is sufficient. If needed later, this can be upgraded to a stronger IPC layer such as D-Bus.

For MVP, the file contract must also define freshness and safety rules:

- state writes must be atomic so the extension never reads partial JSON
- the state object must include `updatedAt`
- the extension must treat the state as stale when it is older than the expected idle polling window by a clearly documented margin
- stale state must render as an explicit stale or error presentation rather than being shown as live data

## Why TypeScript

TypeScript is the recommended shared-core language because:

- the user is already comfortable maintaining it
- the final Linux path needs a lightweight and maintainable developer experience
- GNOME uses JavaScript via GJS, so TypeScript keeps the mental model closer even if the extension itself stays GJS-native

The recommended split is:

- TypeScript for the engine
- GJS for the GNOME shell UI

## Migration Strategy

Use domain-by-domain behavioral porting instead of a big-bang rewrite.

Recommended approach:

- extract and document Swift behavior by domain
- define a stable shared contract
- port one behavior domain at a time into TypeScript
- verify parity with fixtures and golden-style checks
- only build the GNOME extension once the core exposes reliable state

This reduces the risk of drifting away from the proven Swift implementation.

Plan dependency rules:

- Plan A is required before Plan B starts
- Plan B is required before Plan C starts
- Plan C is required before Plan D starts
- Plan D must cover the critical MVP parity domains before Plan E begins implementation
- Plan E may add GNOME-specific presentation details, but it must not redefine shared behavior already locked by Plans A through D
- Plan F remains optional and may improve packaging or ergonomics only after the installed MVP path works

## Domain-Focused Plan Breakdown

The migration should be implemented through several separate plans:

### Plan A: Swift Behavior Inventory

Purpose:

- identify the exact behavior that must be preserved

Outputs:

- source-of-truth module map
- input and output inventory
- edge-case list
- fixture candidates

### Plan B: Shared Contract

Purpose:

- define the stable state shape between the core and all frontends

Outputs:

- versioned state schema for one selected account in MVP
- error schema
- session and weekly state schema
- update and freshness semantics
- deferred-fields list for post-MVP parity

### Plan C: TypeScript Core MVP

Purpose:

- build the first working engine that produces real state

Outputs:

- local runtime
- auth and refresh handling
- polling pipeline
- hook event reader
- persisted state output
- installed user-service path for GNOME MVP

### Plan D: Compatibility Verification

Purpose:

- prove that the TypeScript port behaves like the Swift reference

Outputs:

- fixtures
- golden or snapshot-style comparisons
- parity checks for critical domains

### Plan E: GNOME Extension MVP

Purpose:

- deliver a directly usable top bar experience on GNOME

Outputs:

- indicator in the GNOME top bar
- popup summary
- login-needed and error states
- stale-core-state handling
- manual refresh support

### Optional Future Plan F: Linux Packaging and Service Lifecycle

Purpose:

- improve packaging, distribution, and upgrade ergonomics after MVP

Possible outputs:

- distro-specific packaging
- GNOME extension store publishing work
- installer improvements beyond the MVP service flow

## Risks

- behavior can drift if the TypeScript port is designed from scratch instead of traced from Swift
- GNOME extension code can become fragile if too much logic is pushed into the shell layer
- install flow can feel incomplete if core and extension are not packaged together cleanly enough for development and first-use

## Decisions Made

- preserve behavior as closely as possible to the Swift implementation
- keep Linux code out of the current macOS source folders
- work inside this repository, not a new repository
- use a new directory under this repository for Linux and shared-core work
- recommend a branch dedicated to the migration effort
- use TypeScript for the shared core and GJS for the GNOME extension
- split planning into multiple domain-focused implementation plans

## Next Step

Write separate implementation plans for:

- behavior inventory
- shared contract
- TypeScript core MVP
- compatibility verification
- GNOME extension MVP

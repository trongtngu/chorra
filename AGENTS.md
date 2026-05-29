# Chorra Agent Notes

Read this before making changes in this repo. Keep edits aligned with the current app architecture, Supabase boundary, and workflow constraints below.

## Current State

Chorra is a SwiftUI iOS MVP for household tasks, child photo proof, points, and reward unlocks. The app entry point launches `ContentView`, which owns the shared `AppViewModel`, restores the Supabase session, and routes between signed-out auth, parent dashboard, and child dashboard states.

The implemented user-facing surfaces are:

- Parent auth, account creation, household bootstrapping, child creation, task creation, submission review, reward catalog management, and reward history.
- Child PIN-based login through an anonymous Supabase session, assigned task list, camera-based photo submission, points balance, available rewards, and reward unlock confirmation.
- Shared loading, error, configuration error, refresh, and sign-out states.

`AppShellView`, `AppRoute`, and `HomeView` currently exist as placeholder app-shell code and are not the active runtime path.

## Architecture

The client is a SwiftUI app with a small, direct architecture:

- `ContentView` creates and injects a single `@StateObject` `AppViewModel`.
- `AppViewModel` is `@MainActor` and acts as the presentation state coordinator. It owns session state, loading/working flags, user-visible errors, and refreshes dashboard data after mutations.
- `ChorraService` is the Supabase boundary. It owns the `SupabaseClient`, calls auth methods, invokes database RPCs for writes, performs table/view selects for reads, uploads task photos, and creates signed URLs for parent photo review.
- `ChorraModels` mirrors the Supabase schema with `Codable` domain types and lightweight dashboard item structs for composed UI state.

Supabase is treated as the source of truth. The app keeps only view state, form state, and freshly loaded dashboard data locally.

## Supabase Model

The backend is a hosted Supabase project using Auth, Postgres, Storage, RPC functions, and Row Level Security.

Core persisted concepts are:

- Households and profiles.
- Parent users and child users.
- Durable child records plus `child_auth_sessions` for multiple lightweight anonymous sessions per child.
- Tasks, task assignments, task submissions, and task submission image metadata.
- A points ledger and `child_points_balances` view.
- Rewards and reward redemptions.

Database writes are mostly routed through security-definer RPCs such as parent bootstrap, child creation, child session claim, task creation, task assignment, task submission, submission review, reward creation/update/archive, and reward redemption. RLS policies are the authorization boundary; client-side checks are only for UX.

Task completion photos are uploaded to the private `task-photos` storage bucket. Storage paths are scoped by household, child, and submission id. Parent review uses short-lived signed URLs.

## Product Flows

The current MVP supports these flows:

- Parent signs up or signs in with email/password.
- Parent account creation bootstraps a one-household parent profile.
- Parent adds a child with display name, login name, and PIN.
- Child starts from anonymous auth, then claims a child session using household code, login name, and PIN.
- Parent creates reusable unassigned tasks with title, point value, pastel card color, and catalog icon, then assigns copied task instances to children.
- Child opens an assigned or rejected task, captures a camera photo, and submits it for review.
- Parent reviews the latest submission, approves it to complete the task and create a points ledger entry, or rejects it with optional feedback.
- Parent creates, edits, and archives rewards.
- Child unlocks active rewards when they have enough points; reward redemptions reduce the derived balance and remain visible in history.

## UI And Style

Use the shared design system before adding one-off styling:

- Screens should use `ChorraScreen` for the dark header and white rounded page body.
- Repeated grouped content should use `ChorraCard`.
- Buttons, inputs, nav bars, tab bars, section headers, dividers, empty states, stat pills, and toolbar icons should use the existing Chorra helpers and button styles.
- The base palette is dark slate, white, soft gray, and restrained status colors from `Color+Chorra`.
- Task and reward cards use the fixed pastel palette from `PastelCardColor`; arbitrary colors should not be introduced without changing both app validation and database constraints.
- Task and reward visuals use the PNG-backed `ChorraIconCatalog` and `ChorraIconView`; icon names should be normalized through the catalog before writing to Supabase.

Keep UI pragmatic and child-friendly without turning operational parent screens into marketing pages. Prefer compact, readable SwiftUI views and local private subviews where the current files already use that pattern.

## Hard Constraints

- Do not test with a local Supabase instance.
- Do not use Docker.
- Do not add unit tests for now; the project intentionally has no unit tests yet.
- Supabase credentials come from `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in build settings, launch environment, or `Config/Supabase.xcconfig`.
- Local Supabase overrides belong in `Config/Supabase.local.xcconfig`, which is gitignored.
- Do not treat `supabase/config.toml` or migration files as a signal that local Docker-based Supabase testing is part of the workflow.

## Repo Notes

This repo currently has one Xcode application target and no test target or test files. Swift Package Manager resolves `supabase-swift` and its transitive dependencies through the Xcode project.

The `supabase/migrations` directory records schema, RPC, RLS, storage bucket, fixed card color palette, child multi-session, reward redemption, and icon-name migration history. New app features that change persisted data should keep Swift models, service RPC parameters, migrations, and RLS expectations aligned.

The detailed product architecture and MVP acceptance scenarios live in `docs/mvp.md`. This file is the shorter implementation reference for current and future agents.

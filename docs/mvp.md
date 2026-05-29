# Chorra MVP Architecture

## Summary

Chorra is a parent-child task and reward product. The MVP focuses on one complete household workflow: a parent creates an account, adds a child, creates a reusable task, assigns a copied task instance, the child completes that assignment with photo evidence, the parent reviews the submission, and the child receives points after approval.

The first version should prove the core trust loop:

1. A parent can define work that should be done.
2. A child can clearly see what is assigned to them.
3. The child can submit proof of completion.
4. The parent can approve or reject the work.
5. Approved work reliably turns into a reward.

The MVP should be implementation-oriented, but intentionally small. It should not include money movement, marketplaces, recurring chores, notifications, family chat, or complex household administration.

## Product Roles

### Parent

The parent is the household administrator. A parent can create a household, add children, create tasks, assign tasks, review child submissions, approve completed work, reject incomplete work, and see each child's points.

### Child

The child has a lightweight login and sees only their assigned tasks. A child can view task details, complete a task, attach one photo as proof, and see points awarded after parent approval.

### Household

The household groups parents, children, tasks, submissions, and rewards. For the MVP, each parent account belongs to one household, and each child belongs to one household.

## Main User Flow

1. Parent creates an account.
2. Parent creates or is placed into a household.
3. Parent adds a child.
4. Parent creates a reusable task with a title and point value.
5. Parent assigns the task to one child.
6. Child logs in and views assigned tasks.
7. Child completes the task in the real world.
8. Child marks the task as complete in Chorra.
9. Child attaches one photo to the task submission.
10. Parent reviews the submitted task and photo.
11. Parent approves the submission or rejects it with optional feedback.
12. If approved, the task is completed and the child receives points.
13. If rejected, the task returns to the child for resubmission.

## MVP Architecture

Chorra should use a Supabase-first architecture for the MVP.

### Client App

The mobile app is responsible for the parent and child experiences:

- Authentication screens for parent and child login.
- Parent onboarding for creating the household.
- Parent task management for creating and assigning tasks.
- Child task list and task detail views.
- Photo capture or image selection for task completion.
- Parent review screens for approving or rejecting submissions.
- Child reward summary showing current points.

The client should treat Supabase as the source of truth and keep local state limited to view state, form state, and short-lived cached data.

### Supabase Auth

Supabase Auth should manage both parent and child sessions.

Parents should have standard authenticated accounts. Children should also have lightweight anonymous authenticated sessions so access control can be enforced consistently through Supabase Row Level Security. A single child can have multiple lightweight auth sessions linked at the same time, one per active child device or anonymous session.

The app should distinguish parent and child behavior through profile metadata stored in Postgres, not by relying only on client-side assumptions.

### Supabase Postgres

Supabase Postgres should store the core product data:

- User profiles and role information.
- Households.
- Parent membership in a household.
- Child profiles and their linked auth sessions.
- Tasks created by parents.
- Task assignments to children.
- Task submissions from children.
- Image attachment metadata.
- Approval state and review details.
- Points ledger entries.

The database should model rewards as ledger entries rather than only storing a mutable points total. A current points balance can be derived from approved reward entries or cached later if needed.

### Supabase Storage

Supabase Storage should store task completion photos.

Each submitted task should allow one required image attachment for the MVP. Storage paths should be scoped by household, child, and task or submission identifiers so access policies can be enforced clearly.

The database should store metadata for the image attachment, including the storage path, uploader, related task submission, and upload timestamp.

### Row Level Security

Row Level Security should be the primary authorization boundary.

Parents should be able to access data in their own household. Children should only be able to access their own profile, assigned tasks, submissions, uploaded images, and reward history.

Client-side checks should improve the user experience, but they should not be treated as the security boundary.

## Core Domain Model

### Profile

A profile represents an authenticated user in the product. It stores the user role, display name, and household relationship.

Roles for the MVP:

- `parent`
- `child`

### Household

A household represents one family group. It owns the tasks, child profiles, assignments, submissions, and reward activity for the MVP.

### Child

A child record belongs to a household and is the durable child identity for tasks, submissions, and rewards. Child login creates or refreshes a row in `child_auth_sessions`, allowing multiple anonymous auth sessions to point at the same child without replacing another device's access.

### Task

A task is created by a parent. It defines what should be done and how many points it is worth.

Minimum MVP fields:

- Title.
- Point value.
- Created by parent.
- Household.

### Task Assignment

A task assignment connects a copied snapshot of a task to a child. Each assignment owns its child-specific lifecycle state, so the same parent-created task can be assigned multiple times.

### Task Submission

A task submission represents the child's attempt to complete an assigned task. It includes submission timing, the child who submitted it, the related task, and the current review result.

### Image Attachment

An image attachment points to a photo stored in Supabase Storage. For the MVP, each task submission requires one image attachment.

### Approval

Approval records the parent's review decision. An approved submission completes the task and creates a points ledger entry. A rejected submission returns the task to the child for resubmission.

### Points Ledger

The points ledger records every points change for a child. The MVP should create positive ledger entries when a parent approves a task. Reward unlocks reduce the derived balance through reward redemption rows. Manual adjustments and allowance conversion are deferred.

## Task Assignment States

Task assignments should move through a small explicit lifecycle.

### Draft or Created

The parent has created the reusable task, but it has not yet been assigned to a child.

### Assigned

The copied task assignment is assigned to a child and visible in the child's task list.

### Submitted

The child has marked the task complete and attached the required photo. The task is waiting for parent review.

### Approved

The parent has approved the submitted work. Approval creates the reward event.

### Rejected

The parent has rejected the submission. The child can see that the task needs more work and can submit it again.

### Completed

The task assignment is fully complete. The child has been rewarded, and no further child action is required.

For the MVP, `approved` may be treated as the review event and `completed` as the final task state after the points ledger entry is created.

## Reward Model

Rewards are points-based in the MVP.

Each task has a point value set by the parent. The child does not receive points when they submit the task. Points are awarded only after the parent approves the submission.

The MVP should show each child a current points balance and enough history to understand which completed tasks earned points.

Parents can also maintain a household reward catalog. A reward has an emoji, name, and point cost. Children can unlock active rewards immediately when they have enough points, and unlocks reduce the derived point balance while preserving a reward history for both parent and child.

Deferred reward features:

- Money allowance.
- Payments.
- Marketplace redemption.
- Parent approval before reward unlock.
- Point expiration.
- Negative adjustments.
- Multi-currency or cash conversion.

## MVP Boundaries

The MVP includes only the parent-child task and points loop.

Included:

- Parent account creation.
- Child account/session support, including multiple active lightweight sessions for the same child.
- One household per parent.
- Add child.
- Create task.
- Assign copied task instances to children.
- Child task list.
- Child photo submission.
- Parent review.
- Approve or reject submission.
- Award points after approval.
- Child points balance.
- Parent-defined reward catalog.
- Child reward unlock.
- Parent and child reward history.

Deferred:

- Money allowance.
- Payment processing.
- Marketplace redemption.
- Recurring tasks.
- Push notifications.
- Email notifications beyond auth requirements.
- Family chat.
- Multiple households per user.
- Multiple parents per household.
- Assigning one task to multiple children.
- Complex permission management.
- Offline-first sync.
- Advanced analytics.

## Acceptance Scenarios

### Parent Onboarding

Given a new parent, when they create an account, then Chorra creates a parent profile and household.

### Add Child

Given an authenticated parent, when they add a child, then the child is associated with the parent's household and can have one or more lightweight login sessions.

### Create Task

Given an authenticated parent, when they create a task with a title and point value, then the task is saved in the household.

### Assign Task

Given an existing child and task in the same household, when the parent assigns the task to the child, then the child can see the copied task assignment in their assigned task list.

### Submit Task

Given an assigned task copy, when the child marks it complete and attaches one photo, then the assignment becomes submitted and waits for parent review.

### Approve Task

Given a submitted task assignment, when the parent approves it, then the assignment becomes complete and Chorra creates a points ledger entry for the child.

### Reject Task

Given a submitted task assignment, when the parent rejects it, then the child can see that it needs more work and can submit it again with a new photo.

### View Rewards

Given a child with approved completed tasks, when the child views their rewards, then they can see their current points balance.

## Security and Access Rules

The MVP should enforce these access rules through Supabase Row Level Security:

- A parent can read and manage data for their household.
- A parent cannot access another household.
- A child can read their own profile from any linked lightweight auth session.
- A child can read only task assignments assigned to them.
- A child can create submissions only for their own assigned task copies.
- A child can upload and read only their own task submission photos.
- A child cannot approve tasks or award points.
- Points are awarded only by a trusted approval flow after parent approval.

## Open Decisions After MVP

These are intentionally deferred until the core loop is working:

- Whether rewards convert to real money.
- Whether parents can define a reward catalog.
- Whether children can unlock rewards with points.
- Whether tasks can repeat automatically.
- Whether households can have multiple parents.
- Whether tasks can be shared by multiple children.
- Whether parent approval should require comments on rejection.
- Whether photo evidence can be optional per task.

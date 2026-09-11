# Domain Models

## Household
Represents a family unit ("tribe"). All core records are scoped by `householdId`.

## Household Membership
Links an authenticated user to a household. Roles (DB check constraint):
- admin
- parent
- driver
- observer

## Household Person
Non-user adult attached to a household (grandparent, helper) who may drive.
Roles (DB check constraint): parent, driver, helper, guardian, relative, other.
Backed by `household_people` (Sprint 53).

## Household Invite
Invite with join code / token; resolved via the `resolve_household_by_join_code` RPC.

## Child
Belongs to a household. Has legal name and display name; drivers see display names only.

## Activity
Activities linked to children (school, sports, etc.) — `child_activities`.

## Schedule Template
Recurring plan for transport logistics (`schedule_templates` + `schedule_stops`).

## Run
Generated trip for a specific date derived from schedules (`runs` + `run_stops`).
Status: scheduled / assigned / inProgress / completed / cancelled.
Stop status: pending / enRoute / arrived / completed / skipped.

## Driver
Household member or household person capable of handling a run.

## Run Assignment
Connects drivers to runs.

## Run Driver Position
Live GPS sample for an active run (`run_driver_positions`) — powers observer tracking.

## Emergency Contact
Per-household emergency contact (`emergency_contacts`).

## Household Location
Named place for a household (`household_locations`), e.g. home, school.

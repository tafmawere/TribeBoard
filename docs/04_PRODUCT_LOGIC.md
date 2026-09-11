# Product Logic

Schedules belong to a child and a household.

Runs derive from schedules (or are created manually, validated by RunCreationValidator).

Driver assignments attach drivers to runs. Drivers can be member users or household people.

Only data from the active household should render.

## Run Lifecycle
scheduled / assigned → inProgress → completed / cancelled

Per-stop lifecycle during an in-progress run:
pending → enRoute → arrived → completed (or skipped)

Transitions are enforced by RunStateMachine (Domain/Run) — terminal states are final,
a stop cannot be departed without arriving, and a run cannot complete with unfinished stops.

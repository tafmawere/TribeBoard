# AI Instructions

AI assistants must not:

- modify RunStateMachine without explicit instruction
- bypass household scoping
- reintroduce demo seed logic into authenticated flows
- treat local cache as authoritative backend state
- rename Schedule or Run (core vocabulary)
- hardcode secrets (use Secrets.xcconfig → Info.plist → BackendConfig)

AI should:
- respect offline queue ordering (schedules → runs → assignments)
- preserve household isolation
- maintain idempotent backend updates
- follow the layered flows in GUARDRAILS.md (views never touch persistence/network directly)
- run TribeboardTests after touching Domain/Run or sync code

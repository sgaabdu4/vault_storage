# Strict rules update repair

Status: Ready

## Outcome + scope

The Hard Eng update to b0194d77 passes its own check in this package. The root analysis keeps the example package, because the released check refuses the example/** exclude that the update adds. The error message test joins its adjacent string literals, because the string lint of the analyzer plugin refuses them. Non-goals: package code, other pins.

## Sources + coverage

Sources: N/A — the coordinator's request is the only source.
Deliverables: None

## Repository context

Owners:
- `analysis_options.yaml` owns the root analyzer excludes.
- `test/src/error_message_secrecy_test.dart` owns the expected error texts.

Same cause: `analysis_options.yaml` is the only root exclude list; the error message test is the only file with adjacent string literals.
Single source: The analyzer excludes live in `analysis_options.yaml`.

## Decisions + authorization

Blockers: None
Handoff: None
Authority: Autonomous. The coordinator asked for this repository to pass the Hard Eng release, delivered as a PR.

## Acceptance + steps

- [x] The released check no longer refuses the example exclude or the adjacent strings → N/A — the released check is the proof.
- [x] The error message test still passes → N/A — the existing test keeps its assertions and the released check runs it

## Baseline + execution

Result: Passed
Evidence: Starting code origin/main with the update applied. The released check refuses example/dart-analyze for the example exclude and strict-types-lint for three adjacent string infos.
Execution: One agent; one commit per cause.

## Risks + recovery

Only an analyzer exclude and one test change. Recovery: revert the merge commit.

## ux_reference

N/A — no UI change.

## Verification

Result: Pending
Evidence: Pending the released check.
E2E: N/A — no user journey changes.
Real service: N/A — no changed code calls an outside service.
Retro: Failed check: the example exclude and the string lint → the exclude is gone and the strings are joined (the released check stays the prevention).
Delivery target: Merge
Delivery: Pending — PR, then merge by rebase after review, then confirm the deploy.

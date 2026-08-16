# Phase 13 — Align + recall right (hermes)

Merged `master` (CI, session trees) into `hermes`. Living-agent
code stays here.

## Recall contracts

- Empty search/recall query is an error.
- Other-session ids must look like session ids (no path escape).
- This session is never included in `recall` results.

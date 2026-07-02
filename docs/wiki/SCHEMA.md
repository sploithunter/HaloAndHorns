# Wiki Schema

## Page Types

- `current` — volatile project state that should be checked often.
- `decision` — stable choices and rationale.
- `architecture` — service/config/data boundaries.
- `workflow` — repeatable human + agent procedures.
- `reference` — synthesized notes from old games, web research, screenshots, or experiments.
- `log` — dated session history.

## Page Format

Each page should use:

```markdown
# Title

Status: current | stable | draft | stale

## Summary

Short synthesis.

## Details

Only durable, reusable knowledge.

## Links

- Related pages or source docs.
```

Existing pages may omit this exact shape if they are still clear.

## Raw Vs Wiki

- `docs/wiki/raw/` is for source notes, pasted observations, or one-off extraction notes.
- `docs/wiki/*.md` is for synthesized current knowledge.
- Do not treat raw notes as current truth until they have been compiled into a wiki page.

## Update Protocol

1. Identify whether the new information belongs on an existing page.
2. Update the smallest useful page.
3. Add links to related pages.
4. Add a dated entry to `LOG.md` for meaningful work.
5. If implementation contradicts a wiki page, update the wiki or mark it stale.

## Quality Bar

- A future agent should be able to answer "what did we decide and why?" without reading chat history.
- Claims should point to source files or requirement docs when practical.
- Keep pages compact enough to read directly.


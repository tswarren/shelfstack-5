# Git Workflow

**Status:** Binding delivery convention  
**Purpose:** Keep ShelfStack on a lightweight trunk-based model so branches implement the roadmap instead of duplicating it  
**Related:** [roadmap.md](roadmap.md), [open-decisions.md](open-decisions.md), [AGENTS.md](../../AGENTS.md) §11

## Governing rule

> Use **roadmap phases** as planning containers, **issues** as units of work, **branches** as short-lived implementation vehicles, and **pull requests** as the integration boundary.

```text
main
├── chore/p0-10-rails-scaffold
├── docs/p0-11-classification-audit
├── feat/p1-16-store-memberships
└── phase/p4c-tender-and-completion          # exceptional temporary branch
    ├── feat/p4c-tenders
    ├── feat/p4c-receipt-numbering
    ├── feat/p4c-completion-service
    └── test/p4c-idempotency
```

---

## 1. Permanent branches

### `main`

`main` is the only permanent branch. It should always be:

- buildable;
- migration-consistent;
- passing `bin/ci`;
- coherent with accepted ADRs and Domain Specifications;
- safe for another developer to branch from.

Incomplete functionality may exist on `main` when it is not exposed as operationally complete and does not break existing behavior.

### Do not create permanent branches such as

```text
develop
development
architecture
documentation
phase-1
phase-2
next
staging
```

Delivery sequencing lives in [roadmap.md](roadmap.md) and GitHub issues, not in long-lived branch names.

---

## 2. Working branches

Create one short-lived branch per coherent, reviewable change. Always start from the latest `main`:

```bash
git switch main
git pull --ff-only
git switch -c feat/p1-16-store-memberships
```

### Naming

```text
<type>/<phase>-<issue>-<description>
```

- **phase** — delivery phase slug (`p0`, `p1`, `p2`, `p3`, `p4a`–`p4e`, `p5`…). Prefer this over inventing parallel hierarchies.
- **issue** — GitHub issue number when one exists (recommended). Omit only for tiny chores with no issue.
- **description** — short kebab-case summary.

Examples:

```text
chore/p0-10-compose-database-naming
docs/p0-11-classification-schema-audit
feat/p1-16-organizations-and-stores
feat/p2-14-identifier-generation
feat/p3-12-stock-balances
feat/p4c-atomic-pos-completion
docs/adr-013-inventory-costing
```

### Branch types

| Prefix | Use |
| --- | --- |
| `feat/` | New application behavior |
| `fix/` | Defect correction |
| `chore/` | Scaffold, dependencies, CI, configuration |
| `refactor/` | Structural change without intended behavior change |
| `docs/` | Documentation-only change (including ADR/OD resolutions) |
| `test/` | Test infrastructure or focused coverage |
| `spike/` | Disposable investigation |
| `hotfix/` | Urgent production correction (rarely needed pre-production) |

### PR size

Prefer **one coherent behavior** per PR — often migration + model + constraints + service + tests + seeds + docs together.

Avoid:

- one PR per file or per table when they are meaningless alone;
- one PR for an entire delivery phase.

Phase 1 example of coherent splits: organizations+stores together; memberships; roles/permissions/seeds; authorization evaluation service — not eight empty PRs.

---

## 3. No stacked “subbranches” by default

Git has no true subbranches. Names like `phase-1/users/memberships` are ordinary branches and often hide dependencies.

Do **not** routinely build:

```text
main → feat/A → feat/B → feat/C
```

That produces confusing diffs, out-of-order merge pain, and accidental inclusion of unfinished work.

Default shape:

```text
main
├── feat/p1-organizations-and-stores
├── feat/p1-users
├── feat/p1-store-memberships
└── feat/p1-roles-and-permissions
```

Merge prerequisites to `main` first, then rebase or recreate dependent work from updated `main`.

---

## 4. Temporary phase integration branches

Use a temporary integration branch only when several tightly coupled changes cannot merge to `main` individually without leaving it incoherent.

```text
main
└── phase/p4c-tender-and-completion
    ├── feat/p4c-pos-tenders
    ├── feat/p4c-receipt-sequences
    ├── feat/p4c-completion-service
    └── test/p4c-idempotency-and-concurrency
```

Rules:

1. Create `phase/<slug>` from `main`.
2. Create task branches from the phase branch.
3. Open task PRs **into the phase branch**.
4. Keep the phase branch current with `main` (rebase or ff merge).
5. Open **one** final PR from the phase branch to `main`.
6. Delete the phase branch immediately after merge.

Likely candidates: Phase 4c (atomic completion), Phase 4d (exact-unit path), Phase 6 (corrections + stored value), large coordinated schema reconciliations.

Phase 0, Phase 1, and most of Phase 2 should normally merge as small PRs directly to `main`.

Do not let a phase branch become a long-lived mini-`develop`.

---

## 5. Decision and documentation branches

Resolve open decisions ([open-decisions.md](open-decisions.md)) on `main` **before** the code that depends on them, usually as:

```text
docs/p3-12-inventory-costing-adr
docs/p4-13-tax-calculation-rules
```

or a small `docs/` + spike pair.

When documentation supports an implementation change, prefer **one branch** that includes code and governing doc updates together so they cannot merge at different times.

Do not maintain a permanent documentation branch.

---

## 6. Pull requests

Every branch merges through a pull request, including solo work.

### Suggested PR body

```markdown
## Purpose

What business or technical capability this adds.

## Scope

What is included and explicitly excluded.

## Architecture

- Applicable ADRs:
- Domain specification:
- Open decision resolved:
- Architectural lock affected:

## Data changes

- Migrations:
- Constraints:
- Seeds:
- Backfill or migration risk:

## Testing

- Unit / model:
- Service:
- Request / system:
- Concurrency:
- Idempotency:

## Documentation

- [ ] No governing documentation change required
- [ ] ADR reviewed or added
- [ ] Domain Specification updated
- [ ] Schema documentation updated
- [ ] Workflow documentation updated
- [ ] Implementation phase / roadmap updated
```

Also satisfy [AGENTS.md](../../AGENTS.md) §11 for architecture-sensitive changes.

Link the GitHub issue(s) (`Fixes #16`, `Refs #12`).

---

## 7. Merge strategy

| Kind | Strategy |
| --- | --- |
| Ordinary feat / fix / chore / docs | **Squash merge** |
| Deliberately curated multi-commit series | Rebase merge (rare) |
| Merge commits | Prefer disabled |

Delete the branch after merge.

Prefer conventional PR titles:

```text
feat(auth): add store memberships
feat(catalog): generate variant EAN-13 SKUs
fix(inventory): lock stock balance during reservation
docs(adr): define inventory costing under negative on-hand
chore(ci): rename compose database to shelfstack
```

Squash gives `main` a readable history of capabilities, not WIP noise.

---

## 8. Protect `main`

Recommended GitHub rules for `main`:

- require a pull request before merging;
- require `bin/ci` (and relevant checks) to pass;
- require conversation resolution;
- prevent force pushes;
- require linear history;
- apply rules to administrators as well;
- automatically delete merged branches.

While the project is primarily solo, **do not** require an external approving reviewer (that would block normal work). Add required reviewers when there are regular collaborators.

---

## 9. Releases and tags

Do not create release branches yet.

Use annotated tags for meaningful milestones, for example:

```text
v0.1.0-phase-0
v0.2.0-auth-foundation
v0.3.0-catalog-foundation
v0.4.0-inventory-bootstrap
v0.5.0-first-completed-sale
```

Introduce `release/*` and `hotfix/*` only when there is a production line and more than one supported release.

---

## 10. Suggested splits by early phase

These are examples, not mandatory branch inventories. Keep each PR coherent.

### Phase 0

```text
chore/p0-10-compose-database-naming
chore/p0-10-bin-ci
chore/p0-10-service-layout
docs/p0-11-classification-schema-audit
```

### Phase 1

```text
feat/p1-16-organizations-and-stores
feat/p1-16-users
feat/p1-16-store-memberships
feat/p1-16-roles-and-permissions
feat/p1-16-authorization-evaluation
```

### Phase 2+

Follow [phases/](phases/) exit criteria; include identifier work after [OD-011](open-decisions.md) / issue resolution; inventory concurrency tests with Phase 3 services; consider `phase/p4c-…` only for atomic completion.

---

## Quick checklist

- [ ] Branched from up-to-date `main`
- [ ] Name includes phase (and issue when applicable)
- [ ] One coherent behavior; not an entire phase
- [ ] Not stacked on another unfinished feature branch
- [ ] Dependent OD/ADR merged (or included) before relying code
- [ ] PR filled out; CI green; squash to `main`; branch deleted

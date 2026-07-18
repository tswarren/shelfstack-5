# Phase 1 — Organization and Authorization

**Status:** Complete (2026-07-18)  
**Depends on:** Phase 0  
**Unlocks:** Phase 2  
**Governing docs:** [organization-and-authorization domain](../../domains/organization-and-authorization.md), ADR-0011

## Goal

Establish who may act, at which store, under which permissions and numeric authority limits.

## Principal tables

- `organizations`
- `stores`
- `users`
- `roles`
- `permissions`
- `role_permissions`
- `store_memberships`
- `pos_devices`
- `cash_drawers`
- `administrative_audit_events` (append-only; domain-required addition beyond 260717 proforma)

## Services and behavior

- Session authentication (bcrypt).
- Store-context selection; default store is navigation preference only.
- Permission evaluation: `user.can?(permission_key, store:)` — never hard-code role names.
- Numeric authority fields on memberships; approval **records** wait until POS Phase 4b.
- Authority evaluation uses **membership overrides only** until [OD-013](../open-decisions.md#od-013-role-and-store-authority-defaults) lands (null override = unconfigured deny).
- Minimal admin UI: sign-in, store switcher, org- and store-scoped administration.
- Seeds: one organization, at least one store, administrator role, Phase 1 permission catalog.

## Exit criteria

- [x] Authenticated user with store membership authorized by permission key in tests
- [x] Devices and drawers exist as master data (no sessions yet)
- [x] Role names do not appear in authorization conditionals

## Out of scope

- Business days, POS sessions, approvals as operational events
- Catalog and inventory

## Related

- [../roadmap.md](../roadmap.md)
- [../architectural-locks.md](../architectural-locks.md)
- Issue [#16](https://github.com/tswarren/shelfstack-5/issues/16)

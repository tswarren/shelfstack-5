The files in `docs/exports/schema` are proforma and not necessarily represent the actual database schema. See `db/schema.rb` for actual implementation.

This proforma schema is non-authoritative. Where it conflicts with accepted architecture decisions, the architecture governs. In particular, ADR-0003 establishes one hierarchical merchandise-class structure for merchandising, shelving, browsing, and reporting; a separate display-category hierarchy is not accepted and no `display_categories` table exists. See `docs/adr/0003-merchandise-classes-and-departments.md`.

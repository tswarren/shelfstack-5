# Pre-Phase 11 maintenance — Catalog boundary hardening

**Status:** Ready for implementation **Delivery classification:** Pre-phase maintenance PR **Depends on:** Phase 10 complete **Blocks Phase 11:** No, but should be completed before Phase 11 begins **Closes:** \#116, \#120 **Resolves:** DWR-028, DWR-064

## Goal

Resolve two small Catalog/Product carry-forward items before opening the larger Phase 11 POS workspace effort:

1. Prevent malformed product-import return paths from causing an exception after a Product has already been created.  
2. Establish and enforce ShelfStack’s publication-date normalization policy for exact and partial provider dates.

This PR is intentionally narrow. It introduces no schema changes, new permissions, new user-facing workflows, or Phase 11 functionality.

---

## Scope

### A. Harden product-import `return_to` handling

**Register:** DWR-028 **Issue:** \#116

Product import actions may receive a root-relative `return_to` value so the newly created Product can be passed back into the originating workflow.

The existing sanitizer validates URI structure but does not guarantee that the query string can be decoded. A malformed percent-encoded query may therefore pass initial validation, allow Product creation to commit, and then raise while the redirect URL is assembled.

#### Required behavior

A valid `return_to` must:

* be root-relative;  
* begin with `/`;  
* not begin with `//`;  
* have no scheme or host;  
* have a valid path;  
* contain a query string that can be decoded by `Rack::Utils.parse_nested_query`.

Malformed or external values must be discarded and replaced by the action’s existing fallback path.

#### Controller changes

Update `ProductImportsController#sanitize_return_to` so query decoding is validated during sanitization:

```
def sanitize_return_to(value)
  raw = value.to_s.strip
  return nil if raw.blank?
  return nil if raw.start_with?("//")
  return nil unless raw.start_with?("/")

  uri = URI.parse(raw)
  return nil if uri.scheme.present? || uri.host.present?
  return nil if uri.path.blank? || !uri.path.start_with?("/")

  Rack::Utils.parse_nested_query(uri.query.to_s)

  raw
rescue URI::InvalidURIError, ArgumentError
  nil
end
```

Retain a defensive fallback in `return_path`:

```
def return_path(product, fallback: nil)
  if @return_to.present?
    uri = URI.parse(@return_to)
    query = Rack::Utils.parse_nested_query(uri.query)
    query["product_id"] = product.id
    query_string = query.to_query

    query_string.present? ? "#{uri.path}?#{query_string}" : uri.path
  else
    fallback || product_path(product)
  end
rescue URI::InvalidURIError, ArgumentError
  fallback || product_path(product)
end
```

The exact implementation may differ, but both boundaries must reject malformed query encoding without raising.

#### Accepted redirect behavior

| Import path | Invalid `return_to` fallback |
| :---- | :---- |
| Enrichment preview/accept | Created or existing Product show page |
| Thin Product Request import | New Product Request form with `product_id` |
| Existing Product lookup | Existing Product show page unless another existing fallback is supplied |

#### Tests

Add controller tests covering:

1. Enrichment acceptance with malformed percent encoding:

```
/product_requests/new?value=%E0%A4%A
```

Expected:

* Product is created;  
* response does not raise;  
* redirect falls back to the Product show page.  
2. Thin import with the same malformed query.

Expected:

* Product is created;  
* redirect falls back to the new Product Request form with the Product attached.  
3. A valid root-relative return path still:  
* preserves existing query parameters;  
* inserts or replaces `product_id`;  
* redirects to the intended local path.

Retain existing coverage for:

* malformed URI syntax;  
* absolute URLs;  
* protocol-relative URLs.

---

### B. Normalize exact and partial publication dates

**Register:** DWR-064 **Issue:** \#120

ShelfStack stores `products.publication_date` as a date without a separate precision field.

Provider metadata may supply:

* an exact date;  
* a year and month;  
* a year only.

ShelfStack will normalize partial values into concrete dates.

#### Accepted normalization policy

| Source precision | Example input | Stored date |
| :---- | :---- | :---- |
| Year | `2014` | `2014-01-01` |
| Year and month | `2014-02` | `2014-02-01` |
| Full date | `2014-02-11` | `2014-02-11` |
| Date-time | `2014-02-11T15:30:00Z` | `2014-02-11` |
| Invalid or unsupported | `2014-13`, arbitrary object | `nil` |

The stored value does not distinguish an exact January 1 publication date from a year-only value normalized to January 1\. This limitation is accepted for the current product model.

#### Shared provider parser

Update `Catalog::Providers::ParseProviderDate` to support year-only, year-month, and full-date strings explicitly.

```
module Catalog
  module Providers
    class ParseProviderDate < ApplicationService
      FULL_DATE = /\A(\d{4})-(\d{2})-(\d{2})(?:\D|\z)/
      YEAR_MONTH = /\A(\d{4})-(\d{2})\z/
      YEAR_ONLY = /\A(\d{4})\z/

      def initialize(raw)
        @raw = raw.to_s.strip
      end

      def call
        return nil if @raw.blank?

        if (match = FULL_DATE.match(@raw))
          Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
        elsif (match = YEAR_MONTH.match(@raw))
          Date.new(match[1].to_i, match[2].to_i, 1)
        elsif (match = YEAR_ONLY.match(@raw))
          Date.new(match[1].to_i, 1, 1)
        end
      rescue ArgumentError
        nil
      end
    end
  end
end
```

A different implementation is acceptable if it preserves the same explicit and deterministic rules.

Do not use general-purpose parsing such as `Date.parse`, because it may accept ambiguous or unintended formats.

#### Normalized-result boundary

Update `Catalog::Enrichment::BuildNormalizedResult#normalize_publication_date` so it accepts only known date representations:

* `Date`;  
* `DateTime`;  
* Ruby `Time`;  
* `ActiveSupport::TimeWithZone`;  
* strings processed through `Catalog::Providers::ParseProviderDate`;  
* `nil`.

Arbitrary objects must not be accepted merely because they implement `to_date`.

```
def normalize_publication_date
  case @raw_publication_date
  when nil
    nil
  when Date
    @raw_publication_date.to_date
  when Time, ActiveSupport::TimeWithZone
    @raw_publication_date.to_date
  when String
    Catalog::Providers::ParseProviderDate.call(@raw_publication_date)
  else
    nil
  end
rescue ArgumentError, TypeError
  nil
end
```

Because `DateTime` inherits from `Date`, the `Date` branch covers both.

#### Parser tests

Add or update `ParseProviderDate` tests:

| Input | Expected |
| :---- | :---- |
| `"2014"` | `Date.new(2014, 1, 1)` |
| `"2014-02"` | `Date.new(2014, 2, 1)` |
| `"2014-02-11"` | `Date.new(2014, 2, 11)` |
| `"2014-02-11T15:30:00Z"` | `Date.new(2014, 2, 11)` |
| `"2014-13"` | `nil` |
| `"2014-00"` | `nil` |
| `"2014-02-30"` | `nil` |
| `"2014-"` | `nil` |
| `"14"` | `nil` |
| `""` | `nil` |
| `nil` | `nil` |

#### Normalized-result tests

Extend `CatalogEnrichmentBuildNormalizedResultTest`:

| Input | Expected |
| :---- | :---- |
| `Date.new(2014, 2, 11)` | `2014-02-11` |
| `DateTime.new(2014, 2, 11, 15, 30)` | `2014-02-11` |
| `Time.utc(2014, 2, 11, 15, 30)` | `2014-02-11` |
| `Time.zone.parse("2014-02-11 15:30")` | `2014-02-11` |
| `"2014"` | `2014-01-01` |
| `"2014-02"` | `2014-02-01` |
| `"2014-02-11"` | `2014-02-11` |
| `"2014-02-11T15:30:00Z"` | `2014-02-11` |
| invalid calendar value | `nil` |
| hash containing date parts | `nil` |
| custom object implementing `to_date` | `nil` |
| `nil` | `nil` |

Also retain existing coverage for:

* fully populated normalized results;  
* deep freezing;  
* provider adapter normalization;  
* invalid provider values.

---

## Documentation updates

### Deferred Work Register

Update DWR-028 to resolved:

> Resolved in PR \#\_\_\_ — product-import return paths now validate nested-query decoding before use and fall back safely when URI or percent encoding is malformed. Issue \#116 closed.

Update DWR-064 to resolved:

> Resolved in PR \#\_\_\_ — publication-date normalization now accepts explicit date/time objects and shared provider strings. Year-only values normalize to January 1; year-month values normalize to the first day of the month; arbitrary `to_date` objects are rejected. Issue \#120 closed.

Remove DWR-028 and DWR-064 from the active Catalog/Phase 8 follow-on bucket summary.

### Catalog documentation

Update any governing or design documentation that currently states that year-only or year-month provider dates are rejected.

Document the accepted policy:

```
YYYY       → YYYY-01-01
YYYY-MM    → YYYY-MM-01
YYYY-MM-DD → exact date
```

Also state that date precision is not retained separately in the current schema.

### Current phase

Do not schedule Phase 11 in this PR.

`current-phase.md` may note that pre-Phase 11 readiness hardening is underway or complete, but the next delivery phase must remain unscheduled until the Phase 11 plan is separately promoted.

---

## Explicit non-goals

This PR must not:

* schedule or begin Phase 11;  
* change Product or enrichment schemas;  
* introduce a publication-date precision field;  
* add warnings for partial publication dates;  
* perform general date parsing;  
* accept arbitrary `to_date` objects;  
* build enrichment of existing Products;  
* change Product Request behavior;  
* add a generalized redirect framework;  
* modify permissions;  
* include DWR-029, DWR-065, or DWR-066;  
* refactor unrelated Catalog or POS services.

---

## Suggested implementation order

### Commit 1

```
fix(catalog): reject malformed product import return paths
```

Includes:

* sanitizer query validation;  
* defensive redirect fallback;  
* controller regression tests.

### Commit 2

```
fix(catalog): normalize partial publication dates
```

Includes:

* shared parser changes;  
* normalized-result allowlist;  
* parser and service tests.

### Commit 3

```
docs: resolve pre-phase 11 catalog hardening
```

Includes:

* DWR-028 and DWR-064 resolution;  
* publication-date policy documentation;  
* readiness bookkeeping.

A single combined implementation commit is also acceptable because the work is small, but separate commits make review and rollback clearer.

---

## Git workflow

**Branch**

```
fix/pre-phase-11-catalog-readiness
```

**PR title**

```
fix: complete pre-Phase 11 catalog readiness hardening
```

**PR description**

```
## Summary

- Validate product-import `return_to` query encoding before constructing post-create redirects.
- Fall back safely when URI parsing or nested-query decoding fails.
- Normalize provider publication dates using the accepted policy:
  - `YYYY` → `YYYY-01-01`
  - `YYYY-MM` → `YYYY-MM-01`
  - full dates remain exact.
- Restrict normalized publication-date inputs to explicit date/time types and shared parser strings.
- Resolve DWR-028 and DWR-064.

## Architecture and scope

- No schema changes.
- No new permissions.
- No Phase 11 functionality.
- No general-purpose date parsing.
- No publication-date precision field.
- Existing Product and enrichment ownership remains unchanged.

## Tests

- Product import malformed `return_to` regression coverage.
- Valid local redirect preservation.
- Partial and exact provider publication-date parsing.
- Explicit normalized-result type boundary.
- Full CI.

Closes #116
Closes #120
```

---

## Validation

Run targeted tests first:

```
docker compose run --rm web \
  bin/rails test test/controllers/product_imports_controller_test.rb

docker compose run --rm web \
  bin/rails test test/services/catalog/providers/parse_provider_date_test.rb

docker compose run --rm web \
  bin/rails test test/services/catalog/enrichment/build_normalized_result_test.rb
```

Then run the full suite:

```
docker compose run --rm web bin/ci
```

---

## Exit criteria

The readiness PR is complete when:

1. malformed percent-encoded `return_to` values cannot cause a post-commit exception;  
2. Product creation succeeds and uses the correct fallback redirect;  
3. valid root-relative return paths continue to work;  
4. year-only publication dates normalize to January 1;  
5. year-month publication dates normalize to the first day of the month;  
6. full dates remain exact;  
7. invalid dates normalize to `nil`;  
8. arbitrary `to_date` objects are rejected;  
9. all provider date strings use the shared parser;  
10. targeted tests and full CI pass;  
11. \#116 and \#120 close;  
12. DWR-028 and DWR-064 are marked resolved;  
13. Phase 11 remains separately unscheduled.

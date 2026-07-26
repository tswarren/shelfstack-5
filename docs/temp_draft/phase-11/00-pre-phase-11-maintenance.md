# Pre-Phase 11 maintenance — Catalog boundary hardening

**Status:** Ready for implementation **Delivery classification:** Pre-phase maintenance PR **Depends on:** Phase 10 complete **Blocks Phase 11:** No, but should be completed before Phase 11 begins **Closes:** \#116, \#120 **Resolves:** DWR-028, DWR-064

## Goal

Resolve two small Catalog/Product carry-forward items before opening the larger Phase 11 POS workspace effort:

1. Prevent malformed product-import return paths from causing an exception after a Product has already been created.  
2. Harden the `BuildNormalizedResult` publication-date input boundary so it matches OD-P8-10 / `ParseProviderDate` (exact calendar days only; no duck-typed `to_date`).

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

### B. Harden `publication_date` input boundary (OD-P8-10)

**Register:** DWR-064 **Issue:** \#120

ShelfStack stores `products.publication_date` as an optional **exact** calendar date (OD-P8-10 revision). There is no precision column. Provider year-only / month-only strings are **not** persisted and must not be turned into Jan 1 / day-1 placeholders.

Adapters already use `Catalog::Providers::ParseProviderDate` (day-only). The remaining debt is that `BuildNormalizedResult#normalize_publication_date` still accepts any duck-typed `to_date`.

#### Accepted policy (unchanged)

| Source | Example input | Stored date |
| :---- | :---- | :---- |
| Full date | `2014-02-11` | `2014-02-11` |
| Date-time | `2014-02-11T15:30:00Z` | `2014-02-11` |
| Year only | `2014` | `nil` |
| Year and month | `2014-02` | `nil` |
| Invalid / unsupported / duck-typed `to_date` | `2014-13`, custom object | `nil` |

#### Shared provider parser

Keep day-only behavior. Optionally tighten the day regex so a trailing non-digit terminator is explicit:

```
FULL_DATE = /\A(\d{4})-(\d{2})-(\d{2})(?:\D|\z)/
```

Do not add year-only / month-only acceptance. Do not use `Date.parse`.

#### Normalized-result boundary

Update `Catalog::Enrichment::BuildNormalizedResult#normalize_publication_date` so it accepts only:

* `Date` (covers `DateTime`);  
* `Time` / `ActiveSupport::TimeWithZone` (calendar day via `#to_date`);  
* strings processed through `Catalog::Providers::ParseProviderDate`;  
* `nil`.

Reject arbitrary objects that merely implement `to_date`.

```
def normalize_publication_date
  case @raw_publication_date
  when nil
    nil
  when Date
    @raw_publication_date
  when DateTime, Time, ActiveSupport::TimeWithZone
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

#### Parser tests

Retain / extend `ParseProviderDate` coverage:

| Input | Expected |
| :---- | :---- |
| `"2014-02-11"` | `Date.new(2014, 2, 11)` |
| `"2014-02-11T15:30:00Z"` | `Date.new(2014, 2, 11)` |
| `"2014"` | `nil` |
| `"2014-02"` | `nil` |
| `"2014-02-31"` | `nil` |
| `"20140211"` | `nil` |
| `""` / `nil` | `nil` |

#### Normalized-result tests

Extend `BuildNormalizedResult` tests:

| Input | Expected |
| :---- | :---- |
| `Date.new(2014, 2, 11)` | `2014-02-11` |
| `Time.zone.parse("2014-02-11 15:30")` | `2014-02-11` |
| `"2014-02-11T15:30:00Z"` | `2014-02-11` |
| `"2014"` / `"2014-02"` | `nil` |
| custom object implementing `to_date` | `nil` |
| `nil` | `nil` |

Also retain existing coverage for fully populated results, deep freezing, and provider adapters.

---

## Documentation updates

### Deferred Work Register

Update DWR-028 to resolved:

> Resolved in PR \#\_\_\_ — product-import return paths now validate nested-query decoding before use and fall back safely when URI or percent encoding is malformed. Issue \#116 closed.

Update DWR-064 to resolved:

> Resolved in PR \#\_\_\_ — `BuildNormalizedResult` accepts only `Date` / date-time / `ParseProviderDate` strings; duck-typed `to_date` rejected; year/month-only remain nil per OD-P8-10. Issue \#120 closed.

Remove DWR-028 and DWR-064 from the active Catalog/Phase 8 follow-on bucket summary.

### Catalog documentation

No policy change. Confirm domain/schema text still states that year/month-only provider strings are not persisted (OD-P8-10). Do not document Jan 1 / day-1 placeholders.

### Current phase

Phase 11 scheduling lives in the separate docs PR. This maintenance PR only resolves DWR-028 / DWR-064.

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
- Restrict normalized publication-date inputs to explicit date/time types and `ParseProviderDate` strings (OD-P8-10 exact-day; year/month-only stay nil).
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
- Exact-day provider publication-date parsing; year/month-only remain nil.
- Explicit normalized-result type boundary (reject duck-typed `to_date`).
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
4. full dates remain exact; year-only and month-only stay `nil` (OD-P8-10);  
5. invalid dates normalize to `nil`;  
6. arbitrary `to_date` objects are rejected;  
7. string inputs use the shared parser;  
8. targeted tests and full CI pass;  
9. \#116 and \#120 close;  
10. DWR-028 and DWR-064 are marked resolved.

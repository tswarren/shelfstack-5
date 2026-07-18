# Source inputs for merchandise-class transform

These files are **not** import-ready. They feed:

```bash
ruby script/build_merchandise_classes.rb
```

which writes [`../merchandise_classes.csv`](../merchandise_classes.csv).

| File | Role |
| --- | --- |
| `merchandise_categories_leaf.csv` | Denormalized leaf rows (names, path segment codes, department defaults) |
| `merchandise_classes_leaf_sort.csv` | Original sort order keyed by Primary/Secondary/Minor names |
| `merchandise_class_default_overrides.csv` | Explicit defaults when descendant departments conflict |

When descendants disagree on default department, add a row to the overrides file and regenerate.

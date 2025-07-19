# Restucture Current Project following guidlines where applicable

## Recommended Structure

* Root clearly displays main modules/files
* `README`: brief description and setup
* `setup.py`: package/distribution management
* `requirements.txt`: explicit dev/test dependencies
* `/docs`: standalone documentation
* `/tests`: tests separated from production code
* `Makefile`: automate tasks (`make test`, `make init`)

**Example layout:**

```
project/
├── README.rst
├── setup.py
├── requirements.txt
├── core/
│   ├── __init__.py (minimal/empty)
│   ├── main.py
│   └── helpers.py
├── cli/
│   └── entrypoint.py (delegates only, ≤50 lines)
├── utils/
│   └── common.py
├── docs/
│   ├── conf.py
│   └── index.rst
└── tests/
    ├── context.py (for imports)
    ├── test_core.py
    └── test_cli.py
```

## Key Practices

* **Explicit imports**: prefer `import module`, avoid `from module import *`
* **Namespace clarity**: short, descriptive filenames; avoid special chars
* **No circular dependencies**: clearly isolate module responsibilities
* **Minimal global state**: explicitly pass parameters
* **Immutable vs Mutable**: immutables for keys, mutables for dynamic data
* **Context managers (`with`)**: handle resources safely
* **Decorators**: isolate secondary logic (caching, logging)
* **Pure functions**: deterministic, no side effects
* **Efficient string concatenation**: use list comprehensions and `.join()`
* **Flat Django structures**: `django-admin.py startproject projectname .`

## Anti-Patterns

* Deep nested dirs (`src/python`)
* Spaghetti code (deep nesting)
* Ravioli code (too fragmented)
* Hidden coupling (unrelated breakage)

## Tools and References

* [Kenneth Reitz’s samplemod](https://github.com/kennethreitz/samplemod)
* [Contextlib](https://docs.python.org/3/library/contextlib.html)
* [PEP 3101](https://www.python.org/dev/peps/pep-3101) (string formatting)
* Automation with Makefiles

---

## Clean Project Instructions

* ≤200 lines per file
* ≤40 lines per function
* Folder depth ≤3 levels
* Entry point delegates only (≤50 lines)
* Organize into modules: `core`, `cli`, `utils`, `tests`
* Remove duplicated logic/code
* Eliminate unused/dead code
* Replace magic values with constants/config
* Consistent descriptive naming (files/functions/variables)
* Standardize imports
* Tests ≤100 lines, each tests one behavior
* Remove redundant tests
* Test suite runs ≤30 seconds
* Find duplicate functions:
  ```
  rg "^def " src | cut -d: -f2 | sort | uniq -d
  ```

* Check file sizes:
  ```
  fd -e py src | xargs wc -l | sort -nr
  ```

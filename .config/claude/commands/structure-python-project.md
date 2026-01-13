# Restucture Current Project following guidlines where applicable

## Recommended Structure

* Root clearly displays main modules/files
* `README`: brief description and setup
* `setup.py`: package/distribution management (if using Rye, still useful for compatibility)
* Rye preferred over requirements.txt for dependency management
* `/docs`: standalone documentation with Sphinx
* `/tests`: tests separated from production code
* `Makefile`: comprehensive automation (`test`, `lint`, `format`, `typecheck`, `build`, `install`, `clean`)

**Example layout:**

```
project/
├── README.md
├── Makefile              # Full automation
├── setup.py              # Package compatibility
├── pyproject.toml        # Rye configuration
├── requirements.lock     # Locked dependencies
├── src/                 # Source code
│   ├── core/            # Core business logic
│   │   ├── __init__.py (minimal/empty)
│   │   ├── base.py
│   │   └── interfaces.py
│   ├── cli/             # Command-line interface
│   │   ├── commands/    # Focused command modules (≤134 lines)
│   │   ├── core/        # CLI infrastructure (≤75 lines)
│   │   ├── utils/       # CLI utilities (≤111 lines)
│   │   └── main.py      # Entry point (≤71 lines)
│   └── utils/           # General utilities
│       └── helpers.py
├── docs/
│   ├── conf.py          # Sphinx configuration
│   └── index.rst        # Documentation
└── tests/
    ├── test_core.py     # Essential tests only
    └── test_cli.py      # Remove redundant tests
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

## Modern Tools and Automation

### Essential Makefile Commands
```makefile
.PHONY: help init test lint format typecheck clean build install install-global

help:
	@echo "Available commands:"
	@echo "  make test              - Run tests"
	@echo "  make lint              - Run linting (ruff)"
	@echo "  make format            - Format code (black)"
	@echo "  make typecheck         - Run type checking (mypy)"
	@echo "  make install-global    - Install globally with pipx (fast)"

test:
	rye run pytest

lint:
	rye run ruff check src/

format:
	rye run black src/

install-global:
	@if [ ! -d "dist" ] || [ ! -f "dist/*.whl" ]; then rye build; fi
	pipx install --force dist/*.whl
```

### Fast Global Installation
* Use `pipx install --force` with pre-built wheels
* Reuse existing builds to avoid rebuilding
* Rye global installation often requires root permissions
* pipx provides isolated environments and is faster for repeated installs

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
  ```bash
  # Check file sizes (avoid find, use fd)
  wc -l src/cli/solid_cli.py src/cli/system_info.py src/cli/commands/*.py

  # Find duplicate functions
  rg "^def " src | cut -d: -f2 | sort | uniq -d

  # Verify all tests pass
  make test

  # Clean up redundant test files
  rm tests/test_redundant*.py
  ```

## Success Metrics
* **File sizes**: All files ≤200 lines (target: ≤134 lines for commands)
* **Test coverage**: Essential tests only, all passing
* **Performance**: Commands run in <0.1s
* **Build speed**: Global install reuses existing builds
* **Structure**: Clear separation: core/, cli/, utils/, tests/

# Python Project Structure Guidance (Compact)

## Recommended Structure

* Root folder clearly showing main modules/files.
* `LICENSE`: specify clearly, see [choosealicense.com](https://choosealicense.com/).
* `README`: brief description and quick-start instructions.
* `setup.py`: at root, for packaging and distribution.
* `requirements.txt`: dev/test dependencies clearly stated.
* `/docs`: standalone documentation.
* `/tests`: separate folder, avoid embedding tests in modules.
* `Makefile`: automate common tasks (tests, init, build).
* `pdm`: use pdm for package management

**Example layout:**

```
project/
├── LICENSE
├── README.rst
├── setup.py
├── requirements.txt
├── src/
├── sample/
│   ├── __init__.py (minimal or empty)
│   ├── core.py
│   └── helpers.py
├── docs/
│   ├── conf.py
│   └── index.rst
└── tests/
    ├── context.py (sys.path adjustments)
    ├── test_basic.py
    └── test_advanced.py
```

## Key Practices

* **Explicit Imports**: Prefer `import module`, avoid `from module import *`.
* **Namespace Clarity**: Avoid ambiguity, no special characters in filenames.
* **No Circular Dependencies**: Clearly separate module responsibilities.
* **Minimal Global State**: Pass parameters explicitly.
* **Short, Meaningful Names**: Avoid reuse or reassignment of variable names.
* **Immutable vs Mutable**: Use immutables (tuples) for keys/stable data, mutables (lists) for dynamic accumulation.
* **Context Managers (`with`)**: Manage resources (files, DB connections) cleanly.
* **Decorators**: Separate concerns like caching or logging.
* **Pure Functions**: Favor deterministic, side-effect-free functions for easier testing/refactoring.
* **String Concatenation**: Use list comprehensions and `.join()` for efficiency.
* **Avoid Nested Django Structures**: Run `django-admin.py startproject projectname .` to flatten paths.

## Anti-Patterns to Avoid

* Deeply nested directories (`/src/python` ambiguous subdirs).
* Spaghetti code (nested loops/conditionals).
* Ravioli code (over-fragmented logic).
* Hidden coupling (changes in one place breaking unrelated tests).

## Tools and References

* [Kenneth Reitz’s Python Guide (GitHub)](https://github.com/kennethreitz/samplemod)
* [Python’s Contextlib](https://docs.python.org/3/library/contextlib.html)
* [PEP 3101](https://www.python.org/dev/peps/pep-3101) (String formatting)
* Makefiles for automation (`make test`, `make init`).

**Essence**: Keep Python projects simple, explicit, and structured clearly for maintainability and ease of collaboration.

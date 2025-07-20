## Clean Project Instructions

- Remove all duplicated code or logic
- Remove redundant or duplicated tests
- Eliminate unused or dead code
- Limit each file to ≤200 lines
- Limit each function to ≤40 lines
- Clean up and standardize all imports
- Keep folder structure ≤3 levels deep
- Ensure the entry point only delegates (≤50 lines)
- Organize code into clear modules: `core`, `cli`, `utils`, `tests`
- Use consistent, descriptive naming for files, functions, and variables
- Ensure full test suite runs in ≤12 seconds
- Replace all magic values with constants or config
- Find duplicate functions: `rg "^def " src | cut -d: -f2 | sort | uniq -d`
- Check file sizes: `fd -e py src | xargs wc -l | sort -nr`

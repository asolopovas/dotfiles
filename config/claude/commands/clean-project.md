## Clean Project Instructions

- Limit each file to ≤200 lines
- Limit each function to ≤40 lines
- Keep folder structure ≤3 levels deep
- Ensure the entry point only delegates (≤50 lines)
- Organize code into clear modules: `core`, `cli`, `utils`, `tests`
- Remove all duplicated code or logic
- Eliminate unused or dead code
- Replace all magic values with constants or config
- Use consistent, descriptive naming for files, functions, and variables
- Clean up and standardize all imports
- Write tests that do one thing and are ≤100 lines
- Remove redundant or duplicated tests
- Ensure full test suite runs in ≤30 seconds
- Find duplicate functions: `rg "^def " src | cut -d: -f2 | sort | uniq -d`
- Check file sizes: `fd -e py src | xargs wc -l | sort -nr`

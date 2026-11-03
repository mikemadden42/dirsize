# TODO

Findings from a project review (2026-11-02). Suggested order of work:

1. Fix error handling in `calculate_directory_size`
2. Delete `add_custom_flags()` and fix the MSVC flag strings
3. Fix `%errorlevel%` in `run-builds.bat`
4. Add smoke tests so CI's `ctest` actually tests something

## Program (`main.cc`)

- [x] **One unreadable folder makes the whole entry show "Error"** (`main.cc:41-56`).
      Any permission error during the recursive walk throws away the running total.
      Use `fs::directory_options::skip_permission_denied` and the `std::error_code`
      overloads of `increment()` / `file_size()` so the walk skips the bad entry and keeps counting.
- [x] **Failures are invisible to the user.**
  - [x] An invalid path is only written to the log file; nothing is printed to the terminal (`main.cc:101-105`).
  - [x] If the outer loop throws, the listing is silently cut short and the program still exits 0 (`main.cc:129-135`).
- [x] **Windows: a non-ASCII folder name can stop the listing.** `path::string()` can throw;
      use `.u8string()` or catch per entry.
- [x] **Missing includes:** `<cstdint>` (`uintmax_t`) and `<ctime>` (`std::time_t`, `std::localtime`).
- [ ] Make the log file argument an optional flag instead of required.
- [ ] Count files directly in the target folder and print a grand total.
- [ ] Sort output (by name or size); `directory_iterator` order is unspecified.
- [ ] Drop the `std::setw(10)` before `std::endl` (only adds trailing spaces).

## CMake (`CMakeLists.txt`)

- [x] **Sanitizer flags are applied twice** (e.g. `-fsanitize=address -fno-omit-frame-pointer` appears twice in the compile line).
      `CMAKE_CXX_FLAGS_<CONFIG>` and `add_custom_flags()` both add them. Delete `add_custom_flags()`.
- [x] `add_custom_flags()` checks `CMAKE_BUILD_TYPE`, which multi-config generators (Visual Studio, Xcode) ignore.
      Use generator expressions (`$<CONFIG:ASAN>`) if it's kept.
- [x] **Fix MSVC flags:**
  - [x] `"/DEBUG /COVERAGE"` and `"/O2 /DEBUG"` are each passed as a single argument (`CMakeLists.txt:107,115`).
  - [x] `/DEBUG` is a linker flag; the compiler uses `/Zi`.
  - [x] `/COVERAGE` isn't an MSVC compiler flag.
  - [x] MSVC doesn't support `/fsanitize=undefined`.
- [x] Bump `cmake_minimum_required` from 3.10 to 3.16+ (`target_link_options` needs 3.13; CMake 4.x warns).
- [x] Replace `set(CMAKE_CXX_FLAGS ...)` with `target_compile_options(dirsize PRIVATE -Wall -Wextra -pedantic)`
      so user/toolchain flags aren't overwritten.
- [x] RelWithDebInfo override drops `-DNDEBUG`; its linker flags `-O2 -g` do nothing.
- [x] MSAN build fails on macOS (`unsupported option '-fsanitize=memory'`); Apple Clang has no MemorySanitizer.
      Skip it on Darwin.
- [x] TSAN/MSAN warnings print on every MSVC configure regardless of build type.
- [x] Set a default build type (e.g. Release) when `CMAKE_BUILD_TYPE` is empty.

## Build scripts

- [x] **`run-builds.bat` reports every build as a success.** `%errorlevel%` inside the `for` block is expanded
      before the loop runs. Use `!errorlevel!` or `if errorlevel 1`.
- [x] `run-builds.bash`:
  - [x] Check `cmake` and `cd` results; add `set -euo pipefail`.
  - [x] Quote variables.
  - [x] Use `cmake --build` instead of `make`.
  - [x] Make it work from any directory, not just the repo root.
- [x] `run-builds.ps1`:
  - [x] `$buildResult = cmake --build ...` hides build output and is never used.
  - [x] Check whether configure succeeded.
  - [x] Remove the redundant build-directory delete before the loop.
- [x] All scripts build sanitizer variants but never run them. Run `dirsize` on a sample tree after each sanitizer build.
- [ ] Consider replacing the three scripts with `CMakePresets.json` and `cmake --workflow` (deferred: kept the scripts for now).

## CI and repo hygiene

- [x] **CI "Test" step does nothing**: no tests are defined, so `ctest` passes trivially.
      Add `add_test()` smoke tests (known tree size; bad path returns non-zero).
- [x] Update `actions/checkout@v3` to v4 or later.
- [x] Add a CI matrix (ubuntu, macos, windows) and an ASAN/UBSAN job.
- [x] Remove `rockyou2024.txt` / `rockyou2024.zip` from `.gitignore` (unrelated leftover).
- [x] Add build and usage instructions to `README.md`.

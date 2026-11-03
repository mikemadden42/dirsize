# dirsize
Quickly get directory sizes

`dirsize` lists each directory directly under a path, with the total size of
the files inside it (recursively). Hidden directories (names starting with
`.`) are skipped, and so are subdirectories it isn't allowed to read.

## Usage

```
dirsize <directory_path> <log_file_path>
```

Progress and errors are appended to the log file. The exit code is 1 if the
path is invalid, a directory couldn't be sized (shown as `Error`), or the
listing couldn't be completed. For example:

```
$ dirsize ~/data dirsize.log
projects                       Size: 51.66 KB
photos                         Size: 3.34 MB
```

Sizes are the apparent file sizes added together, in 1024-based units.
Directories are listed in the order the filesystem returns them.

## Building

Requires CMake 3.20 or newer and a C++17 compiler (GCC, Clang or MSVC).

```
cmake -S . -B build
cmake --build build
```

This builds `build/dirsize` in Release mode. Other build types are `Debug`,
`RelWithDebInfo`, `COVERAGE`, and the sanitizer builds `ASAN`, `UBSAN`,
`TSAN` and `MSAN`. Pick one with `-DCMAKE_BUILD_TYPE=<type>`. Sanitizers the
compiler doesn't support are not offered (for example, MSVC only has `ASAN`,
and `MSAN` needs LLVM Clang).

## Testing

```
ctest --test-dir build --output-on-failure
```

With a multi-config generator such as Visual Studio, add the configuration:
`cmake --build build --config Release` and `ctest --test-dir build -C Release`.

To build and test every build type your toolchain supports, run the script
for your platform from anywhere:

```
./run-builds.bash      # Linux, macOS
.\run-builds.ps1       # Windows (PowerShell)
run-builds.bat         # Windows (cmd)
```

CI runs these scripts on Linux, macOS and Windows for every pull request.

#!/usr/bin/env bash
#
# Configure, build and smoke-test every build type this toolchain supports.

set -euo pipefail

# Work from the repo root no matter where the script is run from
cd "$(dirname "$0")"

# Directory for the builds
BUILD_DIR="build"
SAMPLE_DIR="$BUILD_DIR/sample"

# Remove any existing build artifacts
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Ask CMake which build types this toolchain supports
cmake -S . -B "$BUILD_DIR/probe" > /dev/null
types=$(sed -n 's/^DIRSIZE_BUILD_TYPES:INTERNAL=//p' "$BUILD_DIR/probe/CMakeCache.txt")
if [ -z "$types" ]; then
	echo "Unable to read DIRSIZE_BUILD_TYPES from CMakeCache.txt"
	exit 1
fi
IFS=';' read -r -a BUILD_TYPES <<< "$types"

# Sample tree for the smoke test: one 2 KB file in "sub", plus a hidden dir
mkdir -p "$SAMPLE_DIR/sub/nested" "$SAMPLE_DIR/.hidden"
head -c 2048 /dev/zero > "$SAMPLE_DIR/sub/nested/file"

# Configure, build and run dirsize for one build type
build_and_test() {
	local build_type=$1
	local dir="$BUILD_DIR/$build_type"
	local output

	cmake -S . -B "$dir" -DCMAKE_BUILD_TYPE="$build_type" || return 1
	cmake --build "$dir" --config "$build_type" || return 1

	# Sanitizer errors make dirsize exit non-zero
	output=$("$dir/dirsize" "$SAMPLE_DIR" "$dir/dirsize.log") || return 1
	echo "$output"
	if [[ $output != *"2.00 KB"* ]]; then
		echo "Unexpected output from dirsize."
		return 1
	fi
}

# Initialize counters and arrays for build results
success_count=0
failure_count=0
successful_builds=()
failed_builds=()

# Loop through each build type
for build_type in "${BUILD_TYPES[@]}"; do
	echo "Building for type: $build_type"

	if build_and_test "$build_type"; then
		echo "$build_type build succeeded."
		successful_builds+=("$build_type")
		success_count=$((success_count + 1))
	else
		echo "$build_type build failed."
		failed_builds+=("$build_type")
		failure_count=$((failure_count + 1))
	fi
done

# Report the summary of builds
echo "Build Summary:"
echo "Successful Builds: $success_count"
echo "Failed Builds: $failure_count"

# List successful build types
if [ ${#successful_builds[@]} -gt 0 ]; then
	echo "Successful Build Types:"
	for successful_build in "${successful_builds[@]}"; do
		echo "  - $successful_build"
	done
fi

# List failed build types if there were any failures
if [ ${#failed_builds[@]} -gt 0 ]; then
	echo "Failed Build Types:"
	for failed_build in "${failed_builds[@]}"; do
		echo "  - $failed_build"
	done
fi

# Exit with appropriate status code
if [ "$failure_count" -gt 0 ]; then
	exit 1
else
	exit 0
fi

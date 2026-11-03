# Configure, build and smoke-test every build type this toolchain supports.

# Paths are absolute so the script works from any directory
$buildDir = Join-Path $PSScriptRoot "build"

# Remove any existing build artifacts
if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Path $buildDir | Out-Null

# Ask CMake which build types this toolchain supports
$probeDir = Join-Path $buildDir "probe"
cmake -S $PSScriptRoot -B $probeDir | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Output "CMake probe configure failed."
    exit 1
}
$match = Select-String -Path (Join-Path $probeDir "CMakeCache.txt") -Pattern '^DIRSIZE_BUILD_TYPES:INTERNAL=(.+)$'
if (-not $match) {
    Write-Output "Unable to read DIRSIZE_BUILD_TYPES from CMakeCache.txt"
    exit 1
}
$buildTypes = $match.Matches[0].Groups[1].Value -split ';'

# Configure, build and smoke-test one build type
function Invoke-BuildAndTest($buildType) {
    $dir = Join-Path $buildDir $buildType

    # Send tool output to the console so it isn't returned from the function
    cmake -S $PSScriptRoot -B $dir "-DCMAKE_BUILD_TYPE=$buildType" | Out-Host
    if ($LASTEXITCODE -ne 0) { return $false }
    cmake --build $dir --config $buildType | Out-Host
    if ($LASTEXITCODE -ne 0) { return $false }

    # Sanitizer errors make the smoke tests fail
    ctest --test-dir $dir -C $buildType --output-on-failure | Out-Host
    return ($LASTEXITCODE -eq 0)
}

# Initialize counters and lists for build results
$successCount = 0
$failureCount = 0
$successfulBuilds = @()
$failedBuilds = @()

# Loop through each build type
foreach ($buildType in $buildTypes) {
    Write-Output "Building for type: $buildType"

    if (Invoke-BuildAndTest $buildType) {
        Write-Output "$buildType build succeeded."
        $successfulBuilds += $buildType
        $successCount++
    } else {
        Write-Output "$buildType build failed."
        $failedBuilds += $buildType
        $failureCount++
    }
}

# Report the summary of builds
Write-Output "Build Summary:"
Write-Output "Successful Builds: $successCount"
Write-Output "Failed Builds: $failureCount"

# List successful build types
if ($successfulBuilds.Count -gt 0) {
    Write-Output "Successful Build Types:"
    foreach ($successfulBuild in $successfulBuilds) {
        Write-Output "  - $successfulBuild"
    }
}

# List failed build types
if ($failedBuilds.Count -gt 0) {
    Write-Output "Failed Build Types:"
    foreach ($failedBuild in $failedBuilds) {
        Write-Output "  - $failedBuild"
    }
}

# Exit with appropriate status code
if ($failureCount -gt 0) {
    exit 1
} else {
    exit 0
}

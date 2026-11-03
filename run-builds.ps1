# Configure, build and smoke-test every build type this toolchain supports.

# Paths are absolute so the script works from any directory
$buildDir = Join-Path $PSScriptRoot "build"
$sampleDir = Join-Path $buildDir "sample"

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

# Sample tree for the smoke test: one 2 KB file in "sub", plus a hidden dir
New-Item -ItemType Directory -Path (Join-Path $sampleDir "sub\nested") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sampleDir ".hidden") -Force | Out-Null
[System.IO.File]::WriteAllBytes((Join-Path $sampleDir "sub\nested\file"), (New-Object byte[] 2048))

# Configure, build and run dirsize for one build type
function Invoke-BuildAndTest($buildType) {
    $dir = Join-Path $buildDir $buildType

    # Send tool output to the console so it isn't returned from the function
    cmake -S $PSScriptRoot -B $dir "-DCMAKE_BUILD_TYPE=$buildType" | Out-Host
    if ($LASTEXITCODE -ne 0) { return $false }
    cmake --build $dir --config $buildType | Out-Host
    if ($LASTEXITCODE -ne 0) { return $false }

    # Multi-config generators (Visual Studio) put the binary in a per-config folder
    $exe = Join-Path $dir "$buildType\dirsize.exe"
    if (-not (Test-Path $exe)) {
        $exe = Join-Path $dir "dirsize.exe"
    }

    # Sanitizer errors make dirsize exit non-zero
    $output = & $exe $sampleDir (Join-Path $dir "dirsize.log")
    if ($LASTEXITCODE -ne 0) { return $false }
    $output | Out-Host
    if (-not ($output -match "2.00 KB")) {
        Write-Host "Unexpected output from dirsize."
        return $false
    }
    return $true
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

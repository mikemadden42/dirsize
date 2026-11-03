cmake_minimum_required(VERSION 3.20)

# Set the project name
project(dirsize VERSION 1.0 LANGUAGES CXX)

# Specify the C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Define build types, leaving out sanitizers the toolchain doesn't support
set(DIRSIZE_BUILD_TYPES Debug Release RelWithDebInfo ASAN COVERAGE)
if (NOT MSVC)
    list(APPEND DIRSIZE_BUILD_TYPES UBSAN TSAN)
    # MemorySanitizer needs LLVM Clang (not GCC or Apple Clang)
    if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        list(APPEND DIRSIZE_BUILD_TYPES MSAN)
    endif()
endif()

# Record the list so the run-builds scripts can read it from CMakeCache.txt
set(DIRSIZE_BUILD_TYPES "${DIRSIZE_BUILD_TYPES}" CACHE INTERNAL "Build types supported by this toolchain")

get_property(IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if (IS_MULTI_CONFIG)
    set(CMAKE_CONFIGURATION_TYPES ${DIRSIZE_BUILD_TYPES})
else()
    # Default to Release for single-config generators
    if (NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    endif()
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS ${DIRSIZE_BUILD_TYPES})
    if (NOT CMAKE_BUILD_TYPE IN_LIST DIRSIZE_BUILD_TYPES)
        message(FATAL_ERROR "Build type '${CMAKE_BUILD_TYPE}' is not supported "
                            "with this toolchain. Choose one of: ${DIRSIZE_BUILD_TYPES}")
    endif()
endif()

if (MSVC)
    # Define ASAN build type flags (link.exe infers the ASan runtime itself)
    set(CMAKE_CXX_FLAGS_ASAN "/fsanitize=address /Zi /Od")
    set(CMAKE_EXE_LINKER_FLAGS_ASAN "/DEBUG")

    # Define Coverage build type flags (collect with Microsoft.CodeCoverage)
    set(CMAKE_CXX_FLAGS_COVERAGE "/Zi /Od")
    set(CMAKE_EXE_LINKER_FLAGS_COVERAGE "/DEBUG /PROFILE")
else()
    # Define ASAN build type flags
    set(CMAKE_CXX_FLAGS_ASAN "-fsanitize=address -fno-omit-frame-pointer -g")
    set(CMAKE_EXE_LINKER_FLAGS_ASAN "-fsanitize=address")

    # Define UBSan build type flags
    set(CMAKE_CXX_FLAGS_UBSAN "-fsanitize=undefined -fno-sanitize-recover=all -g")
    set(CMAKE_EXE_LINKER_FLAGS_UBSAN "-fsanitize=undefined")

    # Define TSan build type flags
    set(CMAKE_CXX_FLAGS_TSAN "-fsanitize=thread -g")
    set(CMAKE_EXE_LINKER_FLAGS_TSAN "-fsanitize=thread")

    # Define MSan build type flags
    set(CMAKE_CXX_FLAGS_MSAN "-fsanitize=memory -fsanitize-memory-track-origins -fno-omit-frame-pointer -g")
    set(CMAKE_EXE_LINKER_FLAGS_MSAN "-fsanitize=memory")

    # Define Coverage build type flags
    set(CMAKE_CXX_FLAGS_COVERAGE "--coverage -O0 -g")
    set(CMAKE_EXE_LINKER_FLAGS_COVERAGE "--coverage")
endif()

# Add the executable
add_executable(dirsize main.cc)

# Warnings for GCC/Clang
if (NOT MSVC)
    target_compile_options(dirsize PRIVATE -Wall -Wextra -pedantic)
endif()

# MSVC's ASan runtime DLL lives next to cl.exe; copy it beside dirsize.exe
# so ASAN builds run outside a Developer Command Prompt
if (MSVC)
    get_filename_component(MSVC_BIN_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
    file(GLOB ASAN_RUNTIME_DLLS "${MSVC_BIN_DIR}/clang_rt.asan_dynamic-*.dll")
    if (ASAN_RUNTIME_DLLS)
        add_custom_command(TARGET dirsize POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${ASAN_RUNTIME_DLLS} $<TARGET_FILE_DIR:dirsize>)
    endif()
endif()

# Smoke tests (run with ctest)
enable_testing()
add_test(NAME smoke
    COMMAND ${CMAKE_COMMAND}
        -DDIRSIZE=$<TARGET_FILE:dirsize>
        -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/smoke
        -P ${CMAKE_CURRENT_SOURCE_DIR}/tests/smoke.cmake)

# macOS specific settings
if (APPLE)
    set_target_properties(dirsize PROPERTIES
        OSX_ARCHITECTURES "x86_64;arm64"
    )
endif()

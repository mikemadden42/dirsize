# Smoke tests for dirsize, run by ctest as:
#   cmake -DDIRSIZE=<path to dirsize> -DWORK_DIR=<scratch dir> -P smoke.cmake
#
# A sanitizer error makes dirsize exit with something other than the
# expected code, so these also fail sanitizer builds.

if (NOT DIRSIZE OR NOT WORK_DIR)
    message(FATAL_ERROR "DIRSIZE and WORK_DIR must be set")
endif()

# Unreadable directories can only be set up on non-Windows hosts, and root
# can read them anyway
set(CAN_LOCK_DIRS FALSE)
if (NOT CMAKE_HOST_WIN32)
    execute_process(COMMAND id -u OUTPUT_VARIABLE uid OUTPUT_STRIP_TRAILING_WHITESPACE)
    if (NOT uid STREQUAL "0")
        set(CAN_LOCK_DIRS TRUE)
    endif()
endif()

# Unlock anything a previous run left locked so it can be removed
set(LOCKED "${WORK_DIR}/locked")
if (CAN_LOCK_DIRS AND EXISTS "${LOCKED}")
    execute_process(COMMAND chmod 755 "${LOCKED}")
endif()

# Sample tree: one 2 KB file under "sub", a non-ASCII dir name (which
# path::string() can't convert on Windows), and a hidden dir that is skipped
set(TREE "${WORK_DIR}/tree")
file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${TREE}/sub/nested" "${TREE}/写真" "${TREE}/.hidden")
string(REPEAT "x" 2048 CONTENT)
file(WRITE "${TREE}/sub/nested/file" "${CONTENT}")
file(WRITE "${TREE}/写真/file" "${CONTENT}")
file(WRITE "${TREE}/.hidden/file" "${CONTENT}")

# Run dirsize and fail unless it exits with the expected code
function(run_dirsize expected_rc)
    execute_process(COMMAND "${DIRSIZE}" ${ARGN}
                    RESULT_VARIABLE rc
                    OUTPUT_VARIABLE out
                    ERROR_VARIABLE err
                    ENCODING UTF8)
    if (NOT rc STREQUAL expected_rc)
        message(FATAL_ERROR "dirsize ${ARGN}: expected exit code ${expected_rc}, got '${rc}'\n"
                            "stdout:\n${out}\nstderr:\n${err}")
    endif()
    set(OUTPUT "${out}" PARENT_SCOPE)
endfunction()

# Sizes the sample tree correctly and skips hidden directories
run_dirsize(0 "${TREE}" "${WORK_DIR}/dirsize.log")
if (NOT OUTPUT MATCHES "sub +Size: 2\\.00 KB")
    message(FATAL_ERROR "Unexpected output for sample tree:\n${OUTPUT}")
endif()
if (NOT OUTPUT MATCHES "写真 +Size: 2\\.00 KB")
    message(FATAL_ERROR "Non-ASCII directory name missing from output:\n${OUTPUT}")
endif()
if (OUTPUT MATCHES "\\.hidden")
    message(FATAL_ERROR "Hidden directory was not skipped:\n${OUTPUT}")
endif()

# Exits 1 when the listing can't be completed
if (CAN_LOCK_DIRS)
    file(MAKE_DIRECTORY "${LOCKED}")
    execute_process(COMMAND chmod 000 "${LOCKED}")
    run_dirsize(1 "${LOCKED}" "${WORK_DIR}/dirsize.log")
    execute_process(COMMAND chmod 755 "${LOCKED}")
endif()

# Rejects a path that doesn't exist
run_dirsize(1 "${WORK_DIR}/does-not-exist" "${WORK_DIR}/dirsize.log")

# Requires both arguments
run_dirsize(1)

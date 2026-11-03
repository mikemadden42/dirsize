# Smoke tests for dirsize, run by ctest as:
#   cmake -DDIRSIZE=<path to dirsize> -DWORK_DIR=<scratch dir> -P smoke.cmake
#
# A sanitizer error makes dirsize exit with something other than the
# expected code, so these also fail sanitizer builds.

if (NOT DIRSIZE OR NOT WORK_DIR)
    message(FATAL_ERROR "DIRSIZE and WORK_DIR must be set")
endif()

# Sample tree: one 2 KB file under "sub", plus a hidden dir that is skipped
set(TREE "${WORK_DIR}/tree")
file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${TREE}/sub/nested" "${TREE}/.hidden")
string(REPEAT "x" 2048 CONTENT)
file(WRITE "${TREE}/sub/nested/file" "${CONTENT}")
file(WRITE "${TREE}/.hidden/file" "${CONTENT}")

# Run dirsize and fail unless it exits with the expected code
function(run_dirsize expected_rc)
    execute_process(COMMAND "${DIRSIZE}" ${ARGN}
                    RESULT_VARIABLE rc
                    OUTPUT_VARIABLE out
                    ERROR_VARIABLE err)
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
if (OUTPUT MATCHES "\\.hidden")
    message(FATAL_ERROR "Hidden directory was not skipped:\n${OUTPUT}")
endif()

# Rejects a path that doesn't exist
run_dirsize(1 "${WORK_DIR}/does-not-exist" "${WORK_DIR}/dirsize.log")

# Requires both arguments
run_dirsize(1)

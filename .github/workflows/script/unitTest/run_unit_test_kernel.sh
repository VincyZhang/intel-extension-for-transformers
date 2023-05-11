#!/bin/bash

test_install_backend="true"
LOG_DIR=/intel-extension-for-transformers/log_dir
mkdir -p ${LOG_DIR}

# -------------------gtest------------------------
function gtest() {
    pip install cmake
    cmake_path=$(which cmake)
    ln -s ${cmake_path} ${cmake_path}3 || true
    cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/

    mkdir build && cd build && cmake .. -DNE_WITH_SPARSELIB=ON -DNE_WITH_TESTS=ON -DPYTHON_EXECUTABLE=$(which python) && make -j 2>&1 |
        tee -a ${LOG_DIR}/gtest_cmake_build.log
}

# -------------------engine test-------------------
function engine_test() {
    cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/

    if [[ ${test_install_backend} == "true" ]]; then
        local ut_log_name=${LOG_DIR}/unit_test_engine_gtest_backend_only.log
    else
        local ut_log_name=${LOG_DIR}/unit_test_engine_gtest.log
    fi

    ctest -V -L "engine_test" 2>&1 | tee ${ut_log_name}
    if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] ||
        [ $(grep -c "PASSED" ${ut_log_name}) == 0 ] ||
        [ $(grep -c "Segmentation fault" ${ut_log_name}) != 0 ] ||
        [ $(grep -c "core dumped" ${ut_log_name}) != 0 ] ||
        [ $(grep -c "==ERROR:" ${ut_log_name}) != 0 ]; then
        exit 1
    fi
}

# ------------------kernel test--------------------
function kernel_test() {
    cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/

    if [[ ${test_install_backend} == "true" ]]; then
        local ut_log_name=${LOG_DIR}/unit_test_kernel_gtest_backend_only.log
    else
        local ut_log_name=${LOG_DIR}/unit_test_kernel_gtest.log
    fi

    ctest -V -L "kernel_test" 2>&1 | tee ${ut_log_name}
    if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] ||
        [ $(grep -c "PASSED" ${ut_log_name}) == 0 ] ||
        [ $(grep -c "Segmentation fault" ${ut_log_name}) != 0 ] ||
        [ $(grep -c "core dumped" ${ut_log_name}) != 0 ] ||
        [ $(grep -c "==ERROR:" ${ut_log_name}) != 0 ]; then
        exit 1
    fi
}

function main() {
    gtest
    engine_test
    kernel_test
}

main

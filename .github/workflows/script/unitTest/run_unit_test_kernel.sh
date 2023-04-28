#!/bin/bash

# -------------------gtest------------------------
test_install_backend="true"
pip install cmake
cmake_path=$(which cmake)
ln -s ${cmake_path} ${cmake_path}3 || true
cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/

mkdir build && cd build && cmake .. -DNE_WITH_SPARSELIB=ON -DNE_WITH_TESTS=ON -DPYTHON_EXECUTABLE=$(which python) && make -j 2>&1 |
    tee -a ${LOG_DIR}/gtest_cmake_build.log

# -------------------engine test-------------------
if [[ ${test_install_backend} == "true" ]]; then
    ut_log_name=${LOG_DIR}/engine_unit_test_gtest_backend_only.log
else
    ut_log_name=${LOG_DIR}/engine_unit_test_gtest.log
fi
ctest -V -L "engine_test" 2>&1 | tee ${ut_log_name}
if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] ||
    [ $(grep -c "PASSED" ${ut_log_name}) == 0 ] ||
    [ $(grep -c "Segmentation fault" ${ut_log_name}) != 0 ] ||
    [ $(grep -c "core dumped" ${ut_log_name}) != 0 ] ||
    [ $(grep -c "==ERROR:" ${ut_log_name}) != 0 ]; then
    exit 1
fi

# ------------------kernel test--------------------
if [[ ${test_install_backend} == "true" ]]; then
    ut_log_name=${LOG_DIR}/kernel_unit_test_gtest_backend_only.log
else
    ut_log_name=${LOG_DIR}/kernel_unit_test_gtest.log
fi

ctest -V -L "kernel_test" 2>&1 | tee ${ut_log_name}
if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] ||
    [ $(grep -c "PASSED" ${ut_log_name}) == 0 ] ||
    [ $(grep -c "Segmentation fault" ${ut_log_name}) != 0 ] ||
    [ $(grep -c "core dumped" ${ut_log_name}) != 0 ] ||
    [ $(grep -c "==ERROR:" ${ut_log_name}) != 0 ]; then
    exit 1
fi

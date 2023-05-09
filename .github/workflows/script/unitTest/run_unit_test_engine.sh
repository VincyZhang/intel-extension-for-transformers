#!/bin/bash

# -------------------pytest------------------------
function pytest() {
    local coverage_log_dir=$1

    cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/test/pytest || exit 1
    find ./ -name "test*.py" | sed 's,\.\/,python ,g' | sed 's/$/ --verbose/' >run.sh
    LOG_DIR=/intel-extension-for-transformers/log_dir
    JOB_NAME=unit_test
    mkdir -p ${LOG_DIR}
    mkdir -p ${coverage_log_dir}
    ut_log_name=${LOG_DIR}/${JOB_NAME}_pytest.log

    echo "cat run.sh..."
    cat run.sh | tee ${ut_log_name}
    echo "------UT start-------"
    bash run.sh 2>&1 | tee -a ${ut_log_name}
    cp .coverage /${coverage_log_dir}/.coverage
    echo "------UT end -------"

    if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] || [ $(grep -c "OK" ${ut_log_name}) == 0 ]; then
        echo "Find errors in UT test, please check the output..."
        exit 1
    fi

    echo "UT finished successfully! "
}

# -------------------gtest------------------------
function gtest() {
    pip install cmake
    cmake_path=$(which cmake)
    ln -s ${cmake_path} ${cmake_path}3 || true
    cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine

    mkdir build && cd build && cmake .. -DNE_WITH_SPARSELIB=ON -DNE_WITH_TESTS=ON -DPYTHON_EXECUTABLE=$(which python) && make -j 2>&1 |
        tee -a ${LOG_DIR}/gtest_cmake_build.log

    if [[ ${test_install_backend} == "true" ]]; then
        ut_log_name=${LOG_DIR}/unit_test_gtest_backend_only.log
    else
        ut_log_name=${LOG_DIR}/unit_test_gtest.log
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

function install_itrex_base() {
    pip uninstall intel_extension_for_transformers -y
    pip install intel_extension_for_transformers
    cd /intel-extension-for-transformers
    git config --global --add safe.directory "*"
    git fetch
    git checkout master
}

function main() {
    pytest "coverage_pr"
    gtest
    install_itrex_base
    pytest "coverage_base"
}

main

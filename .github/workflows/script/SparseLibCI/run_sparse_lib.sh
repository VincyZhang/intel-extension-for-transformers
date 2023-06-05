#!/bin/bash

output_log_dir="/intel-extension-for-transformers/benchmark_log"
mkdir ${output_log_dir}
mkdir ${output_log_dir}/cur
mkdir ${output_log_dir}/ref
cur_dir=${output_log_dir}/cur
ref_dir=${output_log_dir}/ref

pip install gxx gcc cmake

rm -rf /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/build
cd /intel-extension-for-transformers
git config --global --add safe.directory "*"
git fetch
git submodule update --init --recursive
cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine
mkdir build && cd build

CC=gcc CXX=g++ cmake .. -DNE_WITH_SPARSELIB=ON -DNE_WITH_TESTS=ON -DNE_WITH_SPARSELIB_BENCHMARK=ON -DPYTHON_EXECUTABLE=$(which python)
make -j
cd bin
bash -x /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/build/bin/ci/run_ci.sh $cur_dir

for caselog in $(find $cur_dir/*); do
    case_name=$(echo $caselog | sed -e 's/\.log$//')
    echo "case_name=$case_name"
    bash -x $/intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/build/bin/ci/to_summary.sh $caselog | tee -a "${case_name}_summary.log"
done

cd /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine
mkdir refer && cd refer
git checkout -b refer origin/develop
git pull
CC=gcc CXX=g++ cmake .. -DNE_WITH_SPARSELIB=ON -DNE_WITH_TESTS=ON -DNE_WITH_SPARSELIB_BENCHMARK=ON -DPYTHON_EXECUTABLE=$(which python)
make -j
cd bin
bash -x /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/refer/bin/ci/run_ci.sh $ref_dir

for caselog in $(find $ref_dir/*); do
    case_name=$(echo $caselog | sed -e 's/\.log$//')
    echo "case_name=$case_name"
    bash -x /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/refer/bin/ci/to_summary.sh $caselog | tee -a "${case_name}_summary.log"
done

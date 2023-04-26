pip install clang-format
log_path=${WORKSPACE}/kernels_format.log
cd ${REPO_DIR}/intel_extension_for_transformers/backends/neural_engine/kernels
clang-format --style=file -i include/**/*.hpp
clang-format --style=file -i src/**/*.hpp
clang-format --style=file -i src/**/*.cpp
git diff 2>&1 | tee -a ${log_path}
if [[ ! -f ${log_path} ]] || [[ $(grep -c "diff" ${log_path}) != 0 ]]; then
    exit 1
fi
exit 0

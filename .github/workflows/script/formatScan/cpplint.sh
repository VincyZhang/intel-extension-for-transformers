source /intel-extension-for-transformers/.github/workflows/scripts/change_color.sh

pip install cpplint
REPO_DIR=/intel-extension-for-transformers
log_dir=/intel-extension-for-transformers/.github/workflows/script/formatScan
log_path=${log_dir}/engine_cpplint.log
cpplint --filter=-build/include_subdir,-build/header_guard --recursive --quiet --linelength=120 ${REPO_DIR}/intel_extension_for_transformers/backends/neural_engine/compile 2>&1 | tee ${log_path}
cpplint --filter=-build/include_subdir,-build/header_guard --recursive --quiet --linelength=120 ${REPO_DIR}/intel_extension_for_transformers/backends/neural_engine/executor 2>&1 | tee -a ${log_path}
cpplint --filter=-build/include_subdir,-build/header_guard --recursive --quiet --linelength=120 ${REPO_DIR}/intel_extension_for_transformers/backends/neural_engine/test 2>&1 | tee -a ${log_path}
if [[ ! -f ${log_path} ]] || [[ $(grep -c "Total errors found:" ${log_path}) != 0 ]]; then
    exit 1
fi
exit 0

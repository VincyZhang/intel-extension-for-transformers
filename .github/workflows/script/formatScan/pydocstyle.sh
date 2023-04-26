REPO_DIR=/intel-extension-for-transformers
log_dir=/intel-extension-for-transformers/.github/workflows/script/formatScan
pip install pydocstyle
pydocstyle --convention=google ${REPO_DIR} >${log_dir}/docstring.log

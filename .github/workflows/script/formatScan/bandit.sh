log_dir=/intel-extension-for-transformers/.github/workflows/script/formatScan
pip install bandit
python -m bandit -r -lll -iii /intel-extension-for-transformers >${log_dir}/lpot-bandit.log
exit_code=$?
if [ ${exit_code} -ne 0 ]; then
    echo "Bandit exited with non-zero exit code."
    exit 1
fi
exit 0

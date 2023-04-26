pip install bandit
python -m bandit -r -lll -iii ${REPO_DIR} >${WORKSPACE}/lpot-bandit.log
exit_code=$?
if [ ${exit_code} -ne 0 ]; then
    echo "Bandit exited with non-zero exit code."
    exit 1
fi
exit 0

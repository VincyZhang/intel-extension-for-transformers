pip install pyspelling
# Update paths to validation and lpot repositories
VAL_REPO=${WORKSPACE}

sed -i "s|\${VAL_REPO}|$VAL_REPO|g" ${VAL_REPO}/nlp-toolkit/scripts/pyspelling_conf.yaml
sed -i "s|\${SCAN_REPO}|$REPO_DIR|g" ${VAL_REPO}/nlp-toolkit/scripts/pyspelling_conf.yaml
echo "Modified config:"
cat ${VAL_REPO}/nlp-toolkit/scripts/pyspelling_conf.yaml
pyspelling -c ${VAL_REPO}/nlp-toolkit/scripts/pyspelling_conf.yaml >${WORKSPACE}/pyspelling_output.log
exit_code=$?
if [ ${exit_code} -ne 0 ]; then
    echo "Pyspelling exited with non-zero exit code."
    exit 1
fi
exit 0

#!/bin/bash
cd /intel-extension-for-transformers/tests || exit 1
find ./ -name "test*.py" | sed 's,\.\/,python ,g' | sed 's/$/ --verbose/' >run.sh

LOG_DIR=/intel-extension-for-transformers/log_dir
JOB_NAME=unit_test
mkdir -p ${LOG_DIR}
ut_log_name=${LOG_DIR}/ut_${JOB_NAME}.log

echo "cat run.sh..."
cat run.sh | tee ${ut_log_name}
echo "------UT start-------"
bash run.sh 2>&1 | tee -a ${ut_log_name}
echo "------UT end -------"

if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] || [ $(grep -c "OK" ${ut_log_name}) == 0 ]; then
    echo "Find errors in UT test, please check the output..."
    exit 1
fi
echo "UT finished successfully! "

#!/bin/bash
source /intel-extension-for-transformers/.github/workflows/script/change_color.sh

cd /intel-extension-for-transformers/tests || exit 1
find ./ -name "test*.py" | sed 's,\.\/,python ,g' | sed 's/$/ --verbose/' >run.sh

LOG_DIR=/intel-extension-for-transformers/log_dir
JOB_NAME=unit_test
mkdir -p ${LOG_DIR}
ut_log_name=${LOG_DIR}/${JOB_NAME}.log

$BOLD_YELLOW && echo "cat run.sh..." && $RESET
cat run.sh | tee ${ut_log_name}
$BOLD_YELLOW && echo "------UT start-------" && $RESET
bash run.sh 2>&1 | tee -a ${ut_log_name}
$BOLD_YELLOW && echo "------UT end -------" && $RESET

if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] || [ $(grep -c "OK" ${ut_log_name}) == 0 ]; then
    $BOLD_RED && echo "Find errors in UT test, please check the output..." && $RESET
    exit 1
fi
$BOLD_GREEN && echo "UT finished successfully! " && $RESET

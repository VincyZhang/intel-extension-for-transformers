#!/bin/bash

source /intel-extension-for-transformers/.github/workflows/script/change_color.sh

REPO_DIR=/intel-extension-for-transformers
log_dir=/intel-extension-for-transformers/.github/workflows/script/formatScan
pydocstyle --convention=google ${REPO_DIR} >${log_dir}/pydocstyle.log

$BOLD_YELLOW && echo " -----------------  Current pydocstyle cmd start --------------------------" && $RESET
echo "pydocstyle --convention=google ${REPO_DIR} >${log_dir}/pydocstyle.log"
$BOLD_YELLOW && echo " -----------------  Current pydocstyle cmd end --------------------------" && $RESET

$BOLD_YELLOW && echo " -----------------  Current log file output start --------------------------"
cat $log_dir/pydocstyle.log
$BOLD_YELLOW && echo " -----------------  Current log file output end --------------------------" && $RESET

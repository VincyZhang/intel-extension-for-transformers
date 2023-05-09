#!/bin/bash
source /intel-extension-for-transformers/.github/workflows/script/change_color.sh
WORKSPACE="/intel-extension-for-transformers/.github/workflows/script/unitTest/coverage"
export COVERAGE_RCFILE="/intel-extension-for-transformers/.github/workflows/script/unitTest/coverage/.coveragerc"
cat ${COVERAGE_RCFILE}

# mute engine log
cd /intel-extension-for-transformers
coverage report -m --rcfile=${COVERAGE_RCFILE}
coverage html -d ${WORKSPACE}/coverage_base/htmlcov --rcfile=${COVERAGE_RCFILE}
coverage xml -o ${WORKSPACE}/coverage_base/coverage.xml --rcfile=${COVERAGE_RCFILE}


get_coverage_data() {
    # Input argument
    local coverage_xml="$1"

    # Get coverage data
    local coverage_data=$(python3 -c "import xml.etree.ElementTree as ET; root = ET.parse('$coverage_xml').getroot(); print(ET.tostring(root).decode())")
    if [[ -z "$coverage_data" ]]; then
        echo "Failed to get coverage data from $coverage_xml."
        exit 1
    fi

    # Get lines coverage
    local lines_covered=$(echo "$coverage_data" | grep -o 'lines-covered="[0-9]*"' | cut -d '"' -f 2)
    local lines_valid=$(echo "$coverage_data" | grep -o 'lines-valid="[0-9]*"' | cut -d '"' -f 2)
    if [ $lines_valid == 0 ]; then
        local lines_coverage=0
    else
        local lines_coverage=$(awk "BEGIN {printf \"%.3f\", 100 * $lines_covered / $lines_valid}")
    fi

    # Get branches coverage
    local branches_covered=$(echo "$coverage_data" | grep -o 'branches-covered="[0-9]*"' | cut -d '"' -f 2)
    local branches_valid=$(echo "$coverage_data" | grep -o 'branches-valid="[0-9]*"' | cut -d '"' -f 2)
    if [ $branches_valid == 0 ]; then
        local branches_coverage=0
    else
        local branches_coverage=$(awk "BEGIN {printf \"%.3f\", 100 * $branches_covered/$branches_valid}")
    fi

    # Return values
    echo "$lines_covered $lines_valid $lines_coverage $branches_covered $branches_valid $branches_coverage"
}

$BOLD_YELLOW && echo "compare coverage" && $RESET

coverage_PR_xml="log_dir/coverage_PR/coverage.xml"
coverage_PR_data=$(get_coverage_data $coverage_PR_xml)
read lines_PR_covered lines_PR_valid coverage_PR_lines_rate branches_PR_covered branches_PR_valid coverage_PR_branches_rate <<<"$coverage_PR_data"

coverage_base_xml="log_dir/coverage_base/coverage.xml"
coverage_base_data=$(get_coverage_data $coverage_base_xml)
read lines_base_covered lines_base_valid coverage_base_lines_rate branches_base_covered branches_base_valid coverage_base_branches_rate <<<"$coverage_base_data"

$BOLD_BLUE && echo "PR lines coverage: $lines_PR_covered/$lines_PR_valid ($coverage_PR_lines_rate%)" && $RESET
$BOLD_BLUE && echo "PR branches coverage: $branches_PR_covered/$branches_PR_valid ($coverage_PR_branches_rate%)" && $RESET
$BOLD_BLUE && echo "BASE lines coverage: $lines_base_covered/$lines_base_valid ($coverage_base_lines_rate%)" && $RESET
$BOLD_BLUE && echo "BASE branches coverage: $branches_base_covered/$branches_base_valid ($coverage_base_branches_rate%)" && $RESET


if [ $(grep -c "FAILED" ${ut_log_name}) != 0 ] || [ $(grep -c "OK" ${ut_log_name}) == 0 ]; then
    exit 1
fi
if [ $(grep -c "core dumped" ${ut_log_name}) != 0 ] || [ $(grep -c "Segmentation fault" ${ut_log_name}) != 0 ]; then
    exit 1
fi

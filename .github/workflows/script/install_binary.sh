#!/bin/bash
source /intel-extension-for-transformers/.github/workflows/script/change_color.sh

cd /intel-extension-for-transformers
$BOLD_YELLOW && echo "---------------- git submodule update --init --recursive -------------" && $RESET
git config --global --add safe.directory /intel-extension-for-transformers
git config --global --add safe.directory /intel-extension-for-transformers/intel_extension_for_transformers/backends/neural_engine/third_party/boost/libs/assert
git submodule update --init --recursive

$BOLD_YELLOW && echo "---------------- run python setup.py sdist bdist_wheel -------------" && $RESET
python setup.py sdist bdist_wheel

$BOLD_YELLOW && echo "---------------- pip install binary -------------" && $RESET
pip install dist/intel_extension_for_transformers*.whl
pip list

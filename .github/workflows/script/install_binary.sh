#!/bin/bash

cd /intel-extension-for-transformers
python -m pip install --no-cache-dir -r requirements.txt
python setup.py sdist bdist_wheel
pip install dist/intel_extension_for_transformers*.whl
pip list

cd /intel-extension-for-transformers
log_dir=/intel-extension-for-transformers/.github/workflows/script/formatScan
python -m pip install --default-timeout=100 -r requirements.txt
python -m pip install pylint==2.12.1
python -m pylint -f json --disable=R,C,W,E1129 \
                        --enable=line-too-long \
                        --max-line-length=120 \
                        --extension-pkg-whitelist=numpy \
                        --ignored-classes=TensorProto,NodeProto \
                        --ignored-modules=tensorflow,torch,torch.quantization,torch.tensor,torchvision,mxnet,onnx,onnxruntime,neural_compressor,engine_py,neural_engine_py \
                        /intel_extension_for_transformers >${log_dir}/pylint.json

cat ${log_dir}/pylint.json

exit_code=$?
if [ ${exit_code} -ne 0 ]; then
    echo "PyLint exited with non-zero exit code."
    exit 1
fi
exit 0

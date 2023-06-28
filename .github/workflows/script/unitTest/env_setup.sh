pip list

echo "Install neural_compressor binary..."
n=0
until [ "$n" -ge 5 ]; do
    pip install neural_compressor && break
    n=$((n + 1))
    sleep 5
done

# Install test requirements
cd ./tests
if [ -f "requirements.txt" ]; then
    sed -i '/neural-compressor/d;/tensorflow==/d;/torch==/d;/pytorch-ignite$/d;/mxnet==/d;/mxnet-mkl==/d;/torchvision==/d;/onnx$/d;/onnx==/d;/onnxruntime$/d;/onnxruntime==/d' requirements.txt
    python -m pip install --default-timeout=100 -r requirements.txt
    pip list
else
    echo "Not found requirements.txt file."
fi

# same as jenkins ci
pip instrall scipy==1.10.1

pip install coverage
pip install pytest

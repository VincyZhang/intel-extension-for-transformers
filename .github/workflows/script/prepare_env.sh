cd /intel-extension-for-transformers

pip install -U pip

if [ -f "requirements.txt" ]; then
    python -m pip install --default-timeout=100 -r requirements.txt
    pip list
else
    echo "Not found requirements.txt file."
fi

# Install test requirements
cd ./tests
if [ -f "requirements.txt" ]; then
    sed -i '/neural-compressor/d;/tensorflow==/d;/torch==/d;/pytorch-ignite$/d;/mxnet==/d;/mxnet-mkl==/d;/torchvision==/d;/onnx$/d;/onnx==/d;/onnxruntime$/d;/onnxruntime==/d' requirements.txt
    python -m pip install --default-timeout=100 -r requirements.txt
    pip list
else
    echo "Not found requirements.txt file."
fi

pip list

echo "Install neural_compressor binary..."
n=0
until [ "$n" -ge 5 ]; do
    pip install neural_compressor && break
    n=$((n + 1))
    sleep 5
done

pip install coverage
pip install pytest

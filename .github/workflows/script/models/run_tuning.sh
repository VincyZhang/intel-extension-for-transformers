echo "Running ---- ${framework}, ${model}----Tuning"
[[ -d ${HOME}/anaconda3/bin ]] && export PATH=${HOME}/anaconda3/bin/:$PATH
[[ -d ${HOME}/miniconda3/bin ]] && export PATH=${HOME}/miniconda3/bin/:$PATH
if [[ ${set_HF_offline} != "false" ]]; then
    export TRANSFORMERS_OFFLINE=1
    export TOKENIZERS_PARALLELISM=true
fi
source activate ${conda_env_name}
cd ${working_dir}
echo "Working in ${working_dir}"
echo -e "\nInstalling model requirements..."
if [ -f "requirements.txt" ]; then
    # sed -i '/neural-compressor/d' requirements.txt
    n=0
    until [ "$n" -ge 5 ]; do
        python -m pip install -r requirements.txt && break
        n=$((n + 1))
        sleep 5
    done
    pip list
else
    echo "Not found requirements.txt file."
fi
if [[ ${model} == "pegasus_samsum_dynamic" ]]; then
    pip install protobuf==3.20
fi
${timeout} ${tune_cmd} 2>&1 | tee ${WORKSPACE}/${framework}-${model}-${os}-${cpu}-tune.log

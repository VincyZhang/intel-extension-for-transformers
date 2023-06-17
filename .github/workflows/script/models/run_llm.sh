#!/bin/bash
set -eo pipefail
source /intel-extension-for-transformers/.github/workflows/script/change_color.sh

# get parameters
PATTERN='[-a-zA-Z0-9_]*='
PERF_STABLE_CHECK=false
log_dir="/intel-extension-for-transformers"
for i in "$@"; do
    case $i in
        --framework=*)
            framework=`echo $i | sed "s/${PATTERN}//"`;;
        --model=*)
            model=`echo $i | sed "s/${PATTERN}//"`;;
        --conda_env_name=*)
            conda_env_name=`echo $i | sed "s/${PATTERN}//"`;;
        --mode=*)
            mode=`echo $i | sed "s/${PATTERN}//"`;;
        --log_dir=*)
            log_dir=`echo $i | sed "s/${PATTERN}//"`;;
        --precision=*)
            precision=`echo $i | sed "s/${PATTERN}//"`;;
        --PERF_STABLE_CHECK=*)
            PERF_STABLE_CHECK=`echo $i | sed "s/${PATTERN}//"`;;
        *)
            echo "Parameter $i not recognized."; exit 1;;
    esac
done

main() {
    ## prepare env
    prepare

    # run latency
    run_benchmark 
}

function prepare() {
    [[ -d ${HOME}/anaconda3/bin ]] && export PATH=${HOME}/anaconda3/bin/:$PATH
    [[ -d ${HOME}/miniconda3/bin ]] && export PATH=${HOME}/miniconda3/bin/:$PATH
    export LD_LIBRARY_PATH=/lib64/libcrypto.so.1.1:${HOME}/miniconda3/envs/${conda_env_name}/lib/:$LD_LIBRARY_PATH
    if [[ ${precision} == "fp8" ]]; then
        export NE_WEIGHT_FP8_4E3M=1
    fi
    if [[ ${model} == "gpt-j-6b" ]]|| [[ model == "gpt-j-6b-pruned" ]]; then
        working_dir="/intel-extension-for-transformers/examples/huggingface/pytorch/text-generation/deployment"
    fi
    $BOLD_YELLOW && echo "Running ---- ${framework}, ${model}----Prepare"
    source activate ${conda_env_name}
    if [[ ${cpu} == *"spr"* ]] || [[ ${cpu} == *"SPR"* ]] || [[ ${cpu} == *"Spr"* ]]; then
        export CC=/opt/rh/gcc-toolset-11/root/usr/bin/gcc
        export CXX=/opt/rh/gcc-toolset-11/root/usr/bin/g++
        gcc -v
    fi
    if [[ ${model} == "gpt-j-6b" ]] || [[ model == "gpt-j-6b-pruned" ]]; then
        conda install mkl mkl-include -y
        conda install gperftools jemalloc==5.2.1 -c conda-forge -y
    fi
    
    cd ${working_dir}
    echo "Working in ${working_dir}"
    echo -e "\nInstalling model requirements..."
    export PATH=/lib64/libcrypto.so.1.1:$PATH
    cp /lib64/libcrypto.so.1.1 ${HOME}/miniconda3/envs/${conda_env_name}/lib/libcrypto.so.1.1
    cp /lib64/libcrypto.so.1.1 ${HOME}/miniconda3/lib/libcrypto.so.1.1
    if [ -f "requirements.txt" ]; then
        # sed -i '/neural-compressor/d' requirements.txt
        n=0
        until [ "$n" -ge 5 ]
        do
            python -m pip install -r requirements.txt && break
            n=$((n+1))
            sleep 5
        done
        pip list
    else
        echo "Not found requirements.txt file."
    fi
    if [[ $precision == "fp32" ]]; then
        prepare_cmd="python optimize_llm.py --pt_file=pt_fp32 --dtype=fp32 --model=/tf_dataset2/models/pytorch/gpt-j-6B --output_model=${working_dir}/fp32_ir"
    elif [[ $precision == "int8" ]]; then
        prepare_cmd="python optimize_llm.py --pt_file=/tf_dataset2/models/nlp_toolkit/gpt-j/best_model_bk.pt --dtype=int8 --model=/tf_dataset2/models/pytorch/gpt-j-6B --output_model=${working_dir}/int8_ir"
    fi
    ${prepare_cmd} 2>&1 | tee -a ${log_dir}/${framework}-${model}-tune.log
}

function run_benchmark() {
    bash /intel-extension-for-transformers/.github/workflows/script/launch_llm.sh ${conda_env_name} ${model} ${working_dir} ${log_dir}
}

main

#!/bin/bash
set -eo pipefail

# get parameters
PATTERN='[-a-zA-Z0-9_]*='
PERF_STABLE_CHECK=false

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
    ## run accuracy
    if [[ $(echo "${mode}" | grep "accuracy") ]]; then
        run_benchmark "accuracy"
    fi

    # run latency
    if [[ $(echo "${mode}" | grep "latency") ]] && [[ ${PERF_STABLE_CHECK} == "false" ]]; then
        run_benchmark "latency"
    elif [[ $(echo "${mode}" | grep "latency") ]]; then
        max_loop=3
        gap=(0.05 0.05 0.1)
        for ((iter = 0; iter < ${max_loop}; iter++)); do
            run_benchmark "latency"
            {
                check_perf_gap ${gap[${iter}]}
                exit_code=$?
            } || true

            if [ ${exit_code} -ne 0 ]; then
                $BOLD_RED && echo "FAILED with performance gap!!" && $RESET
            else
                $BOLD_GREEN && echo "SUCCEED!!" && $RESET
                break
            fi
        done
        exit ${exit_code}
    fi
}

function prepare() {
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
    if [[ ${enable_fp8} != "false" ]]; then
        export NE_WEIGHT_FP8_4E3M=1
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
    ${prepare_cmd} 2>&1 | tee -a ${log_dir}/${framework}-${model}-linux-spr-tune.log
}

function run_benchmark() {
    local input_mode=$1
    local batch_size=$2
    if [[ ${model} == "gpt-j-6b" ]] || [[ model == "gpt-j-6b-pruned" ]]; then
        benchmark_cmd="python run_llm.py --max-new-tokens=32 --model_path=${working_dir}/${precision}_ir"
    fi
    cd ${working_dir}
    overall_log="${log_dir}/${framework}-${model}-${precision}-${input_mode}-linux-spr.log"
    ${benchmark_cmd} 2>&1 | tee ${overall_log}
}

function check_perf_gap() {
    python -u ${SCRIPTS_PATH}/collect_log_model.py \
        --framework=${framework} \
        --fwk_ver=${fwk_ver} \
        --model=${model} \
        --logs_dir="${log_dir}" \
        --output_dir="${log_dir}" \
        --build_id=${BUILD_BUILDID} \
        --mode=${mode} \
        --gap=$1
}

main

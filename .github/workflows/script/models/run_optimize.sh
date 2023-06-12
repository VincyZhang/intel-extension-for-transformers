#!/bin/bash
set -eo pipefail

# get parameters
PATTERN='[-a-zA-Z0-9_]*='
PERF_STABLE_CHECK=true

for i in "$@"; do
    case $i in
        --framework=*)
            framework=`echo $i | sed "s/${PATTERN}//"`;;
        --model=*)
            model=`echo $i | sed "s/${PATTERN}//"`;;
        --mode=*)
            benchmark_cmd=`echo $i | sed "s/${PATTERN}//"`;;
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

$BOLD_YELLOW && echo "-------- run_benchmark_common --------" && $RESET

main() {
    ## prepare env
    if [[ ${model} == "bert_base_mrpc_static" ]] && [[ ${framework} == "pytorch" ]]; then
        working_dir="/intel-extension-for-transformers/examples/huggingface/pytorch/text-classification/quantization/ptq"
    elif [[ ${model} == "bert_base_mrpc_static" ]] && [[ ${framework} == "tensorflow" ]]; then
        working_dir="/intel-extension-for-transformers/examples/huggingface/tensorflow/text-classification/quantization/ptq"
    fi
    ## tune
    if [[ $(echo "${mode}" | grep "tuning") ]]; then
        run_tuning
    fi
    ## run accuracy
    if [[ $(echo "${mode}" | grep "accuracy") ]]; then
        run_benchmark "accuracy" 64
    fi

    ## run traner.benchmark using pytorch
    if [[ $framework == "pytorch" ]]; then
        run_benchmark "benchmark_only" 1
    fi

    # run performance
    if [[ $(echo "${mode}" | grep "performance") ]] && [[ ${PERF_STABLE_CHECK} == "false" ]]; then
        run_benchmark "performance" 1
    elif [[ $(echo "${mode}" | grep "performance") ]]; then
        max_loop=3
        gap=(0.05 0.05 0.1)
        for ((iter = 0; iter < ${max_loop}; iter++)); do
            run_benchmark "performance" 1
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

function run_tuning() {
    if [[ ${model} == "bert_base_mrpc_static" ]] && [[ ${framework} == "pytorch" ]]; then
        tuning_cmd="bash run_tuning.sh --topology=bert_base_mrpc_static --output_model=saved_results"
    elif [[ ${model} == "bert_base_mrpc_static" ]] && [[ ${framework} == "tensorflow" ]]; then
        tuning_cmd="bash run_tuning.sh --topology=bert_base_mrpc_static --output_model=saved_results"
    fi
    cd ${working_dir}
    overall_log="${log_dir}/${framework}-${model}-linux-icx-tune.log"
    ${tuning_cmd} 2>&1|tee ${overall_log}
    $BOLD_YELLOW && echo "====== check tuning status. ======" && $RESET
    control_phrase="model which meet accuracy goal."
    if [ $(grep "${control_phrase}" ${log_dir}/${model}/${framework}-${model}-tune.log | wc -l) == 0 ];then
        $BOLD_RED && echo "====== tuning FAILED!! ======" && $RESET; exit 1
    fi
    if [ $(grep "${control_phrase}" ${log_dir}/${model}/${framework}-${model}-tune.log | grep "Not found" | wc -l) == 1 ];then
        $BOLD_RED && echo "====== tuning FAILED!! ======" && $RESET; exit 1
    fi
    $BOLD_GREEN && echo "====== tuning SUCCEED!! ======" && $RESET
}

function run_benchmark() {
    local input_mode=$1
    local batch_size=$2
    if [[ ${model} == "bert_base_mrpc_static" ]] && [[ ${framework} == "pytorch" ]]; then
        benchmark_cmd="bash run_benchmark.sh --mode=${input_mode} --batch_size=${batch_size} --topology=bert_base_mrpc_static --config=saved_results"
    elif [[ ${model} == "bert_base_mrpc_static" ]] && [[ ${framework} == "tensorflow" ]]; then
        benchmark_cmd="bash run_benchmark.sh --mode=${input_mode} --batch_size=${batch_size} --topology=bert_base_mrpc_static --config=saved_results"
    fi
    if [[ $precision == "int8" ]]; then
        benchmark_cmd="${benchmark_cmd} --int8=true"
    else
        benchmark_cmd="${benchmark_cmd} --int8=false"
    fi
    cd ${working_dir}
    if [[ $input_mode == "performance" ]]; then
        multiInstance
    else
        overall_log="${log_dir}/${framework}-${model}-${precision}-${input_mode}-linux-icx.log"
        ${benchmark_cmd} 2>&1|tee ${overall_log}
        status=$?
        if [ ${status} != 0 ]; then
            echo "Benchmark process returned non-zero exit code."
            exit 1
        fi
    fi
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

function run_performance() {
    if [ "${single_instance}" == "true" ]; then
        run_benchmark "performance" 1
    else
        $BOLD_YELLOW && echo "run with external multiInstance benchmark..." && $RESET
        multiInstance 
    fi
}

function multiInstance() {
    ncores_per_socket=${ncores_per_socket:=$(lscpu | grep 'Core(s) per socket' | cut -d: -f2 | xargs echo -n)}
    $BOLD_YELLOW && echo "Executing multi instance benchmark" && $RESET
    ncores_per_instance=4
    $BOLD_YELLOW && echo "ncores_per_socket=${ncores_per_socket}, ncores_per_instance=${ncores_per_instance}" && $RESET

    logFile="${log_dir}/${framework}-${model}-${precision}-performance-linux-icx"
    benchmark_pids=()
    export OMP_NUM_THREADS=${ncores_per_instance}
    
    for((j=0;$j<${ncores_per_socket};j=$(($j + ${ncores_per_instance}))));
    do
        end_core_num=$((j + ncores_per_instance -1))
        if [ ${end_core_num} -ge ${ncores_per_socket} ]; then
            end_core_num=$((ncores_per_socket-1))
        fi
        numactl -m 0 -C "$j-$end_core_num" \
            ${benchmark_cmd} 2>&1|tee ${logFile}-${ncores_per_socket}-${ncores_per_instance}-${j}.log &
            benchmark_pids+=($!)
    done

    status="SUCCESS"
    for pid in "${benchmark_pids[@]}"; do
        wait $pid
        exit_code=$?
        echo "Detected exit code: ${exit_code}"
        if [ ${exit_code} == 0 ]; then
            echo "Process ${pid} succeeded"
        else
            echo "Process ${pid} failed"
            status="FAILURE"
        fi
    done
    echo "Benchmark process status: ${status}"
    if [ ${status} == "FAILURE" ]; then
        echo "Benchmark process returned non-zero exit code."
        exit 1
    fi
}

main

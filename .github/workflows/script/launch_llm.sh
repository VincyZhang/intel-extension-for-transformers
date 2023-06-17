
#!/bin/bash
set -x

cores_list=(56)
batch_size_list=(1 4)
input_list=(32 512)
output_list=(32 128)
beam_list=(1 4)
# input_list=(32 512)
# output_list=(32 128 512)

function main() {
    conda_env="$1"
    model="$2"
    working_dir="$3"
    log_prefix="$4"
    script="${working_dir}/run_llm.py"
    precision_list=("int8" "bf16")
    # init params
    if [[ "${model}" == "gpt-j-6b" ]] || [[ "${model}" == "gpt-j-6b-pruned" ]]; then
        model_name="EleutherAI/gpt-j-6B"
        model_type="gpt-j"
    elif [[ "${model}" == "llama-7b-hf" ]]; then
        model_name="decapoda-research/llama-7b-hf-hf"
        model_type="llama_7b"
    fi

    # init conda 
    . $(dirname ${CONDA_EXE})/../etc/profile.d/conda.sh
    conda activate $conda_env
    # setup conda env for LLM

    # get cpu info
    # sockets=$(lscpu |grep 'Socket(s):' |sed 's/.*://;s/ //g')
    # cores_per_instance=$(lscpu |grep 'Core(s) per socket:' |sed 's/.*://;s/ //g')

    # env
    export KMP_BLOCKTIME=1
    export KMP_SETTINGS=1
    export KMP_AFFINITY=granularity=fine,compact,1,0
    export LD_PRELOAD=${CONDA_PREFIX}/lib/libiomp5.so:${CONDA_PREFIX}/lib/libtcmalloc.so
    export GLOG_minloglevel=2

    # launch benchmark
    for cores_per_instance in ${cores_list[@]}
    do
        for batch_size in ${batch_size_list[@]}
        do
            for input in ${input_list[@]}
            do
                for precision in ${precision_list[@]}
                do
                    [[ "${input}" == "32" ]] && output=32 || output=128
                    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
                    logs_file="${model}-${precision}-${cores_per_instance}-${batch_size}-${input}-${output}.log"
                    ir_path="${working_dir}/${precision}_ir"
                    python /intel-extension-for-transformers/.github/workflows/script/py_task_injection.py --task=get_ITREX_cpu_memory_info --file_name=${script} --toolkit=intel_extension_for_transformers
                    OMP_NUM_THREADS=$[$cores_per_instance * 1] numactl -m 0 -C 0-$[$cores_per_instance * 1 - 1] \
                            python ${script} --input-tokens $input --max-new-tokens $output --batch-size $batch_size --model_path ${ir_path} --model_type ${model_type} 2>&1 |tee ${WORKSPACE}/${logs_file} || true
                    collect_perf_logs_llm ${logs_file} ${precision}

                    #if [[ ${model} == "gpt-j-6b" ]]; then
                    #    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
                    #    logs_file="${model}-${precision}-prune-${cores_per_instance}-${batch_size}-${input}-${output}.log"
                    #    ir_path="${working_dir}/${precision}_ir_pruned"
                    #    OMP_NUM_THREADS=$[$cores_per_instance * 1] numactl -m 0 -C 0-$[$cores_per_instance * 1 - 1] \
                    #            python ${script} --input-tokens $input --max-new-tokens $output --batch-size $batch_size --model_path ${ir_path}-prune --print-memory 2>&1 |tee ${logs_file} || true
                    #    collect_perf_logs_llm ${logs_file} ${precision}-prune
                    #fi
                done
            done
        done
    done

    conda deactivate > /dev/null 2>&1
}

function collect_perf_logs_llm {
    # latency
    log_dir="${WORKSPACE}/$1"
    latency=($(grep -i 'inference latency:' ${log_dir} |sed -e 's/.*atency://;s/[^0-9.]//g;s/\.$//' |awk '
        BEGIN {
            num = 0;
            sum = 0;
        }{
            num ++;
            sum += $1;
        }END {
            if(num > 0) {
                printf("%d  %.6f", num, sum / num);
            }else {
                printf("0  0");
            }
        }
    '))
    first_latency=($(grep -i 'First token average latency:' ${log_dir} |sed -e 's/.*atency://;s/[^0-9.]//g;s/\.$//' |awk '
        BEGIN {
            num = 0;
            sum = 0;
        }{
            num ++;
            sum += $1;
        }END {
            if(num > 0) {
                printf("%.6f", sum / num);
            }else {
                printf("0");
            }
        }
    '))
    avg_latency=($(grep -i 'Average 2... latency:' ${log_dir} |sed -e 's/.*atency://;s/[^0-9.]//g;s/\.$//' |awk '
        BEGIN {
            num = 0;
            sum = 0;
        }{
            num ++;
            sum += $1;
        }END {
            if(num > 0) {
                printf("%.6f", sum / num);
            }else {
                printf("0");
            }
        }
    '))
    p90_latency=($(grep -i 'P90 2... latency:' ${log_dir} |sed -e 's/.*atency://;s/[^0-9.]//g;s/\.$//' |awk '
        BEGIN {
            num = 0;
            sum = 0;
        }{
            num ++;
            sum += $1;
        }END {
            if(num > 0) {
                printf("%.6f", sum / num);
            }else {
                printf("0");
            }
        }
    '))
    input_tokens=$input
    max_new_tokens=$output
    beam_search=4
    # throughput
    throughput=($(
        echo |awk -v bs=$batch_size -v it=$input -v sec=${latency[1]} -v i=${latency[0]} '{
            if(sec <= 0) {
                print "0";
            }else {
                printf("%.3f", bs * it / sec * i);
            }
        }'
    ) 0)
    # memory usage
    used_memory=$(grep 'memory used total:' ${log_dir} |tail -n 1 |head -n 1 |awk '{print $(NF-1)}')
    # summary
    framework="engine"
    mode_name="latency"
    precision=$2
    link="${log_prefix}/$1"
    printf "${framework},${mode_name},${model_name},${precision},${batch_size}," |tee -a ${WORKSPACE}/llm_summary.log
    printf "${input_tokens},${max_new_tokens},${beam_search},${used_memory}," |tee -a ${WORKSPACE}/llm_summary.log
    printf "${cores_per_instance},${latency[0]},${throughput[0]},${link} ," |tee -a ${WORKSPACE}/llm_summary.log
    printf "${latency[1]},${first_latency},${avg_latency},${p90_latency},$(hostname)\n" |tee -a ${WORKSPACE}/llm_summary.log
    set +x
    echo -e "\n\n-------- Summary --------"
    sed -n '1p;$p' ${WORKSPACE}/llm_summary.log |column -t -s ','
}


main $@ 2>&1 |tee ${WORKSPACE}/launch.log



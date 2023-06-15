#!/bin/bash
# set -x
set -eo pipefail
WORKSPACE=generated
last_log_path=FinalReport
summaryLog=${WORKSPACE}/summary.log
summaryLogLast=${last_log_path}/summary.log
tuneLog=${WORKSPACE}/tuning_info.log
tuneLogLast=${last_log_path}/tuning_info.log

function main {
    echo "summaryLog: ${summaryLog}"
    echo "summaryLogLast: ${summaryLogLast}"
    echo "tunelog: ${tuneLog}"
    echo "last tunelog: ${tuneLogLast}"

    generate_html_head
    generate_html_overview
    generate_optimize_results
    generate_html_footer
}

function generate_html_overview {
    Test_Info_Title="<th colspan="4">Test Branch</th> <th colspan="4">Commit ID</th> "
    Test_Info="<th colspan="4">${MR_source_branch}</th> <th colspan="4">${ghprbActualCommit}</th> "

    cat >>${WORKSPACE}/report.html <<eof

<body>
    <div id="main">
        <h1 align="center">NLP-TOOLKIT Tests
        [ <a href="${RUN_DISPLAY_URL}">Job-${BUILD_NUMBER}</a> ]</h1>
      <h1 align="center">Test Status: ${JOB_STATUS}</h1>
        <h2>Summary</h2>
        <table class="features-table">
            <tr>
              <th>Repo</th>
              ${Test_Info_Title}
              </tr>
              <tr>
                    <td><a href="https://github.com/intel/intel-extension-for-transformers">ITREX</a></td>
              ${Test_Info}
                </tr>
        </table>
eof
}

function generate_optimize_results {

    cat >>${WORKSPACE}/report.html <<eof
    <h2>Optimize Result</h2>
      <table class="features-table">
          <tr>
                <th rowspan="2">Platform</th>
                <th rowspan="2">System</th>
                <th rowspan="2">Framework</th>
                <th rowspan="2">Version</th>
                <th rowspan="2">Model</th>
                <th rowspan="2">VS</th>
                <th rowspan="2">Tuning<br>Time(s)</th>
                <th rowspan="2">Tuning<br>Count</th>
                <th colspan="6">INT8/BF16</th>
                <th colspan="6">FP32</th>
                <th colspan="3" class="col-cell col-cell1 col-cellh">Ratio</th>
          </tr>
          <tr>
                <th>bs</th>
                <th>imgs/s</th>
                <th>bs</th>
                <th>imgs/s</th>
                <th>bs</th>
                <th>top1</th>

                <th>bs</th>
                <th>imgs/s</th>
                <th>bs</th>
                <th>imgs/s</th>
                <th>bs</th>
                <th>top1</th>

                <th class="col-cell col-cell1">Throughput<br><font size="2px">INT8/FP32>=2</font></th>
                <th class="col-cell col-cell1">Benchmark<br><font size="2px">INT8/FP32>=2</font></th>
                <th class="col-cell col-cell1">Accuracy<br><font size="2px">(INT8-FP32)/FP32>=-0.01</font></th>
          </tr>
eof

    oses=$(sed '1d' ${summaryLog} | cut -d';' -f1 | awk '!a[$0]++')
    for os in ${oses[@]}; do
        platforms=$(sed '1d' ${summaryLog} | grep "^${os}" | cut -d';' -f2 | awk '!a[$0]++')
        for platform in ${platforms[@]}; do
            frameworks=$(sed '1d' ${summaryLog} | grep "^${os};${platform};optimize" | cut -d';' -f4 | awk '!a[$0]++')
            for framework in ${frameworks[@]}; do
                fw_versions=$(sed '1d' ${summaryLog} | grep "^${os};${platform};optimize;${framework}" | cut -d';' -f5 | awk '!a[$0]++')
                for fw_version in ${fw_versions[@]}; do
                    models=$(sed '1d' ${summaryLog} | grep "^${os};${platform};optimize;${framework};${fw_version}" | cut -d';' -f7 | awk '!a[$0]++')
                    for model in ${models[@]}; do
                        current_values=$(generate_inference ${summaryLog} "optimize")
                        last_values=$(generate_inference ${summaryLogLast} "optimize")
                        if [[ ${model} == "gpt-j-6b" ]] || [[ ${model} == "llama-7b-hf" ]] || [[ ${model} == "stable_diffusion" ]] || [[ ${model} == "gpt-j-6b-pruned" ]]; then
                            local_mode="latency"
                        else
                            local_mode="performance"
                        fi
                        generate_tuning_core "optimize" "${local_mode}"
                    done
                done
            done
        done
    done

    cat >>${WORKSPACE}/report.html <<eof
    </table>
eof
}

function generate_inference {
    local workflow=$2
    awk -v framework="${framework}" -v workflow="${workflow}" -v fw_version="${fw_version}" -v model="${model}" -v os="${os}" -v platform=${platform} -F ';' '
        BEGINE {
            fp32_perf_bs = "nan";
            fp32_perf_value = "nan";
            fp32_perf_url = "nan";
            fp32_acc_bs = "nan";
            fp32_acc_value = "nan";
            fp32_acc_url = "nan";
            fp32_benchmark_value = "nan";
            fp32_benchmark_url = "nan";

            int8_perf_bs = "nan";
            int8_perf_value = "nan";
            int8_perf_url = "nan";
            int8_acc_bs = "nan";
            int8_acc_value = "nan";
            int8_acc_url = "nan";
            int8_benchmark_value = "nan";
            int8_benchmark_url = "nan";

            bf16_perf_bs = "nan";
            bf16_perf_value = "nan";
            bf16_perf_url = "nan";
            bf16_acc_bs = "nan";
            bf16_acc_value = "nan";
            bf16_acc_url = "nan";
            bf16_benchmark_value = "nan";
            bf16_benchmark_url = "nan";

            fp8_perf_bs = "nan";
            fp8_perf_value = "nan";
            fp8_perf_url = "nan";
            fp8_acc_bs = "nan";
            fp8_acc_value = "nan";
            fp8_acc_url = "nan";
            fp8_benchmark_value = "nan";
            fp8_benchmark_url = "nan";

            dint8_perf_bs = "nan";
            dint8_perf_value = "nan";
            dint8_perf_url = "nan";
            dint8_acc_bs = "nan";
            dint8_acc_value = "nan";
            dint8_acc_url = "nan";
            dint8_benchmark_value = "nan";
            dint8_benchmark_url = "nan";
        }{
            if($1 == os && $2 == platform && $3 == workflow && $4 == framework && $5 == fw_version && $7 == model) {
                // FP32
                if($6 == "FP32") {
                    // Performance
                    if($9 == "Performance" || $9 == "Latency") {
                        fp32_perf_bs = $10;
                        fp32_perf_value = $11;
                        fp32_perf_url = $12;
                    }
                    // Accuracy
                    if($9 == "Accuracy" || $9 == "accuracy") {
                        fp32_acc_bs = $10;
                        fp32_acc_value = $11;
                        fp32_acc_url = $12;
                    }
                    // Benchmark
                    if($9 == "Benchmark" || $9 == "benchmark_only") {
                        fp32_bench_bs = $10;
                        fp32_bench_value = $11;
                        fp32_bench_url = $12;
                    }
                }
                // INT8
                if($6 == "INT8") {
                    // Performance
                    if($9 == "Performance" || $9 == "Latency") {
                        int8_perf_bs = $10;
                        int8_perf_value = $11;
                        int8_perf_url = $12;
                    }
                    // Accuracy
                    if($9 == "Accuracy" || $9 == "accuracy") {
                        int8_acc_bs = $10;
                        int8_acc_value = $11;
                        int8_acc_url = $12;
                    }
                    // Benchmark
                    if($9 == "Benchmark" || $9 == "benchmark_only") {
                        int8_bench_bs = $10;
                        int8_bench_value = $11;
                        int8_bench_url = $12;
                    }
                }
                if($6 == "BF16") {
                    // Performance
                    if($9 == "Performance" || $9 == "Latency") {
                        bf16_perf_bs = $10;
                        bf16_perf_value = $11;
                        bf16_perf_url = $12;
                    }
                    // Accuracy
                    if($9 == "Accuracy" || $9 == "accuracy") {
                        bf16_acc_bs = $10;
                        bf16_acc_value = $11;
                        bf16_acc_url = $12;
                    }
                    // Benchmark
                    if($9 == "Benchmark" || $9 == "benchmark_only") {
                        bf16_bench_bs = $10;
                        bf16_bench_value = $11;
                        bf16_bench_url = $12;
                    }
                }
                if($6 == "DYNAMIC_INT8") {
                    // Performance
                    if($9 == "Performance" || $9 == "Latency") {
                        dint8_perf_bs = $10;
                        dint8_perf_value = $11;
                        dint8_perf_url = $12;
                    }
                    // Accuracy
                    if($9 == "Accuracy" || $9 == "accuracy") {
                        dint8_acc_bs = $10;
                        dint8_acc_value = $11;
                        dint8_acc_url = $12;
                    }
                    // Benchmark
                    if($9 == "Benchmark" || $9 == "benchmark_only") {
                        dint8_bench_bs = $10;
                        dint8_bench_value = $11;
                        dint8_bench_url = $12;
                    }
                }
                if($6 == "FP8") {
                    // Performance
                    if($9 == "Performance" || $9 == "Latency") {
                        fp8_perf_bs = $10;
                        fp8_perf_value = $11;
                        fp8_perf_url = $12;
                    }
                    // Accuracy
                    if($9 == "Accuracy" || $9 == "accuracy") {
                        fp8_acc_bs = $10;
                        fp8_acc_value = $11;
                        fp8_acc_url = $12;
                    }
                    // Benchmark
                    if($9 == "Benchmark" || $9 == "benchmark_only") {
                        fp8_bench_bs = $10;
                        fp8_bench_value = $11;
                        fp8_bench_url = $12;
                    }
                }
            }
        }END {
            printf("%s;%s;%s;%s;%s;%s;", int8_perf_bs,int8_perf_value,int8_bench_bs,int8_bench_value,int8_acc_bs,int8_acc_value);
            printf("%s;%s;%s;%s;%s;%s;", fp32_perf_bs,fp32_perf_value,fp32_bench_bs,fp32_bench_value,fp32_acc_bs,fp32_acc_value);
            printf("%s;%s;%s;%s;%s;%s;", int8_perf_url,int8_bench_url,int8_acc_url,fp32_perf_url,fp32_bench_url,fp32_acc_url);
            printf("%s;%s;%s;%s;%s;%s;%s;%s;%s;", bf16_perf_bs,bf16_perf_value,bf16_perf_url,bf16_acc_bs,bf16_acc_value,bf16_acc_url,bf16_bench_bs,bf16_bench_value,bf16_bench_url);
            printf("%s;%s;%s;%s;%s;%s;%s;%s;%s;", dint8_perf_bs,dint8_perf_value,dint8_perf_url,dint8_acc_bs,dint8_acc_value,dint8_acc_url,dint8_bench_bs,dint8_bench_value,dint8_bench_url);
            printf("%s;%s;%s;%s;%s;%s;%s;%s;%s;", fp8_perf_bs,fp8_perf_value,fp8_perf_url,fp8_acc_bs,fp8_acc_value,fp8_acc_url,fp8_bench_bs,fp8_bench_value,fp8_bench_url);
        }
    ' "$1"
}

function generate_tuning_core {
    local workflow=$1
    local mode=$2

    tuning_time=$(grep "^${os};${platform};${workflow};${framework};${fw_version};${model};" ${tuneLog} | awk -F';' '{print $8}')
    tuning_count=$(grep "^${os};${platform};${workflow};${framework};${fw_version};${model};" ${tuneLog} | awk -F';' '{print $9}')
    tuning_log=$(grep "^${os};${platform};${workflow};${framework};${fw_version};${model};" ${tuneLog} | awk -F';' '{print $10}')

    echo "<tr><td rowspan=3>${platform}</td><td rowspan=3>${os}</td><td rowspan=3>${framework}</td><td rowspan=3>${fw_version}</td><td rowspan=3>${model}</td><td>New</td>" >>${WORKSPACE}/report.html
    echo "<td><a href=${tuning_log}>${tuning_time}</a></td><td><a href=${tuning_log}>${tuning_count}</a></td>" >>${WORKSPACE}/report.html

    tuning_time=$(grep "^${os};${platform};${workflow};${framework};${fw_version};${model};" ${tuneLogLast} | awk -F';' '{print $8}')
    tuning_count=$(grep "^${os};${platform};${workflow};${framework};${fw_version};${model};" ${tuneLogLast} | awk -F';' '{print $9}')
    tuning_log=$(grep "^${os};${platform};${workflow};${framework};${fw_version};${model};" ${tuneLogLast} | awk -F';' '{print $10}')

    echo | awk -F ';' -v current_values="${current_values}" -v last_values="${last_values}" \
        -v tuning_time="${tuning_time}" \
        -v tuning_count="${tuning_count}" -v tuning_log="${tuning_log}" -v workflow="${workflow}" -v mode=${mode} '

        function abs(x) { return x < 0 ? -x : x }

        function show_new_last(batch, link, value, metric) {
            if(value ~/[1-9]/) {
                if (metric == "perf" || metric == "bench") {
                    printf("<td>%s</td> <td><a href=%s>%.2f</a></td>\n",batch,link,value);
                } else {
                    if (value <= 1){
                        printf("<td>%s</td> <td><a href=%s>%.2f%</a></td>\n",batch,link,value*100);
                    }else{
                        printf("<td>%s</td> <td><a href=%s>%.2f</a></td>\n",batch,link,value);
                    }
                }
            } else {
                if(link == "" || value == "N/A") {
                    printf("<td></td> <td></td>\n");
                } else {
                    printf("<td>%s</td> <td><a href=%s>Failure</a></td>\n",batch,link);
                }
            }
        }

        function compare_current(int8_result, fp32_result, metric) {

            if(int8_result ~/[1-9]/ && fp32_result ~/[1-9]/) {
                if(metric == "acc") {
                    target = (int8_result - fp32_result) / fp32_result;
                    if(target >= -0.01) {
                       printf("<td rowspan=3 style=\"background-color:#90EE90\">%.2f%</td>", target*100);
                    }else if(target < -0.05) {
                       printf("<td rowspan=3 style=\"background-color:#FFD2D2\">%.2f%</td>", target*100);
                    }else{
                       printf("<td rowspan=3>%.2f%</td>", target*100);
                    }
                } else if(metric == "perf" || metric == "bench") {
                    target = int8_result / fp32_result;
                    if(target >= 2) {
                       printf("<td rowspan=3 style=\"background-color:#90EE90\">%.2f</td>", target);
                    }else if(target < 1) {
                       printf("<td rowspan=3 style=\"background-color:#FFD2D2\">%.2f</td>", target);
                    }else{
                       printf("<td rowspan=3>%.2f</td>", target);
                    }
                } else {
                    // latency mode
                    target = fp32_result / int8_result;
                    if(target >= 2) {
                       printf("<td rowspan=3 style=\"background-color:#90EE90\">%.2f</td>", target);
                    }else if(target < 1) {
                       printf("<td rowspan=3 style=\"background-color:#FFD2D2\">%.2f</td>", target);
                    }else{
                       printf("<td rowspan=3>%.2f</td>", target);
                    }
                }
            }else {
                printf("<td rowspan=3></td>");
            }
        }

        function compare_result(new_result, previous_result, metric) {

            if (new_result ~/[1-9]/ && previous_result ~/[1-9]/) {
                if(metric == "acc") {
                    target = new_result - previous_result;
                    if(target >= -0.0001 && target <= 0.0001) {
                        status_png = "background-color:#90EE90";
                    } else {
                        status_png = "background-color:#FFD2D2";
                    }
                    if (new_result <= 1){
                        printf("<td style=\"%s\" colspan=2>%.2f%</td>", status_png, target*100);
                    }else{
                        printf("<td style=\"%s\" colspan=2>%.2f</td>", status_png, target);
                    }
                } else if (metric == "perf" || metric == "bench"){
                    target = new_result / previous_result;
                    if(target >= 0.95) {
                        status_png = "background-color:#90EE90";
                    } else {
                        status_png = "background-color:#FFD2D2";
                    }
                    printf("<td style=\"%s\" colspan=2>%.2f</td>", status_png, target);
                } else {
                    target = previous_result / new_result;
                    if(target >= 0.95) {
                        status_png = "background-color:#90EE90";
                    } else {
                        status_png = "background-color:#FFD2D2";
                    }
                    printf("<td style=\"%s\" colspan=2>%.2f</td>", status_png, target);
                }
            } else {
                if(new_result == "nan" || previous_result == "nan") {
                    printf("<td class=\"col-cell col-cell3\" colspan=2></td>");
                }else {
                    printf("<td style=\"col-cell col-cell3\" colspan=2></td>");
                    job_red++;
                }
            }
        }

        BEGIN {
        }{
            // Current values
            split(current_values,current_value,";");

            // INT8 Performance results
            int8_perf_batch=current_value[1]
            int8_perf_value=current_value[2]
            int8_perf_url=current_value[13]
            show_new_last(int8_perf_batch, int8_perf_url, int8_perf_value, "perf");
            if (workflow == "optimize") {
                // INT8 Bench results
                int8_bench_batch=current_value[3]
                int8_bench_value=current_value[4]
                int8_bench_url=current_value[14]
                show_new_last(int8_bench_batch, int8_bench_url, int8_bench_value, "bench");
            }
            // INT8 Accuracy results
            int8_acc_batch=current_value[5]
            int8_acc_value=current_value[6]
            int8_acc_url=current_value[15]
            show_new_last(int8_acc_batch, int8_acc_url, int8_acc_value, "acc");

            // FP32 Performance results
            fp32_perf_batch=current_value[7]
            fp32_perf_value=current_value[8]
            fp32_perf_url=current_value[16]
            show_new_last(fp32_perf_batch, fp32_perf_url, fp32_perf_value, "perf");
            if (workflow == "optimize") {
                // FP32 Bench results
                fp32_bench_batch=current_value[9]
                fp32_bench_value=current_value[10]
                fp32_bench_url=current_value[17]
                show_new_last(fp32_bench_batch, fp32_bench_url, fp32_bench_value, "bench");
            }
            // FP32 Accuracy results
            fp32_acc_batch=current_value[11]
            fp32_acc_value=current_value[12]
            fp32_acc_url=current_value[18]
            show_new_last(fp32_acc_batch, fp32_acc_url, fp32_acc_value, "acc");

            // BF16 Performance results
            if (workflow == "deploy") {
                bf16_perf_batch=current_value[19]
                bf16_perf_value=current_value[20]
                bf16_perf_url=current_value[21]
                show_new_last(bf16_perf_batch, bf16_perf_url, bf16_perf_value, "perf");

                // BF16 Accuracy results
                bf16_acc_batch=current_value[22]
                bf16_acc_value=current_value[23]
                bf16_acc_url=current_value[24]
                show_new_last(bf16_acc_batch, bf16_acc_url, bf16_acc_value, "acc");

                fp8_perf_batch=current_value[37]
                fp8_perf_value=current_value[38]
                fp8_perf_url=current_value[39]
                show_new_last(fp8_perf_batch, fp8_perf_url, fp8_perf_value, "perf");

                // fp8 Accuracy results
                fp8_acc_batch=current_value[40]
                fp8_acc_value=current_value[41]
                fp8_acc_url=current_value[42]
                show_new_last(fp8_acc_batch, fp8_acc_url, fp8_acc_value, "acc");

                dint8_perf_batch=current_value[28]
                dint8_perf_value=current_value[29]
                dint8_perf_url=current_value[30]
                show_new_last(dint8_perf_batch, dint8_perf_url, dint8_perf_value, "perf");

                // Dynamic INT8 Accuracy results
                dint8_acc_batch=current_value[31]
                dint8_acc_value=current_value[32]
                dint8_acc_url=current_value[33]
                show_new_last(dint8_acc_batch, dint8_acc_url, dint8_acc_value, "acc");
            }
            

            // Compare Current
            if (mode == "performance") {
                compare_current(int8_perf_value, fp32_perf_value, "perf");
            } else {
                compare_current(int8_perf_value, fp32_perf_value, "latency");
            }
            if (workflow == "optimize") {
                compare_current(int8_bench_value, fp32_bench_value, "bench")
            }
            compare_current(int8_acc_value, fp32_acc_value, "acc");

            if (workflow == "deploy") {
                if (mode == "performance") {
                    compare_current(bf16_perf_value, fp32_perf_value, "perf");
                } else {
                    compare_current(bf16_perf_value, fp32_perf_value, "latency");
                }
                compare_current(bf16_acc_value, fp32_acc_value, "acc");
                
                if (mode == "performance") {
                    compare_current(fp8_perf_value, fp32_perf_value, "perf");
                } else {
                    compare_current(fp8_perf_value, fp32_perf_value, "latency");
                }
                compare_current(fp8_acc_value, fp32_acc_value, "acc");

                if (mode == "performance") {
                    compare_current(dint8_perf_value, fp32_perf_value, "perf");
                } else {
                    compare_current(dint8_perf_value, fp32_perf_value, "latency");
                }
                compare_current(dint8_acc_value, fp32_acc_value, "acc");
            }

            // Last values
            split(last_values,last_value,";");

            // Last
            printf("</tr>\n<tr><td>Last</td><td><a href=%3$s>%1$s</a></td><td><a href=%3$s>%2$s</a></td>", tuning_time, tuning_count, tuning_log);

            // Show last INT8 Performance results
            last_int8_perf_batch=last_value[1]
            last_int8_perf_value=last_value[2]
            last_int8_perf_url=last_value[13]
            show_new_last(last_int8_perf_batch, last_int8_perf_url, last_int8_perf_value, "perf");
            if (workflow == "optimize") {
                // INT8 Bench results
                last_int8_bench_batch=last_value[3]
                last_int8_bench_value=last_value[4]
                last_int8_bench_url=last_value[14]
                show_new_last(last_int8_bench_batch, last_int8_bench_url, last_int8_bench_value, "bench");
            }
            // Show last INT8 Accuracy results
            last_int8_acc_batch=last_value[5]
            last_int8_acc_value=last_value[6]
            last_int8_acc_url=last_value[15]
            show_new_last(last_int8_acc_batch, last_int8_acc_url, last_int8_acc_value, "acc");

            // Show last FP32 Performance results
            last_fp32_perf_batch=last_value[7]
            last_fp32_perf_value=last_value[8]
            last_fp32_perf_url=last_value[16]
            show_new_last(last_fp32_perf_batch, last_fp32_perf_url, last_fp32_perf_value, "perf");
            if (workflow == "optimize") {
                // FP32 Bench results
                last_fp32_bench_batch=last_value[9]
                last_fp32_bench_value=last_value[10]
                last_fp32_bench_url=last_value[17]
                show_new_last(last_fp32_bench_batch, last_fp32_bench_url, last_fp32_bench_value, "bench");
            }
            // Show last FP32 Accuracy results
            last_fp32_acc_batch=last_value[11]
            last_fp32_acc_value=last_value[12]
            last_fp32_acc_url=last_value[18]
            show_new_last(last_fp32_acc_batch, last_fp32_acc_url, last_fp32_acc_value, "acc");

            if (workflow == "deploy") {
                // Show last BF16 Performance results
                last_bf16_perf_batch=last_value[19]
                last_bf16_perf_value=last_value[20]
                last_bf16_perf_url=last_value[21]
                show_new_last(last_bf16_perf_batch, last_bf16_perf_url, last_bf16_perf_value, "perf");

                // Show last BF16 Accuracy results
                last_bf16_acc_batch=last_value[22]
                last_bf16_acc_value=last_value[23]
                last_bf16_acc_url=last_value[24]
                show_new_last(last_bf16_acc_batch, last_bf16_acc_url, last_bf16_acc_value, "acc");

                last_fp8_perf_batch=last_value[37]
                last_fp8_perf_value=last_value[38]
                last_fp8_perf_url=last_value[39]
                show_new_last(last_fp8_perf_batch, last_fp8_perf_url, last_fp8_perf_value, "perf");

                // Show last fp8 Accuracy results
                last_fp8_acc_batch=last_value[40]
                last_fp8_acc_value=last_value[41]
                last_fp8_acc_url=last_value[42]
                show_new_last(last_fp8_acc_batch, last_fp8_acc_url, last_fp8_acc_value, "acc");

                // Show last dynamic int8 Performance results
                last_dint8_perf_batch=last_value[19]
                last_dint8_perf_value=last_value[20]
                last_dint8_perf_url=last_value[21]
                show_new_last(last_dint8_perf_batch, last_dint8_perf_url, last_dint8_perf_value, "perf");
                
                // Show last dynamic int8 Accuracy results
                last_dint8_acc_batch=last_value[22]
                last_dint8_acc_value=last_value[23]
                last_dint8_acc_url=last_value[24]
                show_new_last(last_dint8_acc_batch, last_dint8_acc_url, last_dint8_acc_value, "acc");
            }

            // current vs last
            printf("</tr>\n<tr><td>New/Last</td><td colspan=2 class=\"col-cell3\"></td>");

            // Compare INT8 Performance results
            if (mode == "performance") {
                compare_result(int8_perf_value, last_int8_perf_value,"perf");
            } else {
                compare_result(int8_perf_value, last_int8_perf_value,"latency");
            }
            if (workflow == "optimize") {
                compare_result(int8_bench_value, last_int8_bench_value,"bench");
            }
            // Compare INT8 Accuracy results
            compare_result(int8_acc_value, last_int8_acc_value, "acc");

            // Compare FP32 Performance results
            if (mode == "performance") {
                compare_result(fp32_perf_value, last_fp32_perf_value, "perf");
            } else {
                compare_result(fp32_perf_value, last_fp32_perf_value, "latency");
            }
            if (workflow == "optimize") {
                compare_result(fp32_bench_value, last_fp32_bench_value, "bench")
            }
            // Compare FP32 Performance results
            compare_result(fp32_acc_value, last_fp32_acc_value, "acc");

            if (workflow == "deploy") {
                // Compare BF16 Performance results
                if (mode == "performance") {
                    compare_result(bf16_perf_value, last_bf16_perf_value, "perf")
                } else {
                    compare_result(bf16_perf_value, last_bf16_perf_value, "latency")
                }
                // Compare BF16 Performance results
                compare_result(bf16_acc_value, last_bf16_acc_value, "acc");

                if (mode == "performance") {
                    compare_result(fp8_perf_value, last_fp8_perf_value, "perf")
                } else {
                    compare_result(fp8_perf_value, last_fp8_perf_value, "latency")
                }
                // Compare fp8 Performance results
                compare_result(fp8_acc_value, last_fp8_acc_value, "acc");
                
                // Compare dynamic int8 Performance results
                if (mode == "performance") {
                    compare_result(dint8_perf_value, last_dint8_perf_value, "perf")
                } else {
                    compare_result(dint8_perf_value, last_dint8_perf_value, "latency")
                }
                // Compare dynamic int8 Performance results
                compare_result(dint8_acc_value, last_dint8_acc_value, "acc");
            }
            printf("</tr>\n");
        }
    ' >>${WORKSPACE}/report.html
}

function generate_html_head {

    cat >${WORKSPACE}/report.html <<eof

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
<head>
    <meta http-equiv="content-type" content="text/html; charset=ISO-8859-1">
    <title>Daily Tests - TensorFlow - Jenkins</title>
    <style type="text/css">
        body
        {
            margin: 0;
            padding: 0;
            background: white no-repeat left top;
        }
        #main
        {
            // width: 100%;
            margin: 20px auto 10px auto;
            background: white;
            -moz-border-radius: 8px;
            -webkit-border-radius: 8px;
            padding: 0 30px 30px 30px;
            border: 1px solid #adaa9f;
            -moz-box-shadow: 0 2px 2px #9c9c9c;
            -webkit-box-shadow: 0 2px 2px #9c9c9c;
        }
        .features-table
        {
          width: 100%;
          margin: 0 auto;
          border-collapse: separate;
          border-spacing: 0;
          text-shadow: 0 1px 0 #fff;
          color: #2a2a2a;
          background: #fafafa;
          background-image: -moz-linear-gradient(top, #fff, #eaeaea, #fff); /* Firefox 3.6 */
          background-image: -webkit-gradient(linear,center bottom,center top,from(#fff),color-stop(0.5, #eaeaea),to(#fff));
          font-family: Verdana,Arial,Helvetica
        }
        .features-table th,td
        {
          text-align: center;
          height: 25px;
          line-height: 25px;
          padding: 0 8px;
          border: 1px solid #cdcdcd;
          box-shadow: 0 1px 0 white;
          -moz-box-shadow: 0 1px 0 white;
          -webkit-box-shadow: 0 1px 0 white;
          white-space: nowrap;
        }
        .no-border th
        {
          box-shadow: none;
          -moz-box-shadow: none;
          -webkit-box-shadow: none;
        }
        .col-cell
        {
          text-align: center;
          width: 150px;
          font: normal 1em Verdana, Arial, Helvetica;
        }
        .col-cell3
        {
          background: #efefef;
          background: rgba(144,144,144,0.15);
        }
        .col-cell1, .col-cell2
        {
          background: #B0C4DE;
          background: rgba(176,196,222,0.3);
        }
        .col-cellh
        {
          font: bold 1.3em 'trebuchet MS', 'Lucida Sans', Arial;
          -moz-border-radius-topright: 10px;
          -moz-border-radius-topleft: 10px;
          border-top-right-radius: 10px;
          border-top-left-radius: 10px;
          border-top: 1px solid #eaeaea !important;
        }
        .col-cellf
        {
          font: bold 1.4em Georgia;
          -moz-border-radius-bottomright: 10px;
          -moz-border-radius-bottomleft: 10px;
          border-bottom-right-radius: 10px;
          border-bottom-left-radius: 10px;
          border-bottom: 1px solid #dadada !important;
        }
    </style>
</head>
eof
}

function generate_html_footer {

    cat >>${WORKSPACE}/report.html <<eof
    </div>
</body>
</html>
eof
}

main

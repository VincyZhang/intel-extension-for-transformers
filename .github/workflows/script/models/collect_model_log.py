import argparse
import os
import re

parser = argparse.ArgumentParser(allow_abbrev=False)
parser.add_argument("--framework", type=str, required=True)
parser.add_argument("--fwk_ver", type=str, required=True)
parser.add_argument("--model", type=str, required=True)
parser.add_argument("--logs_dir", type=str, default=".")
parser.add_argument("--output_dir", type=str, default=".")
parser.add_argument("--build_id", type=str, default="0")
parser.add_argument("--stage", type=str, default="collect_log")
parser.add_argument("--gap", type=float, default=0.05)
parser.add_argument("--model_test_type", type=str, default="optimize")
args = parser.parse_args()
print('====== collecting model test log =======')
OS = 'linux'
PLATFORM = 'spr'
URL = '_blank'


def get_model_tuning_dict_results():
    tuning_result_dict = {}

    if os.path.exists(tuning_log):
        print('tuning log found')
        tmp = {'fp32_acc': 0, 'int8_acc': 0, 'tuning_trials': 0}
        with open(tuning_log, "r") as f:
            for line in f:
                parse_tuning_line(line, tmp)
        print(tmp)

        tuning_result_dict = {
            "OS": OS,
            "Platform": PLATFORM,
            "Framework": args.framework,
            "Version": args.fwk_ver,
            "Model": args.model,
            "Strategy": tmp.get('strategy', 'basic'),
            "Tune_time": tmp.get('tune_time'),
        }
        benchmark_accuracy_result_dict = {
            'int8': {
                "OS": OS,
                "Platform": PLATFORM,
                "Framework": args.framework,
                "Version": args.fwk_ver,
                "Model": args.model,
                "Mode": "Inference",
                "Type": "Accuracy",
                "BS": 1,
                "Value": tmp.get('int8_acc'),
                "Url": URL,
            },
            'fp32': {
                "OS": OS,
                "Platform": PLATFORM,
                "Framework": args.framework,
                "Version": args.fwk_ver,
                "Model": args.model,
                "Mode": "Inference",
                "Type": "Accuracy",
                "BS": 1,
                "Value": tmp.get('fp32_acc'),
                "Url": URL,
            }
        }

        return tuning_result_dict, benchmark_accuracy_result_dict
    else:
        return {}, {}


def get_model_benchmark_dict_results():
    benchmark_performance_result_dict = {"int8": {}, "fp32": {}}
    for precision in ["int8", "fp32"]:
        throughput = 0.0
        bs = 1
        for root, dirs, files in os.walk(args.logs_dir):
            for name in files:
                file_name = os.path.join(root, name)
                if ("throughput" in name and precision in name):
                    for line in open(file_name, "r"):
                        result = parse_perf_line(line)
                        if result.get("throughput"):
                            throughput += result.get("throughput")
                        if result.get("batch_size"):
                            bs = result.get("batch_size")

        benchmark_performance_result_dict[precision] = {
            "OS": OS,
            "Platform": PLATFORM,
            "Framework": args.framework,
            "Version": args.fwk_ver,
            "Model": args.model,
            "Mode": "Inference",
            "Type": "Performance",
            "BS": 1,
            "Value": throughput,
            "Url": URL,
        }

    return benchmark_performance_result_dict


def get_refer_data():
    refer_log = os.path.join(f"{args.logs_dir}_refer_log",
                             f"{args.framework}_{args.model}_summary.log")
    result = {}
    if os.path.exists(refer_log):
        with open(refer_log, "r") as f:
            lines = f.readlines()
            keys = lines[0].split(";")
            values = [lines[i].split(";") for i in range(1, len(lines))]
        for value in values:
            precision = value[keys.index("Precision")]
            Type = value[keys.index("Type")]
            result[f"{precision}_{Type}"] = float(value[keys.index(
                "Value")]) if value[keys.index("Value")] != "unknown" else "unknown"
        return result
    else:
        print(f"refer log file: {refer_log} not found")
        return 0


def collect_log():
    results = []
    tuning_infos = []
    print(f"tuning log dir is {tuning_log}")
    # get model tuning results
    if os.path.exists(tuning_log):
        print('tuning log found')
        tmp = {'fp32_acc': 0, 'int8_acc': 0, 'tuning_trials': 0}
        with open(tuning_log, "r") as f:
            for line in f:
                parse_tuning_line(line, tmp)

        # results.append('{};{};{};{};FP32;{};Inference;Accuracy;1;{};{}\n'.format(
        #     OS, PLATFORM, args.framework, args.fwk_ver, args.model, tmp['fp32_acc'], "<url>"))
        # results.append('{};{};{};{};INT8;{};Inference;Accuracy;1;{};{}\n'.format(
        #     OS, PLATFORM, args.framework,  args.fwk_ver, args.model, tmp['int8_acc'], "<url>"))
        tuning_infos.append(';'.join([
            OS, PLATFORM, args.model_test_type, args.framework, args.fwk_ver, args.model,
            tmp.get('strategy', 'basic'),
            str(tmp.get('tune_time', 'na')),
            str(tmp['tuning_trials']), URL, '0' + '\n'
        ]))

    # get model performance results
    for precision in ['int8', 'fp32']:
        throughput = 0.0
        bs = 1
        for root, dirs, files in os.walk(args.logs_dir):
            for name in files:
                file_name = os.path.join(root, name)
                if ("performance" in name and precision in name and args.framework in name):
                    for line in open(file_name, "r"):
                        result = parse_perf_line(line)
                        throughput += result.get("throughput", 0.0)
                        bs = result.get("batch_size", bs)
        results.append(
            f'{OS};{PLATFORM};{args.model_test_type};{args.framework};{args.fwk_ver};{precision.upper()};{args.model};Inference;Performance;{bs};{throughput};{URL}\n'
        )

    # get model accuracy results
    for precision in ['int8', 'fp32']:
        accuracy = 0.0
        bs = 1
        for root, dirs, files in os.walk(args.logs_dir):
            for name in files:
                file_name = os.path.join(root, name)
                if ("accuracy" in name and precision in name and args.framework in name):
                    for line in open(file_name, "r"):
                        result = parse_acc_line(line)
                        accuracy += result.get("accuracy", 0.0)
                        bs = result.get("batch_size", bs)
        results.append(
            f'{OS};{PLATFORM};{args.model_test_type};{args.framework};{args.fwk_ver};{precision.upper()};{args.model};Inference;Accuracy;{bs};{accuracy};{URL}\n'
        )

    # get model benchmark_only results
    for precision in ['int8', 'fp32']:
        benchmark_only = 0.0
        bs = 1
        for root, dirs, files in os.walk(args.logs_dir):
            for name in files:
                file_name = os.path.join(root, name)
                if ("benchmark_only" in name and precision in name and args.framework in name):
                    for line in open(file_name, "r"):
                        result = parse_benchmark_only_line(line)
                        benchmark_only = result.get("throughput", benchmark_only)
                        bs = result.get("batch_size", bs)
        results.append(
            f'{OS};{PLATFORM};{args.model_test_type};{args.framework};{args.fwk_ver};{precision.upper()};{args.model};Inference;Benchmark;{bs};{benchmark_only};{URL}\n'
        )

    # write model logs
    f = open(args.output_dir + '/' + args.framework + '_' + args.model + '_summary.log', "a")
    f.writelines("OS;Platform;Framework;Version;Precision;Model;Mode;Type;BS;Value;Url\n")
    for result in results:
        f.writelines(str(result))
    f2 = open(args.output_dir + '/' + args.framework + '_' + args.model + '_tuning_info.log', "a")
    f2.writelines("OS;Platform;Framework;Version;Model;Strategy;Tune_time\n")
    for tuning_info in tuning_infos:
        f2.writelines(str(tuning_info))


def get_tune_log():
    framework = re.escape(args.framework)
    model = re.escape(args.model)
    pattern = f".*{framework}.*{model}.*tune\.log"
    for root, dirs, files in os.walk(args.logs_dir):
        for file in files:
            if re.search(pattern, file):
                return os.path.join(root, file)
    return ''


def parse_tuning_line(line, tmp):
    tuning_strategy = re.search(r"Tuning strategy:\s+([A-Za-z]+)", line)
    if tuning_strategy and tuning_strategy.group(1):
        tmp['strategy'] = tuning_strategy.group(1)

    baseline_acc = re.search(
        r"FP32 baseline is:\s+\[Accuracy:\s(\d+(\.\d+)?), Duration \(seconds\):\s*(\d+(\.\d+)?)\]",
        line)
    if baseline_acc and baseline_acc.group(1):
        tmp['fp32_acc'] = float(baseline_acc.group(1))

    tuned_acc = re.search(
        r"Best tune result is:\s+\[Accuracy:\s(\d+(\.\d+)?), Duration \(seconds\):\s(\d+(\.\d+)?)\]",
        line)
    if tuned_acc and tuned_acc.group(1):
        tmp['int8_acc'] = float(tuned_acc.group(1))

    tune_trial = re.search(r"Tune \d*\s*result is:", line)
    if tune_trial:
        tmp['tuning_trials'] += 1

    tune_time = re.search(r"Tuning time spend:\s+(\d+(\.\d+)?)s", line)
    if tune_time and tune_time.group(1):
        tmp['tune_time'] = int(tune_time.group(1))

    fp32_model_size = re.search(r"The input model size is:\s+(\d+(\.\d+)?)", line)
    if fp32_model_size and fp32_model_size.group(1):
        tmp['fp32_model_size'] = int(fp32_model_size.group(1))

    int8_model_size = re.search(r"The output model size is:\s+(\d+(\.\d+)?)", line)
    if int8_model_size and int8_model_size.group(1):
        tmp['int8_model_size'] = int(int8_model_size.group(1))

    total_mem_size = re.search(r"Total resident size\D*([0-9]+)", line)
    if total_mem_size and total_mem_size.group(1):
        tmp['total_mem_size'] = float(total_mem_size.group(1))

    max_mem_size = re.search(r"Maximum resident set size\D*([0-9]+)", line)
    if max_mem_size and max_mem_size.group(1):
        tmp['max_mem_size'] = float(max_mem_size.group(1))


def parse_perf_line(line):
    perf_data = {}

    throughput = re.search(r"Throughput:\s+(\d+(\.\d+)?)", line)
    if throughput and throughput.group(1):
        perf_data.update({"throughput": float(throughput.group(1))})
        print(float(throughput.group(1)))

    batch_size = re.search(r"Batch size = ([0-9]+)", line)
    if batch_size and batch_size.group(1):
        perf_data.update({"batch_size": int(batch_size.group(1))})

    return perf_data


def parse_acc_line(line):
    perf_data = {}

    accuracy = re.search(r"Accuracy: (\d+\.\d+)", line)
    if accuracy and accuracy.group(1):
        perf_data.update({"accuracy": float(accuracy.group(1))})
        print(float(accuracy.group(1)))

    batch_size = re.search(r"Batch size = ([0-9]+)", line)
    if batch_size and batch_size.group(1):
        perf_data.update({"batch_size": int(batch_size.group(1))})

    return perf_data


def parse_benchmark_only_line(line):
    perf_data = {}

    if throughput := (line if "Throughput sum [samples/second]" in line else False):
        throughput = re.findall(r'\d+\.\d+', throughput)[-1]
        perf_data.update({"throughput": float(throughput)})

    batch_size = re.search(r"Batch size = ([0-9]+)", line)
    if batch_size and batch_size.group(1):
        perf_data.update({"batch_size": int(batch_size.group(1))})

    return perf_data


def check_status(precision, precision_upper, check_accuracy=False):
    performance_result = get_model_benchmark_dict_results()
    current_performance = performance_result.get(precision).get("Value")
    refer_performance = refer.get(f"{precision_upper}_Performance")
    print(
        f"current_performance_data = {current_performance:.3f}, refer_performance_data = {refer_performance:.3f}"
    )
    assert (refer_performance - current_performance) / refer_performance <= args.gap

    if check_accuracy:
        _, accuracy_result = get_model_tuning_dict_results()
        current_accuracy = accuracy_result.get(precision).get("Value")
        refer_accuracy = refer.get(f"{precision_upper}_Accuracy")
        print(
            f"current_accuracy_data = {current_accuracy:.3f}, refer_accuarcy_data = {refer_accuracy:.3f}"
        )
        assert abs(current_accuracy - refer_accuracy) <= 0.001


if __name__ == '__main__':
    tuning_log = get_tune_log()
    refer = get_refer_data()

    if args.stage == "collect_log":
        collect_log()
    elif args.stage == "int8_benchmark" and refer:
        check_status("int8", "INT8")
    elif args.stage == "fp32_benchmark" and refer:
        check_status("fp32", "FP32")
    elif not refer:
        print("skip check status")
    else:
        raise ValueError(f"{args.stage} does not exist")

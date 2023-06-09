#!/bin/bash

set -x
CUDA_VISIBLE_DEVICES=4 python \
    examples/huggingface/pytorch/language-modeling/pruning/run_clm_no_trainer.py \
    --model_name_or_path bigscience/bloom-3b \
    --calibration_dataset_name NeelNanda/pile-10k \
    --evaluation_dataset_name lambada \
    --per_device_train_batch_size 2 \
    --per_device_eval_batch_size 16 \
    --max_pruning_steps 1002 \
    --weight_decay  0 \
    --block_size 512 \
    --max_length 512 \
    --do_prune \
    --auto_slim \
    --output_dir ./sparse_model \
    --target_sparsity 0.1 \
    --pruning_pattern channelx1 \
    --pruning_frequency 200
    
    
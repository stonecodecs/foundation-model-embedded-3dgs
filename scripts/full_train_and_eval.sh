#!/bin/bash

# Activate conda environment
source ../anaconda3/bin/activate
conda activate fmgs  # Replace 'fmgs' with your actual environment name

# Command line arguments to select specific scenes or run all if none are given
export DATA_PATH="./data/tidy_lerf/fmgs_postprocessed_lerfdata_trainedweights"

SCENES=("bouquet" "figurines" "ramen" "teatime" "waldo_kitchen")

if [ -z "$1" ]; then
    SELECTED_SCENES=("${SCENES[@]}")
else
    SELECTED_SCENES=()
    for ARG in "$@"; do
        if [[ " ${SCENES[@]} " =~ " ${ARG} " ]]; then
            SELECTED_SCENES+=("$ARG")
        else
            echo "Warning: Scene '$ARG' is not in the predefined list and will be ignored."
        fi
    done
    if [ ${#SELECTED_SCENES[@]} -eq 0 ]; then
        echo "No valid scenes selected. Exiting."
        exit 1
    fi
fi

echo "Running for selected scenes (${SELECTED_SCENES[@]})"

# Function to start GPU memory logging
start_gpu_logging() {
    local scene=$1
    mkdir -p ${scene}_output
    while true; do
        echo "$(date '+%Y-%m-%d %H:%M:%S')" >> ${scene}_output/gpu_memory_${scene}.log
        nvidia-smi --query-gpu=memory.used --format=csv >> ${scene}_output/gpu_memory_${scene}.log
        sleep 120
    done
}

# iterate over all selected scenes
for SCENE in "${SELECTED_SCENES[@]}"; do
    echo -e "-----------------------------------\n"
    echo -e "$SCENE\n"
    echo -e "-----------------------------------\n"
    
    # Start GPU memory logging in background
    start_gpu_logging $SCENE &
    LOGGER_PID=$!
    
    echo -e "Constructing Gaussians for $SCENE...\n"
    python train.py -s "$DATA_PATH/$SCENE/$SCENE" --model_path ${SCENE}_output --test_iterations 7000 30000 --save_iterations 7000 30000 --iterations 30000 --checkpoint_iterations 7000 30000 --port 6009
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Gaussian construction completed for $SCENE; now training..." >> ${SCENE}_output/gpu_memory_${SCENE}.log
    echo -e "Training for $SCENE...\n"
    python train.py -s $DATA_PATH/$SCENE/$SCENE --model_path ${SCENE}_output  --opt_vlrenderfeat_from 30000 --test_iterations 32000 32500  --save_iterations 32000 32500 --iterations 32500  --checkpoint_iterations 32000 32500 --start_checkpoint ${SCENE}_output/chkpnt30000.pth --fmap_resolution -1 --lambda_clip 0.2  --fmap_lr 0.005  --fmap_render_radiithre 2  --port 6009
    echo -e "Finished training for $SCENE.\n"
    echo -e "Rendering + eval for $SCENE...\n"
    python ./render_lerf_relavancy_eval.py -s $DATA_PATH/$SCENE/$SCENE -m ${SCENE}_output/ --dataformat colmap --eval_keyframe_path_filename $DATA_PATH/Localization_eval_puremycolmap/${SCENE}/keyframes_reversed_transform2colmap.json --iteration 32500
    mkdir -p /workspace/volume/fmgs_outputs
    
    sleep 5
    kill $LOGGER_PID # end GPU logging for this scene
    sleep 1 
    cp -r ${SCENE}_output/ /workspace/volume/fmgs_outputs
    sleep 1
    echo -e "Completed $SCENE."
done

echo "All training sequences completed!"
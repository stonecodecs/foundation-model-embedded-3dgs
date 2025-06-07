#!/bin/bash
# generates VIDEO sequence with relevancy maps based on a trained model

# Activate conda environment
source ../anaconda3/bin/activate
conda activate fmgs  # Replace 'fmgs' with your actual environment name

# Command line arguments to select specific scenes or run all if none are given
export DATA_PATH="./data/tidy_lerf/fmgs_postprocessed_lerfdata_trainedweights"
export MODEL_DIR_PATH="/workspace/volume/fmgs_outputs/ours"

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

echo "Generating video for selected scenes (${SELECTED_SCENES[@]})"

# NOTE: models must be consistent with their corresponding architectures
# once for all of our outputs
for SCENE in "${SELECTED_SCENES[@]}"; do
    echo -e "-----------------------------------\n"
    echo -e "$SCENE\n"
    echo -e "-----------------------------------\n"
    
    echo -e "Generating video for $SCENE...\n"
    python ./render_lerf_relavancy_eval.py -s $DATA_PATH/$SCENE/$SCENE -m $MODEL_DIR_PATH/${SCENE}_output --dataformat colmap --eval_keyframe_path_filename $DATA_PATH/Localization_eval_puremycolmap/${SCENE}/keyframes_reversed_transform2colmap.json --iteration 32500 --skip_test --runon_train
    echo -e "Completed $SCENE."
done

# another for the controls
# control
export MODEL_DIR_PATH="/workspace/volume/fmgs_outputs/control"
for SCENE in "${SELECTED_SCENES[@]}"; do
    echo -e "-----------------------------------\n"
    echo -e "$SCENE\n"
    echo -e "-----------------------------------\n"
    
    echo -e "Generating video for $SCENE...\n"
    python ./render_lerf_relavancy_eval.py -s $DATA_PATH/$SCENE/$SCENE -m $MODEL_DIR_PATH/${SCENE}_output --dataformat colmap --eval_keyframe_path_filename $DATA_PATH/Localization_eval_puremycolmap/${SCENE}/keyframes_reversed_transform2colmap.json --iteration 32500 --skip_test --runon_train
    echo -e "Completed $SCENE."
done


echo "All training sequences completed!"
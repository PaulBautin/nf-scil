process TRACKING_LOCALTRACKING {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_1.6.0.sif':
        'scilus/scilus:1.6.0' }"

    input:
    tuple val(meta), path(wm), path(fodf), path(fa)

    output:
    tuple val(meta), path("*__local_tracking.trk"), emit: trk
    tuple val(meta), path("*__local_tracking_config.json"), emit: config
    tuple val(meta), path("*__local_seeding_mask.nii.gz"), emit: seedmask
    tuple val(meta), path("*__local_tracking_mask.nii.gz"), emit: trackmask
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    def local_fa_tracking_mask_threshold = task.ext.local_fa_tracking_mask_threshold ? task.ext.local_fa_tracking_mask_threshold : ""
    def local_fa_seeding_mask_threshold = task.ext.local_fa_seeding_mask_threshold ? task.ext.local_fa_seeding_mask_threshold : ""
    def local_tracking_mask = task.ext.local_tracking_mask_type ? "${task.ext.local_tracking_mask_type}" : ""
    def local_seeding_mask = task.ext.local_seeding_mask_type ? "${task.ext.local_seeding_mask_type}" : ""

    def local_step = task.ext.local_step ? "--step " + task.ext.local_step : ""
    def local_random_seed = task.ext.local_random_seed ? "--seed " + task.ext.local_random_seed : ""
    def local_seeding = task.ext.local_seeding ? "--" + task.ext.local_seeding : ""
    def local_nbr_seeds = task.ext.local_nbr_seeds ? "" + task.ext.local_nbr_seeds : ""
    def local_min_len = task.ext.local_min_len ? "--min_length " + task.ext.local_min_len : ""
    def local_max_len = task.ext.local_max_len ? "--max_length " + task.ext.local_max_len : ""
    def local_theta = task.ext.local_theta ? "--theta "  + task.ext.local_theta : ""
    def local_sfthres = task.ext.local_sfthres ? "--sfthres "  + task.ext.local_sfthres : ""
    def local_algo = task.ext.local_algo ? "--algo " + task.ext.local_algo: ""
    def compress = task.ext.local_compress_streamlines ? "--compress " + task.ext.local_compress_value : ""
    def basis = task.ext.basis ? "--sh_basis " + task.ext.basis : ""

    """
    export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1
    export OMP_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1

    if [ "${local_tracking_mask}" == "wm" ]; then
        scil_image_math.py convert $wm ${prefix}__local_tracking_mask.nii.gz \
            --data_type uint8

    elif [ "${local_tracking_mask}" == "fa" ]; then
        mrcalc $fa $local_fa_tracking_mask_threshold -ge ${prefix}__local_tracking_mask.nii.gz\
            --datatype uint8
    fi

    if [ "${local_seeding_mask}" == "wm" ]; then
        scil_image_math.py convert $wm ${prefix}__local_seeding_mask.nii.gz \
            --data_type uint8

    elif [ "${local_seeding_mask}" == "fa" ]; then
        mrcalc $fa $local_fa_seeding_mask_threshold -ge ${prefix}__local_seeding_mask.nii.gz\
            -datatype uint8
    fi

    scil_compute_local_tracking.py $fodf ${prefix}__local_seeding_mask.nii.gz ${prefix}__local_tracking_mask.nii.gz tmp.trk\
            $local_algo $local_seeding $local_nbr_seeds\
            $local_random_seed $local_step $local_theta\
            $local_sfthres $local_min_len\
            $local_max_len $compress $basis

    scil_remove_invalid_streamlines.py tmp.trk\
            ${prefix}__local_tracking.trk\
            --remove_single_point

    cat <<-TRACKING_INFO > ${prefix}__local_tracking_config.json
    {"algorithm": "${task.ext.local_algo}",
    "fa_tracking_threshold": $task.ext.local_fa_tracking_mask_threshold,
    "fa_seeding_threshlod": $task.ext.local_fa_seeding_mask_threshold,
    "seeding_type": "${task.ext.local_seeding}",
    "tracking_mask": "${task.ext.local_tracking_mask_type}",
    "nb_seed": $task.ext.local_nbr_seeds,
    "seeding_mask": "${task.ext.local_seeding_mask_type}",
    "random_seed": $task.ext.local_random_seed,
    "is_compress": "${task.ext.local_compress_streamlines}",
    "compress_value": $task.ext.local_compress_value,
    "step": $task.ext.local_step,
    "theta": $task.ext.local_theta,
    "sfthres": $task.ext.local_sfthres,
    "min_len": $task.ext.local_min_len,
    "max_len": $task.ext.local_max_len,
    "sh_basis": "${task.ext.basis}"}
    TRACKING_INFO

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: 1.6.0
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    scil_compute_local_tracking.py -h
    scil_remove_invalid_streamlines.py -h
    scil_image_math -h
    mrcalc -h

    touch ${prefix}__local_tracking.trk
    touch ${prefix}__local_tracking_config.json
    touch ${prefix}__local_seeding_mask.nii.gz
    touch ${prefix}__local_tracking_mask.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: 1.6.0
    END_VERSIONS
    """
}

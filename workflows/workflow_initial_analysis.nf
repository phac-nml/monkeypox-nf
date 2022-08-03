// Modules to include
include {
    runFastQC;
} from '../modules/initial_analysis_modules.nf'

// Workflow for quality metrics and other checks
workflow initial_analysis {
    take:
        ch_paired_fastqs

    main:
        // Add any other pre-analysis checks here
        runFastQC( ch_paired_fastqs )

    //emit:
}

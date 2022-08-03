// Modules to include
include {
    generateHostRemovedFastq;
    runKraken2
} from '../modules/removal_modules.nf'

// Workflow to generate host removed reads and get read quality metrics
workflow host_removal {
    // Taking in the sample, filtered bam
    take:
        ch_filtered_bam

    main:
        generateHostRemovedFastq( ch_filtered_bam )

        if ( params.kraken_db ) {
            runKraken2( generateHostRemovedFastq.out )
            ch_kraken_results = runKraken2.out.report
        } else {
            //Set empty output to be passed to quality steps
            ch_kraken_results = ch_filtered_bam.map { it -> [ it[0], [] ] }
        }
    emit:
    kraken_results = ch_kraken_results
}

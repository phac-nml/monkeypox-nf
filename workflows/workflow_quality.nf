// Modules to include
include {
    assessSimpleQuality;
    runNextclade;
    concatQuality
} from '../modules/quality_modules.nf'

// Workflow for quality metrics and other checks
workflow assess_quality {
    take:
        ch_consensus_fasta
        ch_filtered_bam
        ch_composite_bam
        ch_kraken_results

    main:
        // Join fasta with bam and get some info
        ch_qual = ch_consensus_fasta
                    .join( ch_filtered_bam, by:0 )
                    .join( ch_composite_bam, by:0 )
                    .join( ch_kraken_results, by:0 )
        assessSimpleQuality( ch_qual )

        // Nextclade with fastas
        ch_fasta_only = ch_consensus_fasta.multiMap { it ->
                            names: it[0]
                            files: it[1]
                        }
        runNextclade( ch_fasta_only.files.collect() )

        // Singular CSV output
        concatQuality( assessSimpleQuality.out.collect(), runNextclade.out )

    //emit:
}

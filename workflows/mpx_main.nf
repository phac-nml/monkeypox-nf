// Modules to Include
include {
    generateSamplesheet;
    generateCompositeReference;
    generateCompositeIndex;
    grabCompositeIndex;
    compositeMapping;
    filterBam as filterBam0;
    filterBam as filterBam30;
    ivarConsensus;
    } from '../modules/main_modules.nf'

// Workflows to Include
include { initial_analysis } from './workflow_initial_analysis.nf'
include { host_removal }   from './workflow_removal.nf'
include { assess_quality } from './workflow_quality.nf'

workflow mpx_main {
    main:
        // Setup Mandatory File Channels
        ch_human_ref    = Channel.fromPath( params.human_ref )
        ch_mpx_ref      = Channel.fromPath( params.mpx_ref )

        // Version tracking - In Progress
        ch_versions     = Channel.empty()

        // Run Processes Start \\
        //#####################\\
        // Setup Composite Ref and Index
        generateCompositeReference( ch_human_ref, ch_mpx_ref )
        ch_comp_ref     = generateCompositeReference.out

        // Skip generation of composite BWA index if one is given 
        if ( params.composite_bwa_index_dir ) {
            grabCompositeIndex( Channel.fromPath( params.composite_bwa_index_dir ), ch_comp_ref )
            ch_comp_idx = grabCompositeIndex.out.collect()
        } else {
            generateCompositeIndex( ch_comp_ref )
            ch_comp_idx = generateCompositeIndex.out.collect()
        }

        // Setup Fastq files
        generateSamplesheet( Channel.fromPath( params.directory, checkIfExists: true) )
            .splitCsv(header: true)
            .map { row -> tuple(row.sample, file(row.read1), file(row.read2), row.gzipped) }
            .set { ch_paired_fastqs }

        // Run initial analysis workflow on fastq files //
        initial_analysis( ch_paired_fastqs )

        // Mapping and Filtering based on wanted ID
        compositeMapping(
            ch_paired_fastqs
                .combine( ch_comp_ref ),
            ch_comp_idx
        )

        // Filter the bam file for mapping quality of both 0 and 30 due to needing a lower map qual to get the termini
        //  The 30 map qual can be used to compare sites - requested by Ana to have both
        filterBam0( compositeMapping.out.sortedbam, 0 )
        filterBam30( compositeMapping.out.sortedbam, 30 )

        // Workflow for host removal, its only one module at the moment //
        host_removal( filterBam0.out.filteredbam )

        // Generate Consensus Sequence
        ivarConsensus( filterBam0.out.filteredbam )

        // Quality Workflow //
        assess_quality( ivarConsensus.out, filterBam0.out.filteredbam, compositeMapping.out.sortedbam, host_removal.out.kraken_results )
}

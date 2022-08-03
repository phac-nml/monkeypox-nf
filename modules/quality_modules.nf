process assessSimpleQuality {
    publishDir "${params.outdir}/${sample}", pattern: "${sample}_quality.csv", mode: "copy"
    tag { sample }

    input:
    tuple val(sample), path(fasta), path(filteredbam), path(compositebam), path(compositebambai), path(krakenreport)

    output:
    path ("${sample}_quality.csv")

    // Script to put all wanted sample values together
    script:
    // If running kraken2, setup to calculate % viral
    if ( params.kraken_db ) {
        checkKraken     = true
        krakenHeader    = ",percent_viral_reads"
    } else {
        checkKraken     = false
        krakenHeader    = ""
    }
    """
    # For kraken2 if it is available/input
    if $checkKraken; then
        KRAKEN_IDS=`{ grep -P "\\s+${params.kraken_viral_id}\\s+" $krakenreport | cut -d\$'\t' -f 2 || :; }`
        ALL_READS=`samtools view -c $compositebam`
        VIRAL_PERCENT=,`awk -v id_count="\$KRAKEN_IDS" -v total_reads="\$ALL_READS" 'BEGIN {if (id_count=="") {print 0} else {print (id_count*2)/total_reads * 100}}'`
    else
        VIRAL_PERCENT=""
    fi

    # Header
    printf "sample,num_reads_mapped,mean_sequencing_depth,median_sequencing_depth,num_consensus_n,genome_completeness${krakenHeader}\n" > ${sample}_quality.csv

    # Stats we want
    NUM_READS=`samtools view -F 0x04 -c $filteredbam`
    AVG_PLUS_MEDIAN_COV=`samtools depth -a $filteredbam | \
        sort -n -k 3 | \
        awk '{ OFS = "," } {dep_a[i++]=\$3;count++;sum+=\$3} END {if (count=='0') {print "0,0"} else print sum/count,dep_a[int(i/2)]}'`
    N_COUNT_PLUS_PROP=`seqtk comp $fasta | awk '{ OFS = "," }{ x=\$3+\$4+\$5+\$6;len=\$2; if (len=='0') {print len-x,len} else print len-x,1-((len-x)/len) }'`

    # Create file
    printf "${sample},\$NUM_READS,\$AVG_PLUS_MEDIAN_COV,\$N_COUNT_PLUS_PROP\$VIRAL_PERCENT\n" >> ${sample}_quality.csv
    """
}
process runNextclade {
    // Running nextclade 2

    input:
    path (fastas)

    output:
    path ("nc_all_data.csv")

    script:
    """
    cat *.fa > all.fasta
    nextclade dataset get --name hMPXV --output-dir dataset
    nextclade run -D dataset/ -p ${params.pcr_csv} -t nextclade.tsv all.fasta

    cat nextclade.tsv | sed -e '1s|\\.|_|g' -e '1s|\\t|\\tnc_|g' -e 's|,|;|g' -e 's|\\t|,|g' > nc_all_data.csv
    """
}
process concatQuality {
    publishDir "${params.outdir}/", pattern: "overall_sample_quality.csv", mode: "copy"

    input:
    path(csvs)
    path(nextclade_csv)

    output:
    path ("overall_sample_quality.csv")

    script:
    """
    awk '(NR == 1) || (FNR > 1)' *quality.csv > simple_sample_quality.csv
    csvtk join -f 'sample;seqName' simple_sample_quality.csv $nextclade_csv > overall_sample_quality.csv
    """
}

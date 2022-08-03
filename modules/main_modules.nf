process generateSamplesheet {
    publishDir "${params.outdir}/", pattern: "samplesheet.csv", mode: "copy"
    tag { directory }

    input:
    path(directory)

    output:
    path("samplesheet.csv")

    script:
    """
    create_illumina_samplesheet.py -d $directory
    """
}
process generateCompositeReference {

    input:
    path(human_ref)
    path(mpx_ref)

    output:
    path("composite_ref.fa")

    script:
    """
    cat $human_ref $mpx_ref > composite_ref.fa
    """
}
process generateCompositeIndex {
    // Push this out so that it can be saved somewhere allowing the user to only need to run this once
    publishDir "${params.outdir}/humanBWAIndex", pattern: "${composite_ref}.*", mode: "symlink"

    input:
    path(composite_ref)

    output:
    path("${composite_ref}.*")

    script:
    """
    bwa index -a bwtsw $composite_ref
    """
}
process grabCompositeIndex {
    // Just grab and set index files - probably a better way to set this up but need it working now

    input:
    path(index_dir)
    path(composite_ref)

    output:
    path("${composite_ref}.*")

    script:
    """
    ln -s $index_dir/*.* .

    # Check for correct MPXV ID in the index
    if \$(grep -q '${params.mpx_ref_id}' ${composite_ref}.ann); then
        :
    else
        printf "ERROR: Given MPX ref ID: '${params.mpx_ref_id}' not found in the specified composite reference index '${composite_ref}.ann'\n"
        exit 1
    fi
    """
}
process compositeMapping {
    publishDir "${params.outdir}/${sample}", pattern: "${sample}.composite.mapped.sorted.bam*", mode: "copy"
    tag { sample }

    label 'mediumProcess'

    input:
    tuple val(sample), path(read1), path(read2), val(gzipped), path(composite_ref)
    path composite_ref_idx

    output:
    tuple val(sample), path("${sample}.composite.mapped.sorted.bam"), path("${sample}.composite.mapped.sorted.bam.bai"), emit: sortedbam

    script:
    processThreads = task.cpus * 2
    """
    bwa mem -t $processThreads -T 30 $composite_ref $read1 $read2 | samtools sort --threads ${task.cpus} -o ${sample}.composite.mapped.sorted.bam
    samtools index ${sample}.composite.mapped.sorted.bam
    """
}
process filterBam {
    publishDir "${params.outdir}/${sample}", pattern: "${sample}.MPXVfiltered-qual${qual}.bam", mode: "copy"
    publishDir "${params.outdir}/${sample}", pattern: "${sample}.MPXVfiltered-qual${qual}.flagstats.txt", mode: "copy"
    tag { sample }

    input:
    tuple val(sample), path(bam), path(bambai)
    val qual

    output:
    tuple val(sample), path("${sample}.MPXVfiltered-qual${qual}.bam"), emit: filteredbam
    path "${sample}.MPXVfiltered-qual${qual}.flagstats.txt", emit: flagstats

    script:
    """
    samtools view -b $bam '${params.mpx_ref_id}' -q $qual > ${sample}.MPXVfiltered-qual${qual}.bam
    samtools flagstats ${sample}.MPXVfiltered-qual${qual}.bam > ${sample}.MPXVfiltered-qual${qual}.flagstats.txt
    """
}
process ivarConsensus {
    publishDir "${params.outdir}/${sample}", pattern: "${sample}.consensus.fa", mode: "copy"
    publishDir "${params.outdir}/all_consensus", pattern: "${sample}.consensus.fa", mode: "copy"
    tag { sample }

    input:
    tuple val(sample), path(bam)

    output:
    tuple val(sample), path("${sample}.consensus.fa")

    script:
    """
    samtools mpileup -Q 20 -a $bam | ivar consensus -q 20 -t 0.7 -m 10 -p ${sample}.consensus

    # Fix Header - If IVAR params changed adjust accordingly
    sed -i -e '1s|Consensus_||' -e '1s|.consensus_threshold_0.7_quality_20||' ${sample}.consensus.fa
    """
}

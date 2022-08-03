process generateHostRemovedFastq {
    publishDir "${params.outdir}/${sample}", pattern: "${sample}*.fastq", mode: "copy"
    tag { sample }

    input:
    tuple val(sample), path(ch_filtered_bam)

    output:
    tuple val(sample), path("${sample}_dehosted_R1.fastq"), path("${sample}_dehosted_R2.fastq"), val(false)

    script:
    """
    samtools collate -u -O $ch_filtered_bam | \
        samtools fastq -1 ${sample}_dehosted_R1.fastq -2 ${sample}_dehosted_R2.fastq -0 /dev/null -s /dev/null -n
    """
}
process runKraken2 {
    publishDir "${params.outdir}/${sample}", pattern: "${sample}*", mode: "copy"
    tag { sample }

    label 'largeProcess'

    input:
    tuple val(sample), path(read1), path(read2), val(gzipped)

    output:
    path("${sample}*"), emit: all
    tuple val(sample), path("${sample}.kraken2.report"), emit: report

    script:
    """
    kraken2 --threads ${task.cpus} --paired \
        --report ${sample}.kraken2.report \
        --output ${sample}.kraken2.output \
        --db ${params.kraken_db} \
        $read1 $read2
    """
}

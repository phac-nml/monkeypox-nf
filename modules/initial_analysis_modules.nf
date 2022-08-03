process runFastQC {
    publishDir "${params.outdir}/${sample}", pattern: "${sample}*.html", mode: "copy"
    tag { sample }

    input:
    tuple val(sample), path(read1), path(read2), val(gzipped)

    output:
    path "${sample}*.html"

    script:
    """
    fastqc -t 2 $read1 $read2
    """
}

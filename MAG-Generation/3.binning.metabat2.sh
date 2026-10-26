#binning method 1: MetaBAT2 (bins: ./sample.*.fa)
metabat/jgi_summarize_bam_contig_depths --outputDepth sample.depth sample.sort.bam
metabat/metabat2 -t 32 --inFile contig.ok.fa --abdFile sample.depth  --outFile ./sample

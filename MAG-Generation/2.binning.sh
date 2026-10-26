bwa index contig.ok.fa
samtools faidx contig.ok.fa
bwa mem -k 32 -t 40 -M  contig.ok.fa clean.1.fq.gz clean.2.fq.gz |samtools view -bS -@ 8 -t contig.ok.fa.fai - >sample.bam
samtools sort -@ 8 -m 2G sample.bam sample.sort
samtools index sample.sort.bam
metabat/jgi_summarize_bam_contig_depths --outputDepth sample.depth sample.sort.bam
metabat/metabat2 -t 32 --inFile contig.ok.fa --abdFile sample.depth  --outFile ./sample

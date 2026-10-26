#reads mapping (shared by all three binning methods)
bwa index contig.ok.fa
samtools faidx contig.ok.fa
bwa mem -k 32 -t 40 -M  contig.ok.fa clean.1.fq.gz clean.2.fq.gz |samtools view -bS -@ 8 -t contig.ok.fa.fai - >sample.bam
samtools sort -@ 8 -m 2G sample.bam sample.sort
samtools index sample.sort.bam

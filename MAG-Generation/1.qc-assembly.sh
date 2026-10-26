java -jar -Xms20G -Xmx20G trimmomatic.jar PE -threads 15 -phred33 1.fastq.gz 2.fastq.gz clip.1.fq.gz single.R1.fastq.gz clip.2.fq.gz single.R2.fastq.gz ILLUMINACLIP:adapters.fa:2:30:10 SLIDINGWINDOW:4:15 MINLEN:75

bwa mem -t 40 -M host.fa clip.1.fq.gz clip.2.fq.gz |awk '$3!="*"'  > host.sam
perl remove-host.pl host.sam ID

#NGS assembly
megahit -1 clean.1.fq.gz -2 clean.2.fq.gz --min-contig-len 500 -t 40 -o ./
perl renamefa.pl ./final.contigs.fa contig.ok.fa
perl deal_fa.pl -format 3 contig.ok.fa |perl -e 'while(<>){chomp;@a=split; if($a[1] > 10000){$a[1]=10000;} print "$a[0]\t$a[1]\n";}' >contig.ok.fa.chrlist

#TGS assembly
flye --nano-raw ONT-data.fastq.gz --meta -t 80 -o ONT-data 


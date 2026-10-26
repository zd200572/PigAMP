#binning method 2: SemiBin2 (bins: semibin/output_bins/*.fa)
#see https://github.com/BigDataBiology/SemiBin for available --environment values
SemiBin2 single_easy_bin -i contig.ok.fa -b sample.sort.bam -o semibin --environment global

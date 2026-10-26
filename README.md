# PigAMP

A collection of pipeline scripts for **MAG construction** and **antimicrobial peptide (AMP) identification** from pig gut metagenomes.

## Contents

```
PigAMP/
├── MAG-Generation/
│   ├── 1.qc-assembly.sh     # QC + host removal + assembly (NGS: MEGAHIT / TGS: Flye --meta)
│   ├── 2.binning.sh         # read mapping + depth + MetaBAT2 binning
│   ├── remove-host.pl       # remove host reads
│   ├── renamefa.pl          # rename contig headers
│   └── deal_fa.pl           # fasta utility (length stats, etc.)
└── AMP-Identification/
    ├── AMP-Identify.pl      # master script: peptide filtering + per-tool job scripts
    ├── AmPEP-info.pl        # parse AmPEP output
    ├── APIN-info.pl         # parse APIN output
    ├── ampir-info.pl        # parse ampir output
    ├── amplify-info.pl      # parse AMPlify output
    ├── ampscan-info.pl      # parse AMPscanner-v2 output
    ├── info-merge.pl        # merge the five tools with score cutoffs
    ├── work.sh              # demo runner
    └── demo.list            # example input list
```

---

## MAG-Generation

### Complete pipeline (short-read: Illumina)

```bash
# 1) QC + host removal + MEGAHIT assembly
java -jar -Xms20G -Xmx20G trimmomatic.jar PE -threads 15 -phred33 \
    1.fastq.gz 2.fastq.gz \
    clip.1.fq.gz single.R1.fastq.gz clip.2.fq.gz single.R2.fastq.gz \
    ILLUMINACLIP:adapters.fa:2:30:10 SLIDINGWINDOW:4:15 MINLEN:75

bwa mem -t 40 -M host.fa clip.1.fq.gz clip.2.fq.gz | awk '$3!="*"' > host.sam
perl remove-host.pl host.sam ID

megahit -1 clean.1.fq.gz -2 clean.2.fq.gz --min-contig-len 500 -t 40 -o ./
perl renamefa.pl ./final.contigs.fa contig.ok.fa
perl deal_fa.pl -format 3 contig.ok.fa | perl -e 'while(<>){chomp;@a=split; if($a[1] > 10000){$a[1]=10000;} print "$a[0]\t$a[1]\n";}' > contig.ok.fa.chrlist

# 2) Binning with MetaBAT2
bwa index contig.ok.fa
samtools faidx contig.ok.fa
bwa mem -k 32 -t 40 -M contig.ok.fa clean.1.fq.gz clean.2.fq.gz \
  | samtools view -bS -@ 8 -t contig.ok.fa.fai - > sample.bam
samtools sort -@ 8 -m 2G sample.bam sample.sort
samtools index sample.sort.bam
metabat/jgi_summarize_bam_contig_depths --outputDepth sample.depth sample.sort.bam
metabat/metabat2 -t 32 --inFile contig.ok.fa --abdFile sample.depth --outFile ./sample
```

### Optional: ONT assembly (not connected to binning)

The script also contains an ONT assembly step:

```bash
flye --nano-raw ONT-data.fastq.gz --meta -t 80 -o ONT-data
```

**Note:** This step is not connected to the binning pipeline in the original RMM repository. The output `flye/assembly.fasta` is not used by `2.binning.sh`, which expects `contig.ok.fa` (from MEGAHIT). To use ONT assembly for MAG construction, you would need to either:
- Rename `flye/assembly.fasta` to `contig.ok.fa` and run `2.binning.sh`, or
- Combine ONT contigs with MEGAHIT contigs before binning

### Inputs


| File                        | Description                                      |
| --------------------------- | ------------------------------------------------ |
| `1.fastq.gz` / `2.fastq.gz` | Paired-end raw reads                             |
| `adapters.fa`               | Trimmomatic adapter file                         |
| `host.fa`                   | Host reference genome (pig: Sscrofa11.1)         |
| `ONT-data.fastq.gz`         | ONT long reads (Method 2)                        |


### Dependencies

Trimmomatic, BWA, SAMtools, MEGAHIT, Flye, MetaBAT2, Perl.

---

## AMP-Identification

Ensemble identification with five tools: **AmPEP, APIN, ampir, AMPscanner-v2, AMPlify**.

### Usage

```bash
# Input is a two-column, tab-delimited file: sample ID <TAB> protein fasta path
cat demo.list
# ABO_D105_1.Bin102	ABO_D105_1.Bin102.faa
# ABO_D105_1.Bin103	ABO_D105_1.Bin103.faa

perl AMP-Identify.pl -input demo.list -out demo-out
```

`AMP-Identify.pl` will:

1. Filter peptides to **10–50 aa** (strictly greater than 10, strictly less than 50), stripping a trailing `*` and discarding sequences containing `X`;
2. Generate `shell/S1.<sample>.<tool>.sh` for every sample × tool combination;
3. Generate `shell/results.list` and `shell/S2.merge.sh` (threshold-based merge).

Then run the generated scripts in order:

```bash
bash demo-out/shell/S1.ABO_D105_1.Bin102.AmPEP.sh     # one tool, one sample
# ... the remaining S1.*.sh scripts
bash demo-out/shell/S2.merge.sh                        # merge with cutoffs
```

### Options

```
-input  <s>  required, two-column file: ID <TAB> protein.faa
-out    <s>  required, output directory
-min    <n>  minimum peptide length, default 10
-max    <n>  maximum peptide length, default 50
-thread <n>  threads per tool, default 40
-AmPEP  <n>  AmPEP score cutoff, default 0.8
-APIN   <n>  APIN score cutoff, default 1
-ampir  <n>  ampir score cutoff, default 0.8
-ampscan<n>  AMPscanner-v2 score cutoff, default 0.5
-ampliy <n>  AMPlify score cutoff, default 0.5
```

### Outputs

```
<out>/<sample>/
├── <sample>.filtered.faa       # candidate peptides, 10-50 aa
├── <sample>.AmPEP.txt          # per-tool results
├── <sample>.APIN.txt
├── <sample>.ampir.txt
├── <sample>.ampscan.txt
├── <sample>.amplify.txt
└── <sample>.AMP.results        # merged hits above the cutoffs
```

Columns of `*.AMP.results`: `ID` / `Peptide` / `Method` / `AMP-score`.

### Dependencies

Each tool needs its own conda environment (AmPEP / APIN / ampir / ascan2\_tf1 / amplify). Edit the paths in `AMP-Identify.pl` to match your installation:


| Location                                        | What to set                                          |
| ----------------------------------------------- | ---------------------------------------------------- |
| `ampep predict -m <model>`                      | AmPEP model path                                     |
| `APIN_HOME`                                     | directory holding `proposed_model.py` and `data/*.fa` |
| `amp-scanner-v2` path and `.h5` model           | AMPscanner-v2                                        |
| `AMPlify` executable                            | AMPlify                                              |


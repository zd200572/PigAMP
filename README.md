# PigAMP

A collection of pipeline scripts for **MAG construction** and **antimicrobial peptide (AMP) identification** from pig gut metagenomes.

## Contents

```
PigAMP/
├── MAG-Generation/
│   ├── 1.qc-assembly.sh          # QC + host removal + MEGAHIT assembly
│   ├── 2.binning.sh              # reads mapping (shared by all binning methods)
│   ├── 3.binning.metabat2.sh     # binning method 1: MetaBAT2
│   ├── 4.binning.sembin2.sh      # binning method 2: SemiBin2
│   ├── 5.binning.vamb.sh         # binning method 3: VAMB
│   ├── remove-host.pl            # remove host reads
│   ├── renamefa.pl               # rename contig headers
│   └── deal_fa.pl                # fasta utility (length stats, etc.)
└── AMP-Identification/
    ├── AMP-Identify.pl           # master script: peptide filtering + per-tool job scripts
    ├── AmPEP-info.pl             # parse AmPEP output
    ├── APIN-info.pl              # parse APIN output
    ├── ampir-info.pl             # parse ampir output
    ├── amplify-info.pl           # parse AMPlify output
    ├── ampscan-info.pl           # parse AMPscanner-v2 output
    ├── info-merge.pl             # merge the five tools with score cutoffs
    ├── work.sh                   # demo runner
    └── demo.list                 # example input list
```

---

## MAG-Generation

### Step 1: QC + host removal + assembly

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
```

### Step 2: reads mapping (shared)

```bash
bwa index contig.ok.fa
samtools faidx contig.ok.fa
bwa mem -k 32 -t 40 -M contig.ok.fa clean.1.fq.gz clean.2.fq.gz \
  | samtools view -bS -@ 8 -t contig.ok.fa.fai - > sample.bam
samtools sort -@ 8 -m 2G sample.bam sample.sort
samtools index sample.sort.bam
```

### Step 3: binning — choose one of three methods

**Method 1: MetaBAT2** (bins: `./sample.*.fa`)

```bash
metabat/jgi_summarize_bam_contig_depths --outputDepth sample.depth sample.sort.bam
metabat/metabat2 -t 32 --inFile contig.ok.fa --abdFile sample.depth --outFile ./sample
```

**Method 2: SemiBin2** (bins: `semibin/output_bins/*.fa`)

```bash
SemiBin2 single_easy_bin -i contig.ok.fa -b sample.sort.bam -o semibin --environment global
```

**Method 3: VAMB 4.1.4** (bins: `vamb/bin.*.fa`)

```bash
VAMB bin contig.ok.fa sample.sort.bam -o vamb
```

### Inputs


| File                        | Description                                      |
| --------------------------- | ------------------------------------------------ |
| `1.fastq.gz` / `2.fastq.gz` | Paired-end raw reads                             |
| `adapters.fa`               | Trimmomatic adapter file                         |
| `host.fa`                   | Host reference genome (pig: Sscrofa11.1)         |


### Dependencies

Trimmomatic, BWA, SAMtools, MEGAHIT, MetaBAT2, SemiBin2, VAMB, Perl.

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


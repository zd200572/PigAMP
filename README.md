# PigAMP

猪肠道微生物组 **MAG 构建** + **抗菌肽（AMP）鉴定** 流程脚本汇总。

脚本原样取自以下两个仓库，未做改动：

| 模块 | 来源 | 取用范围 |
|------|------|----------|
| `MAG-Generation/` | [zd200572/RMM](https://github.com/zd200572/RMM) | `1.MAG-Generation/` 全部脚本（含三种 MAG 构建方式） |
| `AMP-Identification/` | [zd200572/GGM](https://github.com/zd200572/GGM) | `AMP-Identification/` 全部脚本（公司默认 AMP 鉴定流程） |

---

## 目录

```
PigAMP/
├── MAG-Generation/
│   ├── 1.qc-assembly.sh     # 质控 + 去宿主 + 组装（NGS: MEGAHIT / TGS: Flye --meta）
│   ├── 2.binning.sh         # 回贴 + 深度 + MetaBAT2 分箱
│   ├── remove-host.pl       # 去宿主 reads
│   ├── renamefa.pl          # contig 重命名
│   └── deal_fa.pl           # fasta 工具（长度统计等）
└── AMP-Identification/
    ├── AMP-Identify.pl      # 主控：肽段过滤 + 生成各工具运行脚本
    ├── AmPEP-info.pl        # AmPEP 结果解析
    ├── APIN-info.pl         # APIN 结果解析
    ├── ampir-info.pl        # ampir 结果解析
    ├── amplify-info.pl      # AMPlify 结果解析
    ├── ampscan-info.pl      # AMPscanner-v2 结果解析
    ├── info-merge.pl        # 按阈值合并五工具结果
    ├── work.sh              # 演示运行脚本
    └── demo.list            # 输入列表示例
```

---

## MAG-Generation

### 三种 MAG 构建方式

**方式一：短读长（Illumina）**

```bash
# 1) 质控 + 去宿主 + MEGAHIT 组装
java -jar -Xms20G -Xmx20G trimmomatic.jar PE -threads 15 -phred33 \
    1.fastq.gz 2.fastq.gz \
    clip.1.fq.gz single.R1.fastq.gz clip.2.fq.gz single.R2.fastq.gz \
    ILLUMINACLIP:adapters.fa:2:30:10 SLIDINGWINDOW:4:15 MINLEN:75

bwa mem -t 40 -M host.fa clip.1.fq.gz clip.2.fq.gz | awk '$3!="*"' > host.sam
perl remove-host.pl host.sam ID

megahit -1 clean.1.fq.gz -2 clean.2.fq.gz --min-contig-len 500 -t 40 -o ./
perl renamefa.pl ./final.contigs.fa contig.ok.fa
perl deal_fa.pl -format 3 contig.ok.fa | perl -e 'while(<>){chomp;@a=split; if($a[1] > 10000){$a[1]=10000;} print "$a[0]\t$a[1]\n";}' > contig.ok.fa.chrlist

# 2) 分箱
bwa index contig.ok.fa
samtools faidx contig.ok.fa
bwa mem -k 32 -t 40 -M contig.ok.fa clean.1.fq.gz clean.2.fq.gz \
  | samtools view -bS -@ 8 -t contig.ok.fa.fai - > sample.bam
samtools sort -@ 8 -m 2G sample.bam sample.sort
samtools index sample.sort.bam
metabat/jgi_summarize_bam_contig_depths --outputDepth sample.depth sample.sort.bam
metabat/metabat2 -t 32 --inFile contig.ok.fa --abdFile sample.depth --outFile ./sample
```

**方式二：长读长（ONT）**

```bash
flye --nano-raw ONT-data.fastq.gz --meta -t 80 -o ONT-data
# 后续 renamefa.pl / deal_fa.pl / 2.binning.sh 同上
```

**方式三：分箱复用**

三种组装方式产出的 contig 统一命名为 `contig.ok.fa`，之后都套用同一套 `2.binning.sh`。

### 输入要求

| 文件 | 说明 |
|------|------|
| `1.fastq.gz` / `2.fastq.gz` | 双端原始数据 |
| `adapters.fa` | Trimmomatic 接头文件 |
| `host.fa` | 宿主参考基因组（猪：Sscrofa11.1） |
| `ONT-data.fastq.gz` | ONT 长读长数据（方式二） |

### 依赖

Trimmomatic、BWA、SAMtools、MEGAHIT、Flye、MetaBAT2、Perl。

---

## AMP-Identification

五个工具集成鉴定：**AmPEP、APIN、ampir、AMPscanner-v2、AMPlify**。

### 运行

```bash
# 输入为两列制表符文件：样本名 <TAB> 蛋白 fasta 路径
cat demo.list
# ABO_D105_1.Bin102	ABO_D105_1.Bin102.faa
# ABO_D105_1.Bin103	ABO_D105_1.Bin103.faa

perl AMP-Identify.pl -input demo.list -out demo-out
```

`AMP-Identify.pl` 会：

1. 过滤肽段，保留 **10–50 aa**（严格大于 10、小于 50），去掉末尾 `*` 与含 `X` 的序列；
2. 为每个样本 × 每个工具生成 `shell/S1.<sample>.<tool>.sh`；
3. 生成 `shell/results.list` 与 `shell/S2.merge.sh`（按阈值合并）。

之后依次执行生成的脚本：

```bash
bash demo-out/shell/S1.ABO_D105_1.Bin102.AmPEP.sh     # 单工具单样本
# ... 其余 S1.*.sh
bash demo-out/shell/S2.merge.sh                        # 阈值合并
```

### 参数

```
-input  <s>  必需，两列文件：ID <TAB> protein.faa
-out    <s>  必需，输出目录
-min    <n>  最短肽段长度，默认 10
-max    <n>  最长肽段长度，默认 50
-thread <n>  每个工具的线程数，默认 40
-AmPEP  <n>  AmPEP 阈值，默认 0.8
-APIN   <n>  APIN 阈值，默认 1
-ampir  <n>  ampir 阈值，默认 0.8
-ampscan<n>  AMPscanner-v2 阈值，默认 0.5
-ampliy <n>  AMPlify 阈值，默认 0.5
```

### 输出

```
<out>/<sample>/
├── <sample>.filtered.faa       # 10–50 aa 的候选肽段
├── <sample>.AmPEP.txt          # 单工具结果
├── <sample>.APIN.txt
├── <sample>.ampir.txt
├── <sample>.ampscan.txt
├── <sample>.amplify.txt
└── <sample>.AMP.results        # 达阈值的合并结果
```

`*.AMP.results` 列：`ID` / `Peptide` / `Method` / `AMP-score`。

### 依赖

各工具需独立 conda 环境（AmPEP / APIN / ampir / ascan2_tf1 / amplify），路径在 `AMP-Identify.pl` 中按实际安装位置修改：

| 位置 | 变量含义 |
|------|----------|
| `ampep predict -m <model>` | AmPEP 模型路径 |
| `APIN_HOME` | `proposed_model.py` 与 `data/*.fa` 所在目录 |
| `amp-scanner-v2` 路径与 `.h5` 模型 | AMPscanner-v2 |
| `AMPlify` 可执行文件 | AMPlify |

---

## 引用

- MAG 构建：<https://github.com/zd200572/RMM>
- AMP 鉴定：<https://github.com/zd200572/GGM>
- 工具：Trimmomatic、BWA、MEGAHIT、Flye、MetaBAT2、Prodigal、AmPEP、APIN、ampir、AMPscanner-v2、AMPlify

## License

MIT

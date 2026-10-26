use File::Basename;
use Getopt::Long;
use FindBin qw($Bin);

sub usage{
	print STDERR <<USAGE;
	Version 1.0 2025-03-05 by TaoYe
	Include AmPEP, APIN and ampir

	Options 
		-input  <s> : Required (Absolute Dir), Two Columns:
			ID MetaProdigal-5bp.faa
		-out    <s> : Required final results, always exclude AMPlify
		-min    <n> : minimum peptide length, default: 10
		-max    <n> : maximum peptide length, default: 50
		-thread <n> : Thread number, default:40
		-AmPEP  <n> : AmPEP score, default: 0.8
		-APIN   <n> : APIN score, default: 1
		-ampir  <n> : ampri score, default: 0.8
		-ampscan <n> : amp-scanner-v2 score, default: 0.5
		-ampliy <n> : AMPlify score, default: 0.5
USAGE
}

my ($input,$thread,$out,$minlen,$maxlen,$AmPEPscore,$APINscore,$ampirscore,$ampscanscore,$ampliyscore);
GetOptions(
	"input:s"=>\$input,	"thread:n"=>\$thread,
	"min:n"=>\$minlen,	"max:n"=>\$maxlen,
	"AmPEP:n"=>\$AmPEPscore,	"APIN:n"=>\$APINscore,
	"ampir:n"=>\$ampirscore,	"ampscan:n"=>\$ampscanscore,
	"ampliy:n"=>\$ampliyscore,"out:s"=>\$out,
);
$thread||=40;
$minlen||=10;$maxlen||=50;
$AmPEPscore||=0.8; $APINscore||=1;
$ampirscore||=0.8; $ampscanscore||=0.5;$ampliyscore||=0.5;
my $outdir=`pwd`; chomp $outdir;
if(!defined($input)||!defined($out)){
	usage;
	exit;
}

`rm -rf $outdir/shell`;
`mkdir -p $outdir/shell`;

my ($line,@inf);
open IA, "$input" or die "can not open file: $input\n";
open OO, ">$outdir/shell/results.list" or die "not open file: $outdir/shell/results.lis\n";
while($line=<IA>){
	chomp $line;
	@inf=split /\t/,$line;
	print OO "$outdir/$inf[0]\t$outdir/$inf[0]/$inf[0].AmPEP.txt\t$outdir/$inf[0]/$inf[0].ampir.txt\t$outdir/$inf[0]/$inf[0].APIN.txt\t$outdir/$inf[0]/$inf[0].ampscan.txt\t$outdir/$inf[0]/$inf[0].amplify.txt\n";
	`mkdir -p $outdir/$inf[0]`;

	open IB, "$inf[1]" or die "can not open file: $inf[1]\n";
	open OB, ">$outdir/$inf[0]/$inf[0].filtered.faa" or die "can not open file: $outdir/$inf[0]/$inf[0].filtered.faa\n";
	$/=">";<IB>;
	while($line=<IB>){
		chomp $line;
		my @ele=split /\n/,$line;
		my @ele2=split /\s+/,$ele[0];
		my $seq="";
		for(my $i=1;$i<=$#ele;$i++){
			$seq.=$ele[$i];
		}
		$seq=~s/\*$//;
		if(length($seq)>$minlen && length($seq)<$maxlen){
			next if($seq=~/x/i);
			print OB ">$ele2[0]\n$seq\n";
		}
	}
	close IB;
	close OB;
	$/="\n";

	open OA, ">$outdir/shell/S1.$inf[0].AmPEP.sh" or die "can not open: $inf[0].AmPEP.sh\n";
	print OA "cd $outdir/$inf[0]\n";
	print OA "source activate amPEP\n";
	print OA "ampep predict -m /mnt/sdb/zengl/lib/anaconda/envs/amPEP/amPEPpy/pretrained_models/amPEP.model -i $inf[0].filtered.faa -o $inf[0].amPEP-predict.txt --seed 2024 -t $thread\n";
	print OA "perl $Bin/AmPEP-info.pl $inf[0].filtered.faa $inf[0].amPEP-predict.txt $inf[0]\n";
	print OA "rm $inf[0].amPEP-predict.txt\n";
	close OA;

	open OA, ">$outdir/shell/S1.$inf[0].APIN.sh" or die "can not open:$inf[0].APIN.sh\n";
	print OA "cd $outdir/$inf[0]\n";
	print OA "source activate APIN\n";
	print OA "/mnt/sdb/zengl/lib/anaconda/envs/APIN/bin/python3 /mnt/sdb/zengl/lib/anaconda/envs/APIN/APIN/proposed_model.py -test_file $inf[0].filtered.faa -false_train_file /mnt/sdb/zengl/lib/anaconda/envs/APIN/APIN/data/DECOY.tr.fa -true_train_file /mnt/sdb/zengl/lib/anaconda/envs/APIN/APIN/data/AMP.tr.fa -prediction_file $inf[0].APIN-predict.txt\n";
	print OA "perl $Bin/APIN-info.pl $inf[0].filtered.faa $inf[0].APIN-predict.txt $inf[0]\n";
	print OA "rm $inf[0].APIN-predict.txt\n";
	close OA;

	open OA, ">$outdir/shell/S1.$inf[0].ampir.sh" or die "can not open:$inf[0].ampir.sh\n";
	print OA "cd $outdir/$inf[0]\n";
	print OA "source activate ampir\n";
	print OA "/mnt/sdb/zengl/lib/anaconda/envs/ampir/bin/R < ampir.r --no-save\n";
	print OA "perl $Bin/ampir-info.pl $inf[0].filtered.faa $inf[0].ampir-predict.txt $inf[0]\n";
	print OA "rm $inf[0].ampir-predict.txt\n";
	close OA;
	open OA, ">$outdir/$inf[0]/ampir.r" or die "can not open:./$inf[0]/ampir.r\n";
	print OA "library(ampir)\n";
	print OA "my_protein_df \<- read_faa\(\"$inf[0].filtered.faa\"\)\n";
	print OA "my_prediction \<- predict_amps(my_protein_df, model = \"precursor\")\n";
	print OA "write.table(my_prediction,file=\"$inf[0].ampir-predict.txt\",sep=\"\\t\",row.names=F,quote=F)\n";
	close OA;
	
	open OA, ">$outdir/shell/S1.$inf[0].ampscan.sh" or die "can not open:$inf[0].ampscan.sh\n";
        print OA "cd $outdir/$inf[0]\n";
        print OA "source activate ascan2_tf1\n";
        print OA "/mnt/sdb/zengl/lib/anaconda/envs/ascan2_tf1/bin/python /mnt/sdb/zengl/lib/anaconda/envs/ascan2_tf1/amp-scanner-v2/amp_scanner_v2_predict_tf1.py -fasta $inf[0].filtered.faa -model /mnt/sdb/zengl/lib/anaconda/envs/ascan2_tf1/amp-scanner-v2/trained-models/OriginalPaper_081917_FULL_MODEL.h5 -candidates output.fasta -preds $inf[0].ampscan.csv\n";
        print OA "perl $Bin/ampscan-info.pl $inf[0].filtered.faa $inf[0].ampscan.csv $inf[0]\n";
        print OA "rm output.fasta $inf[0].ampscan.csv\n";
        close OA;

	open OA, ">$outdir/shell/S1.$inf[0].amplify.sh" or die "can not open:$inf[0].amplify.sh\n";
        print OA "cd $outdir/$inf[0]\n";
        print OA "source activate amplify\n";
	print OA "rm AMPlify_balanced*.tsv\n";
        print OA "/mnt/sdb/zengl/lib/anaconda/envs/amplify/bin/AMPlify -s $inf[0].filtered.faa\n";
        print OA "perl $Bin/amplify-info.pl $inf[0].filtered.faa `ls AMPlify_balanced_results*.tsv` $inf[0]\n";
        close OA;
}
close IA;
close OO;

open OA, ">$outdir/shell/S2.merge.sh" or die "not open $outdir/shell/S2.merge.sh\n";
print OA "perl $Bin/info-merge.pl $outdir/shell/results.list $AmPEPscore $ampirscore $APINscore $ampscanscore $ampliyscore\n";
close OA;


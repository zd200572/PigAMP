die "perl APIN-info.pl faa predict.txt out\n" if(@ARGV!=3);
my ($line,@inf,%score);

open IN,"output/$ARGV[1]" or die "not open: $ARGV[1]\n";
my $n=0;
while($line=<IN>){
        chomp $line;
	@inf=split /\t/,$line;
	$n++;
	$score{$n}=$line;
}
close IN;

open IN,"$ARGV[0]" or die "not open: $ARGV[0]\n";
open OA,">$ARGV[2].APIN.txt";
print OA "ID\tPeptide\tMethod\tAMP-score\n";
$n=0;
while(my $id=<IN>){
	chomp $id;
	$id=~s/>//;
	$n++;
	my $seq=<IN>;
	chomp $seq;
	print OA "$id\t$seq\tAPIN\t$score{$n}\n";
}
close IN;
close OA;


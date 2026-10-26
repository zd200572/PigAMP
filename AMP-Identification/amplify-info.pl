die "perl amplify-info.pl faa predict.tsv out\n" if(@ARGV!=3);
my ($line,@inf,%score);

open IN,"$ARGV[1]" or die "not open: $ARGV[1]\n";
<IN>;
while($line=<IN>){
        chomp $line;
	@inf=split /\t/,$line;
	$score{$inf[0]}=$inf[4];
}
close IN;

open IN,"$ARGV[0]" or die "not open: $ARGV[0]\n";
open OA,">$ARGV[2].amplify.txt";
print OA "ID\tPeptide\tMethod\tAMP-score\n";
while(my $id=<IN>){
	chomp $id;
	$id=~s/>//;
	my $seq=<IN>;
	chomp $seq;
	print OA "$id\t$seq\tamplify\t$score{$id}\n";
}
close IN;
close OA;


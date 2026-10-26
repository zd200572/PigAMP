die "perl AmPEP-info.pl faa predict.txt out\n" if(@ARGV!=3);
my ($line,@inf,%score);

open IN,"$ARGV[1]" or die "not open: $ARGV[1]\n";
<IN>;
while($line=<IN>){
        chomp $line;
	@inf=split /\t/,$line;
	$score{$inf[3]}=$inf[1];
}
close IN;

open IN,"$ARGV[0]" or die "not open: $ARGV[0]\n";
open OA,">$ARGV[2].AmPEP.txt";
print OA "ID\tPeptide\tMethod\tAMP-score\n";
while(my $id=<IN>){
	chomp $id;
	$id=~s/>//;
	my $seq=<IN>;
	chomp $seq;
	print OA "$id\t$seq\tAmPEP\t$score{$id}\n";
}
close IN;
close OA;


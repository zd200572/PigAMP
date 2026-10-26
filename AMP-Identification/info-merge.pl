die "perl info-merge.pl results.list AmPEPscore ampirscore APINscore ampscanscore ampliyscore\n" if(@ARGV!=6);
my ($line,@inf,%score);

open IN,"$ARGV[0]" or die "not open: $ARGV[0]\n";
while($line=<IN>){
	chomp $line;
	@inf=split /\t/,$line;
	open OA,">$inf[0].AMP.results";
	print OA "ID\tPeptide\tMethod\tAMP-score\n";
	for(my $i=1;$i<=$#inf;$i++){
		open IA,"$inf[$i]" or die "not open $inf[$i]\n";
		<IA>;
		while(my $line2=<IA>){
			chomp $line2;
			my @ele=split /\t/,$line2;
			print OA "$line2\n" if($ele[3]>=$ARGV[$i]);
		}
		close IA;
	}
	close OA;
}
close IN;


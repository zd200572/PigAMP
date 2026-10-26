#!usr/bin/perl -w

use strict;
use warnings;

die "useage : perl $0 <file> <id> <output>\n" unless @ARGV == 3;

open A,$ARGV[0];
my $id = $ARGV[1];
open B,">",$ARGV[2];
my $num = 1;
while(<A>){
	chomp;
	if(/^\>/){
		print B ">$id\__$num\n";
		$num++;
	}else{
		print B "$_\n";
	}
}

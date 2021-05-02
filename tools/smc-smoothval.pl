#!/usr/bin/perl
for my $path (glob("smc-num/*.*.*")) {
    warn $path;
    my %val;
    my %sval;
    my $fh;
    open $fh, $path;
    my $lasttime;
    while (<$fh>) {
	my ($time, $val) = split /  /;
	$lasttime = $time - 30 unless $lasttime;
	for my $t0 ($lasttime + 1 .. $time) {
	    $val{$t0} = $val;
	}
	$lasttime = $time;
    }
    close $fh;
    for my $t1 (keys %val) {
	my $sum0 = 0;
	my $sum1 = 0;
	for my $t0 ($t1 - 29 .. $t1) {
	    next unless exists $val{$t0};
	    $sum0 += 1;
	    $sum1 += $val{$t0};
	}
	$sval{$t1} = $sum1/$sum0;
    }
    $path =~ s/^smc-num/smc-smooth/;
    open $fh, ">$path";
    for my $t1 (sort { $a <=> $b } keys %sval) {
	print $fh "$t1 $sval{$t1}\n";
    }
    print $fh "\n\n$lasttime 0\n";
    close $fh;
}

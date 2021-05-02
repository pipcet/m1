#!/usr/bin/perl

#cd 23e050000.smc
#ls *.*.* | egrep -v '\.payload$' | sed -e 's/ //g' | while read; do touch ~/smc-monitor/smc/$REPLY; done
#perl ~pip/smc-monitor.pl
#while true; do perl ~pip/smc-numerify.pl; perl ~pip/smc-smoothval.pl; perl ~pip/smc-plotval.pl; done

use File::Slurp qw(read_file);
use Time::HiRes;
sleep(1);
mkdir("smc");
while (1) {
    warn time();
    for my $path (glob "smc/*.*.*") {
	my $name = $path;
	$name =~ s/.*\///;
	my ($key, $type, $flags) = split /\./, $name;
	my $value = read_file("/sys/kernel/debug/smc/" . $key);
	chomp($value);
	$value =~ s/SMC KEY.*?\n//g;
	for my $line (split "\n", $value) {
	    next if ($line =~ /^SMC/);
	    my $fh;
	    open $fh, ">>smc/$name";
	    print $fh time() . " $value\n";
	    close $fh;
	}
    }
}

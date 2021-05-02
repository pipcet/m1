#!/usr/bin/perl
for my $path (glob "smc-smooth/*.*.*") {
    warn $path;
    my $outpath = $path;
    $outpath =~ s/^smc-smooth/smc-plot/;
    my $fh;
    open $fh, "|gnuplot" or die;
    print $fh "set xdata time\n";
    print $fh "set timefmt '\%s'\n";
    print $fh "set terminal png size 1600,1200\n";
    print $fh "set output \"$outpath.png\"\n";
    print $fh "plot \"$path\" using (\$1):(\$2) with lines\n";
    close $fh;
}
for my $path (glob "smc-num/*.*.*") {
    warn $path;
    my $outpath = $path;
    $outpath =~ s/^smc-smooth/smc-plot-rough/;
    my $fh;
    open $fh, "|gnuplot" or die;
    print $fh "set xdata time\n";
    print $fh "set timefmt '\%s'\n";
    print $fh "set terminal png size 1600,1200\n";
    print $fh "set output \"$outpath.png\"\n";
    print $fh "plot \"$path\" using (\$1):(\$2) with lines\n";
    close $fh;
}
system("find smc-plot -type f -empty | xargs rm");

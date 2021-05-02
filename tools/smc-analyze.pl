#!/usr/bin/perl
my %seen;
my $name = shift;
my ($key, $type, $flags);
if ($name =~ /^.*\/(....)\.(....?)\.(..)$/) {
    ($key, $type, $flags) = ($1, $2, $3);
}
my $fh;
open $fh, $name;
my $outname = shift;
my $fh3;
open $fh3, ">$outname";
while (<$fh>) {
    if (/^(\d+)  ?(.*?)$/) {
	my ($ts, $bytes) = ($1, $2, $3, $4, $5);
	my $value = $bytes;
	if ($type eq "flt " or $type eq "flt") {
	    $value = unpack("f", pack("CCCC", map { hex } split(" ", $bytes)));
	} elsif ($type eq "si64") {
	    $value = unpack("q", pack("CCCCCCCC", map { hex } split(" ", $bytes)));
	} elsif ($type eq "ui64") {
	    $value = unpack("Q", pack("CCCCCCCC", map { hex } split(" ", $bytes)));
	} elsif ($type eq "si32") {
	    $value = unpack("l", pack("CCCC", map { hex } split(" ", $bytes)));
	} elsif ($type eq "ui32") {
	    $value = unpack("L", pack("CCCC", map { hex } split(" ", $bytes)));
	} elsif ($type eq "si16") {
	    $value = unpack("s", pack("CC", map { hex } split(" ", $bytes)));
	} elsif ($type eq "ui16") {
	    $value = unpack("S", pack("CC", map { hex } split(" ", $bytes)));
	} elsif ($type eq "ioft") {
	    # unknown number(?) format, treat as ui64 scaled by 1/32768
	    $value = unpack("Q", pack("CCCCCCCC", map { hex } split(" ", $bytes)));
	    $value /= 32768;
	}
	$seen{$value}++;
	# print "$ts $value\n";
	print $fh3 "$ts $value\n";
    }
}

print $fh3 "\n\n\n";
print $fh3 time() . " 0\n";

close $fh3;

my $sum0 = 0;
my $sum = 0;
my $sum2 = 0;
for my $value (sort { $a <=> $b } keys %seen) {
    $sum0 += $seen{$value};
    $sum += $seen{$value} * $value;
    $sum2 += $seen{$value} * $value * $value;
}

my $mean = $sum / $sum0;
my $var2 = $sum2 / $sum0 - ($mean * $mean);
my $var = $var2 > 0 ? sqrt($var2) : 0.0;
#warn "$name: n $sum0 $mean v2 $var2\n";

$mean = sprintf("%5.03g", $mean);
$var = ($var > 0 && $mean) ? sprintf("±%2.0f%%", 100 * $var/abs($mean)) : "";
if ($var eq "± 0%") {
    $var = "";
}

warn "| $key.$flags | $type | | | |  $mean$var |\n";
if ($var2) {
    my $fh2;
    open $fh2, "|gnuplot";
    print $fh2 "set xdata time\n";
    print $fh2 "set timefmt '\%s'\n";
    print $fh2 "set terminal png size 1600,1200\n";
    print $fh2 "set output \"$outname.png\"\n";
    print $fh2 "plot \"$outname\" using (\$1):(\$2) with lines\n";
    close $fh2;
}

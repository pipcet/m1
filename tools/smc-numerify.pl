for my $path (glob("smc/*.*.*")) {
    my $name = $path;
    warn $name;
    $name =~ s/.*\///;
    my ($key, $type, $flags) = split(/\./, $name);
    my $fh;
    open $fh, "$path";
    open $outfh, ">smc-num/$name";
    while (<$fh>) {
	chomp;
	/^([^ ]*) (.*)$/;
	my ($time, $value) = ($1, $2);
	my $bytes = pack("C*", map { hex } split(" ", $value));
	my $numval = undef;
	if ($type eq "flt " or $type eq "flt") {
	    $numval = unpack("f", $bytes);
	} elsif ($type eq "si64") {
	    $numval = unpack("q", $bytes);
	} elsif ($type eq "ui64") {
	    $numval = unpack("Q", $bytes);
	} elsif ($type eq "si32") {
	    $numval = unpack("l", $bytes);
	} elsif ($type eq "ui32") {
	    $numval = unpack("L", $bytes);
	} elsif ($type eq "si16") {
	    $numval = unpack("s", $bytes);
	} elsif ($type eq "ui16") {
	    $numval = unpack("S", $bytes);
	} elsif ($type eq "ioft") {
	    # unknown number(?) format, treat as ui64 scaled by 1/32768
	    $numval = unpack("Q", $bytes);
	    $numval /= 16384.0;
	} else {
	    $numval = 0;
	}
	#warn "value $value numval $numval";
	print $outfh "$time  $numval\n" if defined($numval);
    }
    close $fh;
}

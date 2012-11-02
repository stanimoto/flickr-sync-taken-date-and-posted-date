#!/usr/bin/env perl

BEGIN {
    eval {require App::cpanminus};
    if ($@) {
        die "please install cpanminus: sudo apt-get install cpanminus\n";
    }
}

use FindBin;

open my $reqs, "<", "$FindBin::Bin/requirements.txt"
    or die "requirements.txt is missing: $!";
while (<$reqs>) {
    s/^\s+//;
    s/\s+$//;
    s/#.*//;
    next unless $_;
    `cpanm -L $FindBin::Bin/extlib $_`
}

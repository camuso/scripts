#!/usr/bin/perl
#
#
use strict;
use warnings;

# Slurp file myfile.txt into a single string
open(FILE,"$ARGV[3]") || die "Can't open file: $!";
undef $/;
my $file = <FILE>;

# Set strings to find and insert
my $first_line = "$ARGV[0]";
my $second_line = "$ARGV[1]";
my $insert = "$ARGV[3]";

# Insert our text
$file =~ s/\Q$first_line\E\n\Q$second_line\E/$first_line\n$insert\n$second_line/;

# Write output
open(OUTPUT,">$file") || die "Can't open file: $!";
print OUTPUT $file;
close(OUTPUT);

#!/usr/bin/perl -w

use strict;
use diagnostics;

# Set the following value to 0 to hide the line separators.
my $use_separators = 1;

my $pid2;
my $filename;
my $dir;
my $string;

# search directories in $PATH for matching string
(( $dir = shift ) && ( $string = shift )) || die "format: $0 <top-dir> <search-string>";

if ( ! -d $dir ){ die "Error: '$dir' is not a valid path."; }

my $pid = open FILELIST, "find $dir -type f |" || die "Error: Can't open '$dir' for reading files.";

my $line;

while (<FILELIST>)
{
    chop;
    $filename = $_;
    if ( -T $filename )
    {
        $pid2 = open FILE, "<$filename";
        if ( 0 == $pid2 )
        {
            print "Warning: could not open $filename for reading.\n";
        }
        else
        {
            $line = 0;

            while (<FILE>)
            {
               chop;
               if (/$string/)
               {
                  print "$filename:$line:`$_'\n";
                  ($use_separators == 1) && print "=================\n";
               }
               $line++;
            }
        }
        close FILE;
    }
}
print "finished.\n";
    





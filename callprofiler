#!/usr/bin/python3
#
# callprofiler.py
#

###########################################################################
#
# cscope command line searches
# cscope.out should have been built.
#
# cscope -d -R -L<n> where n is one of ...
# 0: Find this C symbol
# 1: Find this definition
# 2: Find functions called by this function
# 3: Find functions calling this function
# 4: Find this text string
# 6: Find this egrep pattern
# 7: Find this file
# 8: Find files #including this file
# 9: Find places where this symbol is assigned a value
#
###########################################################################

import sys
import os
import numpy as np  # efficient memory management

scriptname = os.path.basename(__file__)

usagestr = """
Trace callers of the named function. Without a named directory, the trace
will be kernel-wide.

NOTE: Must have cscope.out in the Current Working Directory.
      Current Working Directory must be the top of a linux kernel tree.
      Current Working Directory: $BLD$PWD$OFF

Arguments:
  function  - function to trace
  directory - limits search to the named directory and its subdirectories

Options:
  -h  - help
"""

def usage():
    print("\n%s function [directory]" % scriptname)
    print(usagestr)

def main():

    usage()

    return 0

exit(main())

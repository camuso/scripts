#!/bin/bash

loopvar=1
while [ $loopvar -ge 1 ]; do
        echo "***************************************************"
        echo "**                                               **"
        echo "** Make Loop Number $loopvar                     **"
        echo "**                                               **"
        echo "***************************************************"
        loopvar=$((loopvar + 1))
        make clean;
        make -j4;
        make -j4 modules;
        make -j4 modules_install;
done



#!/bin/bash
crop=(${2:-320} ${3:-240})
size=($(identify ${1} | sed 's/.* \([0-9]*\)x\([0-9]*\) .*/\1 \2/'))
centroid=($(convert ${1} txt: | tail +2 | grep "white" | sed 's/\([0-9]*\),\([0-9]*\).*/\1 \2/' | awk '{ total += 1; x+=$1; y+=$2 } END { printf("%d %d\n", x/total, y/total) }'))
echo ${size[0]} ${size[1]} ${centroid[0]} ${centroid[1]} ${crop[0]} ${crop[1]} | awk '{ x1=$3-$5/2; x2=$3+$5/2; y1=$4-$6/2; y2=$4+$6/2; if (x1 < 0) { x2+=0-x1; x1=0 }; if (y1 < 0) { y2+=0-y1; y1=0 }; if (x2>$1) { x1-=x2-$1; x2=$1 }; if (y2>$2) { y1-=y2-$2; y2=$2 }; if (x1<0) { x1=0 }; if (y1<0) { y1=0 }; printf("%d %d %d %d\n", x1, y1, x2, y2) }'


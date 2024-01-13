#!/bin/bash

ID=(
    "SRR710092"
    "SRR710093"
    "SRR710094"
    "SRR710095"
)
NAME=(
    "HEK293_Control_rep1"
    "HEK293_Control_rep2"
    "HEK293_siCTCF_rep1"
    "HEK293_siCTCF_rep2"
)

#sing="singularity exec --bind /work,/work2,/work3 /work3/SingularityImages/rumball.0.5.2.sif"
sing="singularity exec rumball.sif"

mkdir -p log
for ((i=0; i<${#ID[@]}; i++))
do
    echo ${NAME[$i]}
    fq1=fastq/${ID[$i]}_1.fastq.gz
    $sing check_stranded.sh human $fq1
done

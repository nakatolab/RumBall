#!/bin/bash
cmdname=`basename $0`
function usage()
{
    echo "$cmdname [Options] <inputfile> <num of reps> <groupname> <species>" 1>&2
    echo '   <inputfile>: prefix of input matrix file' 1>&2
    echo '   <Ddir>: directory of gene annotation files' 1>&2
    echo '   <num of reps>: number of replicates (quated by ":")' 1>&2
    echo '   <group name>: labels of two groups compared (quated by ":")' 1>&2
    echo '   <species>: [Human|Mouse|Rat|Fly|Celegans]' 1>&2
    echo '   Options:' 1>&2
    echo '      -t <float>: FDR threshould for GO analysis (default: 0.05)' 1>&2
    echo '      -n <int>: number of genes for GO analysis (default: 500)' 1>&2
    echo "  Example:" 1>&2
    echo "   $cmdname Matrix 2:2 WT:KD Human" 1>&2
}

p=0.05
nGene_GO=500
while getopts t:n: option
do
    case ${option} in
        t) p=${OPTARG};;
        n) nGene_GO=${OPTARG};;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if [ $# -ne 4 ]; then
  usage
  exit 1
fi

outname=$1
n=$2
gname=$3
sp=$4
n1=$(cut -d':' -f1 <<<${n})
n2=$(cut -d':' -f2 <<<${n})

if test $sp = "Human"; then
    orgdb=org.Hs.eg.db
    orggp=hsapiens
elif test $sp = "Mouse"; then
    orgdb=org.Mm.eg.db
    orggp=mmusculus
elif test $sp = "Rat"; then
    orgdb=org.Rn.eg.db
    orggp=rnorvegicus
elif test $sp = "Fly"; then
    orgdb=org.Dm.eg.db
    orggp=dmelanogaster
elif test $sp = "Celegans"; then
     orgdb=org.Ce.eg.db
     orggp=celegans
else
    echo "[Note] Species $sp is not included in [Human|Mouse|Rat|Fly|Celegans]. GO analysis will be skipped."
fi

Rdir=$(cd $(dirname $0) && pwd)
R="Rscript $Rdir/edgeR.R"


ex(){ echo $1; eval $1; }

postfix=count
ex "$R -i=$outname.genes.$postfix.txt -n=$n -gname=$gname -o=$outname.genes.$postfix -p=$p -nrowname=2 -ncolskip=1"
ex "$R -i=$outname.isoforms.$postfix.txt -n=$n -gname=$gname -o=$outname.isoforms.$postfix -p=$p -nrowname=2 -ncolskip=1 -color=orange"

for str in genes isoforms; do
    for ty in DEGs upDEGs downDEGs; do
       head=$outname.$str.$postfix.edgeR.$ty
       ncol=`head -n1 $head.tsv | awk '{print NF}'`
       n1=$((ncol-6))
       n2=$((ncol-5))
       n3=$((ncol-4))
       n4=$((ncol-3))
       n5=$((ncol-2))
       cut -f$n1,$n3,$n4 $head.tsv | grep -v chromosome > $head.bed
       grep -v chromosome $head.tsv | awk 'BEGIN { OFS="\t" } {print $'$n1', $'$n3', $'$n4', $2, $'$n5', $'$n2' }' > $head.bed6
    done

    s=""
    for ty in all DEGs upDEGs downDEGs; do
        head=$outname.$str.$postfix.edgeR.$ty
        s="$s -i $head.tsv -n fitted-$str-$ty"
    done

    csv2xlsx.pl $s -o $outname.$str.$postfix.edgeR.xlsx
done

for ty in DEGs upDEGs downDEGs; do
    ifile=$outname.genes.$postfix.edgeR.$ty.tsv
    n=`wc -l $ifile | cut -f1 -d " "`
    if test "$orgdb" != "" && test $n -gt 1; then
        Rscript $Rdir/run_clusterProfiler.R \
                -i=$ifile -n=$nGene_GO -orgdb=$orgdb \
		-o=$outname.genes.$postfix.edgeR.GO.clusterProfiler.$ty \
		-tool=edger
    fi
done

if test "$orggp" != ""; then
    head=$outname.genes.$postfix.edgeR
    n1=`wc -l $head.upDEGs.tsv | cut -f1 -d " "`
    n2=`wc -l $head.downDEGs.tsv | cut -f1 -d " "`
    if test $n1 -gt 1 && test $n2 -gt 1; then
    Rscript $Rdir/run_gprofiler2.R -i_up=$head.upDEGs.tsv -i_down=$head.downDEGs.tsv \
            -n=$nGene_GO -org=$orggp -o=$head.GO.gProfiler2 \
	    -tool=edger
    fi
fi

options(bitmapType='cairo')

print.usage <- function() {
	cat('\nUsage: Rscript edgeR.R <options>\n',file=stderr())
	cat('   MANDATORY ARGUMENTS\n',file=stderr())
	cat('      -i=<input file>  , input file (RSEM gene/transcript file, estimated count) \n',file=stderr())
	cat('      -n=<num1>:<num2> , num of replicates for each group \n',file=stderr())
	cat('   OPTIONAL ARGUMENTS\n',file=stderr())
	cat('      -nrowname=<int> , row name (default: 1) \n',file=stderr())
	cat('      -ncolskip=<int> , colmun num to be skiped (default: 0) \n',file=stderr())
	cat('      -gname=<name1>:<name2> , name of each group \n',file=stderr())
	cat('      -p=<float>      , threshold for FDR (default: 0.01) \n',file=stderr())
	cat('      -lfcthre=<float> , threshold of log2(foldchange) (default: 0) \n',file=stderr())
	cat('      -color=<color>  , heatmap color (blue|orange|purple|green , default: blue) \n',file=stderr())
    cat('      -noannotation, specify when the gene|transcript annotation is missing) \n', file=stderr())
	cat('   OUTPUT ARGUMENTS\n',file=stderr())
	cat('      -o=<output> , prefix of output file \n',file=stderr())
	cat('\n',file=stderr())
}

args <- commandArgs(trailingOnly = T)
nargs = length(args);
minargs = 1;
maxargs = 9;
if (nargs < minargs | nargs > maxargs) {
	print.usage()
	q(save="no",status=1)
}

nrowname <- 1
ncolskip <- 0
p <- 0.01
color <- "blue"
gname1 <- "group1"
gname2 <- "group2"
lfcthre <- 0
isannotation <- "on"

for (each.arg in args) {
    if (grepl('^-i=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            filename <- arg.split[2]
        }
        else { stop('No input file name provided for parameter -i=')}
    }
    else if (grepl('^-n=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            sep.vals <- arg.split[2]
            sep.vals.split <- strsplit(sep.vals,':',fixed=TRUE)[[1]]
            if (length(sep.vals.split) != 2) {
                stop('must be specified as -n=<num1>:<num2>')
            } else {
                if (any(is.na(as.numeric(sep.vals.split)))) { # check that sep vals are numeric
                    stop('must be numeric values')
                }
                num1 <- as.numeric(sep.vals.split[1])
                num2 <- as.numeric(sep.vals.split[2])
            }
        }
        else { stop('No value provided for parameter -n=')}
    }
    else if (grepl('^-gname=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            sep.vals <- arg.split[2]
            sep.vals.split <- strsplit(sep.vals,':',fixed=TRUE)[[1]]
            if (length(sep.vals.split) != 2) {
                stop('must be specified as -gname=<num1>:<num2>')
            } else {
                gname1 <- paste(gname1, sep.vals.split[1], sep=" ")
                gname2 <- paste(gname2, sep.vals.split[2], sep=" ")
            }
        }
        else { stop('No value provided for parameter -gname=')}
    }
    else if (grepl('^-color=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            color <- arg.split[2]
        }
        else { stop('No value provided for parameter -color=')}
    }
    else if (grepl('^-nrowname=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            nrowname <- as.numeric(arg.split[2])
        }
        else { stop('No value provided for parameter -nrowname=')}
    }
    else if (grepl('^-ncolskip=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            ncolskip <- as.numeric(arg.split[2])
        }
        else { stop('No value provided for parameter -ncolskip=')}
    }
    else if (grepl('^-lfcthre=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            lfcthre <- as.numeric(arg.split[2])
        }
        else { stop('No value provided for parameter -lfcthre=')}
    }
    else if (grepl('^-p=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) {
            p <- as.numeric(arg.split[2])
        }
        else { stop('No value provided for parameter -p=')}
    }
    else if (grepl('^-o=',each.arg)) {
        arg.split <- strsplit(each.arg,'=',fixed=TRUE)[[1]]
        if (! is.na(arg.split[2]) ) { output <- arg.split[2] }
        else { stop('No output file name provided for parameter -o=')}
    }
    else if (grepl("^-noannotation", each.arg)) {
        isannotation <- "off"
    }
}

cat('filename: ', filename, '\n', file = stdout())
cat('color: ', color, '\n', file = stdout())
cat('nrowname: ', nrowname, '\n', file = stdout())
cat('ncolskip: ', ncolskip, '\n', file = stdout())
cat('p: ', p, '\n', file = stdout())
cat('lfcthre: ', lfcthre, '\n', file = stdout())
cat('num1: ', num1, '\n', file = stdout())
cat('num2: ', num2, '\n', file = stdout())
cat('output: ', output, '\n', file = stdout())

nsample <- num1 + num2

group <- factor(c(rep(gname1,num1),rep(gname2,num2)))
design <- model.matrix(~ group)
design

### read data
cat('\nread in', filename, '\n',file=stdout())

data <- read.table(filename, header=F, row.names=nrowname, sep="\t")
colnames(data) <- unlist(data[1,])   # ヘッダ文字化け対策 header=Tで読み込むと記号が.になる
data <- data[-1,]

if (isannotation == "on") {
    first = dim(data)[2] - 5
    last = dim(data)[2]
    annotation <- data[,first:last]
    data <- data[,-first:-last]
} else {
    annotation <- ""
}

if (ncolskip==1) {
    data[,-1] <- lapply(data[,-1], function(x) as.numeric(as.character(x)))
    annotation <- subset(annotation,rowSums(data[,-1])!=0)
    data <- subset(data,rowSums(data[,-1])!=0)
    genename <- data[,1]
    data <- data[,-1]
} else if(ncolskip==2) {
    data[,-1:-2] <- lapply(data[,-1:-2], function(x) as.numeric(as.character(x)))
    annotation <- subset(annotation,rowSums(data[,-1:-2])!=0)
    data <- subset(data,rowSums(data[,-1:-2])!=0)
    genename <- data[,1:2]
    colnames(genename) <- c('genename','id')
    data <- data[,-1:-2]
} else {
    data <- subset(data,rowSums(data)!=0)
}

name <- colnames(data)
counts <- as.matrix(data)
colnames(counts)

library(edgeR)
d <- DGEList(counts = counts, group = group)
cat('\ndim(', filename, ')\n',file=stdout())
dim(counts)

### filter lowly expressed genes
keep <- filterByExpr(d, group=group)
d <- d[keep, , keep.lib.sizes=FALSE]
counts <- counts[keep,]
genename <- genename[keep]
if (isannotation == "on") {
    annotation <- annotation[keep,]
}
cat('\nThe number of transcripts after filtering lowly expressed ones by filterByExpr\n',file=stdout())
sum(keep)

### log and z_score
cat('\nlog(count+1) and z-scored\n', file=stdout())
library(som)
logcounts <- log2(counts+1)
zlog <- normalize(logcounts, byrow=T)  # logcountsを元にしたz-score
zlog[which(is.na(zlog))] <- 0          # 欠損値(全サンプルで同じ値)を0で置換
colnames(zlog) <- colnames(logcounts)

### fitted count
d <- calcNormFactors(d)  # TMM norm factor
d$samples$scaling_factor = d$samples$lib.size * d$samples$norm.factors / mean(d$samples$lib.size)  # fittedcount補正係数
d$samples

d <- estimateDisp(d, design)
### d <- estimateGLMCommonDisp(d, design)  # variance  μ(1 + μφ)  for all genes
### d <- estimateGLMTrendedDisp(d, design)
### d <- estimateGLMTagwiseDisp(d, design) # variance  μ(1 + μφ)  for each gene

fit <- glmQLFit(d, design)
if (lfcthre > 0) {
   # Option to use foldchange threhold
   qlf <- glmTreat(fit, coef=2, lfc=1)
} else {
   # The quasi-likelihood F-tests (recommended for bulk RNA-seq)
   qlf <- glmQLFTest(fit, coef=2)
}

fittedcount <- qlf$fitted.values
tt <- topTags(qlf, sort.by="none", n=sum(keep))

# The likelihood ratio tests (recommended for scRNA-seq or RNA-seq without replicates)
#fit <- glmFit(d, design)
#lrt <- glmLRT(fit, coef = 2)
#tt <- topTags(lrt, sort.by="none", n=nrow(data))
#fittedcount <- lrt$fitted.values

# GO/Pathway analysis
#go <- goana(qlf, species="Mm")
#topGO(go, sort="up")
#keg <- kegga(qlf, species="Mm")
#topKEGG(keg, sort="up")

fittedcount_norm <- t(t(fittedcount) / d$samples$scaling_factor)

pdf(paste(output, ".edgeR.BCV-MDS.pdf", sep=""), height=7, width=14)
par(mfrow=c(1,2))
plotBCV(d) # coefficient of variation of biological variation
plotMDS(d, method="bcv")
dev.off()

### QQ plot
cat('\nmake QQ plot\n',file=stdout())
pdf(paste(output, ".QQplot.1stSample.pdf", sep=""), height=7, width=14)
par(mfrow=c(1,2))
qqnorm(counts[,1], main="linear scale")
qqnorm(logcounts[,1], main="log2 scale")
dev.off()

### density plot
f <- paste(output, ".density.png", sep="")
cat('\ndensity plot in', f, '\n',file=stdout())
library(ggplot2)
png(f, h=600, w=700, pointsize=20)
cells <- rep(name, each = nrow(logcounts))
dat <- data.frame(log2exp = as.vector(logcounts), cells = cells)
ggplot(dat, aes(x = log2exp, fill = cells)) + geom_density(alpha = 0.5)
dev.off()

### PCA
cat('\nmake PCA plot\n',file=stdout())
library(ggfortify)
pdf(paste(output, ".samplePCA.pdf", sep=""), height=7, width=7)
autoplot(prcomp(t(counts)), shape=F, label=T, label.size=3, data=d$samples, colour = 'group', main="raw counts")
autoplot(prcomp(t(logcounts)), shape=F, label=T, label.size=3, data=d$samples, colour = 'group', main="log counts")
autoplot(prcomp(t(zlog)), shape=F, label=T, label.size=3, data=d$samples, colour = 'group', main="z score")
autoplot(prcomp(t(fittedcount_norm)), shape=F, label=T, label.size=3, data=d$samples, colour = 'group', main="normalized fitted counts")
dev.off()

## normalize後のfitted valueを表示

if (isannotation == "on") {
    if(ncolskip==0){
        cnts <- cbind(rownames(fittedcount), fittedcount_norm, tt$table, annotation)
    }else{
        cnts <- cbind(rownames(fittedcount), genename, fittedcount_norm, tt$table, annotation)
    }
}else{
    if(ncolskip==0){
        cnts <- cbind(rownames(fittedcount), fittedcount_norm, tt$table)
    }else{
        cnts <- cbind(rownames(fittedcount), genename, fittedcount_norm, tt$table)
    }

}

colnames(cnts)[1] <- "Ensembl ID"
significant <- cnts$FDR < p
cnts_sig <- cnts[significant,]
cnts_sig <- cnts_sig[order(cnts_sig$PValue),]

# FDRでソートすると同値が発生するので、PValueでソートする
write.table(cnts[order(cnts$PValue),], file=paste(output, ".edgeR.all.tsv", sep=""), quote=F, sep = "\t",row.names = F, col.names = T)
write.table(cnts_sig, file=paste(output, ".edgeR.DEGs.tsv", sep=""), quote=F, sep = "\t",row.names = F, col.names = T)
write.table(cnts_sig[cnts_sig$logFC > 0,], file=paste(output, ".edgeR.upDEGs.tsv", sep=""), quote=F, sep = "\t",row.names = F, col.names = T)
write.table(cnts_sig[cnts_sig$logFC < 0,], file=paste(output, ".edgeR.downDEGs.tsv", sep=""), quote=F, sep = "\t",row.names = F, col.names = T)

### MAplot
cat('\nMA plot\n',file=stdout())
Data <- cbind(cnts$logCPM, cnts$logFC)
colnames(Data) <- c("logCPM", "logFC")
ma = ggplot(Data, aes(logCPM, logFC)) +
    geom_point(aes(col=significant)) +
    scale_color_manual(values=c("black", "red")) +
    ggtitle(paste("MA plot (", gname1, ", ", gname2, ")", sep=""))
ggsave(paste(output, ".edgeR.MAplot.pdf", sep=""), plot=ma, device="pdf")

# Volcano plot
cat('\nmake Volcano plot\n',file=stdout())
library(ggplot2)
library(ggrepel)
cnts_temp <- cnts[order(cnts$PValue),]
volcanoData <- data.frame(Gene=cnts_temp$genename, logFC=cnts_temp$logFC, FDR=-log10(cnts_temp$FDR), significant=cnts_temp$FDR < p)

volc = ggplot(volcanoData, aes(logFC, FDR)) +
    geom_point(aes(col=significant)) +
    scale_color_manual(values=c("black", "red")) +
    ggtitle(paste("Volcano plot (", gname1, ", ", gname2, ")", sep=""))
    volc = volc + geom_text_repel(data=head(volcanoData[order(volcanoData$FDR, decreasing=T),], 20), aes(label=Gene))
ggsave(paste(output, ".edgeR.Volcano.pdf", sep=""), plot=volc, device="pdf")

# DEGsのクラスタリング
if(sum(significant) > 0){
    cat('\ncluster DEGs\n',file=stdout())
    logt <- apply(fittedcount_norm[significant,]+1, c(1,2), log2)
    logt.z <- normalize(logt, byrow=T)
    colnames(logt.z) <- colnames(logt)
    dist.z <- dist(logt.z)
    tdist.z <- dist(t(logt.z))
    rlt.z <- hclust(dist.z, method="ward.D2")
    trlt.z <- hclust(tdist.z, method="ward.D2")

    pdf(paste(output, ".samplesCluster.inDEGs.pdf", sep=""), height=7, width=7)
    plot(trlt.z)
    dev.off()

    #heatmap
    cat('\nmake heatmap\n',file=stdout())
    library("RColorBrewer")
    library("gplots")

    if(color=="blue"){
        hmcol <- colorRampPalette(brewer.pal(9, "GnBu"))(100)
    }else if(color=="green"){
        hmcol <- colorRampPalette(brewer.pal(9, "YlGn"))(100)
    }else if(color=="orange"){
        hmcol <- colorRampPalette(brewer.pal(9, "OrRd"))(100)
    }else if(color=="purple"){
        hmcol <- colorRampPalette(brewer.pal(9, "Purples"))(100)
    }

    png(paste(output, ".heatmap.", p,".png", sep=""), h=1000, w=1000, pointsize=20)
    heatmap.2(logt.z, scale = "none",
              dendrogram="both", Rowv=as.dendrogram(rlt.z), Colv=as.dendrogram(trlt.z), trace="none",
              col=hmcol, key.title="Color Key", key.xlab="Z score", key.ylab=NA)
    dev.off()
} else {
    cat('\nNo DEGs identified. Quit.\n',file=stdout())
}

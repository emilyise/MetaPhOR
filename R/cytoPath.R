#' @rdname CytoPath
#' @title Map Differentially Expressed Genes to Dysregulated Pathways
#' @description requires the package RCy3 and a local instance of Cytoscape
#' @param pathway character, the name of the pathway to be visualized
#' @param DEGpath character, the path to a DEG file by DESeq2 or limma
#' @param figpath character, the path to which the figure will be saved
#' @param genename character, column name with HUGO Gene Names in DEG file
#' @param headers character vector of length 2 in the form c(log fold change
#' col name, adjusted p value col name)
#' @return cytoPath() Returns a Cytoscape figure of DEG data on rWikiPathways
#' @importFrom clusterProfiler bitr
#' @importFrom RecordLinkage levenshteinSim
#' @importFrom RCy3 cytoscapePing installApp commandsRun loadTableData
#' setNodeColorDefault setNodeColorMapping fitContent exportImage
#' @export
#' @examples
#' \donttest{
#' cytoPath(pathway = "Tryptophan Metabolism",
#'         DEGpath = system.file("extdata/BRCA_DEGS.csv", package = "MetaPhOR"),
#'         figpath = file.path(tempdir(), "example_map"),
#'         genename = "X",
#'         headers = c("logFC", "adj.P.Val"))
#' }
cytoPath <- function(pathway, DEGpath, figpath, genename,
                    headers = c("log2FoldChange","padj")){
    for (i in c(pathway, DEGpath, figpath, genename)){
        stopifnot(is.character(i), length(i) == 1, !is.na(i))}
    stopifnot(
        is.vector(headers), length(headers) == 2, !is.na(headers))

    #check cytoscape connection
    cytoscapePing()
    installApp('wikipathways')

    #load a wikipathway into cytoscape
    wpoi <- wpid2name$WPID[grep(paste0("\\b", pathway, "$"), wpid2name$name,
                                                        ignore.case = TRUE)[1]]
    if (is.na(wpoi) == TRUE){
        distances <- levenshteinSim(pathway, wpid2name$name)
        pathoi <- wpid2name$name[distances == max(distances)][1]
        wpoi <- wpid2name$WPID[distances == max(distances)][1]
    }

    commandsRun(paste0('wikipathways import-as-pathway id=', wpoi))

    #load node data
    nodes <- subset(wpid2gene, wpid2gene$WPID == wpoi)[,"gene"]
    DEGS <- read.csv(DEGpath, header = TRUE)

    #set up node table
    node.table <- as.data.frame(matrix(nrow=length(nodes), ncol = 2))
    colnames(node.table) <- c("id", "logfc")
    node.table[,1] <- nodes

    #get logFC for nodes
    node.table$logfc <- unlist(lapply(node.table$id, function(x)
                    mean(DEGS[,headers[1]][grep(x,toupper(DEGS[,genename]))])))
    node.table$logfc <- as.numeric(gsub(NaN, NA, node.table$logfc))

    #load into cytoscape
    loadTableData(node.table, data.key.column = 'id', table = 'node',
        table.key.column = "shared name", namespace = 'default',
        network = 'current')
    setNodeColorDefault("#FFFFFF", style.name = "WikiPathways")
    myscale <- ceiling(max(abs(range(na.omit(node.table$logfc)))))
    setNodeColorMapping(table.column = "logfc",
                        table.column.values =  c(-myscale, 0, myscale),
                        colors = c("#00008B", "#BEBEBE", "#FF0000"),
                        mapping.type = 'c', style.name = "WikiPathways")

    #export image
    fitContent()
    exportImage(figpath, "PNG", units = "in", resolution = 150)
    file.show(paste0(figpath, ".png"))
}

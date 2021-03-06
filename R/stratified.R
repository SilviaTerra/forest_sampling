#' @title Summarize stratified sample
#' @description Summarizes strata- and population-level statistics for
#' stratified sample data. The calculations are derived from Chapter 5 in
#' Gregoire and Valentine's (2008) Sampling Strategies for Natural Resources
#' and the Environment. The variance terms refer to the variance of the mean,
#' hence the \code{n} terms in the denominators. This function has two
#' options: (1) stratified and (2) post-stratified.
#' @usage summarize_stratified(trainingData, attribute, stratumTab,
#'                             desiredConfidence = 0.95, post = T)
#' @param trainingData data frame containing observations of variable of
#' interest, and stratum assignment for each plot
#' @param attribute character name of attribute to be summarized
#' @param stratumTab data frame containing acreages for each stratum
#' @param desiredConfidence numeric desired confidence level (e.g. 0.9)
#' @param post logical true if post-stratification was used
#' @return a data frame of population mean, variance, standard error, and
#' high and low confidence limits.
#' @author Henry Rodman
#' @import dplyr
#' @examples
#' \dontrun{
#' 
#' # See Forest Sampling vignette for more details
#' 
#' # Data can be expressed as:
#' 
#' trainingData <- data.frame(
#'   bapa = c(120, 140, 160, 110, 100, 90),
#'   stratum = c(1, 1, 1, 2, 2, 2)
#' )
#' stratumTab <- data.frame(stratum = c(1, 2), acres = c(200, 50))
#' attribute <- "bapa"
#' desiredConfidence <- 0.9
#' }
#' @export

summarize_stratified <- function(trainingData, attribute,
                                 stratumTab, desiredConfidence = 0.95, post = T) {

  # give the variable of interest a generic name
  attrTemp <- unlist(trainingData %>% dplyr::select(one_of(attribute)))
  trainingData$attr <- attrTemp

  # summarize strata
  if (!post) {
    # summarize strata
    stratumSummaries <- trainingData %>%
      left_join(stratumTab) %>%
      mutate(attrExpanded = attr * acres) %>%
      group_by(stratum) %>%
      summarize(
        stratMeanTot = mean(attr),
        stratVarTot = var(attrExpanded) / n(),
        stratVarMean = stratVarTot / mean(acres)^2,
        stratSE = sqrt(stratVarMean),
        stratPlots = n(),
        stratAcres = mean(acres)
      )

    totalSummary <- stratumSummaries %>%
      left_join(stratumTab) %>%
      summarize(
        popMean = weighted.mean(stratMeanTot, w = acres),
        popVar = sum(stratVarTot) / (sum(acres)^2),
        popSE = sqrt(popVar),
        popCIhalf = popSE * qt(1 - (1 - desiredConfidence) / 2,
          df = sum(stratPlots - 1)
        )
      ) %>%
      mutate(ciPct = 100 * popCIhalf / popMean) %>%
      select(popMean, popSE, popCIhalf, ciPct)
  } else { # summarize (post-stratification, in progress)
    stratumSummaries <- trainingData %>%
      left_join(stratumTab) %>%
      group_by(stratum) %>%
      summarize(
        stratMean = mean(attr),
        stratVarMean = var(attr) / n(),
        stratSE = sqrt(stratVarMean),
        stratPlots = n(),
        stratAcres = mean(acres)
      )

    totalSummary <- stratumSummaries %>%
      left_join(stratumTab) %>%
      summarize(
        popMean = weighted.mean(stratMean, w = acres),
        popMeanVar = sum((acres / sum(acres))^2 * stratVarMean),
        popSE = sqrt(popMeanVar),
        popCIhalf = popSE * qt(1 - (1 - desiredConfidence) / 2,
          df = sum(stratPlots - 1)
        )
      ) %>%
      mutate(ciPct = 100 * popCIhalf / popMean) %>%
      select(popMean, popSE, popCIhalf, ciPct)
  }

  # return list of key values
  outList <- list(
    stratumSummaries = data.frame(stratumSummaries),
    totalSummary = data.frame(totalSummary)
  )

  return(outList)
}

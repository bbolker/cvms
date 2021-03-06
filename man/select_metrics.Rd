% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/select_metrics.R
\name{select_metrics}
\alias{select_metrics}
\title{Select columns with evaluation metrics and model definitions.}
\usage{
select_metrics(results, include_definitions = TRUE, additional_includes = NULL)
}
\arguments{
\item{results}{Results tibble from \code{\link{cross_validate}()} or \code{\link{validate}()}.}

\item{include_definitions}{Whether to include the \code{Dependent},
\code{Fixed} and (possibly) \code{Random} columns. (Logical)}

\item{additional_includes}{Names of additional columns to select. (Character)}
}
\value{
The results tibble with only metric and model definition columns.
}
\description{
\Sexpr[results=rd, stage=render]{lifecycle::badge("maturing")}

 When reporting results, we might not want all
 the nested tibbles and process information columns.
 This function selects the evaluation metrics and model formulas only.
}
\details{
The first element in the \code{Family} column is used to identify the relevant columns.
}
\author{
Ludvig Renbo Olsen, \email{r-pkgs@ludvigolsen.dk}
}

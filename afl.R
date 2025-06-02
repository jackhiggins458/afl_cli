#!/usr/bin/env -S Rscript

shhh <- base::suppressPackageStartupMessages # It's a library, so shhh!
quietly <- base::suppressMessages # Please perform your function quietly!
library(fitzRoy) |> shhh()
library(docopt) |> shhh()
library(dplyr) |> shhh()
library(glue) |> shhh()
library(memoise) |> shhh()
library(cachem) |> shhh()
library(knitr) |> shhh()

source("R/cache.R")
source("R/functions.R")
source("R/vars.R")


args_ <- parse_args(doc)
 
if (args_$ladder) {
  ladder <- get_ladder()
  print_out(ladder, "ladder")
} else if (args_$fixture) {
  fixture <- get_fixture()
  print_out(fixture, "fixture")
} else if (args_$results) {
  results <- get_results()
  print_out(results, "results")
} else if (args_$live) {
  live <- get_live()
  print_out(live, "live")
}
#!/usr/bin/env -S Rscript --vanilla

# Environment setup ############################################################
shhh <- base::suppressPackageStartupMessages # It's a library, so shhh!
quietly <- base::suppressMessages # Please perform your function quietly!

library(fitzRoy) |> shhh()
library(docopt) |> shhh()
library(dplyr) |> shhh()
library(glue) |> shhh()
library(memoise) |> shhh()
library(cachem) |> shhh()

# Cache setup
# Some data (e.g. scores for the current round) are subject to change, while 
# other data (e.g. results of the 1996 season) aren't. 
# To minimise the number of API calls, we cache data for different lengths
# of time, depending on how often it may be updated.

# Cache large, historical data sets for a year
cd_long <- cachem::cache_disk(
  "~/.cache/afl/long_term", 
  max_size = 5e6,
  max_age = 365 * 86400,
  evict = "lru"
)

# Cache data that may change week to week for a few days
cd_medium <- cachem::cache_disk(
  "~/.cache/afl/medium_term", 
  max_size = 5e6,
  max_age = 5 * 86400, # 5 days
  evict = "lru"
)

# Cache live data for a minute
cd_short <- cachem::cache_disk(
  "~/.cache/afl/short_term", 
  max_size = 5e6,
  max_age = 60,
  evict = "lru"
)

# Helper functions
# Memoise the fetch_squiggle_data functions
fsd_ms <- memoise::memoise(fitzRoy::fetch_squiggle_data, cache = cd_short)
fsd_mm <- memoise::memoise(fitzRoy::fetch_squiggle_data, cache = cd_medium)
fsd_ml <- memoise::memoise(fitzRoy::fetch_squiggle_data, cache = cd_long)

fetch_current_round <- function() {
  date_today <- base::Sys.Date()
  year_today <- base::format(date_today, "%Y")
  # Look in cached fixture data, set current round equal to round of next game
  # (or, if there was a game on this day, then the round of that game)
  current_round <- fsd_mm(query = "games", year = year_today) |> 
    quietly() |> 
    dplyr::filter(date >= date_today) |> 
    dplyr::pull(round) |> 
    dplyr::first() |> 
    base::as.integer()
  return(current_round)
}

print_table <- function(df) {
  # Print kable table line by line to remove leading blank lines
  df <- knitr::kable(df, format = "simple")
  for(i in 1:length(df)) {
    glue::glue("{df[i]}") |> print()
  }
}

# Global variables
current_year <- base::format(base::Sys.Date(), "%Y") |> as.integer()
current_round <- fetch_current_round()
user_agent <- "Jack's AFL CLI tool, squiggle@sent.com"

# CLI definition ###############################################################

# Define CLI tool expected inputs
doc <- 'afl

Usage:
  afl (w|m) ladder [--season <year>] [--round <round>]
  afl (w|m) results [--season <year>] [--round <round>]
  afl (w|m) scores

Options:
  -h --help              Show this screen.
  -v --version           Show version.
  -s --season <year>     Season [default: {current_year}].
  -r --round <round>     Round of season [default: {current_round}].

' |> glue::glue()

arguments <- base::tryCatch(
  expr = {
    docopt::docopt(doc, version = 'NA')
  },
  error = function(e) {
    # Hopefully the weird error message when entering invalid args gets fixed?
    # https://github.com/docopt/docopt.R/issues/49
    #base::stop(
    #  "Invalid argument entered. See above for valid args.", 
    #  call. = FALSE
    #)
    # TODO: Implement debug mode, optionally, print the original error message:
    message("Original error: ", e$message)
  }
) 

# docopt doesn't support specifying types of arguments, so we enforce manually
arguments$season <- as.integer(arguments$season)
# arguments$round <- as.integer(arguments$round)

if (arguments$w) {
  arguments$w <- "AFLW"
} else if (arguments$m) {
  arguments$m <- "AFLM"
} else {
  stop("Competition must either be 'w' for AFLW or 'm' for AFLM")
}

# Main #########################################################################

if (arguments$ladder) {
  if (arguments$season < current_year | arguments$round < current_round){
    fetch <- fsd_ml
  } else {
    fetch <- fsd_ms
  }
  
  ladder <- fetch(
    query = "standings",
    year = arguments$season, 
    comp = arguments$comp,
    round = arguments$round,
    user_agent = user_agent
    ) |> 
    quietly() |> 
    dplyr::select(
      rank,
      name,
      pts,
      played,
      wins,
      losses,
      draws,
      percentage
      
    ) |> 
    dplyr::mutate(percentage = round(percentage, 1)) |> 
    print_table()
}

if (arguments$results) {
  # fitzRoy::fetch_fixture(
  #   season = arguments$season, 
  #   comp = arguments$comp,
  #   round = 11)
}

if (arguments$scores) {
  scores <- fsd_ms(
    query = "games",
    year = arguments$season, 
    comp = arguments$comp,
    round = current_round,
    live = 1
  ) |> quietly()
  if (nrow(scores) > 0) {
    scores <- scores |> 
      dplyr::select(
        date,
        venue,
        timestr,
        hteam,
        hscore,
        hgoals,
        hbehinds,
        ateam,
        ascore,
        agoals,
        abehinds,
    ) |>
      dplyr::arrange(date)
    scores_table <- tibble::tibble(
      team = c(scores$hteam, scores$ateam),
      score = c(scores$hscore, scores$ascore),
      goals = c(scores$hgoals, scores$agoals),
      behinds = c(scores$hbehinds, scores$abehinds))
    cat("Live scores\n")
    cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
    glue::glue("Venue: {scores$venue}, Clock: {scores$timestr}")
    cat("---------------------------------\n")
    print_table(scores_table)
      
  }

}

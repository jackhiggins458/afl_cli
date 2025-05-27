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
library(knitr) |> shhh()

# Some data (e.g. scores for the current round) are subject to change, while 
# other data (e.g. results of the 1996 season) aren't. 
# To minimise the number of API calls, we cache data.

cd_long <- cachem::cache_disk(
  "~/.cache/afl/long_term", 
  max_size = 5e6,
  max_age = 365 * 86400, # 1 year
  evict = "lru"
)

cd_medium <- cachem::cache_disk(
  "~/.cache/afl/medium_term", 
  max_size = 5e6,
  max_age = 86400, # 1 day
  evict = "lru"
)

cd_short <- cachem::cache_disk(
  "~/.cache/afl/short_term", 
  max_size = 5e6,
  max_age = 60, # 1 min
  evict = "lru"
)

# Helper functions
# Memoise the fetch_squiggle_data functions
ff_mm <- memoise::memoise(fitzRoy::fetch_fixture, cache = cd_medium)
ff_ml <- memoise::memoise(fitzRoy::fetch_fixture, cache = cd_long)
fl_ms <- memoise::memoise(fitzRoy::fetch_ladder, cache = cd_short)
fl_mm <- memoise::memoise(fitzRoy::fetch_ladder, cache = cd_medium)
fl_ml <- memoise::memoise(fitzRoy::fetch_ladder, cache = cd_long)
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

print_table <- function(df, format) {
  # Print kable table line by line to remove leading blank lines
  df <- knitr::kable(df, format = "simple")
  cat(strrep(" ", 3), strrep("-", max(nchar(df))), "\n")
  for(i in 1:length(df)) {
    glue::glue("    {df[i]}") |> print()
    if(format == "ladder" & i == 10) {
      cat(strrep(" ", 6), strrep("~", 87),"\n")
    }
  }
  cat(strrep(" ", 3), strrep("-", max(nchar(df))), "\n\n")
}

# Global variables
current_year <- base::format(base::Sys.Date(), "%Y") |> as.integer()
current_round <- fetch_current_round()
user_agent <- "Jack's AFL CLI tool, squiggle@sent.com"
team_name_emojis <- c(
  "Adelaide Crows" = "💎 Adelaide Crows",
  "Brisbane Lions" = "🦁 Brisbane Lions",
  "Carlton" = "🎶 Carlton",
  "Collingwood" = "🥧 Collingwood",
  "Essendon" = "✈️  Essendon",
  "Fremantle" = "🚢 Fremantle",
  "Geelong Cats" = "🐱 Geelong Cats",
  "Gold Coast Suns" = "🌞 Gold Coast Suns",
  "GWS Giants" = "🍊 GWS Giants",
  "Hawthorn" = "🐣 Hawthorn ",
  "Melbourne" = "👹 Melbourne",
  "North Melbourne" = "🦘 North Melbourne",
  "Port Adelaide" = "🔌 Port Adelaide",
  "Richmond" = "🐯 Richmond",
  "St Kilda" = "👼 St Kilda",
  "Sydney Swans" = "🦢 Sydney Swans",
  "Western Bulldogs" = "🦴 Western Bulldogs",
  "West Coast Eagles" = "🦅 West Coast Eagles"
)

# CLI definition ###############################################################

# Define CLI tool expected inputs
doc <- 'A cli for viewing AFL(W/M) data

Usage:
  afl (w|m) ladder [--season <year>]
  afl (w|m) fixture [--season <year>] [--round <round>]
  afl (w|m) results [--season <year>] [--round <round>]
  afl (w|m) live

Options:
  -h --help              Show this screen.
  -v --version           Show version.
  -s --season <year>     Season [default: {current_year}].
  -r --round <round>     Round of season [default: {current_round}].

' |> glue::glue()

args <- base::tryCatch(
  expr = {
    docopt::docopt(doc, version = 'NA')
  },
  error = function(e) {
    # Hopefully the weird error message when entering invalid args gets fixed?
    # https://github.com/docopt/docopt.R/issues/49
    base::stop(
      "Invalid command Please see above for valid commands.", 
      call. = FALSE
    )
    # TODO: Implement debug mode, optionally, print the original error message:
    message("Original error: ", e$message)
  }
) 

# docopt doesn't support specifying types of arguments, so we enforce manually
args$season <- as.integer(args$season)
args$round <- as.integer(args$round)

if (args$w) {
  args$comp <- "AFLW"
} else if (args$m) {
  args$comp <- "AFLM"
} else {
  stop("Must enter 'afl w' for AFLW or 'afl m' for AFLM.")
}

# Main #########################################################################

if (args$ladder) {
  if (args$season < current_year){
    fetch <- fl_ml
  } else {
    fetch <- fl_mm # TODO: Change back
  }

  ladder <- fetch(
    season = args$season, 
    comp = args$comp,
    user_agent = user_agent
    ) |> 
    quietly() |> 
    dplyr::select(
      position,
      team.club.name, 
      thisSeasonRecord.aggregatePoints,
      thisSeasonRecord.winLossRecord.played,
      thisSeasonRecord.winLossRecord.wins,
      thisSeasonRecord.winLossRecord.losses,
      thisSeasonRecord.winLossRecord.draws,
      thisSeasonRecord.percentage,
      form
    ) |> 
    dplyr::rename(
      rank = "position",
      team = "team.club.name",
      points = "thisSeasonRecord.aggregatePoints",
      played = "thisSeasonRecord.winLossRecord.played",
      wins = "thisSeasonRecord.winLossRecord.wins",
      losses = "thisSeasonRecord.winLossRecord.losses",
      draws = "thisSeasonRecord.winLossRecord.draws",
      percentage = "thisSeasonRecord.percentage",
      ) |> 
    dplyr::mutate(
      team = base::replace(team, team == "GWS GIANTS", "GWS Giants"),
      team = base::replace(team, team == "Gold Coast SUNS", "Gold Coast Suns"),
      team = team_name_emojis[team],
      percentage = round(percentage, 1),
      form = substr(form, nchar(form) - 4, nchar(form))  
    )
    cat("\n", glue::glue("🏉 {args$comp} {args$season} Ladder"), "\n\n")
    print_table(ladder, "ladder")
}

if (args$fixture) {
  
  results <- ff_ml(round = args$round) |>
    quietly() |> 
    dplyr::select(
      utcStartTime,
      home.team.club.name,
      away.team.club.name,
      venue.name,
      venue.location,
      venue.landOwner
    ) |> 
    dplyr::rename(
      when = "utcStartTime",
      home = "home.team.club.name",
      away = "away.team.club.name",
      ground = "venue.name",
      where = "venue.location",
      country = "venue.landOwner"
    ) |> 
    dplyr::mutate(
      when = as.POSIXct(when, format = "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC") |> 
        format(format = "%a, %b %e at %H:%M", tz = "Australia/Melbourne"),
      home = base::replace(home, home == "GWS GIANTS", "GWS Giants"),
      home = base::replace(home, home == "Gold Coast SUNS", "Gold Coast Suns"),
      home = team_name_emojis[home],
      away = base::replace(away, away == "GWS GIANTS", "GWS Giants"),
      away = base::replace(away, away == "Gold Coast SUNS", "Gold Coast Suns"),
      away = team_name_emojis[away]
    )

  cat("\n", 
      glue::glue("🏉 {args$comp} {args$season} Round {args$round} Fixture"), 
      "\n\n")
  print_table(results, "fixture")
}

if (args$live) {
  # TODO: Check if AFL live scores are reliable
  scores <- fsd_ms(
    query = "games",
    year = args$season, 
    comp = args$comp,
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

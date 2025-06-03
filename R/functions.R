shhh <- base::suppressPackageStartupMessages # It's a library, so shhh!
quietly <- base::suppressMessages # Please perform your function quietly!

library(fitzRoy) |> shhh()
library(docopt) |> shhh()
library(dplyr) |> shhh()
library(glue) |> shhh()
library(memoise) |> shhh()
library(cachem) |> shhh()
library(knitr) |> shhh()

# Helper functions #############################################################
# Memoise the fetch_* functions
ff_ms <- memoise::memoise(fitzRoy::fetch_fixture, cache = cd_short)
ff_mm <- memoise::memoise(fitzRoy::fetch_fixture, cache = cd_medium)
ff_ml <- memoise::memoise(fitzRoy::fetch_fixture, cache = cd_long)
fl_ms <- memoise::memoise(fitzRoy::fetch_ladder, cache = cd_short)
fl_mm <- memoise::memoise(fitzRoy::fetch_ladder, cache = cd_medium)
fl_ml <- memoise::memoise(fitzRoy::fetch_ladder, cache = cd_long)
fr_ms <- memoise::memoise(fitzRoy::fetch_results, cache = cd_short)
fr_mm <- memoise::memoise(fitzRoy::fetch_results, cache = cd_medium)
fr_ml <- memoise::memoise(fitzRoy::fetch_results, cache = cd_long)
fsd_ms <- memoise::memoise(fitzRoy::fetch_squiggle_data, cache = cd_short)
fsd_mm <- memoise::memoise(fitzRoy::fetch_squiggle_data, cache = cd_medium)
fsd_ml <- memoise::memoise(fitzRoy::fetch_squiggle_data, cache = cd_long)

fetch_current_round <- function(format) {
  date_today <- base::Sys.Date()
  year_today <- base::format(date_today, "%Y")
  
  # Look in cached fixture data, set current round equal to round of next game
  # (or, if there was a game on this day, then the round of that game)
  fixtures <- fsd_mm(query = "games", year = year_today) |> quietly() 
  
  current_round <- fixtures |> 
    dplyr::filter(date >= date_today) |> 
    dplyr::pull(round) |>
    dplyr::first() |> 
    base::as.integer()
  
  # Check if the round has started yet
  round_started <- base::any(
    Sys.time() >= fixtures |> 
      dplyr::filter(round == current_round) |> 
      dplyr::pull(date)
  )
  # When viewing results, you usually want the last completed round, unless
  # the current round has already started
  if (format == "results" & !round_started) {
    current_round <- current_round - 1
  }
  
  return(current_round)
}

format_results <- function(df) {
  # Use to process df for printing results
  results <- df |> 
    dplyr::mutate(
      result = dplyr::case_when(
        home_score > away_score ~ "def",
        home_score < away_score ~ "def by",
        home_score == away_score ~ "drew",
      ),
      to = "to"
    ) |>
    dplyr::rename(
      # Give shorter names for more compact table formatting
      hg = "home_goals", hb = "home_behinds", hs = "home_score",
      ag = "away_goals", ab = "away_behinds", as = "away_score"
    ) |> 
    dplyr::select(
      home, result, away,
      hg, hb, hs, to, ag, ab, as
    )
  return(results)
}

print_table <- function(df, format) {
  # Use to pretty print tables
  align <- NULL
  if(format == "results") align <- c(rep("l", 3), rep("r", 7))
  df <- knitr::kable(df, format = "simple", align = align) 
  cat(strrep(" ", 3), strrep("-", max(nchar(df))), "\n")
  # Print kable table line by line to enable modifications
  for(i in 1:length(df)) {  
    if(format == "results" & i < 3) next
    glue::glue("    {df[i]}") |> print()
    if(format == "ladder" & i == 10) cat(strrep(" ", 6), strrep("~", 87),"\n")
    
  }
  cat(strrep(" ", 3), strrep("-", max(nchar(df))), "\n\n")
}

print_out <- function(df, format)  {
  if(format == "ladder") {
    cat("\n   ", glue::glue("🏉 {args_$comp} {args_$season} Ladder\n\n"))
    print_table(df, "ladder")
  } else if (format == "fixture") {
    cat("\n   ",
      glue::glue(
        "🏉 {args_$comp} {args_$season} Round {args_$round} Fixture\n\n"
      ) 
    )
    print_table(df, "fixture")
  } else if (format == "results") {
    cat("\n   ",
      glue::glue(
      "🏉 {args_$comp} {args_$season} Round {args_$round} Results\n\n"
      ) 
    )
    print_table(df, "results")
  }
}

parse_args <- function(doc) {
  args_ <- base::tryCatch(
    expr = {
      docopt::docopt(doc)
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
  args_$season <- as.integer(args_$season)
  args_$round <- as.integer(args_$round)
  
  if (args_$w) {
    args_$comp <- "AFLW"
  } else if (args_$m) {
    args_$comp <- "AFLM"
  } else {
    stop("Must enter 'afl w' for AFLW or 'afl m' for AFLM.")
  }
  
  return(args_)
}

# Main functions ###############################################################

get_ladder <- function() {
  if (args_$season < current_year){
    fetch <- fl_ml
  } else {
    fetch <- fl_mm # TODO: Change back
  }
  
  ladder <- fetch(
    season = args_$season, 
    comp = args_$comp
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
  return(ladder)
}

get_fixture <- function() {
  fixture <- ff_ml(round = args_$round) |>
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
  return(fixture)
}

get_results <- function() {
  if (args_$round == current_round) {
    args_$round <- fetch_current_round("results")
  }
  results <- fr_mm(
    season = args_$season,
    round = args_$round,
    comp = args_$comp
  ) |> 
    dplyr::select(
      match.date,
      match.homeTeam.name,
      match.awayTeam.name,
      venue.name,
      venue.address,
      venue.landOwner,
      homeTeamScore.matchScore.totalScore,
      homeTeamScore.matchScore.goals,
      homeTeamScore.matchScore.behinds,
      awayTeamScore.matchScore.totalScore,
      awayTeamScore.matchScore.goals,
      awayTeamScore.matchScore.behinds
    ) |> dplyr::rename(
      when = "match.date",
      home = "match.homeTeam.name",
      away = "match.awayTeam.name",
      ground = "venue.name",
      where = "venue.address",
      country = "venue.landOwner",
      home_score = "homeTeamScore.matchScore.totalScore",
      home_goals = "homeTeamScore.matchScore.goals",
      home_behinds = "homeTeamScore.matchScore.behinds",
      away_score = "awayTeamScore.matchScore.totalScore",
      away_goals = "awayTeamScore.matchScore.goals",
      away_behinds = "awayTeamScore.matchScore.behinds"
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
    ) |> 
    format_results()
  return(results)
}

get_live <- function() {
  # AFL API doesn't seem to provide live scores
  # None of the other APIs support AFLW
  if (args_$comp == "AFLW") {
    stop("Live scores are not available for the AFLW.")
  }
  warning("Not implemented yet!")
}

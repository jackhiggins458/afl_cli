shhh <- base::suppressPackageStartupMessages # It's a library, so shhh!
library(glue) |> shhh()

current_year <- base::format(base::Sys.Date(), "%Y") |> as.integer()
current_round <- fetch_current_round("fixture")
user_agent <- "Jack's AFL CLI tool, squiggle@sent.com"

# Define the CLI
doc <- 'A cli for viewing AFL(W/M) data

Usage:
  afl (w|m) ladder [--season <year>]
  afl (w|m) fixture [--season <year>] [--round <round>]
  afl (w|m) results [--season <year>] [--round <round>]
  afl (w|m) live

Options:
  -h --help              Show help.
  -s --season <year>     Season [default: {current_year}].
  -r --round <round>     Round of season [default: {current_round}].

' |> glue::glue()

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

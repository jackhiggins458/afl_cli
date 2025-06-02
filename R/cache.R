library(cachem) |> shhh()

# Define caches, used to minimise the number of API calls
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
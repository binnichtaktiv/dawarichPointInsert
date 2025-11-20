# dawarichPointInsert
bash script to manually add GPS points to your Dawarich database via command line

## Features

- add single GPS point with custom date/time
- add multiple points in sequence (forward/backward in time)
- automatic timezone handling (Europe/Berlin)
- 30-second intervals for bulk imports
- copy coordinates directly from Google Maps

## Requirements

- running Dawarich Docker setup
- postgreSQL container named `dawarich_db`
- bash shell

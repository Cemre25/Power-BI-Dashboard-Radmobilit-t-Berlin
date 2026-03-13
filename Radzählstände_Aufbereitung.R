library(readxl)
library(tidyverse)
library(lubridate)

pfad <- "data/gesamtdatei-stundenwerte.xlsx"

rad_2022_raw <- read_excel(
  path  = pfad,
  sheet = "Jahresdatei 2022"
)

radverkehr_2022 <- rad_2022_raw %>%
  rename(DatumZeit = 1) %>%
  pivot_longer(
    cols      = -DatumZeit,
    names_to  = "ZaehlstellenCode",
    values_to = "Anzahl"
  ) %>%
  filter(!is.na(Anzahl)) %>%
  mutate(
    Jahr       = year(DatumZeit),
    Monat      = month(DatumZeit),
    Monat_Name = month(DatumZeit, label = TRUE),
    Stunde     = hour(DatumZeit),
    Wochentag  = wday(DatumZeit, label = TRUE)
  )

write_csv(
  radverkehr_2022,
  "data/radverkehr_2022.csv"
)

zaehlstellen <- read_excel(
  path  = pfad,
  sheet = "Standortdaten"
) %>%
  rename(
    Zaehlstelle = `Zählstelle`,
    Laengengrad = `Längengrad`
  )


write_csv(
  zaehlstellen,
  "data/zaehlstellen.csv"
)



#==========================================================================================

library(tidyr)
library(dplyr)

df <- read.csv("data/radverkehr_2022.csv", sep = ",", stringsAsFactors = FALSE)

df_neu <- df %>%
  separate(
    col = ZaehlstellenCode,
    into = c("ZaehlstellenCode", "Installationsdatum"),
    sep = "\\s+",
    extra = "merge",
    fill = "right"
  )

write_csv(df_neu, "data/radverkehr1_2022.csv" )

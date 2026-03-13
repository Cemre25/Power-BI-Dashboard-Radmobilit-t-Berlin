library(tidyverse)

# # Daten einlesen (mit header = TRUE für Spaltennamen)
# wetterdaten_Berlin <- read.table(
#   "dataprodukt_klima_tag_19480101_20241231_00433.txt",
#   sep = ";",
#   header = TRUE
# )
# 
# # Als CSV speichern (ohne Zuweisung)
# write.csv2(
#   wetterdaten_Berlin,
#   "data/wetterdaten_Berlin.csv",
#   row.names = FALSE
# )
# 
# wetterdaten_Berlin <- read.table("data/wetterdaten_Berlin.csv", sep = ";",
#                                  header = TRUE )
# 
# wetterdaten_Berlin_filter_2022 <- wetterdaten_Berlin %>%
#   filter(MESS_DATUM >= 20220101 & MESS_DATUM <= 20221231)
# 
# 
# write.csv2(wetterdaten_Berlin_filter_2022, "data/wetterdaten_Berlin_2022.csv",row.names = FALSE  )
# 


library(tidyverse)

# Daten einlesen
wetterdaten <- read_csv2("data/Radzählstände Berlin/wetterdaten_Berlin_2022.csv")

# ============================================
# 1. ÜBERBLICK VERSCHAFFEN
# ============================================

# Struktur der Daten
glimpse(wetterdaten)

# Zusammenfassung
summary(wetterdaten)

# Fehlende Werte prüfen
colSums(is.na(wetterdaten))

# ============================================
# 2. DATENBEREINIGUNG
# ============================================

wetterdaten_clean <- wetterdaten %>%
  
  # Datum in richtiges Format konvertieren
  mutate(
    datum = ymd(MESS_DATUM),
    jahr = year(datum),
    monat = month(datum),
    tag = day(datum)
  ) %>%
  
  # Fehlwerte behandeln (-999 ist der Fehlwert-Code beim DWD)
  mutate(across(
    c(FX, FM, RSK, SDK, SHK_TAG, NM, VPM, PM, TMK, UPM, TXK, TNK, TGK),
    ~na_if(., -999)
  )) %>%
  
  # Qualitätsniveau prüfen - nur Daten mit QN >= 7 behalten
  # (QN = 7, 8, 9, 10 bedeutet geprüfte/korrigierte Daten)
  filter(QN_3 >= 7 | QN_4 >= 7) %>%
  
  # Plausibilitätsprüfungen
  # Temperatur sollte zwischen -50 und +50°C liegen
  filter(
    is.na(TMK) | (TMK >= -50 & TMK <= 50),
    is.na(TXK) | (TXK >= -50 & TXK <= 50),
    is.na(TNK) | (TNK >= -50 & TNK <= 50)
  ) %>%
  
  # TXK (Maximum) sollte >= TNK (Minimum) sein
  filter(is.na(TXK) | is.na(TNK) | TXK >= TNK) %>%
  
  # Negative Niederschläge sind unmöglich
  filter(is.na(RSK) | RSK >= 0) %>%
  
  # Relative Feuchte zwischen 0 und 100%
  filter(is.na(UPM) | (UPM >= 0 & UPM <= 100)) %>%
  
  # Duplikate entfernen (falls vorhanden)
  distinct(MESS_DATUM, .keep_all = TRUE) %>%
  
  # Sortieren nach Datum
  arrange(datum)

# ============================================
# 3. DATENQUALITÄT PRÜFEN
# ============================================

cat("\n=== DATENQUALITÄTSBERICHT - BERLIN 2022 ===\n\n")

# Anzahl Zeilen vor und nach Bereinigung
cat("Zeilen vorher:", nrow(wetterdaten), "\n")
cat("Zeilen nachher:", nrow(wetterdaten_clean), "\n")
cat("Entfernte Zeilen:", nrow(wetterdaten) - nrow(wetterdaten_clean), "\n\n")

# Fehlende Werte nach Bereinigung
cat("Fehlende Werte pro Spalte:\n")
print(colSums(is.na(wetterdaten_clean)))

# Prüfe Vollständigkeit: Sollten 365 Tage sein (2022 ist kein Schaltjahr)
cat("\n\nErwartete Tage in 2022: 365\n")
cat("Tatsächliche Tage:", nrow(wetterdaten_clean), "\n")

# Zeitliche Lücken finden
alle_tage <- seq(ymd("2022-01-01"), ymd("2022-12-31"), by = "day")
fehlende_tage <- alle_tage[!alle_tage %in% wetterdaten_clean$datum]
if(length(fehlende_tage) > 0) {
  cat("\nACHTUNG: Fehlende Tage:\n")
  print(fehlende_tage)
}

# ============================================
# 4. BEREINIGTE DATEN SPEICHERN
# ============================================

write_csv2(
  wetterdaten_clean,
  "data/Radzählstände Berlin/wetterdaten_Berlin_2022_clean.csv"
)

cat("\n✓ Bereinigte Daten gespeichert als: wetterdaten_Berlin_2022_clean.csv\n")

# ============================================
# 5. FÜR POWER BI OPTIMIEREN
# ============================================

wetterdaten_powerbi <- wetterdaten_clean %>%
  select(
    # Datum-Spalten
    datum,
    jahr,
    monat,
    tag,
    MESS_DATUM,
    
    # Wichtige Messwerte (mit verständlichen Namen)
    temperatur_mittel = TMK,
    temperatur_max = TXK,
    temperatur_min = TNK,
    temperatur_boden = TGK,
    
    niederschlag = RSK,
    niederschlag_form = RSKF,
    
    sonnenschein_stunden = SDK,
    schneehoehe = SHK_TAG,
    
    bewoelkung = NM,
    luftfeuchtigkeit = UPM,
    luftdruck = PM,
    dampfdruck = VPM,
    
    windgeschwindigkeit = FM,
    windspitze = FX,
    
    # Qualitätsindikatoren
    qualitaet_wind = QN_3,
    qualitaet_klima = QN_4,
    
    STATIONS_ID
  ) %>%
  
  # Wochentag hinzufügen (für Analysen)
  mutate(
    wochentag = wday(datum, label = TRUE, abbr = FALSE, week_start = 1),
    kalenderwoche = isoweek(datum),
    quartal = quarter(datum),
    
    # Kategorien für bessere Visualisierungen
    temperatur_kategorie = case_when(
      temperatur_mittel < 0 ~ "Frost",
      temperatur_mittel < 10 ~ "Kühl",
      temperatur_mittel < 20 ~ "Mild",
      temperatur_mittel < 25 ~ "Warm",
      TRUE ~ "Heiß"
    ),
    
    regen_kategorie = case_when(
      is.na(niederschlag) | niederschlag < 0.1 ~ "Kein Regen",
      niederschlag < 5 ~ "Leichter Regen",
      niederschlag < 15 ~ "Mäßiger Regen",
      TRUE ~ "Starker Regen"
    )
  )

# ============================================
# 6. POWER BI DATEN SPEICHERN
# ============================================

# Als CSV für Power BI (mit Komma als Trennzeichen)
write_csv(
  wetterdaten_powerbi,
  "data/Radzählstände Berlin/wetterdaten_Berlin_2022_PowerBI.csv"
)

cat("\n✓ Power BI-optimierte Daten gespeichert als: wetterdaten_Berlin_2022_PowerBI.csv\n")

# ============================================

# Statistiken für wichtige Variablen
cat("\n=== STATISTIKEN - BERLIN 2022 ===\n\n")
cat("Temperatur (TMK):\n")
cat("  Mittelwert:", round(mean(wetterdaten_clean$TMK, na.rm = TRUE), 1), "°C\n")
cat("  Minimum:", round(min(wetterdaten_clean$TMK, na.rm = TRUE), 1), "°C\n")
cat("  Maximum:", round(max(wetterdaten_clean$TMK, na.rm = TRUE), 1), "°C\n\n")

cat("Niederschlag (RSK):\n")
cat("  Gesamtsumme:", round(sum(wetterdaten_clean$RSK, na.rm = TRUE), 1), "mm\n")
cat("  Regentage:", sum(wetterdaten_clean$RSK > 0.1, na.rm = TRUE), "\n\n")

cat("Sonnenschein (SDK):\n")
cat("  Gesamtsumme:", round(sum(wetterdaten_clean$SDK, na.rm = TRUE), 1), "Stunden\n")

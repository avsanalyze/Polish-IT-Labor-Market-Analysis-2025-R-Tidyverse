library(tidyverse)
library(ggrepel)

# 1. Wczytanie i czyszczenie danych z GUS (BDL) -------------------------------
miesiace_pl <- c("styczeń", "luty", "marzec", "kwiecień", "maj", "czerwiec",
                 "lipiec", "sierpień", "wrzesień", "październik", "listopad", "grudzień")

gus_raw <- read_delim("RYNEK_IT_2025.csv", delim = ";", show_col_types = FALSE) |>
  select(-last_col())

gus_raw_plec <- read_delim("plec.csv", delim = ";", show_col_types = FALSE) |>
  select(-last_col())

gus_clean <- gus_raw |>
  pivot_longer(
    cols = -c(Kod, Nazwa),
    names_to = c("Miesiac", "Dzial_PKD", "Kategoria", "Rok", "Jednostka"),
    names_sep = ";",
    values_to = "Pracujacy"
  ) |>
  mutate(
    Miesiac = factor(Miesiac, levels = miesiace_pl),
    Rok = as.integer(Rok)
  ) |>
  select(Kod, Nazwa, Rok, Miesiac, Dzial_PKD, Pracujacy)

gus_plec_clean <- gus_raw_plec |>
  pivot_longer(
    cols = -c(Kod, Nazwa),
    names_to = c("Miesiac", "Sekcja", "Plec", "Rok", "Jednostka"),
    names_sep = ";",
    values_to = "Pracujacy_Sekcja_J"
  ) |>
  mutate(
    Miesiac = factor(Miesiac, levels = miesiace_pl),
    Rok = as.integer(Rok)
  ) |>
  select(Kod, Nazwa, Rok, Miesiac, Plec, Pracujacy_Sekcja_J)

# 2. Koncentracja regionalna IT (PKD 62, grudzień 2025) ----------------------
ranking_woj <- gus_clean |>
  filter(
    Nazwa != "POLSKA",
    Miesiac == "grudzień",
    Dzial_PKD == "Sekcja J dz. 62"
  ) |>
  mutate(
    Udzial_PL = round(Pracujacy / sum(Pracujacy) * 100, 2),
    Nazwa = str_to_title(Nazwa)
  ) |>
  arrange(desc(Pracujacy)) |>
  select(Nazwa, Pracujacy, Udzial_PL)

print(ranking_woj, n = 16)

# 3. Dynamika zatrudnienia styczeń vs. grudzień 2025 (PKD 62) ----------------
dynamika_2025 <- gus_clean |>
  filter(
    Nazwa != "POLSKA",
    Miesiac %in% c("styczeń", "grudzień"),
    Dzial_PKD == "Sekcja J dz. 62"
  ) |>
  select(Nazwa, Miesiac, Pracujacy) |>
  pivot_wider(
    id_cols = Nazwa,
    names_from = Miesiac,
    values_from = Pracujacy
  ) |>
  mutate(
    zmiana_osob = grudzień - styczeń,
    zmiana_proc = round((grudzień - styczeń) / styczeń * 100, 2),
    Nazwa = str_to_title(Nazwa)
  ) |>
  arrange(desc(zmiana_proc))

print(dynamika_2025, n = 16)

# 4. Struktura płci i specjalizacja IT (left_join dwóch zbiorów GUS) ---------
plec_grudzien <- gus_plec_clean |>
  filter(Nazwa != "POLSKA", Miesiac == "grudzień") |>
  pivot_wider(
    id_cols = Nazwa,
    names_from = Plec,
    values_from = Pracujacy_Sekcja_J
  ) |>
  mutate(
    Udzial_Kobiet_Proc = round(kobiety / ogółem * 100, 2),
    Nazwa = str_to_title(Nazwa)
  ) |>
  arrange(desc(Udzial_Kobiet_Proc))

analiza_laczna <- ranking_woj |>
  left_join(plec_grudzien, by = "Nazwa") |>
  mutate(
    Specjalizacja_IT_Proc = round(Pracujacy / ogółem * 100, 2)
  ) |>
  select(Nazwa, Pracujacy_IT_62 = Pracujacy, Cala_Sekcja_J = ogółem, Specjalizacja_IT_Proc, Udzial_Kobiet_Proc)

print(analiza_laczna, n = 16)

# 5. Szeregi czasowe 2025 dla TOP 5 hubów IT (indeks styczeń = 100) ----------
top5_woj <- c("MAZOWIECKIE", "MAŁOPOLSKIE", "DOLNOŚLĄSKIE", "ŚLĄSKIE", "POMORSKIE")

trend_2025 <- gus_clean |>
  filter(
    Nazwa %in% top5_woj,
    Dzial_PKD == "Sekcja J dz. 62"
  ) |>
  group_by(Nazwa) |>
  arrange(Miesiac) |>
  mutate(
    Indeks_Sty100 = round(Pracujacy / first(Pracujacy) * 100, 2),
    Zmiana_MdM = Pracujacy - lag(Pracujacy),
    Nazwa = str_to_title(Nazwa)
  ) |>
  ungroup()

# 6. Dekompozycja dynamiki 2025 według płci (Sekcja J) -----------------------
dynamika_plec <- gus_plec_clean |>
  filter(
    Miesiac %in% c("styczeń", "grudzień"),
    Plec %in% c("kobiety", "mężczyźni")
  ) |>
  pivot_wider(
    id_cols = c(Nazwa, Plec),
    names_from = Miesiac,
    values_from = Pracujacy_Sekcja_J
  ) |>
  mutate(
    Zmiana_Osob = grudzień - styczeń,
    Zmiana_Proc = round((grudzień - styczeń) / styczeń * 100, 2),
    Nazwa = str_to_title(Nazwa)
  ) |>
  filter(Nazwa %in% c("Polska", "Mazowieckie", "Małopolskie", "Dolnośląskie", "Śląskie", "Pomorskie")) |>
  arrange(Nazwa, Plec)

print(dynamika_plec, n = 12)

# 7. Wizualizacje (ggplot2) --------------------------------------------------
wykres_udzial <- ggplot(ranking_woj, aes(x = reorder(Nazwa, Pracujacy), y = Pracujacy)) +
  geom_col(fill = "#2c3e50", width = 0.7) +
  geom_text(
    aes(label = paste0(format(Pracujacy, big.mark = " "), " (", Udzial_PL, "%)")),
    hjust = -0.08,
    size = 3.3,
    fontface = "bold"
  ) +
  coord_flip() +
  scale_y_continuous(limits = c(0, 118000), labels = scales::label_number(big.mark = " ")) +
  labs(
    title = "Zatrudnienie w polskim IT (Sekcja J, dz. 62) wg województw",
    subtitle = "Stan na grudzień 2025 r. | Źródło: Bank Danych Lokalnych GUS",
    x = NULL,
    y = "Liczba pracujących (osoby)"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

wykres_dynamika <- dynamika_2025 |>
  mutate(Kierunek = ifelse(zmiana_proc >= 0, "Wzrost", "Spadek")) |>
  ggplot(aes(x = reorder(Nazwa, zmiana_proc), y = zmiana_proc, fill = Kierunek)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
  geom_text(
    aes(
      label = paste0(ifelse(zmiana_proc > 0, "+", ""), zmiana_proc, "%"),
      hjust = ifelse(zmiana_proc >= 0, -0.15, 1.15)
    ),
    size = 3.3,
    fontface = "bold"
  ) +
  scale_fill_manual(values = c("Wzrost" = "#27ae60", "Spadek" = "#c0392b")) +
  coord_flip() +
  scale_y_continuous(limits = c(-1.3, 4.3)) +
  labs(
    title = "Dynamika zatrudnienia w polskim IT w 2025 r. (styczeń vs grudzień)",
    subtitle = "Zmiana procentowa w dziale Oprogramowanie i doradztwo (PKD 62) | Źródło: GUS",
    x = NULL,
    y = "Zmiana procentowa (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

wykres_struktura <- ggplot(
  analiza_laczna,
  aes(x = Specjalizacja_IT_Proc, y = Udzial_Kobiet_Proc, size = Pracujacy_IT_62)
) +
  geom_vline(xintercept = mean(analiza_laczna$Specjalizacja_IT_Proc), linetype = "dashed", color = "grey70") +
  geom_hline(yintercept = mean(analiza_laczna$Udzial_Kobiet_Proc), linetype = "dashed", color = "grey70") +
  geom_point(color = "#2980b9", alpha = 0.85) +
  geom_text_repel(
    aes(label = Nazwa),
    size = 3.3,
    box.padding = 0.45,
    point.padding = 0.35,
    min.segment.length = 0.2,
    segment.color = "grey60",
    show.legend = FALSE
  ) +
  scale_size_continuous(
    range = c(3, 13),
    labels = scales::label_number(big.mark = " "),
    name = "Pracujący w IT (dz. 62)"
  ) +
  scale_y_continuous(limits = c(25.5, 36.2)) +
  scale_x_continuous(limits = c(60, 74.5)) +
  labs(
    title = "Struktura polskiego sektora IT wg województw (grudzień 2025)",
    subtitle = "Udział czystego oprogramowania (PKD 62) w Sekcji J vs. odsetek kobiet | Linie przerywane = średnia województw",
    x = "Specjalizacja IT — udział PKD 62 w całej Sekcji J (%)",
    y = "Udział kobiet w Sekcji J (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

wykres_trend <- ggplot(
  trend_2025,
  aes(x = Miesiac, y = Indeks_Sty100, color = Nazwa, group = Nazwa)
) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "grey60") +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.2) +
  scale_color_brewer(palette = "Set1", name = "Województwo") +
  labs(
    title = "Miesięczna dynamika zatrudnienia w TOP 5 hubach IT w 2025 r.",
    subtitle = "Indeks zmian w PKD 62 (styczeń 2025 = 100) | Źródło: GUS",
    x = NULL,
    y = "Indeks zatrudnienia (styczeń = 100)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 30, hjust = 1)
  )

wykres_plec <- dynamika_plec |>
  mutate(
    Plec = str_to_title(Plec),
    Nazwa = factor(Nazwa, levels = c("Polska", "Małopolskie", "Śląskie", "Mazowieckie", "Pomorskie", "Dolnośląskie"))
  ) |>
  ggplot(aes(x = Nazwa, y = Zmiana_Proc, fill = Plec)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.68) +
  geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
  geom_text(
    aes(
      label = paste0(ifelse(Zmiana_Proc > 0, "+", ""), Zmiana_Proc, "%"),
      vjust = ifelse(Zmiana_Proc >= 0, -0.4, 1.3)
    ),
    position = position_dodge(width = 0.75),
    size = 3.1,
    fontface = "bold"
  ) +
  scale_fill_manual(values = c("Kobiety" = "#e67e22", "Mężczyźni" = "#2c3e50"), name = "Płeć") +
  scale_y_continuous(limits = c(-1.3, 3.4)) +
  labs(
    title = "Zmiana zatrudnienia w Sekcji J w 2025 r. według płci (styczeń vs grudzień)",
    subtitle = "Dynamika procentowa w Polsce oraz TOP 5 województwach IT | Źródło: GUS",
    x = NULL,
    y = "Zmiana procentowa (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

# 8. Eksport wykresów (300 DPI) ----------------------------------------------
ggsave("wykres_udzial_it_2025.png", plot = wykres_udzial, width = 10, height = 6, dpi = 300, bg = "white")
ggsave("wykres_dynamika_it_2025.png", plot = wykres_dynamika, width = 10, height = 6, dpi = 300, bg = "white")
ggsave("wykres_struktura_it_2025.png", plot = wykres_struktura, width = 10, height = 6, dpi = 300, bg = "white")
ggsave("wykres_trend_it_2025.png", plot = wykres_trend, width = 10, height = 6, dpi = 300, bg = "white")
ggsave("wykres_plec_dynamika_2025.png", plot = wykres_plec, width = 10, height = 6, dpi = 300, bg = "white")
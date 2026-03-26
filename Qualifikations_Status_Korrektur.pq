section Section1;

// ============================================================
// Qualifikations_Status_Korrektur
//
// Erweitert Qualifikations_Status um statusabhängige, rollierend
// berechnete Gültigkeitsdaten und ein Fehler-Flag.
//
// Neue Spalten:
//   Erstberufung_Korrekt  – statusabhängiges Erstberufungsdatum
//   Berufung_Monate       – Zykluslänge aus Qualifikations_Regelwerk
//   Gültig_ab_Korrekt     – Start des aktuell gültigen Zyklus
//   Gültig_bis_Korrekt    – Ende des aktuell gültigen Zyklus
//   Datum_Fehlerhaft      – true  = Ist ≠ Soll
//                           false = beide Werte korrekt
//                           null  = kein Erstberufungsdatum vorhanden
//
// Statusgruppen:
//   Lead-Auditor | Experte | Prüfer  →  Datum_Erstberufung_Lead_Auditor
//   Co-Auditor                       →  Datum_Erstberufung_Co_Auditor
//   Assistant | Trainee              →  Datum_Erstberufung_Assistant_Tra
//
// Zykluslogik (rollierend):
//   1) Monatsdifferenz Erstberufung → heute
//   2) Ganzzahldivision / Berufung_Monate = abgeschlossene Zyklen
//   3) Startkandidat = Erstberufung + Zyklen * Berufung_Monate
//   4) Taggenau: liegt der Kandidat noch in der Zukunft?
//      → einen Zyklus zurück (sofern Zyklen > 0)
// ============================================================
shared Qualifikations_Status_Korrektur = let

    // ── 1. Basis: bereits transformierte Haupttabelle ───────────────────────
    Basis = Qualifikations_Status,

    // ── 2. Berufung_Monate aus Regelwerk einjoinen ─────────────────────
    MitRegelwerk = Table.NestedJoin(
        Basis,
        {"Quali_SP_ID"},
        Qualifikations_Regelwerk,
        {"Quali_SP_ID"},
        "Regelwerk",
        JoinKind.LeftOuter
    ),
    ExpandRegelwerk = Table.ExpandTableColumn(
        MitRegelwerk,
        "Regelwerk",
        {"Berufung_Monate"},
        {"Berufung_Monate"}
    ),
    TypRegelwerk = Table.TransformColumnTypes(
        ExpandRegelwerk,
        {{"Berufung_Monate", Int64.Type}}
    ),

    // ── 3. Statusabhängiges Erstberufungsdatum ─────────────────────────
    // Text.Lower + Text.Trim: robust gegen Groß-/Kleinschreibung und Leerzeichen
    MitErstberufung = Table.AddColumn(
        TypRegelwerk,
        "Erstberufung_Korrekt",
        each
            let s = Text.Trim(Text.Lower([Status] ?? ""))
            in
                if   s = "lead-auditor" or s = "experte" or s = "prüfer"
                then [Datum_Erstberufung_Lead_Auditor]
                else if s = "co-auditor"
                then [Datum_Erstberufung_Co_Auditor]
                else if s = "assistant" or s = "trainee"
                then [Datum_Erstberufung_Assistant_Tra]
                else null,
        type date
    ),

    // ── 4. Rollierende Zyklusberechnung ───────────────────────────────
    //
    // Beispiel:
    //   Erstberufung = 2018-01-15 | Berufung_Monate = 36 | Heute = 2026-03-25
    //   MonateDiff   = (2026-2018)*12 + (3-1) = 98
    //   Zyklen       = 98 / 36 = 2 (Ganzzahl)
    //   Kandidat     = 2018-01-15 + 72 Monate = 2024-01-15
    //   2024-01-15 <= 2026-03-25 → kein Rückschritt nötig
    //   Gültig_ab_Korrekt  = 2024-01-15
    //   Gültig_bis_Korrekt = 2027-01-15
    //
    // Taggenauer Kantfall:
    //   Erstberufung = 2024-01-20 | Monate = 36 | Heute = 2026-01-10
    //   MonateDiff = 24 | Zyklen = 0 | Kandidat = 2024-01-20
    //   2024-01-20 <= 2026-01-10 → korrekt, kein Rückschritt
    //
    MitGueltigAb = Table.AddColumn(
        MitErstberufung,
        "Gültig_ab_Korrekt",
        each
            let
                eb     = [Erstberufung_Korrekt],
                monate = [Berufung_Monate]
            in
                if eb = null or monate = null or monate <= 0 then null
                else
                    let
                        heute      = Date.From(DateTime.LocalNow()),
                        diffMonate = (Date.Year(heute) - Date.Year(eb)) * 12
                                   + (Date.Month(heute) - Date.Month(eb)),
                        diffPos    = Number.Max(0, diffMonate),
                        zyklen     = Number.IntegerDivide(diffPos, monate),
                        kandidat   = Date.AddMonths(eb, zyklen * monate),
                        // Taggenau: Kandidat noch in der Zukunft? Einen Zyklus zurück.
                        finalZyklen = if kandidat > heute and zyklen > 0
                                      then zyklen - 1
                                      else zyklen
                    in
                        Date.AddMonths(eb, finalZyklen * monate),
        type date
    ),

    MitGueltigBis = Table.AddColumn(
        MitGueltigAb,
        "Gültig_bis_Korrekt",
        each
            if [Gültig_ab_Korrekt] = null or [Berufung_Monate] = null
            then null
            else Date.AddMonths([Gültig_ab_Korrekt], [Berufung_Monate]),
        type date
    ),

    // ── 5. Fehler-Flag ─────────────────────────────────────────────────
    // null  → kein Soll-Datum ermittelbar (Erstberufung fehlt oder Status unbekannt)
    // true  → mindestens ein Datumswert weicht vom Soll ab
    // false → Gültig_ab und Gültig_bis stimmen mit dem Soll überein
    MitFehlerFlag = Table.AddColumn(
        MitGueltigBis,
        "Datum_Fehlerhaft",
        each
            if [Gültig_ab_Korrekt] = null then null
            else
                   [Gültig_ab]  <> [Gültig_ab_Korrekt]
                or [Gültig_bis] <> [Gültig_bis_Korrekt],
        type logical
    ),

    // ── 6. Spaltenreihenfolge (Ist | Soll nebeneinander) ───────────────
    FinaleSpalten = Table.ReorderColumns(
        MitFehlerFlag,
        {
            "ID", "Quali_SP_ID", "Auditor_SP_ID", "Status",
            "Erstberufung_Korrekt",
            "Datum_Erstberufung_Lead_Auditor",
            "Datum_Erstberufung_Co_Auditor",
            "Datum_Erstberufung_Assistant_Tra",
            "Berufung_Monate",
            "Gültig_ab",          "Gültig_ab_Korrekt",
            "Gültig_bis",         "Gültig_bis_Korrekt",
            "Datum_Fehlerhaft",
            "quali_log", "Approval_SP_ID"
        }
    )

in
    FinaleSpalten;

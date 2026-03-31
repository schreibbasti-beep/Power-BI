section Section1;

shared Auditoren_Stammdaten = let
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Auditoren_Stammdaten')/items"
        & "?$select=ID,Title,Nachname,Vorname,Geschlecht,Email_Adresse,Land_Name,Land_kurz,PLZ"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),
    Umbenannt = Table.RenameColumns(Quelle, {
        {"ID",         "Auditor_SP_ID"},
        {"Title",      "Auditor_Nummer"},
        {"Geschlecht", "Anrede"}
    }),
    Typen = Table.TransformColumnTypes(Umbenannt, {
        {"Auditor_SP_ID",  Int64.Type},
        {"Auditor_Nummer", type text},
        {"Nachname",       type text},
        {"Vorname",        type text},
        {"Anrede",         type text},
        {"Email_Adresse",  type text},
        {"Land_Name",      type text},
        {"Land_kurz",      type text},
        {"PLZ",            type text}
    }),
    OhneErrors = Table.ReplaceErrorValues(
        Typen,
        List.Transform(Table.ColumnNames(Typen), each {_, null})
    )
in
    OhneErrors;

shared Qualifikations_Regelwerk = let
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Regelwerk')/items"
        & "?$select=ID,Title,Berufung_Monate,Anzahl_Monitorings,Anzahl_Audits,"
        & "Anzahl_Stand_der_Technik_Schulun,Anzahl_ERFA"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),
    Umbenannt = Table.RenameColumns(Quelle, {
        {"ID",    "Quali_SP_ID"},
        {"Title", "Qualifikation_Name"}
    }),
    Typen = Table.TransformColumnTypes(Umbenannt, {
        {"Quali_SP_ID",                      Int64.Type},
        {"Qualifikation_Name",               type text},
        {"Berufung_Monate",                  Int64.Type},
        {"Anzahl_Monitorings",               Int64.Type},
        {"Anzahl_Audits",                    Int64.Type},
        {"Anzahl_Stand_der_Technik_Schulun", Int64.Type},
        {"Anzahl_ERFA",                      Int64.Type}
    }),
    OhneErrors = Table.ReplaceErrorValues(
        Typen,
        List.Transform(Table.ColumnNames(Typen), each {_, null})
    )
in
    OhneErrors;

shared Qualifikations_Status = let
    // $expand=Auditor_Lookup erfordert $select mit Auditor_Lookup/ID.
    // Ohne dieses Unterfeld liefert SharePoint einen 400-Fehler.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$select=ID,Qualifikation0Id,G_x00fc_ltig_ab,G_x00fc_ltig_bis,"
        & "quali_log,approval_lookup_idId,Status,"
        & "Datum_Erstberufung_Assistant_Tra,Datum_Erstberufung_Co_Auditor,"
        & "Datum_Erstberufung_Lead_Auditor,"
        & "Auditor_Lookup/ID"
        & "&$expand=Auditor_Lookup"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),
    // OData v4 liefert expanded Lookups als Table (nicht Record).
    // Erste Zeile der Table auslesen; leer = null.
    MitAuditor = Table.AddColumn(
        Quelle,
        "Auditor_SP_ID",
        each let t = [Auditor_Lookup]
             in if Table.IsEmpty(t) then null else t{0}[ID],
        Int64.Type
    ),
    OhneRoheTabelle = Table.RemoveColumns(MitAuditor, {"Auditor_Lookup"}),
    Umbenannt = Table.RenameColumns(OhneRoheTabelle, {
        {"Qualifikation0Id",     "Quali_SP_ID"},
        {"approval_lookup_idId", "Approval_SP_ID"}
    }),
    Typen = Table.TransformColumnTypes(Umbenannt, {
        {"ID",                               Int64.Type},
        {"Auditor_SP_ID",                    Int64.Type},
        {"Quali_SP_ID",                      Int64.Type},
        {"Approval_SP_ID",                   Int64.Type},
        {"Status",                           type text},
        {"G\u00fcltig_ab",                        type date},
        {"G\u00fcltig_bis",                       type date},
        {"Datum_Erstberufung_Assistant_Tra", type date},
        {"Datum_Erstberufung_Co_Auditor",    type date},
        {"Datum_Erstberufung_Lead_Auditor",  type date},
        {"quali_log",                        type text}
    }),
    OhneErrors = Table.ReplaceErrorValues(
        Typen,
        List.Transform(Table.ColumnNames(Typen), each {_, null})
    ),
    // Zeilen ohne Auditor- oder Qualifikations-Verknüpfung herausfiltern –
    // verhindert leere Auditor/Berufung-Zeilen im Power-BI-Bericht.
    GefilterteZeilen = Table.SelectRows(OhneErrors,
        each [Auditor_SP_ID] <> null and [Quali_SP_ID] <> null
    ),
    // "Id" (Tippfehler) und "ID" waren beide vorhanden → nur "ID" behalten.
    #"Neu angeordnete Spalten" = Table.ReorderColumns(GefilterteZeilen, {
        "ID", "Quali_SP_ID", "Auditor_SP_ID", "G\u00fcltig_ab", "G\u00fcltig_bis",
        "quali_log", "Approval_SP_ID", "Status",
        "Datum_Erstberufung_Assistant_Tra", "Datum_Erstberufung_Co_Auditor",
        "Datum_Erstberufung_Lead_Auditor"
    })
in
    #"Neu angeordnete Spalten";

shared approval_log = let
    // Auditor_LookupId / Qualifikation_LookupId sind direkte Integer-Felder.
    // Auditor_Lookup / Qualifikation_Lookup werden via $expand für den Textwert geladen.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('approval_log')/items"
        & "?$select=ID,Auditor_LookupId,Qualifikation_LookupId,Art,Datum,Kommentar,Status,"
        & "formaleReberufung,G_x00fc_ltigkeitderformalenReber,abweichendeDauer,Created,"
        & "Auditor_Lookup/Title,Qualifikation_Lookup/Title"
        & "&$expand=Auditor_Lookup,Qualifikation_Lookup"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),
    // Lookup-Record-Spalten auf den Textwert (Title) reduzieren
    ExpandAuditor = Table.ExpandRecordColumn(
        Quelle, "Auditor_Lookup", {"Title"}, {"Auditor_Nachname"}
    ),
    ExpandQuali = Table.ExpandRecordColumn(
        ExpandAuditor, "Qualifikation_Lookup", {"Title"}, {"Qualifikation_Name"}
    ),
    Umbenannt = Table.RenameColumns(ExpandQuali, {
        {"ID",                         "Approval_SP_ID"},
        {"Auditor_LookupId",           "Auditor_SP_ID"},
        {"Qualifikation_LookupId",     "Quali_SP_ID"},
        {"Datum",                      "Datum_CL"},
        {"formaleReberufung",          "gültig_von"},
        {"GültigkeitderformalenReber", "gültig_bis"},
        {"Created",                    "Erstellt"}
    }),
    Typen = Table.TransformColumnTypes(Umbenannt, {
        {"Approval_SP_ID",     Int64.Type},
        {"Auditor_SP_ID",      Int64.Type},
        {"Quali_SP_ID",        Int64.Type},
        {"Datum_CL",           type date},
        {"gültig_von",         type date},
        {"gültig_bis",         type date},
        {"Erstellt",           type datetime},
        {"abweichendeDauer",   type number},
        {"Art",                type text},
        {"Status",             type text},
        {"Kommentar",          type text},
        {"Auditor_Nachname",   type text},
        {"Qualifikation_Name", type text}
    }),
    OhneErrors = Table.ReplaceErrorValues(
        Typen,
        List.Transform(Table.ColumnNames(Typen), each {_, null})
    )
in
    OhneErrors;

// ============================================================
// Datum-Tabelle (Kalenderdimension)
//
// Zweck: Ersetzt die automatische Auto Date/Time-Hierarchie
//        von Power BI, die für Gültig_bis-Felder leere Zeilen
//        (Phantomzeilen) ohne Auditor/Berufung erzeugt.
//
// Einrichtung in Power BI Desktop:
//   1. Datei → Optionen → Aktuelle Datei → Datenladen
//      → "Auto Datum/Uhrzeit" DEAKTIVIEREN
//   2. Beziehung erstellen:
//      Datum[Datum]  →  Qualifikations_Status[Gültig_bis]
//      (1:n, Einzelrichtung: Datum → Qualifikations_Status)
//   3. Im Visual folgende Spalten verwenden (statt alter Gültig_bis-Hierarchie):
//        Jahr | Halbjahr | Quartal | KW | Monat_Name | Jahresmonat | Tag
//      Wichtig – "Sortierung nach Spalte" setzen:
//        Monat_Name  → Monat_Nr
//        Wochentag   → Wochentag_Nr
// ============================================================
shared Datum = let
    StartDatum  = #date(2015, 1, 1),
    EndDatum    = #date(2035, 12, 31),
    AnzahlTage  = Duration.Days(EndDatum - StartDatum) + 1,
    Datumsliste = List.Dates(StartDatum, AnzahlTage, #duration(1, 0, 0, 0)),
    Tabelle = Table.FromList(
        Datumsliste,
        Splitter.SplitByNothing(),
        type table [Datum = date]
    ),
    MitJahr        = Table.AddColumn(Tabelle,        "Jahr",         each Date.Year([Datum]),                                                                    Int64.Type),
    MitHalbjahr    = Table.AddColumn(MitJahr,        "Halbjahr",     each if Date.Month([Datum]) <= 6 then "H1" else "H2",                                        type text),
    MitQuartal     = Table.AddColumn(MitHalbjahr,    "Quartal",      each "Q" & Text.From(Date.QuarterOfYear([Datum])),                                           type text),
    MitKW          = Table.AddColumn(MitQuartal,     "KW",           each Date.WeekOfYear([Datum], Day.Monday),                                                   Int64.Type),
    MitMonatNr     = Table.AddColumn(MitKW,          "Monat_Nr",     each Date.Month([Datum]),                                                                    Int64.Type),
    MitMonatName   = Table.AddColumn(MitMonatNr,     "Monat_Name",   each Date.ToText([Datum], "MMMM", "de-DE"),                                                  type text),
    MitJahresmonat = Table.AddColumn(MitMonatName,   "Jahresmonat",  each Text.From(Date.Year([Datum])) & "-" & Text.PadStart(Text.From(Date.Month([Datum])), 2, "0"), type text),
    MitTag         = Table.AddColumn(MitJahresmonat, "Tag",          each Date.Day([Datum]),                                                                      Int64.Type),
    MitWochentag   = Table.AddColumn(MitTag,         "Wochentag",    each Date.ToText([Datum], "dddd", "de-DE"),                                                  type text),
    // Wochentag_Nr: 1 = Montag … 7 = Sonntag
    // "Sortierung nach Spalte" für Wochentag → Wochentag_Nr setzen!
    MitWochentagNr = Table.AddColumn(MitWochentag,   "Wochentag_Nr", each Date.DayOfWeek([Datum], Day.Monday) + 1,                                                Int64.Type)
in
    MitWochentagNr;

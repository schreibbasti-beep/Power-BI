section Section1;

shared approval_log = let
    // Lookup-IDs und Textwerte werden gemeinsam via $expand geladen.
    // GültigkeitderformalenReber hat einen Umlaut – wird über NormalizeUmlaute behandelt.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('approval_log')/items"
        & "?$select=ID,Auditor_Lookup/Id,Auditor_Lookup/Title,"
        & "Qualifikation_Lookup/Id,Qualifikation_Lookup/Title,"
        & "Art,Datum,Kommentar,Status,"
        & "formaleReberufung,G_x00fc_ltigkeitderformalenReber,abweichendeDauer,Created"
        & "&$expand=Auditor_Lookup,Qualifikation_Lookup"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),

    // Lookup-Record-Spalten auf ID und Textwert expandieren
    ExpandAuditor = Table.ExpandRecordColumn(
        Quelle, "Auditor_Lookup", {"Id", "Title"}, {"Auditor_SP_ID", "Auditor_Nachname"}
    ),
    ExpandQuali = Table.ExpandRecordColumn(
        ExpandAuditor, "Qualifikation_Lookup", {"Id", "Title"}, {"Quali_SP_ID", "Qualifikation_Name"}
    ),

    // Umlaut-kodierte Spaltennamen normalisieren
    NormalizeUmlaute = let
        Cols = Table.ColumnNames(ExpandQuali),
        RenameList = List.Select(
            {{"G_x00fc_ltigkeitderformalenReber", "GültigkeitderformalenReber"}},
            each List.Contains(Cols, _{0})
        )
    in
        if List.IsEmpty(RenameList) then ExpandQuali
        else Table.RenameColumns(ExpandQuali, RenameList),

    Umbenannt = Table.RenameColumns(NormalizeUmlaute, {
        {"Datum",                      "Datum_CL"},
        {"formaleReberufung",          "gültig_von"},
        {"GültigkeitderformalenReber", "gültig_bis"},
        {"Created",                    "Erstellt"}
    }),

    Typen = Table.TransformColumnTypes(Umbenannt, {
        {"ID",                 Int64.Type},
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

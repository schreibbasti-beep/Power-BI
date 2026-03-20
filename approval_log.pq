section Section1;

shared approval_log = let
    // Auditor_Lookup / Qualifikation_Lookup sind SharePoint-Lookup-Spalten.
    // Der Textwert wird via $expand geladen und danach als Record expandiert.
    // GültigkeitderformalenReber hat einen Umlaut – wird wie in Qualifikations_Status
    // über NormalizeUmlaute behandelt.
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

    // Lookup-Record-Spalten auf den Title-Wert reduzieren
    ExpandAuditor = Table.ExpandRecordColumn(
        Quelle, "Auditor_Lookup", {"Title"}, {"Auditor_Lookup"}
    ),
    ExpandQuali = Table.ExpandRecordColumn(
        ExpandAuditor, "Qualifikation_Lookup", {"Title"}, {"Qualifikation_Lookup"}
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

    OhneErrors = Table.ReplaceErrorValues(
        NormalizeUmlaute,
        List.Transform(Table.ColumnNames(NormalizeUmlaute), each {_, null})
    ),

    Umbenannt = Table.RenameColumns(OhneErrors, {
        {"Auditor_LookupId",           "Auditor_SP_ID"},
        {"Qualifikation_LookupId",     "Quali_SP_ID"},
        {"Datum",                      "Datum_CL"},
        {"formaleReberufung",          "gültig_von"},
        {"GültigkeitderformalenReber", "gültig_bis"},
        {"Created",                    "Erstellt"},
        {"Auditor_Lookup",             "Auditor_Nachname"},
        {"Qualifikation_Lookup",       "Qualifikation_Name"}
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
    })
in
    Typen;

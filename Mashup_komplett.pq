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

    OhneErrors = Table.ReplaceErrorValues(
        Quelle,
        List.Transform(Table.ColumnNames(Quelle), each {_, null})
    ),

    Umbenannt = Table.RenameColumns(OhneErrors, {
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
    })
in
    Typen;

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

    OhneErrors = Table.ReplaceErrorValues(
        Quelle,
        List.Transform(Table.ColumnNames(Quelle), each {_, null})
    ),

    Umbenannt = Table.RenameColumns(OhneErrors, {
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
    })
in
    Typen;

shared Qualifikations_Status = let
    // Hinweis: Spalten mit Umlauten (Gültig_ab, Gültig_bis) werden nach dem Laden
    // ggf. als G_x00fc_ltig_ab / G_x00fc_ltig_bis zurückgegeben (SharePoint-interne
    // Kodierung). Der Rename-Schritt "NormalizeUmlaute" behandelt beide Varianten.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$select=ID,Auditor_LookupId,Qualifikation0Id,G_x00fc_ltig_ab,G_x00fc_ltig_bis,"
        & "quali_log,approval_lookup_idId,Status,"
        & "Datum_Erstberufung_Assistant_Tra,Datum_Erstberufung_Co_Auditor,Datum_Erstberufung_Lead_Auditor"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),

    // Umlaut-kodierte Spaltennamen normalisieren (falls SharePoint sie enkodiert zurückgibt)
    NormalizeUmlaute = let
        Cols = Table.ColumnNames(Quelle),
        RenameList = List.Select(
            {
                {"G_x00fc_ltig_ab",  "Gültig_ab"},
                {"G_x00fc_ltig_bis", "Gültig_bis"}
            },
            each List.Contains(Cols, _{0})
        )
    in
        if List.IsEmpty(RenameList) then Quelle
        else Table.RenameColumns(Quelle, RenameList),

    OhneErrors = Table.ReplaceErrorValues(
        NormalizeUmlaute,
        List.Transform(Table.ColumnNames(NormalizeUmlaute), each {_, null})
    ),

    Umbenannt = Table.RenameColumns(OhneErrors, {
        {"Auditor_LookupId",     "Auditor_SP_ID"},
        {"Qualifikation0Id",     "Quali_SP_ID"},
        {"approval_lookup_idId", "Approval_SP_ID"}
    }),

    Typen = Table.TransformColumnTypes(Umbenannt, {
        {"ID",                               Int64.Type},
        {"Auditor_SP_ID",                    Int64.Type},
        {"Quali_SP_ID",                      Int64.Type},
        {"Approval_SP_ID",                   Int64.Type},
        {"Status",                           type text},
        {"Gültig_ab",                        type date},
        {"Gültig_bis",                       type date},
        {"Datum_Erstberufung_Assistant_Tra", type date},
        {"Datum_Erstberufung_Co_Auditor",    type date},
        {"Datum_Erstberufung_Lead_Auditor",  type date},
        {"quali_log",                        type text}
    })
in
    Typen;

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

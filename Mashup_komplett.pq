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
    // Lookup-IDs werden via $expand/{ColumnName}/Id geladen, da SharePoint OData
    // den direkten $select=...LookupId-Zugriff nicht zuverlässig unterstützt.
    // Spalten mit Umlauten (Gültig_ab/bis) werden über NormalizeUmlaute behandelt.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$select=ID,Auditor_Lookup/Id,Qualifikation0/Id,approval_lookup_id/Id,"
        & "G_x00fc_ltig_ab,G_x00fc_ltig_bis,quali_log,Status,"
        & "Datum_Erstberufung_Assistant_Tra,Datum_Erstberufung_Co_Auditor,Datum_Erstberufung_Lead_Auditor"
        & "&$expand=Auditor_Lookup,Qualifikation0,approval_lookup_id"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),

    // Lookup-Record-Spalten auf die ID reduzieren
    ExpandAuditor  = Table.ExpandRecordColumn(Quelle,        "Auditor_Lookup",    {"Id"}, {"Auditor_SP_ID"}),
    ExpandQuali    = Table.ExpandRecordColumn(ExpandAuditor,  "Qualifikation0",    {"Id"}, {"Quali_SP_ID"}),
    ExpandApproval = Table.ExpandRecordColumn(ExpandQuali,    "approval_lookup_id",{"Id"}, {"Approval_SP_ID"}),

    // Umlaut-kodierte Spaltennamen normalisieren
    NormalizeUmlaute = let
        Cols = Table.ColumnNames(ExpandApproval),
        RenameList = List.Select(
            {
                {"G_x00fc_ltig_ab",  "Gültig_ab"},
                {"G_x00fc_ltig_bis", "Gültig_bis"}
            },
            each List.Contains(Cols, _{0})
        )
    in
        if List.IsEmpty(RenameList) then ExpandApproval
        else Table.RenameColumns(ExpandApproval, RenameList),

    Typen = Table.TransformColumnTypes(NormalizeUmlaute, {
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
    }),

    OhneErrors = Table.ReplaceErrorValues(
        Typen,
        List.Transform(Table.ColumnNames(Typen), each {_, null})
    )
in
    OhneErrors;

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

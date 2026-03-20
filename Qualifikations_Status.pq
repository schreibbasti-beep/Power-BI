section Section1;

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

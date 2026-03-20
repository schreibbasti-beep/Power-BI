section Section1;

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

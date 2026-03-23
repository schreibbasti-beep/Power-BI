section Section1;

shared Qualifikations_Status = let
    // $expand erfordert $select mit Unterfeldern (Auditor_Lookup/ID).
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

    ExpandAuditor = Table.ExpandRecordColumn(
        Quelle, "Auditor_Lookup", {"ID"}, {"Auditor_SP_ID"}
    ),

    Umbenannt = Table.RenameColumns(ExpandAuditor, {
        {"Qualifikation0Id",     "Quali_SP_ID"},
        {"approval_lookup_idId", "Approval_SP_ID"}
    }),

    Typen = Table.TransformColumnTypes(Umbenannt, {
        {"ID",                               Int64.Type},
        {"Auditor_SP_ID",                    Int64.Type},
        {"Quali_SP_ID",                      Int64.Type},
        {"Approval_SP_ID",                   Int64.Type},
        {"Status",                           type text},
        {"G_x00fc_ltig_ab",                  type date},
        {"G_x00fc_ltig_bis",                 type date},
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

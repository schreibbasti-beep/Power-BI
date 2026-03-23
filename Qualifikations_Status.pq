section Section1;

shared Qualifikations_Status = let
    // Kein $select: Auditor_LookupId ist ein von Power Query
    // auto-generierter Companion-Key und kein gültiger SharePoint-
    // REST-Feldname – würde in $select immer null liefern.
    // Stattdessen alle Felder laden und danach filtern.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$top=5000",
        null,
        [Implementation = "2.0"]
    ),

    Ausgewählt = Table.SelectColumns(Quelle, {
        "ID",
        "Auditor_LookupId",
        "Qualifikation0Id",
        "Gültig_ab",
        "Gültig_bis",
        "quali_log",
        "approval_lookup_idId",
        "Status",
        "Datum_Erstberufung_Assistant_Tra",
        "Datum_Erstberufung_Co_Auditor",
        "Datum_Erstberufung_Lead_Auditor"
    }),

    Umbenannt = Table.RenameColumns(Ausgewählt, {
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
    }),

    OhneErrors = Table.ReplaceErrorValues(
        Typen,
        List.Transform(Table.ColumnNames(Typen), each {_, null})
    )
in
    OhneErrors;

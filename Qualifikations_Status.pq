section Section1;

shared Qualifikations_Status = let
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Raw = Quelle{[Title="Qualifikations_Status"]}[Items],

    OhneErrors = Table.ReplaceErrorValues(
        Raw,
        List.Transform(Table.ColumnNames(Raw), each {_, null})
    ),

    Gefiltert = Table.SelectColumns(OhneErrors, {
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

    Umbenannt = Table.RenameColumns(Gefiltert, {
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

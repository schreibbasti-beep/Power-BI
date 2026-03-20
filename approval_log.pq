section Section1;

shared approval_log = let
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Log_Raw = Quelle{[Title="approval_log"]}[Items],

    OhneErrors = Table.ReplaceErrorValues(
        Log_Raw,
        List.Transform(Table.ColumnNames(Log_Raw), each {_, null})
    ),

    Gefiltert = Table.SelectColumns(OhneErrors, {
        "ID",
        "Auditor_LookupId",
        "Qualifikation_LookupId",
        "Art",
        "Datum",
        "Kommentar",
        "Status",
        "formaleReberufung",
        "GültigkeitderformalenReber",
        "abweichendeDauer",
        "Created",
        "Auditor_Lookup",
        "Qualifikation_Lookup"
    }),

    Umbenannt = Table.RenameColumns(Gefiltert, {
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

section Section1;

shared Qualifikations_Regelwerk = let
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Raw = Quelle{[Title="Qualifikations_Regelwerk"]}[Items],

    OhneErrors = Table.ReplaceErrorValues(
        Raw,
        List.Transform(Table.ColumnNames(Raw), each {_, null})
    ),

    Gefiltert = Table.SelectColumns(OhneErrors, {
        "ID",
        "Title",
        "Berufung_Monate",
        "Anzahl_Monitorings",
        "Anzahl_Audits",
        "Anzahl_Stand_der_Technik_Schulun",
        "Anzahl_ERFA"
    }),

    Umbenannt = Table.RenameColumns(Gefiltert, {
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

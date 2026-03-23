section Section1;

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

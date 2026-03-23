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

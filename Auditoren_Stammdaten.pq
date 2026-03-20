section Section1;

shared Auditoren_Stammdaten = let
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Raw = Quelle{[Title="Auditoren_Stammdaten"]}[Items],

    OhneErrors = Table.ReplaceErrorValues(
        Raw,
        List.Transform(Table.ColumnNames(Raw), each {_, null})
    ),

    Gefiltert = Table.SelectColumns(OhneErrors, {
        "ID",
        "Title",
        "Nachname",
        "Vorname",
        "Geschlecht",
        "Email_Adresse",
        "Land_Name",
        "Land_kurz",
        "PLZ"
    }),

    Umbenannt = Table.RenameColumns(Gefiltert, {
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
    })
in
    Typen;

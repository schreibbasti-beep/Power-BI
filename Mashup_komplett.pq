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

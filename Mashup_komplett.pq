section Section1;

shared Auditoren_Stammdaten = let
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Auditoren_Raw = Quelle{[Title="Auditoren_Stammdaten"]}[Items],
    GewuenschteSpalten = {"ID", "Title", "Nachname", "Vorname", "Geschlecht",
                          "Email_Adresse", "Land_kurz", "Land_Name", "PLZ"},
    VorhandeneSpalten = List.Intersect({
        GewuenschteSpalten,
        Table.ColumnNames(Auditoren_Raw)
    }),
    Gefiltert = Table.SelectColumns(Auditoren_Raw, VorhandeneSpalten),
    Umbenannt = Table.RenameColumns(
        Gefiltert,
        List.Select(
            {
                {"Title",      "Auditor_Nummer"},
                {"ID",         "Auditor_SP_ID"},
                {"Geschlecht", "Anrede"}
            },
            each List.Contains(Table.ColumnNames(Gefiltert), _{0})
        )
    ),
    AlleTypen = {
        {"Auditor_SP_ID",  Int64.Type},
        {"Auditor_Nummer", type text},
        {"Nachname",       type text},
        {"Vorname",        type text},
        {"Anrede",         type text},
        {"Email_Adresse",  type text},
        {"Land_kurz",      type text},
        {"Land_Name",      type text},
        {"PLZ",            type text}
    },
    GueltigeTypen = List.Select(
        AlleTypen,
        each List.Contains(Table.ColumnNames(Umbenannt), _{0})
    ),
    Typen = Table.TransformColumnTypes(Umbenannt, GueltigeTypen)
in
    Typen;

shared Qualifikations_Regelwerk = let
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Regelwerk_Raw = Quelle{[Title="Qualifikations_Regelwerk"]}[Items],
    GewuenschteSpalten = {
        "ID", "Title", "Berufung_Monate", "Anzahl_Monitorings",
        "Anzahl_Audits", "Anzahl_Stand_der_Technik_Schulun", "Anzahl_ERFA"
    },
    VorhandeneSpalten = List.Intersect({
        GewuenschteSpalten,
        Table.ColumnNames(Regelwerk_Raw)
    }),
    Gefiltert = Table.SelectColumns(Regelwerk_Raw, VorhandeneSpalten),
    Umbenannt = Table.RenameColumns(
        Gefiltert,
        List.Select(
            {
                {"Title", "Qualifikation_Name"},
                {"ID",    "Quali_SP_ID"}
            },
            each List.Contains(Table.ColumnNames(Gefiltert), _{0})
        )
    ),
    AlleTypen = {
        {"Quali_SP_ID",                         Int64.Type},
        {"Qualifikation_Name",                  type text},
        {"Berufung_Monate",                     Int64.Type},
        {"Anzahl_Monitorings",                  Int64.Type},
        {"Anzahl_Audits",                       Int64.Type},
        {"Anzahl_Stand_der_Technik_Schulun",    Int64.Type},
        {"Anzahl_ERFA",                         Int64.Type}
    },
    GueltigeTypen = List.Select(
        AlleTypen,
        each List.Contains(Table.ColumnNames(Umbenannt), _{0})
    ),
    Typen = Table.TransformColumnTypes(Umbenannt, GueltigeTypen)
in
    Typen;

shared Qualifikations_Status = let
    BaseUrl = "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/Web/Lists/GetByTitle('Qualifikations_Status')/Items",

    // Kein $select – Gültig_ab wird im $select nicht akzeptiert (interner Name ≠ OData-Name)
    // Spaltenfilterung erfolgt komplett in Power Query
    Quelle = OData.Feed(
        BaseUrl & "?$top=5000",
        null,
        [Implementation = "2.0"]
    ),

    // Navigations-/Lookup-Expansionen abfangen
    OhneErrors = Table.ReplaceErrorValues(
        Quelle,
        List.Transform(Table.ColumnNames(Quelle), each {_, null})
    ),

    // Exakte Spaltennamen laut OData-Response (verifiziert via Diagnose-Abfrage)
    GewuenschteSpalten = {
        "ID",
        "Auditor_LookupId",
        "Qualifikation0Id",
        "Status",
        "Gültig_ab",
        "Gültig_bis",
        "approval_lookup_idId",
        "Datum_Erstberufung_Assistant_Tra",
        "Datum_Erstberufung_Co_Auditor",
        "Datum_Erstberufung_Lead_Auditor",
        "quali_log"
    },
    VorhandeneSpalten = List.Intersect({
        GewuenschteSpalten,
        Table.ColumnNames(OhneErrors)
    }),
    Gefiltert = Table.SelectColumns(OhneErrors, VorhandeneSpalten),

    Umbenannt = Table.RenameColumns(
        Gefiltert,
        List.Select(
            {
                {"Auditor_LookupId",     "Auditor_SP_ID"},
                {"approval_lookup_idId", "Approval_SP_ID"}
            },
            each List.Contains(Table.ColumnNames(Gefiltert), _{0})
        )
    ),

    AlleTypen = {
        {"ID",                               Int64.Type},
        {"Auditor_SP_ID",                    Int64.Type},
        {"Approval_SP_ID",                   Int64.Type},
        {"Qualifikation0Id",                 type text},
        {"Status",                           type text},
        {"Gültig_ab",                        type date},
        {"Gültig_bis",                       type date},
        {"Datum_Erstberufung_Assistant_Tra", type date},
        {"Datum_Erstberufung_Co_Auditor",    type date},
        {"Datum_Erstberufung_Lead_Auditor",  type date},
        {"quali_log",                        type text}
    },
    GueltigeTypen = List.Select(
        AlleTypen,
        each List.Contains(Table.ColumnNames(Umbenannt), _{0})
    ),
    Typen = Table.TransformColumnTypes(Umbenannt, GueltigeTypen)
in
    Typen;

shared approval_log = let
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Log_Raw = Quelle{[Title="approval_log"]}[Items],
    GewuenschteSpalten = {
        "ID", "Auditor_Lookup", "Qualifikation_Lookup",
        "Art", "Datum", "formaleReberufung", "GültigkeitderformalenReber",
        "Status", "Kommentar", "Erstellt", "abweichendeDauer",
        "Auditor_Lookup_Nachname: ID", "Qualifikation_Lookup_Titel: ID"
    },
    VorhandeneSpalten = List.Intersect({
        GewuenschteSpalten,
        Table.ColumnNames(Log_Raw)
    }),
    Gefiltert = Table.SelectColumns(Log_Raw, VorhandeneSpalten),
    Umbenannt = Table.RenameColumns(
        Gefiltert,
        List.Select(
            {
                {"Auditor_Lookup_Nachname: ID",     "Auditor_SP_ID"},
                {"Qualifikation_Lookup_Titel: ID",  "Quali_SP_ID"},
                {"Auditor_Lookup",                  "Auditor_Nachname"},
                {"Qualifikation_Lookup",            "Qualifikation_Name"},
                {"GültigkeitderformalenReber",      "gültig_bis"},
                {"formaleReberufung",               "gültig_von"},
                {"Datum",                           "Datum_CL"}
            },
            each List.Contains(Table.ColumnNames(Gefiltert), _{0})
        )
    ),
    AlleTypen = {
        {"ID",                Int64.Type},
        {"Auditor_SP_ID",     Int64.Type},
        {"Quali_SP_ID",       Int64.Type},
        {"Datum_CL",          type date},
        {"gueltig_von",       type date},
        {"gueltig_bis",       type date},
        {"Erstellt",          type datetime},
        {"abweichendeDauer",  type number},
        {"Art",               type text},
        {"Status",            type text},
        {"Kommentar",         type text},
        {"Auditor_Nachname",  type text},
        {"Qualifikation_Name",type text}
    },
    GueltigeTypen = List.Select(
        AlleTypen,
        each List.Contains(Table.ColumnNames(Umbenannt), _{0})
    ),
    Typen = Table.TransformColumnTypes(Umbenannt, GueltigeTypen)
in
    Typen;

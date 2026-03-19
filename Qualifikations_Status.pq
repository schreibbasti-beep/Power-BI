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

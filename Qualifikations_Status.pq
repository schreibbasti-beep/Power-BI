shared Qualifikations_Status = let
    // SharePoint.Tables statt OData.Feed – vermeidet Auth-Probleme ("Unerwarteter Dokumenttyp")
    // und nutzt Anzeigenamen (Gültig_ab funktioniert direkt)
    Quelle = SharePoint.Tables(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation",
        [ApiVersion = 15]
    ),
    Raw = Quelle{[Title="Qualifikations_Status"]}[Items],

    OhneErrors = Table.ReplaceErrorValues(
        Raw,
        List.Transform(Table.ColumnNames(Raw), each {_, null})
    ),

    // Lookup-IDs erscheinen in SharePoint.Tables als "FeldName: ID"
    // Mehrere Kandidaten angegeben – nur vorhandene werden übernommen
    GewuenschteSpalten = {
        "ID",
        "Auditor_Lookup: ID",       // Lookup-ID für Auditor
        "Qualifikation0: ID",       // Lookup-ID für Qualifikation
        "Qualifikation0Id",         // Fallback (falls direkt vorhanden)
        "Status",
        "Gültig_ab",
        "Gültig_bis",
        "approval_lookup_id: ID",   // Lookup-ID für Approval
        "approval_lookup_idId",     // Fallback
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
                {"Auditor_Lookup: ID",      "Auditor_SP_ID"},
                {"Auditor_LookupId",        "Auditor_SP_ID"},
                {"Qualifikation0: ID",      "Qualifikation0Id"},
                {"approval_lookup_id: ID",  "Approval_SP_ID"},
                {"approval_lookup_idId",    "Approval_SP_ID"}
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

section Section1;

shared Qualifikations_Status = let
    // $expand=Auditor_Lookup erfordert $select mit Auditor_Lookup/ID.
    // Ohne dieses Unterfeld liefert SharePoint einen 400-Fehler.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$select=ID,Qualifikation0Id,G_x00fc_ltig_ab,G_x00fc_ltig_bis,"
        & "quali_log,approval_lookup_idId,Status,"
        & "Datum_Erstberufung_Assistant_Tra,Datum_Erstberufung_Co_Auditor,"
        & "Datum_Erstberufung_Lead_Auditor,"
        & "Auditor_Lookup/ID"
        & "&$expand=Auditor_Lookup"
        & "&$top=5000",
        null,
        [Implementation = "2.0"]
    ),
    // OData v4 liefert expanded Lookups als Table (nicht Record).
    // Erste Zeile der Table auslesen; leer = null.
    MitAuditor = Table.AddColumn(
        Quelle,
        "Auditor_SP_ID",
        each let t = [Auditor_Lookup]
             in if Table.IsEmpty(t) then null else t{0}[ID],
        Int64.Type
    ),
    OhneRoheTabelle = Table.RemoveColumns(MitAuditor, {"Auditor_Lookup"}),
    Umbenannt = Table.RenameColumns(OhneRoheTabelle, {
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
    }),
    OhneErrors = Table.ReplaceErrorValues(
        Typen,
        List.Transform(Table.ColumnNames(Typen), each {_, null})
    ),
    // Zeilen ohne Auditor-Verknüpfung herausfiltern –
    // verhindert leere Auditor/Berufung-Zeilen im Power-BI-Bericht.
    GefilterteZeilen = Table.SelectRows(OhneErrors, each [Auditor_SP_ID] <> null),
    // "Id" (Tippfehler) und "ID" waren beide vorhanden → nur "ID" behalten.
    #"Neu angeordnete Spalten" = Table.ReorderColumns(GefilterteZeilen, {
        "ID", "Quali_SP_ID", "Auditor_SP_ID", "Gültig_ab", "Gültig_bis",
        "quali_log", "Approval_SP_ID", "Status",
        "Datum_Erstberufung_Assistant_Tra", "Datum_Erstberufung_Co_Auditor",
        "Datum_Erstberufung_Lead_Auditor"
    })
in
    #"Neu angeordnete Spalten";

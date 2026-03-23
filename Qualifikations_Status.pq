section Section1;

// DIAGNOSE: Expandiert das primäre Lookup-Feld Auditor_Lookup_Nachname_x003a__x
// und listet die Felder des zurückgegebenen Records auf.
shared Qualifikations_Status = let
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$expand=Auditor_Lookup_Nachname_x003a__x"
        & "&$top=5",
        null,
        [Implementation = "2.0"]
    ),

    // Ersten Record aus der Auditor-Spalte nehmen und dessen Felder auflisten
    ErsterRecord = Quelle{0}[Auditor_Lookup_Nachname_x003a__x],
    Felder = Record.FieldNames(ErsterRecord),
    AlsTabelle = Table.FromList(Felder, Splitter.SplitByNothing(), {"Feldname"})
in
    AlsTabelle;

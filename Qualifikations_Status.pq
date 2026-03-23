section Section1;

// DIAGNOSE: Expandiert Auditor_Lookup (bekannte Navigation Property)
// und zeigt alle Felder des zurückgegebenen Records.
shared Qualifikations_Status = let
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$expand=Auditor_Lookup"
        & "&$top=5",
        null,
        [Implementation = "2.0"]
    ),

    // Ersten Record aus der Auditor_Lookup-Spalte nehmen
    ErsterRecord = Quelle{0}[Auditor_Lookup],
    Felder = Record.FieldNames(ErsterRecord),
    AlsTabelle = Table.FromList(Felder, Splitter.SplitByNothing(), {"Feldname"})
in
    AlsTabelle;

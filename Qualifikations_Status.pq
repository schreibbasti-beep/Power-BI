section Section1;

// DIAGNOSE-QUERY: Lädt alle Spalten ohne $select, um die echten OData-Spaltennamen zu sehen.
// Schritt 1: Diese Version in Power BI laden und im Power Query Editor die Spaltennamen prüfen.
// Schritt 2: Den Auditor-Lookup-Spaltennamen notieren (suche nach Spalten, die "Auditor" enthalten).
// Schritt 3: Danach diese Query durch die finale Version ersetzen.
shared Qualifikations_Status = let
    // Kein $select – alle Felder laden, damit wir die echten Spaltennamen sehen.
    Quelle = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$top=5",
        null,
        [Implementation = "2.0"]
    ),

    // Nur die Spaltennamen zurückgeben – leichter zu lesen als eine volle Tabelle.
    Spalten = Table.ColumnNames(Quelle),
    AlsTabelle = Table.FromList(Spalten, Splitter.SplitByNothing(), {"Spaltenname"})
in
    AlsTabelle;

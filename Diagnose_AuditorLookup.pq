section Section1;

// Diagnose-Abfrage: Zeigt alle Feldnamen des expandierten Auditor_Lookup-Records.
// Ergebnis: Liste der tatsächlichen Feldnamen -> zum Korrigieren von ExpandRecordColumn.
shared Diagnose_AuditorFelder = let
    // Variante A: $select mit /ID (Großbuchstaben)
    QuelleA = OData.Feed(
        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
        & "?$select=ID,Auditor_Lookup/ID,Auditor_Lookup/Id,Auditor_Lookup/Title"
        & "&$expand=Auditor_Lookup"
        & "&$top=3",
        null,
        [Implementation = "2.0"]
    ),

    // Ersten Record aus Auditor_Lookup-Spalte holen
    ErsterRecord = QuelleA{0}[Auditor_Lookup],

    // Alle vorhandenen Feldnamen anzeigen
    FeldNamen = Record.FieldNames(ErsterRecord),

    // Und die Werte der Felder
    FeldWerte = Record.ToTable(ErsterRecord)
in
    FeldWerte;

// Variante B: Ohne $select testen ob SharePoint es dann doch akzeptiert
// (nur auskommentiert als Reserve)
//shared Diagnose_OhneSelect = let
//    Quelle = OData.Feed(
//        "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
//        & "/_api/lists/getbytitle('Qualifikations_Status')/items"
//        & "?$expand=Auditor_Lookup"
//        & "&$top=3",
//        null,
//        [Implementation = "2.0"]
//    ),
//    Erster = Quelle{0}[Auditor_Lookup]
//in
//    Erster;

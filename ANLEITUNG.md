# Power BI Dashboard – Auditor-Qualifikationen
## Vollständige Schritt-für-Schritt-Aufbauanleitung

**Version:** 1.0 · **Stand:** März 2026  
**Umgebung:** Power BI Service (Pro-Lizenz) · SharePoint Online  
**Datenquelle:** `https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation`

---

## Inhaltsverzeichnis

1. [Überblick & Zielbild](#1-überblick--zielbild)
2. [Voraussetzungen](#2-voraussetzungen)
3. [Schritt 1 – SharePoint-Datenanbindung](#schritt-1--sharepoint-datenanbindung)
4. [Schritt 2 – Datenmodell & Beziehungen](#schritt-2--datenmodell--beziehungen)
5. [Schritt 3 – Korrekturlogik (Power Query M)](#schritt-3--korrekturlogik-power-query-m)
6. [Schritt 4 – DAX-Formeln](#schritt-4--dax-formeln)
7. [Schritt 5 – Dashboard-Visualisierung](#schritt-5--dashboard-visualisierung)
8. [Schritt 6 – Slicer & Filter](#schritt-6--slicer--filter)
9. [Schritt 7 – Echtzeit-Aktualisierung](#schritt-7--echtzeit-aktualisierung)
10. [Schritt 8 – Row-Level Security (Hinweis)](#schritt-8--row-level-security-hinweis)
11. [Anhang – Rollenperspektiven](#anhang--rollenperspektiven)

---

## 1. Überblick & Zielbild

Das Dashboard zeigt auf einen Blick, welche Auditor-Qualifikationen ablaufen oder bereits abgelaufen sind. Es kombiniert eine farbkodierte Dringlichkeitsanzeige (Ampellogik) mit einer automatischen Korrektur fehlerhafter Berufungsdaten und einem separaten Datenqualitäts-Visual.

### 1.1 Zielgruppen & Nutzungskontext

| Zielgruppe | Hauptnutzen | Primärseite |
|---|---|---|
| **Auditoren** | Eigenübersicht eigener Ablauffristen | Seite 2 – Eigenansicht |
| **Auditmanager / Teamleitung** | Teamübersicht, Handlungsbedarf erkennen | Seite 1 – Gesamtübersicht |
| **QM / Compliance** | Vollständigkeit, Regelkonformität, Datenqualität prüfen | Seite 3 – Datenqualität |
| **Geschäftsführung** | Aggregierte Risikoübersicht, KPIs | Seite 1 (gefiltert nach Land/Region) |

> **Hinweis zu Row-Level Security:** Ob Auditoren nur ihre eigenen Daten sehen sollen, kann über RLS gesteuert werden – ohne RLS sind alle Seiten durch manuelle Slicer-Auswahl bedienbar. Siehe [Schritt 8](#schritt-8--row-level-security-hinweis).

### 1.2 Ampellogik

| Farbe | Bedingung | Tage bis Ablauf |
|---|---|---|
| 🔴 **Rot** | Abgelaufen oder ≤ 30 Tage | ≤ 30 (inkl. negative Werte) |
| 🟡 **Gelb** | Fällig in 31–60 Tagen | 31 – 60 |
| 🟠 **Orange** | Fällig in 61–90 Tagen | 61 – 90 |
| 🟢 **Grün** | Gültig für mehr als 90 Tage | > 90 |
| ⚪ **Grau** | Kein `Gültig_bis_Korrekt` gesetzt | – |

### 1.3 Dateienübersicht (dieses Repository)

| Datei | Inhalt |
|---|---|
| `Mashup_komplett.pq` | Alle 4 SharePoint-Listen + vollständige Kalenderdimension |
| `Qualifikations_Status_Korrektur.pq` | Korrekturlogik: statusabhängige Erstberufung + rollierender Zyklus |
| `Ampel_Measures_v2.dax` | 4-Farben-Ampel, KPI-Counts, HEX-Farben, Sortierung |
| `Datenqualitaet_Measures.dax` | Fehleranzahl, Fehleranteil, Abweichung, Gesamtampel |
| `Auditoren_Stammdaten.pq` | Einzelabfrage Liste 1 |
| `Qualifikations_Regelwerk.pq` | Einzelabfrage Liste 2 |
| `Qualifikations_Status.pq` | Einzelabfrage Liste 3 (Basis ohne Korrektur) |
| `approval_log.pq` | Einzelabfrage Liste 4 |

---

## 2. Voraussetzungen

### 2.1 Software & Lizenzen

- **Power BI Desktop** – aktuellste Version (min. Release 2024-05)
- **Power BI Pro-Lizenz** – für Veröffentlichung, Sharing und geplante Aktualisierung
- **SharePoint Online-Zugriff** – mind. Leserechte auf alle vier Listen der Site `TeamCyber_Innovation`
- **Power Automate** (optional) – für Near-Realtime-Refresh-Trigger

### 2.2 Pro-Lizenz: relevante Limits & Möglichkeiten

| Feature | Pro-Limit | Bemerkung |
|---|---|---|
| Max. Datensatzgröße | 1 GB (komprimiert) | Für SharePoint-Listen mit < 50.000 Zeilen unkritisch |
| Geplante Aktualisierungen | **bis zu 8× täglich** | ≈ alle 3 Stunden |
| Row-Level Security | ✅ vollständig unterstützt | Konfiguration im Service |
| DirectQuery mit SharePoint | ⚠️ möglich, nicht empfohlen | Siehe Schritt 7 |
| Sharing | Nur mit Pro-Lizenzinhabern | Oder via Einbettung in Teams/SharePoint |

### 2.3 SharePoint-Listen im Überblick

| Liste | Funktion | Verknüpfungsschlüssel |
|---|---|---|
| `Auditoren_Stammdaten` | Stammdaten der Auditoren | `ID` → `Auditor_SP_ID` |
| `Qualifikations_Regelwerk` | Berufungszyklen & Mindestanforderungen je Qualifikation | `ID` → `Quali_SP_ID` |
| `Qualifikations_Status` | Qualifikationsstatus je Auditor-Qualifikation-Kombination | `ID` (Faktentabelle) |
| `approval_log` | Historie formaler Berufungen und Genehmigungen | `ID` → `Approval_SP_ID` |

### 2.4 Feldbenennung: `Gültig_ab` vs. `Gültig_von`

Die Aufgabenstellung verwendet den Begriff `Gültig_von` für das Startdatum des Berufungszeitraums. Im tatsächlichen SharePoint-Feld lautet der interne API-Name `G_x00fc_ltig_ab` (OData-kodiert), der von Power BI beim Laden automatisch zu **`Gültig_ab`** dekodiert wird. Die Korrekturlogik und DAX-Formeln verwenden durchgehend `Gültig_ab` / `Gültig_ab_Korrekt`.

---

## Schritt 1 – SharePoint-Datenanbindung

### 1.1 Connector-Einrichtung in Power BI Desktop

**Option A – Eingebauter SharePoint-Connector (für Einstieg)**

1. **Start → Daten abrufen → Mehr…**
2. Suche: `SharePoint` → **SharePoint Online-Liste** → Verbinden
3. URL eingeben: `https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation`
4. Authentifizierung: **Organisationskonto** → Mit DEKRA-Konto anmelden
5. Im Navigator alle vier Listen auswählen → **Daten transformieren**

> **Nachteil:** Der eingebaute Connector lädt Dutzende interne SharePoint-Metadaten-Spalten mit. Die unten beschriebene OData.Feed-Methode (Option B) ist effizienter und bereits in allen `.pq`-Dateien dieses Repositories implementiert.

**Option B – OData.Feed via REST API (aktive Implementierung)**

Alle Abfragen nutzen direkt die SharePoint REST API mit `$select`-Parametern. Das reduziert die Ladezeit erheblich, da nur benötigte Felder übertragen werden.

```m
// Grundmuster für alle Listen:
OData.Feed(
    "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
    & "/_api/lists/getbytitle('{Listenname}')/items"
    & "?$select=Feld1,Feld2,..."
    & "&$top=5000",
    null,
    [Implementation = "2.0"]   // OData v4 – wichtig für korrekte Typen
)
```

### 1.2 Wichtige OData-Besonderheiten

| Besonderheit | Erklärung |
|---|---|
| `Implementation = "2.0"` | Aktiviert OData v4-Kompatibilität; liefert korrekte Datumstypen |
| URL-Kodierung von Umlauten | `ü` → `_x00fc_` im internen Feldnamen; wird beim Laden automatisch dekodiert |
| Lookup-Spalten mit `$expand` | Erfordern `$select` mit Unterfeld (z. B. `Auditor_Lookup/ID`), sonst HTTP-400-Fehler |
| Expanded Lookups in OData v4 | Werden als **Table** (nicht Record) zurückgegeben → erste Zeile muss explizit ausgelesen werden |
| `$top=5000` | SharePoint-Standard-Limit pro Seite; bei über 5.000 Einträgen Paginierung erforderlich |

### 1.3 Liste 1 – Auditoren_Stammdaten

```m
Quelle = OData.Feed(
    "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
    & "/_api/lists/getbytitle('Auditoren_Stammdaten')/items"
    & "?$select=ID,Title,Nachname,Vorname,Geschlecht,Email_Adresse,Land_Name,Land_kurz,PLZ"
    & "&$top=5000",
    null,
    [Implementation = "2.0"]
)
// Spaltenumbenennung: ID → Auditor_SP_ID | Title → Auditor_Nummer | Geschlecht → Anrede
```

→ Vollständige Abfrage inkl. Typisierung und Fehlerbehandlung: `Auditoren_Stammdaten.pq`

### 1.4 Liste 2 – Qualifikations_Regelwerk

```m
Quelle = OData.Feed(
    "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
    & "/_api/lists/getbytitle('Qualifikations_Regelwerk')/items"
    & "?$select=ID,Title,Berufung_Monate,Anzahl_Monitorings,Anzahl_Audits,"
    & "Anzahl_Stand_der_Technik_Schulun,Anzahl_ERFA"
    & "&$top=5000",
    null,
    [Implementation = "2.0"]
)
// Spaltenumbenennung: ID → Quali_SP_ID | Title → Qualifikation_Name
```

→ Vollständige Abfrage: `Qualifikations_Regelwerk.pq`

### 1.5 Liste 3 – Qualifikations_Status (mit Lookup-Expand)

Diese Liste enthält eine Lookup-Spalte `Auditor_Lookup`, die via `$expand` geladen werden muss:

```m
Quelle = OData.Feed(
    "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
    & "/_api/lists/getbytitle('Qualifikations_Status')/items"
    & "?$select=ID,Qualifikation0Id,G_x00fc_ltig_ab,G_x00fc_ltig_bis,"
    & "quali_log,approval_lookup_idId,Status,"
    & "Datum_Erstberufung_Assistant_Tra,Datum_Erstberufung_Co_Auditor,"
    & "Datum_Erstberufung_Lead_Auditor,"
    & "Auditor_Lookup/ID"          // <-- Unterfeld zwingend angeben!
    & "&$expand=Auditor_Lookup"
    & "&$top=5000",
    null,
    [Implementation = "2.0"]
),
// OData v4: Auditor_Lookup kommt als Table (nicht Record)
// → Erste Zeile auslesen; bei leerer Table = null
MitAuditor = Table.AddColumn(
    Quelle, "Auditor_SP_ID",
    each let t = [Auditor_Lookup]
         in if Table.IsEmpty(t) then null else t{0}[ID],
    Int64.Type
)
```

> **Häufiger Fehler:** Wird `Auditor_Lookup/ID` im `$select` weggelassen, antwortet SharePoint mit HTTP 400. Das Unterfeld muss immer explizit angegeben werden.

→ Vollständige Abfrage inkl. Filterung von Zeilen ohne Auditor/Qualifikation-Verknüpfung: `Qualifikations_Status.pq`

### 1.6 Liste 4 – approval_log

```m
Quelle = OData.Feed(
    "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
    & "/_api/lists/getbytitle('approval_log')/items"
    & "?$select=ID,Auditor_LookupId,Qualifikation_LookupId,Art,Datum,Kommentar,Status,"
    & "formaleReberufung,G_x00fc_ltigkeitderformalenReber,abweichendeDauer,Created,"
    & "Auditor_Lookup/Title,Qualifikation_Lookup/Title"
    & "&$expand=Auditor_Lookup,Qualifikation_Lookup"
    & "&$top=5000",
    null,
    [Implementation = "2.0"]
)
// Lookup-Spalten via ExpandRecordColumn auf Title-Wert reduzieren
// Umbenennung: formaleReberufung → gültig_von | Gültig...Reber → gültig_bis
```

> **Hinweis zur Feldnamenkürzung:** SharePoint begrenzt interne Feldnamen auf 32 Zeichen. `G_x00fc_ltigkeitderformalenReber` ist die gekürzte Form von „GültigkeitderformalenReberufung“. Der Feldname im Query muss exakt diesem gekürzten API-Namen entsprechen.

→ Vollständige Abfrage: `approval_log.pq`

### 1.7 Datum-Hilfstabelle (Kalenderdimension)

Die Datum-Tabelle wird vollständig in Power Query generiert – keine SharePoint-Quelle. Sie deckt den Zeitraum 2015–2035 ab und enthält folgende Spalten:

| Spalte | Typ | Verwendung |
|---|---|---|
| `Datum` | date | Primärschlüssel, Beziehung zu `Gültig_bis` |
| `Jahr` | integer | Jahresfilter |
| `Halbjahr` | text | „H1“ / „H2“ |
| `Quartal` | text | „Q1“–„Q4“ |
| `KW` | integer | Kalenderwoche (Montag-basiert) |
| `Monat_Nr` | integer | Sortierspalte für `Monat_Name` |
| `Monat_Name` | text | Ausgeschriebener Monatsname (de-DE) |
| `Jahresmonat` | text | „2026-03“ – kompakt für Zeitachsen |
| `Tag` | integer | Tageszahl |
| `Wochentag` | text | Ausgeschriebener Wochentag (de-DE) |
| `Wochentag_Nr` | integer | 1 = Mo … 7 = So (Sortierspalte für `Wochentag`) |

> **Wichtig:** Nach dem Laden in Power BI Desktop müssen zwei **„Sortierung nach Spalte“**-Einstellungen gesetzt werden (im Datenbereich, Spalte auswählen → Spaltentools → Sortierung nach Spalte):
> - `Monat_Name` → sortieren nach `Monat_Nr`
> - `Wochentag` → sortieren nach `Wochentag_Nr`
>
> Ohne diese Einstellung sortieren Monate und Wochentage alphabetisch (Dezember vor Februar).

→ Vollständige Abfrage aller Listen inkl. Datum-Tabelle: `Mashup_komplett.pq`

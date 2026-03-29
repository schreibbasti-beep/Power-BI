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
| `Implementation = "2.0"` | Aktiviert OData v4; liefert korrekte Datumstypen |
| URL-Kodierung von Umlauten | `ü` → `_x00fc_` im internen Feldnamen; wird beim Laden dekodiert |
| Lookup mit `$expand` | Erfordert `$select` mit Unterfeld (z. B. `Auditor_Lookup/ID`) |
| Expanded Lookups OData v4 | Werden als **Table** zurückgegeben → erste Zeile explizit auslesen |
| `$top=5000` | SharePoint-Standard-Limit; bei > 5.000 Zeilen Paginierung nötig |

### 1.3–1.6 Listen-Abfragen

→ Vollständige M-Abfragen für alle vier Listen in `Mashup_komplett.pq`. Einzeldateien: `Auditoren_Stammdaten.pq`, `Qualifikations_Regelwerk.pq`, `Qualifikations_Status.pq`, `approval_log.pq`.

> **Häufiger Fehler bei Qualifikations_Status:** Wird `Auditor_Lookup/ID` im `$select` weggelassen, antwortet SharePoint mit HTTP 400.

### 1.7 Datum-Hilfstabelle

Vollständig in Power Query generiert. Zeitraum 2015–2035, 11 Spalten. Nach dem Laden **Sortierung nach Spalte** setzen: `Monat_Name` → `Monat_Nr`, `Wochentag` → `Wochentag_Nr`.

---

## Schritt 2 – Datenmodell & Beziehungen

### 2.1 Star-Schema

Zentrale Faktentabelle: `Qualifikations_Status`. Dimensionen: `Auditoren_Stammdaten`, `Qualifikations_Regelwerk`, `Datum`. Historientabelle: `approval_log`.

### 2.2 Beziehungen konfigurieren

**Start → Beziehungen verwalten → Neu**

| Von-Tabelle | Von-Spalte | Zu-Tabelle | Zu-Spalte | Kardinalität | Filterrichtung |
|---|---|---|---|---|---|
| `Qualifikations_Status` | `Auditor_SP_ID` | `Auditoren_Stammdaten` | `Auditor_SP_ID` | n:1 | Einfach |
| `Qualifikations_Status` | `Quali_SP_ID` | `Qualifikations_Regelwerk` | `Quali_SP_ID` | n:1 | Einfach |
| `Qualifikations_Status` | `Approval_SP_ID` | `approval_log` | `Approval_SP_ID` | n:1 | Einfach |
| `Qualifikations_Status` | `Gültig_bis` | `Datum` | `Datum` | n:1 | Einfach |

> Filterrichtung immer **einfach**: Filter fließen von der Dimensionstabelle in die Faktentabelle. Bidirektionale Filter können bei Measures zu falschem Verhalten führen.

### 2.3 Auto Date/Time deaktivieren (Pflicht)

**Datei → Optionen → Aktuelle Datei → Datenladen → „Auto Datum/Uhrzeit“ deaktivieren**

Ohne diesen Schritt entstehen Phantomzeilen im Visual (leere Zeilen aus der versteckten Auto-Kalendertabelle).

### 2.4 Primäre Faktentabelle mit Korrektur

Nach Schritt 3 empfohlen: `Qualifikations_Status_Korrektur` als Faktentabelle einsetzen, alle vier Beziehungen darauf umleiten. Die Originaltabelle kann mit deaktiviertem Laden im Hintergrund bleiben.

---

## Schritt 3 – Korrekturlogik (Power Query M)

### 3.1 Das Datenproblem

In `Qualifikations_Status` wurden `Gültig_ab` und `Gültig_bis` mit einem einheitlichen Datum befüllt – unabhängig vom tatsächlichen Status des Auditors. Die korrekte Laufzeit richtet sich nach dem **statusabhängigen Erstberufungsdatum**:

| Status | Korrektes Erstberufungsdatum |
|---|---|
| Lead-Auditor, Experte, Prüfer | `Datum_Erstberufung_Lead_Auditor` |
| Co-Auditor | `Datum_Erstberufung_Co_Auditor` |
| Assistant, Trainee | `Datum_Erstberufung_Assistant_Tra` |

Da die Erstberufungen in der Vergangenheit liegen und Zyklen zwischenzeitlich abgelaufen sind, muss der **aktuell gültige Zyklus rollierend berechnet** werden.

### 3.2 Zyklusberechnung (Kernlogik)

```
MonatsDiff  = (JahrHeute – JahrErstberufung) × 12 + (MonatHeute – MonatErstberufung)
Zyklen      = GANZZAHL(MonatsDiff ÷ Berufung_Monate)
Gültig_ab_Korrekt  = Erstberufung + Zyklen × Berufung_Monate
Gültig_bis_Korrekt = Gültig_ab_Korrekt + Berufung_Monate
```

**Taggenauer Kantfall:** Wenn der berechnete Startkandidat noch in der Zukunft liegt (d. h. der Tag im aktuellen Monat ist noch nicht erreicht), wird `Zyklen – 1` verwendet.

**Beispiel:** Erstberufung = 2018-01-15 · Berufung_Monate = 36 · Heute = 2026-03-25  
→ MonatsDiff = 98 · Zyklen = 2 · **Gültig_ab = 2024-01-15 · Gültig_bis = 2027-01-15**

### 3.3 Neue Spalten

| Spalte | Typ | Bedeutung |
|---|---|---|
| `Erstberufung_Korrekt` | date | Statusabhängig ermitteltes Erstberufungsdatum |
| `Berufung_Monate` | integer | Zykluslänge aus `Qualifikations_Regelwerk` (via Left Join) |
| `Gültig_ab_Korrekt` | date | Start des aktuellen Zyklus |
| `Gültig_bis_Korrekt` | date | Ende des aktuellen Zyklus |
| `Datum_Fehlerhaft` | logical | `true` = Ist ≠ Soll · `false` = OK · `null` = nicht prüfbar |

→ **Vollständige M-Implementierung:** `Qualifikations_Status_Korrektur.pq`

### 3.4 Einbindung in Power BI Desktop

1. `Qualifikations_Status_Korrektur.pq` öffnen → Inhalt in den Power Query-Editor kopieren
2. Im Editor: **Start → Neue Quelle → Leere Abfrage → Erweiterter Editor**
3. Code einfügen → Fertig → Abfrage in `Qualifikations_Status_Korrektur` umbenennen
4. Beziehungen aus Schritt 2.2 auf diese Tabelle umleiten (Schritt 2.4)
5. Originaltabelle `Qualifikations_Status`: Rechtsklick → **„Laden deaktivieren“**

---

## Schritt 4 – DAX-Formeln

> Alle Formeln sind in `Ampel_Measures_v2.dax` und `Datenqualitaet_Measures.dax` vollständig kommentiert. Dieser Abschnitt fasst die wichtigsten Formeln zusammen und erklärt die Einrichtung.

### 4.1 Berechnete Spalten vs. Measures

| Typ | Wann verwenden | Besonderheit |
|---|---|---|
| **Berechnete Spalte** | Slicer, bedingte Formatierung nach Feldwert, Sortierung | Wird einmalig beim Refresh berechnet; `TODAY()` = Refresh-Zeitpunkt |
| **Measure** | KPI-Karten, aggregierte Werte, dynamische Berechnungen | Wird zur Laufzeit im Filterkontext ausgewertet |

### 4.2 Berechnete Spalten anlegen

**Modellierung → Neue Spalte** (Tabelle `Qualifikations_Status` auswählen)

**Tage_bis_Ablauf** – verbleibende Tage (negativ = abgelaufen):

```dax
Tage_bis_Ablauf =
DATEDIFF(
    TODAY(),
    Qualifikations_Status[Gültig_bis_Korrekt],
    DAY
)
```

**Ampel_Farbe** – für Slicer und bedingte Formatierung:

```dax
Ampel_Farbe =
VAR Tage = Qualifikations_Status[Tage_bis_Ablauf]
RETURN
    IF(
        ISBLANK(Qualifikations_Status[Gültig_bis_Korrekt]),
        "⚪ Kein Datum",
        IF(Tage <= 30,  "🔴 Rot",
        IF(Tage <= 60,  "🟡 Gelb",
        IF(Tage <= 90,  "🟠 Orange",
                        "🟢 Grün")))
    )
```

> **Wichtig:** `Ampel_Farbe` – **Sortierung nach Spalte** → `Ampel_Sortierung` setzen, damit Rot im Slicer und Visual immer oben erscheint.

**Ampel_Sortierung** – Sortierspalte (1 = Rot, 5 = kein Datum):

```dax
Ampel_Sortierung =
VAR Tage = Qualifikations_Status[Tage_bis_Ablauf]
RETURN
    IF(ISBLANK(Qualifikations_Status[Gültig_bis_Korrekt]), 5,
    IF(Tage <= 30,  1,
    IF(Tage <= 60,  2,
    IF(Tage <= 90,  3,
                    4))))
```

**Dringlichkeits_Bucket** – für Slicer mit klar lesbaren Stufen:

```dax
Dringlichkeits_Bucket =
VAR Tage = Qualifikations_Status[Tage_bis_Ablauf]
RETURN
    IF(ISBLANK(Qualifikations_Status[Gültig_bis_Korrekt]), "Kein Datum",
    IF(Tage <  0,   "Abgelaufen",
    IF(Tage <= 30,  "≤ 30 Tage",
    IF(Tage <= 60,  "31–60 Tage",
    IF(Tage <= 90,  "61–90 Tage",
                    "> 90 Tage (OK)")))))
```

### 4.3 Measures anlegen

**Modellierung → Neues Measure** (Tabelle `Qualifikations_Status` auswählen)

**KPI-Zählmeasures** (jeweils eine Karte pro Ampelfarbe):

```dax
Anzahl_Rot =
CALCULATE(
    COUNTROWS(Qualifikations_Status),
    NOT ISBLANK(Qualifikations_Status[Tage_bis_Ablauf]),
    Qualifikations_Status[Tage_bis_Ablauf] <= 30
)

Anzahl_Gelb    = CALCULATE(COUNTROWS(Qualifikations_Status),
    Qualifikations_Status[Tage_bis_Ablauf] >= 31,
    Qualifikations_Status[Tage_bis_Ablauf] <= 60)

Anzahl_Orange  = CALCULATE(COUNTROWS(Qualifikations_Status),
    Qualifikations_Status[Tage_bis_Ablauf] >= 61,
    Qualifikations_Status[Tage_bis_Ablauf] <= 90)

Anzahl_Gruen   = CALCULATE(COUNTROWS(Qualifikations_Status),
    Qualifikations_Status[Tage_bis_Ablauf] > 90)
```

**Ampel_Farbe_HEX** – Hexfarbcode für bedingte Formatierung per Feldwert:

```dax
Ampel_Farbe_HEX =
VAR Tage = [Tage_bis_Ablauf_M]
RETURN
    IF(ISBLANK(Tage),  "#808080",
    IF(Tage <= 30,     "#C00000",
    IF(Tage <= 60,     "#FFD700",
    IF(Tage <= 90,     "#FF8C00",
                       "#00B050"))))
```

**Datenqualitäts-Measures** (für Seite 3):

```dax
Anzahl_Datum_Fehlerhaft =
CALCULATE(
    COUNTROWS(Qualifikations_Status),
    Qualifikations_Status[Datum_Fehlerhaft] = TRUE()
)

Anteil_Fehlerhaft_Prozent =
VAR Pruefbar = CALCULATE(COUNTROWS(Qualifikations_Status),
    NOT ISBLANK(Qualifikations_Status[Datum_Fehlerhaft]))
RETURN
    DIVIDE([Anzahl_Datum_Fehlerhaft], Pruefbar, 0)

Datenqualitaet_Ampel =
VAR Anteil = [Anteil_Fehlerhaft_Prozent]
RETURN
    IF(Anteil = 0,       "✅ Keine Fehler",
    IF(Anteil < 0.05,    "🟢 Gut (< 5%)",
    IF(Anteil < 0.20,    "🟡 Prüfen (5–20%)",
                         "🔴 Kritisch (> 20%)")))
```

→ Sämtliche Measures mit vollständiger Dokumentation: `Ampel_Measures_v2.dax` und `Datenqualitaet_Measures.dax`

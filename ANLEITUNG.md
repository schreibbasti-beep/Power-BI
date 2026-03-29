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

> **Hinweis zu Row-Level Security:** Ohne RLS sind alle Seiten durch manuelle Slicer-Auswahl bedienbar. Siehe [Schritt 8](#schritt-8--row-level-security-hinweis).

### 1.2 Ampellogik

| Farbe | Bedingung | Tage bis Ablauf |
|---|---|---|
| 🔴 **Rot** | Abgelaufen oder ≤ 30 Tage | ≤ 30 (inkl. negative Werte) |
| 🟡 **Gelb** | Fällig in 31–60 Tagen | 31 – 60 |
| 🟠 **Orange** | Fällig in 61–90 Tagen | 61 – 90 |
| 🟢 **Grün** | Gültig für mehr als 90 Tage | > 90 |
| ⚪ **Grau** | Kein `Gültig_bis_Korrekt` gesetzt | – |

### 1.3 Dateienübersicht

| Datei | Inhalt |
|---|---|
| `Mashup_komplett.pq` | Alle 4 SharePoint-Listen + Kalenderdimension |
| `Qualifikations_Status_Korrektur.pq` | Korrekturlogik: statusabhängige Erstberufung + rollierender Zyklus |
| `Ampel_Measures_v2.dax` | 4-Farben-Ampel, KPI-Counts, HEX-Farben |
| `Datenqualitaet_Measures.dax` | Fehleranzahl, Fehleranteil, Gesamtampel |
| `Auditoren_Stammdaten.pq` / `Qualifikations_Regelwerk.pq` / `Qualifikations_Status.pq` / `approval_log.pq` | Einzelabfragen |

---

## 2. Voraussetzungen

### 2.1 Software & Lizenzen

- **Power BI Desktop** – aktuellste Version (min. Release 2024-05)
- **Power BI Pro-Lizenz** – für Veröffentlichung, Sharing und geplante Aktualisierung
- **SharePoint Online-Zugriff** – mind. Leserechte auf alle vier Listen
- **Power Automate** (optional) – für Near-Realtime-Refresh-Trigger

### 2.2 Pro-Lizenz: relevante Limits

| Feature | Limit | Bemerkung |
|---|---|---|
| Max. Datensatzgröße | 1 GB | Unkritisch für SharePoint-Listen |
| Geplante Aktualisierungen | **bis zu 8× täglich** | ≈ alle 3 Stunden |
| Row-Level Security | ✅ vollständig | Konfiguration im Service |
| DirectQuery SharePoint | ⚠️ nicht empfohlen | Siehe Schritt 7 |

### 2.3 SharePoint-Listen

| Liste | Verknüpfungsschlüssel |
|---|---|
| `Auditoren_Stammdaten` | `ID` → `Auditor_SP_ID` |
| `Qualifikations_Regelwerk` | `ID` → `Quali_SP_ID` |
| `Qualifikations_Status` | Faktentabelle |
| `approval_log` | `ID` → `Approval_SP_ID` |

### 2.4 Feldbenennung: `Gültig_ab` vs. `Gültig_von`

SharePoint-interner Feldname: `G_x00fc_ltig_ab` (OData). Nach dem Laden automatisch dekodiert zu `Gültig_ab`. Alle Formeln und Abfragen verwenden `Gültig_ab`.

---

## Schritt 1 – SharePoint-Datenanbindung

### 1.1 Connector-Einrichtung

**Option A – Eingebauter Connector:** Start → Daten abrufen → SharePoint Online-Liste → Site-URL → Organisationskonto. Nachteil: lädt viele Metadaten-Spalten mit.

**Option B – OData.Feed (aktive Implementierung):**

```m
OData.Feed(
    "https://dekracloud.sharepoint.com/sites/TeamCyber_Innovation"
    & "/_api/lists/getbytitle('{Liste}')/items?$select=...&$top=5000",
    null, [Implementation = "2.0"]
)
```

### 1.2 Wichtige OData-Besonderheiten

| Besonderheit | Erklärung |
|---|---|
| `Implementation = "2.0"` | OData v4, korrekte Datumstypen |
| Umlaut-Kodierung | `ü` → `_x00fc_`; wird beim Laden dekodiert |
| Lookup + `$expand` | `$select` muss Unterfeld enthalten (z. B. `Auditor_Lookup/ID`) |
| OData v4 Lookups | Werden als **Table** zurückgegeben → erste Zeile auslesen |

→ Vollständige Abfragen in `Mashup_komplett.pq`. Datum-Tabelle: 11 Spalten, 2015–2035. Nach dem Laden `Monat_Name` → nach `Monat_Nr` und `Wochentag` → nach `Wochentag_Nr` sortieren.

---

## Schritt 2 – Datenmodell & Beziehungen

Zentrale Faktentabelle: `Qualifikations_Status`. Beziehungen:

| Von | Zu | Typ |
|---|---|---|
| `Qualifikations_Status[Auditor_SP_ID]` | `Auditoren_Stammdaten[Auditor_SP_ID]` | n:1, einfach |
| `Qualifikations_Status[Quali_SP_ID]` | `Qualifikations_Regelwerk[Quali_SP_ID]` | n:1, einfach |
| `Qualifikations_Status[Approval_SP_ID]` | `approval_log[Approval_SP_ID]` | n:1, einfach |
| `Qualifikations_Status[Gültig_bis]` | `Datum[Datum]` | n:1, einfach |

**Pflicht:** Auto Date/Time deaktivieren – Datei → Optionen → Aktuelle Datei → Datenladen.

---

## Schritt 3 – Korrekturlogik (Power Query M)

Fehler: `Gültig_ab` / `Gültig_bis` wurden mit einheitlichem Datum befüllt statt statusabhängigem Erstberufungsdatum.

**Statuszuordnung:**

| Status | Erstberufungsfeld |
|---|---|
| Lead-Auditor, Experte, Prüfer | `Datum_Erstberufung_Lead_Auditor` |
| Co-Auditor | `Datum_Erstberufung_Co_Auditor` |
| Assistant, Trainee | `Datum_Erstberufung_Assistant_Tra` |

**Zyklusformel:** `Gültig_ab_Korrekt = Erstberufung + GANZZAHL(MonatsDiff / Berufung_Monate) * Berufung_Monate`

Beispiel: Erstberufung 2018-01-15 · 36 Monate · Heute 2026-03-25 → Gültig_ab = 2024-01-15 · Gültig_bis = 2027-01-15

→ **Vollständig implementiert in** `Qualifikations_Status_Korrektur.pq`

---

## Schritt 4 – DAX-Formeln

**Berechnete Spalten** (Modellierung → Neue Spalte):
- `Tage_bis_Ablauf` = `DATEDIFF(TODAY(), [Gültig_bis_Korrekt], DAY)`
- `Ampel_Farbe` = Emoji-Text („🔴 Rot“ etc.) – nach `Ampel_Sortierung` sortieren
- `Dringlichkeits_Bucket` = „Abgelaufen“ / „≤ 30 Tage“ / „31–60 Tage“ / „61–90 Tage“ / „> 90 Tage (OK)“

**Measures** (Modellierung → Neues Measure):
- `Anzahl_Rot/Gelb/Orange/Gruen` = CALCULATE/COUNTROWS mit Tage-Schwellen
- `Ampel_Farbe_HEX` = Hexfarbcode für bedingte Formatierung
- `Anzahl_Datum_Fehlerhaft`, `Anteil_Fehlerhaft_Prozent`, `Datenqualitaet_Ampel`

→ Vollständig in `Ampel_Measures_v2.dax` und `Datenqualitaet_Measures.dax`

---

## Schritt 5 – Dashboard-Visualisierung

### 5.1 Seitenstruktur

| Seite | Name | Primäre Zielgruppe | Besonderheit |
|---|---|---|---|
| 1 | Gesamtübersicht | Auditmanager, Geschäftsführung | KPI-Leiste + Haupttabelle + Dringlichkeitsdiagramm |
| 2 | Eigenansicht | Auditoren | Identisch zu Seite 1, aber Slicer auf eigenen Namen vorausgefüllt |
| 3 | Datenqualität | QM / Compliance | Fehler-KPI + Ist-Soll-Vergleichstabelle |

### 5.2 Seite 1 – Gesamtübersicht

#### Kopfzeile: 4 KPI-Karten nebeneinander

| Karte | Measure | Hintergrundfarbe | Schriftfarbe |
|---|---|---|---|
| Rot | `Anzahl_Rot` | `#C00000` | Weiß |
| Gelb | `Anzahl_Gelb` | `#FFD700` | Schwarz |
| Orange | `Anzahl_Orange` | `#FF8C00` | Schwarz |
| Grün | `Anzahl_Gruen` | `#00B050` | Weiß |

**Visual:** Karte (Card) oder Neue Karte (New Card Visual)  
**Einrichtung:** Format → Hintergrund → Farbe auf den jeweiligen Hex-Wert setzen

#### Haupttabelle mit Ampelfarben

**Visual:** Tabellenvisual oder Matrixvisual

**Empfohlene Spalten:**

| Spalte | Quelle |
|---|---|
| Nachname | `Auditoren_Stammdaten[Nachname]` |
| Vorname | `Auditoren_Stammdaten[Vorname]` |
| Qualifikation | `Qualifikations_Regelwerk[Qualifikation_Name]` |
| Status | `Qualifikations_Status[Status]` |
| Gültig bis (Soll) | `Qualifikations_Status[Gültig_bis_Korrekt]` |
| Tage bis Ablauf | Measure `Tage_bis_Ablauf_M` |
| Ampel | Measure `Ampel_Symbol_M` |

**Bedingte Formatierung einrichten – Methode A (empfohlen):**

1. Spalte `Tage bis Ablauf` im Visual auswählen
2. Format → **Zellenelement → Hintergrundfarbe** → aktivieren
3. Formatierungsart: **Feldwert** → Measure `Ampel_Farbe_HEX` auswählen
4. → Jede Zelle erhält automatisch die passende Ampelfarbe

**Methode B – Regelbasiert (kein extra Measure):**

1. Spalte auswählen → Hintergrundfarbe → **Regeln**
2. Basierend auf Feldwert `Tage_bis_Ablauf` (berechnete Spalte):

| Regel | Wenn Wert | bis | Farbe |
|---|---|---|---|
| Rot | ≤ | 30 | `#C00000` |
| Gelb | > 30 und ≤ | 60 | `#FFD700` |
| Orange | > 60 und ≤ | 90 | `#FF8C00` |
| Grün | > | 90 | `#00B050` |

**Tabelle nach Dringlichkeit sortieren:**
Spalte `Tage bis Ablauf` → aufsteigend sortieren (kleinste/negativste Werte oben – höchste Dringlichkeit).

**Visual-Filter gegen Phantomzeilen:**  
Visual-Ebenen-Filter hinzufügen: Measure `Hat_Qualifikation` = 1

#### Dringlichkeitsdiagramm

**Visual:** Gestapeltes Balkendiagramm
- Y-Achse: `Auditoren_Stammdaten[Nachname]`
- X-Achse: `Anzahl_Gesamt` (Measure)
- Legende: `Qualifikations_Status[Ampel_Farbe]` (berechnete Spalte)
- Farben im Format-Bereich manuell auf die Ampelfarben setzen
- Sortierung: nach `Anzahl_Rot` absteigend

### 5.3 Seite 2 – Auditor-Eigenansicht

Identischer Aufbau wie Seite 1, zusätzlich:
- **Slicer Nachname** vorausgefüllt (oder via RLS automatisch gefiltert)
- **Zeitlinie:** X-Achse `Datum[Jahresmonat]`, Y-Achse `Tage_bis_Ablauf_M` – zeigt den zeitlichen Verlauf der eigenen Qualifikations-Fälligkeiten
- **Karte „nächste Fälligkeit“:** Measure `Frühestes_Ablaufdatum`

### 5.4 Seite 3 – Datenqualität

#### KPI-Karten oben

| Karte | Measure | Hintergrund (bedingt) |
|---|---|---|
| Fehlerhafte Einträge | `Anzahl_Datum_Fehlerhaft` | Rot wenn > 0 |
| Fehleranteil | `Anteil_Fehlerhaft_Prozent` | Als % formatieren |
| Gesamtbewertung | `Datenqualitaet_Ampel` | Kein Hintergrund |

#### Ist-Soll-Vergleichstabelle

**Visual:** Tabellenvisual mit **Visual-Filter: `Datum_Fehlerhaft = TRUE`**

| Spalte | Quelle |
|---|---|
| Nachname | `Auditoren_Stammdaten[Nachname]` |
| Vorname | `Auditoren_Stammdaten[Vorname]` |
| Qualifikation | `Qualifikations_Regelwerk[Qualifikation_Name]` |
| Status | `Qualifikations_Status[Status]` |
| Erstberufung | `Qualifikations_Status[Erstberufung_Korrekt]` |
| Gültig ab (Ist) | `Qualifikations_Status[Gültig_ab]` |
| Gültig ab (Soll) | `Qualifikations_Status[Gültig_ab_Korrekt]` |
| Gültig bis (Ist) | `Qualifikations_Status[Gültig_bis]` |
| Gültig bis (Soll) | `Qualifikations_Status[Gültig_bis_Korrekt]` |

**Bedingte Formatierung der Ist-Spalten:**  
Spalten `Gültig ab (Ist)` und `Gültig bis (Ist)` → Hintergrundfarbe → Feldwert → Measure `Hat_Datumsfehler_Auditor` → Farbe `#C00000` (setzt alle Ist-Zellen rot, wenn fehlerhaft)

**Export-Button:**  
Visualization → Tabellenvisual auswählen → `...` → Daten exportieren → CSV – liefert QM/Compliance eine bereinigte Fehlerliste für die manuelle Korrektur in SharePoint.

---

## Schritt 6 – Slicer & Filter

### 6.1 Empfohlene Slicer (alle Seiten)

| Slicer | Feld | Visual-Typ | Zielgruppe |
|---|---|---|---|
| Auditor | `Auditoren_Stammdaten[Nachname]` | Dropdown | Alle (Eigenansicht: vorausgefüllt) |
| Qualifikationstyp | `Qualifikations_Regelwerk[Qualifikation_Name]` | Dropdown | Alle |
| Dringlichkeitsstufe | `Qualifikations_Status[Dringlichkeits_Bucket]` | Kachel / Liste | Alle |
| Ampelfarbe | `Qualifikations_Status[Ampel_Farbe]` | Kachel | Alle |
| Status | `Qualifikations_Status[Status]` | Dropdown | Auditmanager, QM |
| Jahr | `Datum[Jahr]` | Dropdown | Alle |
| Land | `Auditoren_Stammdaten[Land_Name]` | Dropdown | Management |

### 6.2 Slicer-Synchronisation (seitenübergreifend)

**Ansicht → Slicer synchronisieren**

Alle Slicer (Auditor, Qualifikationstyp, Dringlichkeitsstufe) auf allen Berichtsseiten synchronisieren. Damit wirkt eine Änderung auf Seite 1 auch auf Seite 2 und 3.

### 6.3 Rollenperspektive ohne RLS (via Lesezeichen)

Für eine einfache Rollenperspektive ohne RLS: Lesezeichen (Bookmarks) für vorkonfigurierte Slicer-Zustände anlegen.

**Einrichtung:**
1. Slicer auf gewünschten Zustand einstellen (z. B. Dringlichkeitsstufe = „Abgelaufen“ + „≤ 30 Tage“)
2. **Ansicht → Lesezeichen → Lesezeichen hinzufügen** → Name: `Kritische Fälle`
3. Schaltfläche (Button-Visual) auf der Seite platzieren → **Format → Aktion → Typ: Lesezeichen → Lesezeichen auswählen**
4. Weitere Schaltflächen für `Team-Übersicht`, `Nur Grün`, `Zurücksetzen` anlegen

Empfohlene Lesezeichen-Schaltflächen-Leiste (oberer Rand des Dashboards):

```
[ Alle anzeigen ]  [ 🔴 Kritisch ]  [ 🟡 In Kürze ]  [ 🟢 OK ]  [ Meine Qualifikationen ]
```

### 6.4 Visual-Ebenen-Filter (Pflicht)

Für jedes Tabellenvisual im Filterbereich unter **Visual-Ebenen-Filter** eintragen:

- `Hat_Qualifikation` = 1 – verhindert Phantomzeilen aus der Datum-Tabelle

Für das Datenqualitäts-Visual zusätzlich:
- `Datum_Fehlerhaft` = `TRUE` – zeigt nur fehlerhafte Einträge

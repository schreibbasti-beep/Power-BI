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

→ Vollständige M-Abfragen für alle vier Listen in `Mashup_komplett.pq` (alle Transformationen, Typisierungen und Fehlerbehandlungen enthalten). Einzeldateien: `Auditoren_Stammdaten.pq`, `Qualifikations_Regelwerk.pq`, `Qualifikations_Status.pq`, `approval_log.pq`.

> **Häufiger Fehler bei Qualifikations_Status:** Wird `Auditor_Lookup/ID` im `$select` weggelassen, antwortet SharePoint mit HTTP 400. Das Unterfeld muss immer explizit angegeben werden.

### 1.7 Datum-Hilfstabelle

Vollständig in Power Query generiert (kein SharePoint-Load). Zeitraum 2015–2035, 11 Spalten. Nach dem Laden **Sortierung nach Spalte** setzen: `Monat_Name` → `Monat_Nr`, `Wochentag` → `Wochentag_Nr`.

---

## Schritt 2 – Datenmodell & Beziehungen

### 2.1 Star-Schema-Überblick

Die Tabelle `Qualifikations_Status` ist die **zentrale Faktentabelle**. Alle anderen Tabellen sind Dimensionen oder Historientabellen:

```
                ┌─────────────────────┐
                │  Auditoren_Stammdaten │
                │  (Dimension)          │
                │  PK: Auditor_SP_ID    │
                └──────────┬──────────┘
                           │ 1:n
  ┌───────────┐   n │       1   ┌───────────────────────┐
  │   Datum    │◄────────╌────────►│ Qualifikations_Status │
  │ Dimension │ Gültig_bis  (Fakt)   │ FK: Auditor_SP_ID     │
  │ PK: Datum │              │       │ FK: Quali_SP_ID       │
  └───────────┘              │       │ FK: Approval_SP_ID    │
                             │       └────────┬──────────────┘
                             │                │
  ┌─────────────────┐   │          n:1 │
  │ Qualifikations_    │◄──┘       ┌────────┴────────┐
  │ Regelwerk          │           │ approval_log   │
  │ (Dimension)        │           │ (Historie)     │
  │ PK: Quali_SP_ID    │           │ PK: Approval_  │
  └─────────────────┘           │     SP_ID      │
                                   └────────────────┘
```

### 2.2 Beziehungen konfigurieren

**Start → Beziehungen verwalten → Neu** (oder per Drag & Drop in der Modellansicht)

| Von-Tabelle (Viele-Seite) | Von-Spalte | Zu-Tabelle (Eine-Seite) | Zu-Spalte | Kardinalität | Filterrichtung | Aktiv |
|---|---|---|---|---|---|---|
| `Qualifikations_Status` | `Auditor_SP_ID` | `Auditoren_Stammdaten` | `Auditor_SP_ID` | n:1 | Einfach | ✅ |
| `Qualifikations_Status` | `Quali_SP_ID` | `Qualifikations_Regelwerk` | `Quali_SP_ID` | n:1 | Einfach | ✅ |
| `Qualifikations_Status` | `Approval_SP_ID` | `approval_log` | `Approval_SP_ID` | n:1 | Einfach | ✅ |
| `Qualifikations_Status` | `Gültig_bis` | `Datum` | `Datum` | n:1 | Einfach | ✅ |

> **Filterrichtung immer einfach (single):** Filter fließen von der Dimensions-Tabelle (Eine-Seite) in die Faktentabelle (Viele-Seite). Bidirektionale Filter können zu unerwartetem Verhalten bei Measures führen und sind hier nicht nötig.

> **Hinweis zu `approval_log`:** Die Beziehung verbindet jeden `Qualifikations_Status`-Eintrag mit dem zugehörigen letzten Genehmigungsdatensatz. Der `approval_log` enthält die komplette Genehmigungshistorie; über `Approval_SP_ID` in `Qualifikations_Status` ist immer nur der aktuell referenzierte Eintrag verknüpft.

### 2.3 Auto Date/Time deaktivieren (Pflichtschritt)

Power BI erstellt für jede Datumsspalte automatisch eine versteckte Kalendertabelle (Auto Date/Time). Das erzeugt **Phantomzeilen** in Visuals – leere Tabellenzeilen ohne Auditor oder Qualifikation. Da eine eigene `Datum`-Tabelle vorhanden ist, muss Auto Date/Time deaktiviert werden:

**Datei → Optionen und Einstellungen → Optionen → Aktuelle Datei → Datenladen**  
→ Häkchen bei **„Auto Datum/Uhrzeit“ entfernen** → OK

Anschließend im Visual-Bereich statt der alten `Gültig_bis`-Hierarchie die Spalten der `Datum`-Tabelle verwenden: `Datum[Jahr]`, `Datum[Monat_Name]`, `Datum[Jahresmonat]` etc.

### 2.4 Qualifikations_Status_Korrektur als primäre Tabelle

Nach Einbindung der Korrekturlogik (Schritt 3) gibt es zwei Möglichkeiten:

**Option A – Ersetzung (empfohlen):**  
Die Abfrage `Qualifikations_Status_Korrektur` ersetzt `Qualifikations_Status` als primäre Faktentabelle. Alle vier Beziehungen (Schritt 2.2) auf `Qualifikations_Status_Korrektur` umstellen. Die Originaltabelle `Qualifikations_Status` bleibt als Hintergrundabfrage erhalten (Laden deaktivieren).

**Option B – Direktintegration:**  
Den Merge-Schritt und die Korrekturspalten direkt in `Qualifikations_Status.pq` einfügen (nach dem letzten vorhandenen Transformationsschritt). Dann ist nur eine Tabelle nötig.

In beiden Fällen zeigen alle DAX-Measures auf die Tabelle mit den Spalten `Gültig_ab_Korrekt`, `Gültig_bis_Korrekt` und `Datum_Fehlerhaft`.

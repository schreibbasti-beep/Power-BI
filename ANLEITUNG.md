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

> **Hinweis zu Row-Level Security:** Ob Auditoren nur ihre eigenen Daten sehen sollen, kann über RLS gesteuert werden – ohne RLS sind alle Seiten durch manuelle Slicer-Auswahl bedienbar. Siehe [Schritt 8](#schritt-8--row-level-security-hinweis) für eine Konfigurationsbeschreibung.

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
| `Mashup_komplett.pq` | Alle 4 SharePoint-Listen + Datum-Hilfstabelle (vollständige Kalenderdimension) |
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

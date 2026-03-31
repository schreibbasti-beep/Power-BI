# Power BI Dashboard – Auditor-Qualifikationen
## Vollständige Schritt-für-Schritt-Aufbauanleitung

**Version:** 1.2 · **Stand:** März 2026  
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
| **Geschäftsführung** | Aggregierte Risikouübersicht, KPIs | Seite 1 (gefiltert nach Land/Region) |

> Ohne RLS sind alle Seiten durch manuelle Slicer-Auswahl bedienbar. Siehe [Schritt 8](#schritt-8--row-level-security-hinweis).

### 1.2 Ampellogik

| Farbe | Tage bis Ablauf |
|---|---|
| 🔴 **Rot** | < 0 (abgelaufen) |
| 🟠 **Orange** | 0 – 90 |
| 🟡 **Gelb** | 91 – 180 |
| 🟢 **Grün** | > 180 |
| ⚪ **Grau** | kein Datum |

### 1.3 Dateiübersicht

| Datei | Inhalt |
|---|---|
| `Mashup_komplett.pq` | Alle 4 Listen + Kalenderdimension |
| `Qualifikations_Status_Korrektur.pq` | Korrekturlogik: Erstberufung + Zyklusrechnung |
| `Ampel_Measures_v2.dax` | 4-Farben-Ampel, KPI-Counts, HEX-Farben |
| `Datenqualitaet_Measures.dax` | Fehleranzahl, Anteil, Gesamtampel |
| `*.pq` (Einzeldateien) | Einzelabfragen je Liste |

---

## 2. Voraussetzungen

- **Power BI Desktop** – min. Release 2024-05
- **Power BI Pro-Lizenz** – Veröffentlichung, Sharing, max. 8 Refreshes/Tag, RLS
- **SharePoint-Zugriff** – Leserechte auf alle vier Listen
- **Power Automate** (optional) – Near-Realtime-Trigger
- Feldbenennung: `Gültig_von` in der Aufgabe = `Gültig_ab` im Code (OData-Dekodierung von `G_x00fc_ltig_ab`)

---

## Schritt 1 – SharePoint-Datenanbindung

Alle Abfragen nutzen OData.Feed mit `Implementation = "2.0"` und `$select` für performante Feldauswahl. Lookup-Spalten via `$expand`; OData v4 liefert Lookups als Table – erste Zeile auslesen. Datum-Tabelle in Power Query generiert (2015–2035, 11 Spalten). Sortierung nach Spalte setzen: `Monat_Name` → `Monat_Nr`, `Wochentag` → `Wochentag_Nr`.

→ `Mashup_komplett.pq` (vollständig) | Einzeldateien je Liste

---

## Schritt 2 – Datenmodell & Beziehungen

Faktentabelle `Qualifikations_Status`, Beziehungen zu `Auditoren_Stammdaten`, `Qualifikations_Regelwerk`, `approval_log`, `Datum` – alle n:1, Filterrichtung einfach. **Auto Date/Time deaktivieren** (Datei → Optionen → Aktuelle Datei).

Nach Schritt 3: `Qualifikations_Status_Korrektur` als Faktentabelle einsetzen und Beziehungen umleiten.

---

## Schritt 3 – Korrekturlogik (Power Query M)

Die Korrekturlogik ergänzt `Qualifikations_Status` um fünf neue Spalten:
`Erstberufung_Korrekt`, `Berufung_Monate`, `Gültig_ab_Korrekt`, `Gültig_bis_Korrekt`, `Datum_Fehlerhaft`.

> **Wichtig:** Die DAX-Formeln in `Ampel_Measures_v2.dax` referenzieren diese Spalten direkt in der Tabelle `Qualifikations_Status`. Die Korrektur muss deshalb **in diese Tabelle integriert** werden – nicht als separate Tabelle geladen werden. Zwei Optionen:

### Option A – Direkte Integration in `Qualifikations_Status` (empfohlen)

Diese Option erweitert die bestehende Abfrage, sodass alle Beziehungen und DAX-Formeln unverändert funktionieren.

1. Power BI Desktop → **Start → Daten transformieren** (Power Query Editor öffnen)
2. Im linken Panel `Qualifikations_Status` auswählen
3. **Start → Erweiterter Editor** öffnen
4. Den letzten Schritt der Abfrage notieren (z. B. `UmbenennteSpalten` oder `GeänderterTyp`)
5. Datei `Qualifikations_Status_Korrektur.pq` öffnen
6. **Alle Schritte ab `MitRegelwerk` bis `FinaleSpalten`** kopieren und ans Ende der bestehenden Abfrage einfügen
7. Im kopierten ersten Schritt `Basis = Qualifikations_Status` durch den notierten letzten Schritt ersetzen, z. B.:
   ```m
   Basis = UmbenennteSpalten,
   ```
8. Den `in`-Ausdruck am Ende auf `FinaleSpalten` ändern:
   ```m
   in
       FinaleSpalten
   ```
9. **Schließen & Anwenden** – die fünf neuen Spalten erscheinen jetzt in `Qualifikations_Status`

### Option B – Als eigenständige Abfrage (falls Option A nicht möglich)

Diese Option behält beide Abfragen, erfordert aber das Umstellen aller Beziehungen.

1. Power Query Editor → **Neue Quelle → Leere Abfrage**
2. **Erweiterter Editor** öffnen, Inhalt von `Qualifikations_Status_Korrektur.pq` einfügen
3. Abfrage umbenennen: `Qualifikations_Status_Korrektur`
4. Originale `Qualifikations_Status`-Abfrage rechtsklicken → **„Laden aktivieren" deaktivieren** (Tabelle bleibt als Staging-Quelle erhalten, wird aber nicht ins Modell geladen)
5. **Schließen & Anwenden**
6. Im Datenmodell (Modellierungsansicht) alle vier Beziehungen auf `Qualifikations_Status_Korrektur` umstellen
7. In allen DAX-Formeln `Qualifikations_Status` durch `Qualifikations_Status_Korrektur` ersetzen

→ `Qualifikations_Status_Korrektur.pq`

---

## Schritt 4 – DAX-Formeln

Berechnete Spalten: `Tage_bis_Ablauf`, `Ampel_Farbe` (nach `Ampel_Sortierung` sortieren), `Dringlichkeits_Bucket`.

Ampellogik der berechneten Spalten:

| Bedingung | Farbe | Bucket |
|---|---|---|
| `Tage_bis_Ablauf < 0` | 🔴 Rot | Abgelaufen |
| `0 ≤ Tage_bis_Ablauf ≤ 90` | 🟠 Orange | 0–90 Tage |
| `91 ≤ Tage_bis_Ablauf ≤ 180` | 🟡 Gelb | 91–180 Tage |
| `Tage_bis_Ablauf > 180` | 🟢 Grün | > 180 Tage (OK) |

Measures: `Anzahl_Rot`, `Anzahl_Orange`, `Anzahl_Gelb`, `Anzahl_Gruen`, `Ampel_Farbe_HEX`, `Anzahl_Datum_Fehlerhaft`, `Anteil_Fehlerhaft_Prozent`, `Datenqualitaet_Ampel`.

→ `Ampel_Measures_v2.dax` | `Datenqualitaet_Measures.dax`

---

## Schritt 5 – Dashboard-Visualisierung

**Seite 1:** 4 KPI-Karten (🔴 Rot / 🟠 Orange / 🟡 Gelb / 🟢 Grün) + Haupttabelle mit bedingter Formatierung per `Ampel_Farbe_HEX` + Balkendiagramm nach Dringlichkeit. Visual-Filter `Hat_Qualifikation = 1` gegen Phantomzeilen.

**Seite 2:** Wie Seite 1 + Auditor-Slicer vorausgefüllt + Zeitlinie + Karte „nächste Fälligkeit“.

**Seite 3:** Fehler-KPIs + Ist-Soll-Vergleichstabelle (Filter: `Datum_Fehlerhaft = TRUE`, Ist-Spalten rot hinterlegt, CSV-Export).

---

## Schritt 6 – Slicer & Filter

Slicer: Nachname (Dropdown), Qualifikationstyp, Dringlichkeits_Bucket (Kachel), Ampel_Farbe, Status, Jahr, Land. Slicer-Synchronisation über alle Seiten aktivieren. Lesezeichen für Rollenperspektiven: `Kritische Fälle`, `Team-Übersicht`, `Meine Qualifikationen`.

---

## Schritt 7 – Echtzeit-Aktualisierung

### 7.1 DirectQuery vs. Import + Refresh

| Kriterium | DirectQuery | Import + Scheduled Refresh |
|---|---|---|
| Datenaktualität | Immer live | Bis zum letzten Refresh |
| Performance | Langsam (SharePoint REST) | Schnell (In-Memory) |
| M-Transformationen | Stark eingeschränkt | Vollständig unterstützt |
| Berechnete Spalten (Korrekturlogik) | ❌ Nicht möglich | ✅ Vollständig |
| SharePoint Eignung | ⚠️ Sehr langsam | ✅ Optimal |
| Empfehlung | ❌ | **✅ Import-Modus** |

**Empfehlung: Import-Modus** – Die Korrekturlogik (`Table.NestedJoin`, berechnete Spalten, Datumstransformationen) ist in DirectQuery nicht ausführbar. SharePoint REST API ist für Live-Abfragen zu langsam. Mit bis zu 8 täglichen Refreshes ist die Aktualität für ein Qualifikations-Dashboard vollständig ausreichend.

### 7.2 Scheduled Refresh im Power BI Service

**Voraussetzung:** Bericht via **Veröffentlichen (Publish)** in den Power BI Service hochgeladen.

1. Power BI Service → Workspace → **Datensatz** auswählen (nicht den Bericht)
2. **Einstellungen** (⚙️) → **Geplante Aktualisierung** → aufklappen
3. **Aktualisierungsfrequenz:** Täglich
4. **Zeitzone:** Europe/Berlin
5. **Uhrzeiten hinzufügen** (empfohlen): 06:00 · 09:00 · 12:00 · 15:00 · 18:00 (5×/Tag)
6. **E-Mail bei Fehler:** aktivieren
7. Speichern

**Authentifizierung konfigurieren:**  
Einstellungen → **Datenquellenanmeldeinformationen** → SharePoint Online bearbeiten  
→ **OAuth2** → Mit Organisationskonto anmelden  
> Service-Account empfohlen (kein persönliches Konto), damit der Refresh auch bei Abwesenheit funktioniert.

### 7.3 Power Automate als Near-Realtime-Trigger

Für Aktualisierungen kurz nach jeder SharePoint-Änderung kann Power Automate den Refresh auslösen:

**Flow erstellen in Power Automate (make.powerautomate.com):**

1. **Trigger:** `When an item is created or modified`  
   → SharePoint Online → Site: `TeamCyber_Innovation` → Liste: `Qualifikations_Status`

2. **Aktion (Option A – kein Premium nötig):** `Refresh a dataset`  
   → Power BI Connector → Workspace auswählen → Datensatz auswählen

3. **Aktion (Option B – HTTP-Premium-Connector):**

```
POST https://api.powerbi.com/v1.0/myorg/groups/{workspaceId}/datasets/{datasetId}/refreshes
Authorization: Bearer {token}
Content-Type: application/json
Body: {"notifyOption": "NoNotification"}
```

4. Optional: **Delay** von 15–30 Minuten vor der Refresh-Aktion einfügen, um Refresh-Häufung bei Massenänderungen zu vermeiden.

> **Pro-Lizenz-Limit:** Maximal 48 Refreshes pro Tag insgesamt (geplante + automatisch ausgelöste). Bei vielen SharePoint-Änderungen ggf. zusätzliche Bedingung im Flow: nur Refresh auslösen, wenn relevante Felder („Status“, „Datum_Erstberufung_*“) geändert wurden.

---

## Schritt 8 – Row-Level Security (Hinweis)

> **Status:** RLS ist noch nicht implementiert. Dieser Abschnitt beschreibt, wie RLS konfiguriert werden könnte, damit Auditoren nur ihre eigenen Daten sehen.

### 8.1 Konzept

RLS (Row-Level Security) schränkt im Power BI Service den Datenzugriff pro Benutzer ein. Auditoren sehen nur Zeilen in `Qualifikations_Status`, die ihrem eigenen Konto zugeordnet sind. Auditmanager, QM und Geschäftsführung erhalten keine Rolleneinschränkung und sehen alle Daten.

### 8.2 Konfigurationsschritte in Power BI Desktop

**Schritt 1 – Rolle erstellen**

Modellierung → **Rollen verwalten** → **Erstellen**

Rollenname: `Auditor_Eigenansicht`

DAX-Filter auf Tabelle `Auditoren_Stammdaten`:

```dax
[Email_Adresse] = USERPRINCIPALNAME()
```

> `USERPRINCIPALNAME()` gibt die E-Mail-Adresse des angemeldeten Azure AD-Benutzers zurück. Voraussetzung: `Auditoren_Stammdaten[Email_Adresse]` enthält exakt die gleiche E-Mail wie der Azure AD-Account.

**Schritt 2 – Beziehungsfilter prüfen**

Die Beziehung `Auditoren_Stammdaten[Auditor_SP_ID]` → `Qualifikations_Status[Auditor_SP_ID]` muss **aktiv** und Filterrichtung **einfach** (von `Auditoren_Stammdaten` nach `Qualifikations_Status`) sein. Der RLS-Filter propagiert automatisch über aktive Beziehungen auf alle verknüpften Tabellen.

**Schritt 3 – Lokal testen**

Modellierung → **Als Rolle anzeigen** → `Auditor_Eigenansicht` → eigene E-Mail eingeben → prüfen, ob nur eigene Zeilen sichtbar sind.

### 8.3 Rolle im Power BI Service zuweisen

Nach dem Publish:

1. Power BI Service → Workspace → Datensatz → **Mehr (…) → Sicherheit**
2. Rolle `Auditor_Eigenansicht` auswählen
3. Benutzer oder Azure AD-Gruppe hinzufügen (z. B. `sg-auditoren@dekra.com`)
4. Speichern

> Auditmanager, QM und Geschäftsführung erhalten **keine Rollenzuweisung** und sehen damit automatisch alle Daten.

### 8.4 Einschränkungen bei Pro-Lizenz

| Einschränkung | Details |
|---|---|
| Nur im Service wirksam | Im Desktop (für Endnutzer) gibt es keine RLS-Einschränkung |
| Excel-Export umgeht RLS | Export nach Excel/CSV ist nicht durch RLS geschützt |
| Dashboard-Pins | Gepinnte Kacheln respektieren RLS nur beim Ersteller der Kachel |
| Performance | Bei vielen RLS-Rollen kann die Abfragezeit steigen |

---

## Anhang – Rollenperspektiven

### Auditoren – Eigenansicht

**Einstiegspunkt:** Seite 2 als Standard-Landingpage konfigurieren (Lesezeichen auf Seite 2 setzen und als Startseite festlegen).

| Handlung | Wo |
|---|---|
| Eigene ablaufende Qualifikationen sehen | Seite 2 – Tabellenvisual, absteigend nach Tage sortiert |
| Nächste Fälligkeit prüfen | Karte `Frühestes_Ablaufdatum` |
| Zeitlichen Verlauf überblicken | Zeitlinie auf Seite 2 |
| Bei RLS aktiv | Slicer auf eigenen Namen hat keine Wirkung – Daten sind bereits gefiltert |

### Auditmanager / Teamleitung

**Einstiegspunkt:** Seite 1 ohne Vorfilter.

| Handlung | Wo |
|---|---|
| Kritische Fälle identifizieren | KPI-Karte `Anzahl_Rot` (abgelaufene Qualifikationen) + Tabellenvisual gefiltert auf `Tage_bis_Ablauf < 0` |
| Dringliche Fälle (0–90 Tage) überblicken | KPI-Karte `Anzahl_Orange` + Dringlichkeits_Bucket-Slicer |
| Einzelne Auditoren prüfen | Nachname-Slicer auf Seite 1 |
| Team-Risikoprofil | Balkendiagramm nach Dringlichkeit (alle Auditoren) |
| Teamliste exportieren | Tabellenvisual → `…` → Daten exportieren |

### QM / Compliance

**Einstiegspunkt:** Seite 3 – Datenqualität.

| Handlung | Wo |
|---|---|
| Fehleranzahl prüfen | KPI-Karte `Anzahl_Datum_Fehlerhaft` |
| Gesamtbewertung | Measure `Datenqualitaet_Ampel` |
| Fehlerhafte Einträge identifizieren | Ist-Soll-Vergleichstabelle (automatisch gefiltert) |
| Fehlerliste für Korrektur exportieren | CSV-Export der Vergleichstabelle |
| Regelkonformität je Qualifikationstyp | Qualifikationstyp-Slicer + Fehleranteil-Karte |

### Geschäftsführung / Management

**Einstiegspunkt:** Seite 1 – optional in Microsoft Teams oder SharePoint eingebettet.

| Handlung | Wo |
|---|---|
| Risiko-KPIs auf einen Blick | KPI-Leiste oben (🔴 Rot / 🟠 Orange / 🟡 Gelb / 🟢 Grün) |
| Regionale Analyse | Land-Slicer → Balkendiagramm aktualisiert sich automatisch |
| Anteil abgelaufener Qualifikationen | Measure `Anteil_Kritisch_Prozent` als zusätzliche Karte |
| Datenqualität überwachen | Measure `Datenqualitaet_Ampel` als Karte auf Seite 1 einbinden |

---

*Technische Fragen zur Implementierung: Abfragen in `Mashup_komplett.pq`, DAX in `Ampel_Measures_v2.dax` und `Datenqualitaet_Measures.dax`, Korrekturlogik in `Qualifikations_Status_Korrektur.pq`.*

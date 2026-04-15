# TODO – Zündplus-Unterstützung für ExpanderPiSetup

## Ziel

ExpanderPiSetup soll optional eine **Zündplus-Erfassung** für den DPlus_Simulator bereitstellen.

Wichtig:
- ExpanderPiSetup ist **nicht** Voraussetzung für den normalen DPlus-Simulator-Betrieb
- Es wird **nur** benötigt, wenn im DPlus_Simulator der neue Schalter **„Zündplus verwenden“** aktiviert wird
- ExpanderPiSetup soll eine **saubere digitale Zündinformation** bereitstellen:
  - `0` = Zündung aus
  - `1` = Zündung an

---

## Grundidee

ExpanderPiSetup soll die Hardware-/Signalquelle für Zündplus definieren und so aufbereiten, dass der DPlus_Simulator nur noch einen einfachen digitalen Zustand lesen muss.

Der DPlus_Simulator soll **nicht** selbst 12–14,5 V direkt messen oder interpretieren.

---

## Gewünschte Ausgabe für DPlus_Simulator

ExpanderPiSetup bzw. der zugehörige Laufzeitdienst soll einen D-Bus-Wert bereitstellen, sinngemäß:

- Service: z. B. `com.victronenergy.expanderpi`
- Path: z. B. `/DPlusSimulator/Ignition`

Wert:
- `0` / `False` = Zündung aus
- `1` / `True` = Zündung an

Die endgültige Namensgebung kann angepasst werden, aber die Ausgabe muss:
- digital
- stabil
- dokumentiert
- für DPlus_Simulator konfigurierbar

sein.

---

## UI-Anforderungen

ExpanderPiSetup braucht eine Möglichkeit, einen Eingang oder Kanal gezielt als Zündplusquelle zu definieren.

## Neue UI-Funktion
Zum Beispiel:
- **Zündplus-Eingang für DPlus_Simulator**
- Auswahl des zu verwendenden Eingangs / Kanals
- optional Label / Beschreibung

Optional zusätzlich:
- Anzeige des aktuellen Zustands
  - Zündung an
  - Zündung aus

---

## Anforderungen an die Konfiguration

Es muss definiert werden:

- welcher Eingang / Kanal für Zündplus verwendet wird
- ob dieser Eingang digital oder aus einer ADC-Schwellenlogik abgeleitet wird
- wie daraus ein eindeutiger 0/1-Zustand erzeugt wird

### Bevorzugter Weg
Ein **digitales Eingangssignal**.

### Nicht bevorzugt, nur falls nötig
Analoge Messung mit Schwellwertauswertung.

Wenn analog nötig:
- Schwellwert einstellbar
- Hysterese sinnvoll prüfen
- aber möglichst vermeiden, wenn ein digitaler Zustand einfacher erzeugt werden kann

---

## Hardwareanforderungen

## Sehr wichtig
Das Fahrzeugsignal Zündplus (12–14,5 V, Bordnetz) darf **nicht direkt** an Pi-/Expander-Eingänge angeschlossen werden.

Es braucht eine saubere Signalaufbereitung.

---

## Unterstützte bzw. empfohlene Hardwarevarianten

### 1. Optokoppler
Empfohlen für robuste Fahrzeugintegration.

Vorteile:
- galvanische Trennung
- guter Schutz
- saubere Entkopplung

### 2. Transistorstufe mit Schutzbeschaltung
Ebenfalls möglich.

Vorteile:
- kompakt
- günstig
- gut umsetzbar

### 3. Relais als Signaltrenner
Soll ausdrücklich als zulässige Option berücksichtigt werden.

## Relais-Variante
- 12–14,5 V Zündplus schaltet die Spule eines kleinen 12-V-Relais
- der Relaiskontakt schaltet **nicht** direkt 12 V zum Expander
- der Relaiskontakt schaltet ein **sauberes Hilfssignal** zum Expander-Eingang

Das ist wichtig:
Das Relais dient als **Signaltrenner**, nicht als Spannungsreduzierer.

---

## Erwartetes Eingangssignal für den Expander

Am Ende soll der Expander nur noch ein klares Logiksignal sehen:

- Eingang inaktiv -> 0
- Eingang aktiv -> 1

Wie dieses Signal hardwareseitig erzeugt wird, ist egal, solange es:
- sicher
- zulässig
- stabil
- dokumentiert

ist.

---

## Was in ExpanderPiSetup erweitert werden muss

## 1. Konfigurationsschema
Neue Settings/Optionen für:
- Ignition aktiv / nicht aktiv
- gewählter Eingang / Kanal
- optional Typ „ignition“

Wenn heute nur Typen wie `none`, `tank`, `temp` existieren, muss erweitert werden um:
- `ignition`

oder eine separate Ignition-Konfiguration.

---

## 2. Setup-Skript / Generator
Das Setup-Skript muss aus der Konfiguration:
- die passende Laufzeitkonfiguration erzeugen
- ggf. den gewählten Kanal bekannt machen
- und die D-Bus-Bereitstellung vorbereiten

---

## 3. Laufzeitdienst / D-Bus-Ausgabe
Der relevante Dienst muss einen lesbaren Wert bereitstellen, den der DPlus_Simulator verwenden kann.

Anforderung:
- stabiler boolescher Zustand
- sauber über D-Bus lesbar
- eindeutiger, dokumentierter Pfad

---

## 4. UI-Anzeige
Im UI sollte erkennbar sein:
- ob Ignition-Funktion aktiviert ist
- welcher Eingang verwendet wird
- optional aktueller Zustand

---

## 5. README / Dokumentation
ExpanderPiSetup-README ergänzen um:
- Unterstützung für DPlus_Simulator-Zündplus
- Hardwarehinweis: kein direktes 12–14,5-V-Signal
- zulässige Signalaufbereitung:
  - Optokoppler
  - Transistorstufe
  - Relais als Signaltrenner
- Hinweis auf Ziel:
  - sauberer digitaler Zustand für DPlus_Simulator

---

## Schnittstelle zu DPlus_Simulator fest definieren

Es muss klar definiert werden:
- Service-Name
- Pfad
- Datentyp
- Wertebereich

### Beispiel
- Service: `com.victronenergy.expanderpi`
- Path: `/DPlusSimulator/Ignition`
- Typ: bool / int
- Werte:
  - 0 = aus
  - 1 = an

Wichtig:
Diese Schnittstelle muss dokumentiert und in beiden Repos identisch verwendet werden.

---

## Fehlerbehandlung

Wenn kein gültiger Ignition-Eingang konfiguriert ist:
- D-Bus-Wert entweder gar nicht bereitstellen
- oder klar als „nicht verfügbar“ kennzeichnen

Der DPlus_Simulator soll dann sauber erkennen können:
- Ignition nicht verfügbar
- Einschalten blockieren, wenn `UseIgnition=true`

---

## Testfälle

### Konfiguration
- Ignition-Eingang konfigurierbar
- Setting bleibt persistent

### Laufzeit
- Eingang LOW -> D-Bus-Wert 0
- Eingang HIGH -> D-Bus-Wert 1

### DPlus-Simulator-Integration
- DPlus_Simulator kann den Zustand lesen
- Zustand ändert sich sauber und ohne wilde Flanken

### Fehlerfall
- Ignition konfiguriert, aber Quelle nicht vorhanden -> sauberer Fehlerzustand
- kein Crash des Systems

---

## Offene technische Entscheidungen

Vor Umsetzung festlegen:

1. Welcher konkrete Service-/Pfadname wird verwendet?
2. Digitaler Eingang direkt oder abgeleitet aus ADC?
3. Wo findet die Schwellenbildung statt, falls analog?
   - möglichst in ExpanderPi-/Eingangsseite, nicht im DPlus_Simulator
4. Soll der aktuelle Ignition-Status im ExpanderPi-UI sichtbar sein?
   - empfohlen: ja

---

## Empfehlung zur Umsetzung

1. Erst die D-Bus-Schnittstelle festlegen
2. Dann UI/Settings erweitern
3. Dann Laufzeitwert erzeugen
4. Dann README ergänzen
5. Danach Integration mit DPlus_Simulator testen

---

## Wichtigster Grundsatz

ExpanderPiSetup stellt nur das **optionale Zündplus-Signal** bereit.

Der normale DPlus_Simulator-Betrieb ohne Zündplus muss weiterhin ohne ExpanderPiSetup funktionieren.

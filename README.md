# ExpanderPiSetup

Richtet die analogen Eingänge des [AB-Electronics Expander Pi](https://www.abelectronics.co.uk/p/50/expander-pi) auf Venus OS ein. Verwendet den Victron-Treiber `dbus-adc`.

## Installation

Voraussetzung: unterstützter Raspberry Pi, angeschlossene Expander-Pi-Platine und [SetupHelper](https://github.com/kwindrem/SetupHelper).

Im Paketmanager: Paket `ExpanderPiSetup`, GitHub-Benutzer `CoYoDuDe`, Branch `main`.

## Sensoren einrichten

1. **Einstellungen → ExpanderPi** öffnen.
2. Für die acht ADC-Kanäle Typ und Namen festlegen: `tank`, `temp` oder `none`.
3. Nach Änderungen das Paket über SetupHelper erneut installieren, damit die Treiberkonfiguration angewendet wird.
4. Kanäle unter **Einstellungen → I/O → Analoge Eingänge** aktivieren und die Werte prüfen.

Die Vorlage sieht ADC 1–4 als Tanks und ADC 5–8 als Temperaturen vor; die Eingänge sind zunächst deaktiviert. Das ist keine automatische Erkennung der angeschlossenen Sensoren. `none` entfernt den Kanal aus der Liste. Eigene Zuordnung und Kalibrierung bleiben bei Updates erhalten.

## Sensorwerte

Der Software-Standard ist **Vref 1,3 / Scale 4095**. Vref gehört zur Umrechnung des Victron-Treibers einschließlich Spannungsteiler. Die nominelle Referenzspannung der Platine allein ist kein Grund, funktionierende Werte zu ändern.

`temp` nutzt die [LM335-Umrechnung von Victron](https://github.com/victronenergy/dbus-adc/blob/master/software/src/sensors.c). Ein 10-kΩ-NTC B3950 braucht eine andere Umrechnung und ist damit nicht direkt kompatibel. Tanksensoren brauchen eine zum Geber passende Beschaltung und Kalibrierung.

Ab v1.5.1 stimmen Einstellungsliste und Setup-Standard wieder überein. Bereits gespeicherte Werte werden nicht automatisch geändert. Wurde eine funktionierende Konfiguration früher auf 4,096 umgestellt, den ursprünglichen Wert gezielt wiederherstellen.

## Updates und Entfernen

Über SetupHelper aktualisieren und entfernen. Benutzerkonfiguration und Sicherungen liegen außerhalb des Pakets unter `/data/setupOptions/ExpanderPiSetup`. Das Setup verwaltet seine Boot-Anpassungen in einem markierten Block und erhält fremde Einträge.

## Unterstützung

Die Pakete sind kostenlos. Freiwillige Unterstützung: [PayPal](https://paypal.me/CoYoDuDe), [Buy Me a Coffee](https://www.buymeacoffee.com/CoYoDuDe), [weitere Projekte](https://dnsmith.net/). Kein Abo-Zwang.

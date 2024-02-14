# Venus OS dbus-adc Konfiguration mit dem ExpanderPi

Dieses Skript automatisiert die Konfiguration und Einrichtung der `dbus-adc.conf` und der erforderlichen Overlays auf Venus OS-Geräten mit dem ExpanderPi. Es ist ideal für Anwendungen in Wohnmobilen, um Tankanzeige oder Temperaturen zu überwachen.

## Funktionen

- Wiederherstellung der `dbus-adc.conf`, falls erforderlich.
- Überprüfung und Wiederherstellung fehlender Overlay-Dateien (`i2c-rtc.dtbo`, `ds1307-rtc.dtbo`, `mcp3208.dtbo`).
- Anpassung der `/u-boot/config.txt`, um erforderliche `dtoverlay`-Einträge hinzuzufügen.
- Überprüfung und Installation benötigter Kernel-Module (`kernel-module-rtc-ds1307`, `kernel-module-mcp320x`).
- Einrichtung der `/data/rc.local` für die RTC-Zeitsynchronisation.

## Installation über Venus OS GUI mit dem SetupHelper von kwindream

1. Öffnen Sie die Venus OS GUI auf Ihrem Gerät.
2. Navigieren Sie zum Bereich für die Erweiterungen oder zum SetupHelper.
3. Fügen Sie die URL `https://github.com/CoYoDuDe/VenusOS_ExpanderPi`, die dieses Skript enthält, in das entsprechende Feld ein, um es dem SetupHelper hinzuzufügen.
4. Wählen Sie dieses Skript aus der Liste der verfügbaren Skripte/Erweiterungen zur Installation aus.
5. Bestätigen Sie die Installation und warten Sie, bis der SetupHelper das Skript automatisch installiert hat.

## Deinstallation

Um das Skript zu deinstallieren und alle vorgenommenen Änderungen rückgängig zu machen, verwenden Sie die Venus OS GUI:

1. Gehen Sie zurück zum Bereich vom SetupHelper in der Venus OS GUI.
2. Wählen Sie das installierte Skript aus der Liste der installierten Skripte/Erweiterungen aus.
3. Wählen Sie die Option zur Deinstallation oder Entfernung.
4. Bestätigen Sie die Deinstallation, um das Skript und alle damit verbundenen Konfigurationen zu entfernen.

## Fehlerbehebung

- Überprüfen Sie die Internetverbindung Ihres Geräts, falls das Skript externe Module oder Dateien herunterladen muss.
- Stellen Sie sicher, dass das GitHub-Repository `https://github.com/CoYoDuDe/VenusOS_ExpanderPi` korrekt zur SetupHelper-Konfiguration hinzugefügt wurde.
- Überprüfen Sie die Venus OS-Dokumentation und -Supportforen für spezifische Anweisungen oder bekannte Probleme im Zusammenhang mit dem SetupHelper.

## Support

Bei Fragen oder Problemen mit der Konfiguration wenden Sie sich bitte an die [Community-Foren von Venus OS](https://community.victronenergy.com/) oder erstellen Sie ein [Issue im GitHub-Repository](https://github.com/CoYoDuDe/VenusOS_ExpanderPi/issues).

import QtQuick 1.1
import com.victron.velib 1.0

MbPage {
    id: root
    title: qsTr("ExpanderPi DBus-ADC")

    property string settingsPrefix: "com.victronenergy.settings/Settings/ExpanderPi/DbusAdc"
    property int channelCount: 8

    readonly property var sensorTypeOptions: [
        { text: qsTr("Nicht belegt"), value: "none" },
        { text: qsTr("Tank"), value: "tank" },
        { text: qsTr("Temperatur"), value: "temp" }
    ]

    readonly property var sensorTypeCanonicalMap: ({
        "": "none",
        "none": "none",
        "nicht belegt": "none",
        "kein": "none",
        "keiner": "none",
        "keine": "none",
        "leer": "none",
        "deaktiviert": "none",
        "aus": "none",
        "ausgeschaltet": "none",
        "disabled": "none",
        "off": "none",

        "tank": "tank",
        "fuel": "tank",
        "diesel": "tank",
        "wasser": "tank",
        "water": "tank",
        "level": "tank",
        "tankgeber": "tank",
        "tanksensor": "tank",

        "temp": "temp",
        "temperature": "temp",
        "temperatur": "temp",
        "heat": "temp",
        "temperatursensor": "temp",
        "temperaturesensor": "temp",
        "tempsensor": "temp"
    })

    function canonicalSensorType(typeValue) {
        var raw = "";
        if (typeValue !== undefined && typeValue !== null) {
            raw = String(typeValue).trim();
        }
        var normalized = raw.toLowerCase();
        var compact = normalized.replace(/[\s_-]+/g, "");
        if (sensorTypeCanonicalMap.hasOwnProperty(normalized)) {
            return sensorTypeCanonicalMap[normalized];
        }
        if (sensorTypeCanonicalMap.hasOwnProperty(compact)) {
            return sensorTypeCanonicalMap[compact];
        }

        switch (normalized) {
        case "tank":
        case "temp":
        case "none":
            return normalized;
        default:
            return raw.length === 0 ? "none" : "none";
        }
    }

    readonly property var defaultChannelSetup: [
        { type: "tank", label: qsTr("Tank %1").arg(1) },
        { type: "tank", label: qsTr("Tank %1").arg(2) },
        { type: "tank", label: qsTr("Tank %1").arg(3) },
        { type: "tank", label: qsTr("Tank %1").arg(4) },
        { type: "temp", label: qsTr("Temperatur %1").arg(5) },
        { type: "temp", label: qsTr("Temperatur %1").arg(6) },
        { type: "temp", label: qsTr("Temperatur %1").arg(7) },
        { type: "temp", label: qsTr("Temperatur %1").arg(8) }
    ]

    function defaultLabelForType(type, index) {
        var rawType = String(type || "none");
        var normalizedType = canonicalSensorType(rawType);
        var channelNumber = (index !== undefined ? index : 0) + 1;

        switch (normalizedType) {
        case "tank":
            return qsTr("Tank %1").arg(channelNumber);
        case "temp":
            return qsTr("Temperatur %1").arg(channelNumber);
        case "none":
        default:
            return "";
        }
    }

    property VBusItem vrefItem: VBusItem { bind: settingsPrefix + "/Vref" }
    property VBusItem scaleItem: VBusItem { bind: settingsPrefix + "/Scale" }
    property VBusItem packageActionItem: VBusItem { bind: "com.victronenergy.packageManager/GuiEditAction" }
    property VBusItem packageStatusItem: VBusItem { bind: "com.victronenergy.packageManager/GuiEditStatus" }

    property bool installRequestPending: false
    property string localStatusMessage: ""
    readonly property bool packageManagerAvailable: packageActionItem.valid && packageStatusItem.valid
    readonly property string currentStatusText: {
        if (!packageManagerAvailable) {
            return qsTr("PackageManager-Dienst nicht verfügbar.");
        }
        if (localStatusMessage && localStatusMessage.length > 0) {
            return localStatusMessage;
        }
        if (packageStatusItem.valid) {
            var raw = packageStatusItem.value;
            if (raw !== undefined && raw !== null) {
                var text = String(raw).trim();
                if (text.length > 0) {
                    return text;
                }
            }
        }
        return "";
    }

    function channelPath(index) {
        return settingsPrefix + "/Channel" + index;
    }

    function sensorSummary(typeValue, labelValue, index) {
        var rawType = String(typeValue || "none");
        var canonicalType = canonicalSensorType(rawType);
        var normalizedOriginal = rawType.toLowerCase();
        var compactOriginal = normalizedOriginal.replace(/[\s_-]+/g, "");
        var recognizedOriginal = sensorTypeCanonicalMap.hasOwnProperty(normalizedOriginal)
            || sensorTypeCanonicalMap.hasOwnProperty(compactOriginal)
            || normalizedOriginal === "tank"
            || normalizedOriginal === "temp"
            || normalizedOriginal === "none"
            || normalizedOriginal.length === 0;
        if (canonicalType === "none") {
            if (!recognizedOriginal && rawType.length > 0) {
                return qsTr("Kanal %1: Nicht unterstützter Typ (%2)")
                        .arg(index + 1)
                        .arg(rawType);
            }
            return qsTr("Kanal %1 deaktiviert").arg(index + 1);
        }

        var typeText = "";
        switch (canonicalType) {
        case "tank":
            typeText = qsTr("Tank");
            break;
        case "temp":
            typeText = qsTr("Temperatur");
            break;
        default:
            var trimmedOriginalType = rawType;
            if (trimmedOriginalType.trim) {
                trimmedOriginalType = trimmedOriginalType.trim();
            }
            typeText = trimmedOriginalType.length > 0 ? trimmedOriginalType : rawType;
            break;
        }

        var labelText = String(labelValue || "").trim();
        if (labelText.length === 0) {
            labelText = typeText;
        }

        return labelText + " • " + typeText;
    }

    function ensureChannelDefault(binding) {
        if (!binding) {
            return;
        }

        var defaults = defaultChannelSetup[binding.channelIndex] || { type: "none", label: "" };

        if (!binding.typeItem.valid || !binding.typeItem.value || binding.typeItem.value === "") {
            binding.typeItem.setValue(defaults.type);
        }

        var effectiveType = String(binding.typeItem.value || defaults.type || "none");
        var canonicalType = canonicalSensorType(effectiveType);
        if (binding.typeItem.valid && canonicalType !== binding.typeItem.value) {
            binding.typeItem.setValue(canonicalType);
            effectiveType = canonicalType;
        } else {
            effectiveType = canonicalType;
        }
        var normalizedType = effectiveType.toLowerCase();
        var currentLabel = binding.labelItem.value;
        var trimmedLabel = String(currentLabel === undefined ? "" : currentLabel).trim();
        var labelMissing = !binding.labelItem.valid || currentLabel === undefined || trimmedLabel.length === 0;

        if (binding.labelItem.valid && currentLabel !== undefined && currentLabel !== "" && trimmedLabel.length === 0) {
            binding.labelItem.setValue("");
            currentLabel = "";
        }

        if (normalizedType === "none") {
            if (!labelMissing) {
                binding.labelItem.setValue("");
            }
            return;
        }

        if (!labelMissing) {
            return;
        }

        var typeDefaultLabel = defaultLabelForType(effectiveType, binding.channelIndex);
        if (typeDefaultLabel && typeDefaultLabel.length > 0) {
            binding.labelItem.setValue(typeDefaultLabel);
            return;
        }

        if (defaults.label !== undefined) {
            binding.labelItem.setValue(defaults.label);
        }
    }

    function ensureDefaults() {
        if (!vrefItem.valid || vrefItem.value === undefined || vrefItem.value === null || String(vrefItem.value).trim().length === 0) {
            vrefItem.setValue("1.300");
        }
        if (!scaleItem.valid || scaleItem.value === undefined || scaleItem.value === null || String(scaleItem.value).trim().length === 0) {
            scaleItem.setValue("4095");
        }

        for (var i = 0; i < channelCount; ++i) {
            var channel = channelBindings[i];
            if (!channel) {
                continue;
            }
            ensureChannelDefault(channel);
        }
    }

    function applyChanges() {
        if (!packageActionItem.valid) {
            localStatusMessage = qsTr("PackageManager-Dienst nicht verfügbar.");
            if (packageStatusItem.valid) {
                packageStatusItem.setValue(localStatusMessage);
            }
            console.warn("PackageManager-Dienst nicht verfügbar – Installationslauf kann nicht gestartet werden.");
            return false;
        }

        var currentAction = packageActionItem.value;
        if (currentAction !== undefined && currentAction !== null) {
            var actionText = String(currentAction).trim();
            if (actionText.length > 0) {
                var busyMessage = qsTr("PackageManager beschäftigt (%1)").arg(actionText);
                localStatusMessage = busyMessage;
                if (packageStatusItem.valid) {
                    packageStatusItem.setValue(busyMessage);
                }
                console.warn("PackageManager ist noch beschäftigt (", actionText, ")");
                return false;
            }
        }

        installRequestPending = true;

        var startMessage = qsTr("Setup wird gestartet …");
        localStatusMessage = startMessage;
        if (packageStatusItem.valid) {
            packageStatusItem.setValue(startMessage);
        }

        packageActionItem.setValue("install:ExpanderPiSetup");
        return true;
    }

    function reloadFromPersistedState() {
        ensureDefaults();
    }

    property var channelBindings: new Array(channelCount)

    function registerChannelBinding(binding) {
        if (!binding) {
            return;
        }
        channelBindings[binding.channelIndex] = binding;
        ensureChannelDefault(binding);
    }

    Component.onCompleted: ensureDefaults()

    Connections {
        target: packageStatusItem
        onValueChanged: {
            if (!packageStatusItem.valid) {
                return;
            }
            var statusText = packageStatusItem.value !== undefined && packageStatusItem.value !== null
                    ? String(packageStatusItem.value).trim()
                    : "";
            if (statusText.length > 0) {
                localStatusMessage = "";
            }
        }
    }

    Connections {
        target: packageActionItem
        onValueChanged: {
            if (!packageActionItem.valid) {
                return;
            }
            var actionValue = packageActionItem.value !== undefined && packageActionItem.value !== null
                    ? String(packageActionItem.value)
                    : "";
            if (actionValue === "ERROR") {
                installRequestPending = false;
                var errorMessage = packageStatusItem.valid && packageStatusItem.value
                        ? String(packageStatusItem.value)
                        : qsTr("Fehler beim Installationslauf.");
                localStatusMessage = errorMessage;
            } else if (actionValue.length === 0 && installRequestPending) {
                installRequestPending = false;
                if (packageStatusItem.valid && packageStatusItem.value) {
                    var statusText = String(packageStatusItem.value).trim();
                    if (statusText.length === 0) {
                        localStatusMessage = qsTr("Installationslauf ausgelöst.");
                    }
                } else {
                    localStatusMessage = qsTr("Installationslauf ausgelöst.");
                }
            }
        }
    }

    model: VisibleItemModel {
        MbItemText {
            text: qsTr("Verwalten Sie Referenzspannung, ADC-Scale und die Sensorbelegung der acht ExpanderPi-Kanäle.")
            wrapMode: Text.WordWrap
        }

        MbEditBox {
            id: vrefEditor
            description: qsTr("Referenzspannung (Vref)")
            maximumLength: 8
            item: vrefItem
            writeAccessLevel: User.AccessInstaller
            unit: "V"
        }

        MbEditBox {
            id: scaleEditor
            description: qsTr("ADC Scale")
            maximumLength: 8
            item: scaleItem
            writeAccessLevel: User.AccessInstaller
        }

        MbSubMenu {
            id: channel0
            property int channelIndex: 0
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel0)
            onLabelItemChanged: root.registerChannelBinding(channel0)
            Component.onCompleted: root.registerChannelBinding(channel0)

            Connections {
                target: channel0.typeItem
                onValueChanged: root.registerChannelBinding(channel0)
            }

            Connections {
                target: channel0.labelItem
                onValueChanged: root.ensureChannelDefault(channel0)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel0.typeItem.value, channel0.labelItem.value, channel0.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel0.channelIndex + 1)
                    property int channelIndex: channel0.channelIndex
                    property VBusItem typeItem: channel0.typeItem
                    property VBusItem labelItem: channel0.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbSubMenu {
            id: channel1
            property int channelIndex: 1
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel1)
            onLabelItemChanged: root.registerChannelBinding(channel1)
            Component.onCompleted: root.registerChannelBinding(channel1)

            Connections {
                target: channel1.typeItem
                onValueChanged: root.registerChannelBinding(channel1)
            }

            Connections {
                target: channel1.labelItem
                onValueChanged: root.ensureChannelDefault(channel1)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel1.typeItem.value, channel1.labelItem.value, channel1.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel1.channelIndex + 1)
                    property int channelIndex: channel1.channelIndex
                    property VBusItem typeItem: channel1.typeItem
                    property VBusItem labelItem: channel1.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbSubMenu {
            id: channel2
            property int channelIndex: 2
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel2)
            onLabelItemChanged: root.registerChannelBinding(channel2)
            Component.onCompleted: root.registerChannelBinding(channel2)

            Connections {
                target: channel2.typeItem
                onValueChanged: root.registerChannelBinding(channel2)
            }

            Connections {
                target: channel2.labelItem
                onValueChanged: root.ensureChannelDefault(channel2)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel2.typeItem.value, channel2.labelItem.value, channel2.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel2.channelIndex + 1)
                    property int channelIndex: channel2.channelIndex
                    property VBusItem typeItem: channel2.typeItem
                    property VBusItem labelItem: channel2.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbSubMenu {
            id: channel3
            property int channelIndex: 3
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel3)
            onLabelItemChanged: root.registerChannelBinding(channel3)
            Component.onCompleted: root.registerChannelBinding(channel3)

            Connections {
                target: channel3.typeItem
                onValueChanged: root.registerChannelBinding(channel3)
            }

            Connections {
                target: channel3.labelItem
                onValueChanged: root.ensureChannelDefault(channel3)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel3.typeItem.value, channel3.labelItem.value, channel3.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel3.channelIndex + 1)
                    property int channelIndex: channel3.channelIndex
                    property VBusItem typeItem: channel3.typeItem
                    property VBusItem labelItem: channel3.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbSubMenu {
            id: channel4
            property int channelIndex: 4
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel4)
            onLabelItemChanged: root.registerChannelBinding(channel4)
            Component.onCompleted: root.registerChannelBinding(channel4)

            Connections {
                target: channel4.typeItem
                onValueChanged: root.registerChannelBinding(channel4)
            }

            Connections {
                target: channel4.labelItem
                onValueChanged: root.ensureChannelDefault(channel4)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel4.typeItem.value, channel4.labelItem.value, channel4.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel4.channelIndex + 1)
                    property int channelIndex: channel4.channelIndex
                    property VBusItem typeItem: channel4.typeItem
                    property VBusItem labelItem: channel4.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbSubMenu {
            id: channel5
            property int channelIndex: 5
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel5)
            onLabelItemChanged: root.registerChannelBinding(channel5)
            Component.onCompleted: root.registerChannelBinding(channel5)

            Connections {
                target: channel5.typeItem
                onValueChanged: root.registerChannelBinding(channel5)
            }

            Connections {
                target: channel5.labelItem
                onValueChanged: root.ensureChannelDefault(channel5)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel5.typeItem.value, channel5.labelItem.value, channel5.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel5.channelIndex + 1)
                    property int channelIndex: channel5.channelIndex
                    property VBusItem typeItem: channel5.typeItem
                    property VBusItem labelItem: channel5.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbSubMenu {
            id: channel6
            property int channelIndex: 6
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel6)
            onLabelItemChanged: root.registerChannelBinding(channel6)
            Component.onCompleted: root.registerChannelBinding(channel6)

            Connections {
                target: channel6.typeItem
                onValueChanged: root.registerChannelBinding(channel6)
            }

            Connections {
                target: channel6.labelItem
                onValueChanged: root.ensureChannelDefault(channel6)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel6.typeItem.value, channel6.labelItem.value, channel6.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel6.channelIndex + 1)
                    property int channelIndex: channel6.channelIndex
                    property VBusItem typeItem: channel6.typeItem
                    property VBusItem labelItem: channel6.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbSubMenu {
            id: channel7
            property int channelIndex: 7
            property string channelPath: root.channelPath(channelIndex)
            property VBusItem typeItem: VBusItem { bind: channelPath + "/Type" }
            property VBusItem labelItem: VBusItem { bind: channelPath + "/Label" }
            onTypeItemChanged: root.registerChannelBinding(channel7)
            onLabelItemChanged: root.registerChannelBinding(channel7)
            Component.onCompleted: root.registerChannelBinding(channel7)

            Connections {
                target: channel7.typeItem
                onValueChanged: root.registerChannelBinding(channel7)
            }

            Connections {
                target: channel7.labelItem
                onValueChanged: root.ensureChannelDefault(channel7)
            }

            description: qsTr("Sensor Kanal %1").arg(channelIndex + 1)
            item: labelItem

            MbTextBlock {
                text: root.sensorSummary(channel7.typeItem.value, channel7.labelItem.value, channel7.channelIndex)
            }

            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal %1").arg(channel7.channelIndex + 1)
                    property int channelIndex: channel7.channelIndex
                    property VBusItem typeItem: channel7.typeItem
                    property VBusItem labelItem: channel7.labelItem

                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem
                            possibleValues: root.sensorTypeOptions
                            writeAccessLevel: User.AccessInstaller
                        }

                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            maximumLength: 24
                            item: labelItem
                            writeAccessLevel: User.AccessInstaller
                            show: typeItem.value !== "none"
                        }
                    }
                }
            }
        }

        MbOK {
            id: reloadButton
            description: ""
            value: qsTr("Zurücksetzen")
            onClicked: {
                reloadFromPersistedState();
            }
        }

        MbTextBlock {
            id: packageStatusBlock
            text: root.currentStatusText
            wrapMode: Text.WordWrap
            show: root.currentStatusText.length > 0
        }

        MbOK {
            id: saveButton
            description: ""
            value: qsTr("Speichern & Installieren")
            onClicked: applyChanges()
            writeAccessLevel: User.AccessInstaller
        }
    }
}

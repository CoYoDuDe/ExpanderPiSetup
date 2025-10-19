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
        { text: qsTr("Temperatur"), value: "temp" },
        { text: qsTr("Spannung"), value: "voltage" },
        { text: qsTr("Strom"), value: "current" },
        { text: qsTr("Druck"), value: "pressure" },
        { text: qsTr("Feuchte"), value: "humidity" },
        { text: qsTr("Generisch"), value: "custom" }
    ]

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
        var normalizedType = String(type || "none");
        var channelNumber = (index !== undefined ? index : 0) + 1;

        switch (normalizedType) {
        case "tank":
            return qsTr("Tank %1").arg(channelNumber);
        case "temp":
            return qsTr("Temperatur %1").arg(channelNumber);
        case "voltage":
            return qsTr("Spannung %1").arg(channelNumber);
        case "current":
            return qsTr("Strom %1").arg(channelNumber);
        case "pressure":
            return qsTr("Druck %1").arg(channelNumber);
        case "humidity":
            return qsTr("Feuchte %1").arg(channelNumber);
        case "custom":
            return qsTr("Generisch %1").arg(channelNumber);
        case "none":
        default:
            return "";
        }
    }

    property var helperApi: ({
        get instance() {
            if (typeof SetupHelper !== "undefined") {
                return SetupHelper;
            }
            if (typeof SetupHelperApi !== "undefined") {
                return SetupHelperApi;
            }
            if (typeof helperApp !== "undefined") {
                return helperApp;
            }
            return null;
        }
    }).instance

    property VBusItem vrefItem: VBusItem { bind: settingsPrefix + "/Vref" }
    property VBusItem scaleItem: VBusItem { bind: settingsPrefix + "/Scale" }

    function channelPath(index) {
        return settingsPrefix + "/Channel" + index;
    }

    function sensorSummary(typeValue, labelValue, index) {
        var normalizedType = String(typeValue || "none");
        if (normalizedType === "none") {
            return qsTr("Kanal %1 deaktiviert").arg(index + 1);
        }

        var typeText = "";
        switch (normalizedType) {
        case "tank":
            typeText = qsTr("Tank");
            break;
        case "temp":
            typeText = qsTr("Temperatur");
            break;
        case "voltage":
            typeText = qsTr("Spannung");
            break;
        case "current":
            typeText = qsTr("Strom");
            break;
        case "pressure":
            typeText = qsTr("Druck");
            break;
        case "humidity":
            typeText = qsTr("Feuchte");
            break;
        case "custom":
            typeText = qsTr("Benutzerdefiniert");
            break;
        default:
            typeText = qsTr("Deaktiviert");
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
        var currentLabel = binding.labelItem.value;
        var trimmedLabel = String(currentLabel === undefined ? "" : currentLabel).trim();
        var labelMissing = !binding.labelItem.valid || currentLabel === undefined || trimmedLabel.length === 0;

        if (binding.labelItem.valid && currentLabel !== undefined && currentLabel !== "" && trimmedLabel.length === 0) {
            binding.labelItem.setValue("");
            currentLabel = "";
        }

        if (effectiveType === "none") {
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

    function buildSnapshot() {
        var snapshot = {
            vref: vrefItem.value,
            scale: scaleItem.value,
            sensors: []
        };

        for (var i = 0; i < channelCount; ++i) {
            var channel = channelBindings[i];
            if (!channel) {
                continue;
            }
            snapshot.sensors.push({
                index: i,
                type: channel.typeItem.value,
                label: channel.labelItem.value
            });
        }
        return snapshot;
    }

    function persistState(state) {
        if (!state) {
            return;
        }
        var api = helperApi;
        if (!api) {
            return;
        }

        try {
            if (api.savePageState) {
                api.savePageState("dbusAdcConfig", state);
            } else if (api.setPageState) {
                api.setPageState("dbusAdcConfig", state);
            } else if (api.savePageData) {
                api.savePageData("dbusAdcConfig", state);
            }
        } catch (error) {
            console.warn("Speichern des Zustands nicht möglich:", error);
        }
    }

    function applyState(state) {
        if (!state) {
            return;
        }

        if (vrefItem.valid) {
            var vrefValue = (state.vref !== undefined && state.vref !== null) ? String(state.vref) : "";
            vrefItem.setValue(vrefValue);
        }
        if (scaleItem.valid) {
            var scaleValue = (state.scale !== undefined && state.scale !== null) ? String(state.scale) : "";
            scaleItem.setValue(scaleValue);
        }

        if (state.sensors && state.sensors.length) {
            for (var i = 0; i < state.sensors.length; ++i) {
                var entry = state.sensors[i];
                if (!entry) {
                    continue;
                }
                var channelIndex = entry.index !== undefined ? entry.index : i;
                var channel = channelBindings[channelIndex];
                if (!channel) {
                    continue;
                }
                var typeValue = (entry.type !== undefined && entry.type !== null) ? String(entry.type) : "none";
                channel.typeItem.setValue(typeValue);

                var labelValue = (entry.label !== undefined && entry.label !== null) ? String(entry.label) : "";
                channel.labelItem.setValue(labelValue);
            }
        }
    }

    function loadPersistedValues() {
        var api = helperApi;
        if (!api) {
            return;
        }
        try {
            if (api.loadPageState) {
                applyState(api.loadPageState("dbusAdcConfig"));
            } else if (api.getPageState) {
                applyState(api.getPageState("dbusAdcConfig"));
            } else if (api.loadPageData) {
                applyState(api.loadPageData("dbusAdcConfig"));
            }
        } catch (error) {
            console.warn("Konnte gespeicherten Zustand nicht lesen:", error);
        }
    }

    function buildEnvironment(snapshot) {
        var env = {};
        var vrefString = (snapshot.vref !== undefined && snapshot.vref !== null) ? String(snapshot.vref) : "";
        var scaleString = (snapshot.scale !== undefined && snapshot.scale !== null) ? String(snapshot.scale) : "";
        env["EXPANDERPI_VREF"] = vrefString.trim().length === 0 ? "" : vrefString;
        env["EXPANDERPI_SCALE"] = scaleString.trim().length === 0 ? "" : scaleString;

        for (var i = 0; i < snapshot.sensors.length; ++i) {
            var channel = snapshot.sensors[i];
            var base = "EXPANDERPI_CHANNEL_" + channel.index;
            env[base + "_TYPE"] = String(channel.type || "none");
            env[base + "_LABEL"] = String(channel.label || "");
        }
        return env;
    }

    function triggerInstall(envPayload) {
        var api = helperApi;
        if (!api) {
            console.warn("SetupHelper API nicht verfügbar – Installationsmodus kann nicht gestartet werden.");
            return;
        }
        try {
            if (api.runInstallMode) {
                api.runInstallMode("setup", { env: envPayload });
                return;
            }
            if (api.startInstallMode) {
                api.startInstallMode("setup", { env: envPayload });
                return;
            }
            if (api.install) {
                api.install("setup", { env: envPayload });
                return;
            }
        } catch (error) {
            console.error("Installationsmodus konnte nicht gestartet werden:", error);
        }
    }

    function applyChanges() {
        var snapshot = buildSnapshot();
        persistState(snapshot);
        triggerInstall(buildEnvironment(snapshot));
    }

    function reloadFromPersistedState() {
        loadPersistedValues();
    }

    property var channelBindings: new Array(channelCount)

    function registerChannelBinding(binding) {
        if (!binding) {
            return;
        }
        channelBindings[binding.channelIndex] = binding;
        ensureChannelDefault(binding);
    }

    Component.onCompleted: {
        loadPersistedValues();
        ensureDefaults();
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" },
                                MbOption { description: qsTr("Spannung"); value: "voltage" },
                                MbOption { description: qsTr("Strom"); value: "current" },
                                MbOption { description: qsTr("Druck"); value: "pressure" },
                                MbOption { description: qsTr("Feuchte"); value: "humidity" },
                                MbOption { description: qsTr("Generisch"); value: "custom" }
                            ]
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
                ensureDefaults();
                reloadFromPersistedState();
            }
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

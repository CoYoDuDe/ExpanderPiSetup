import QtQuick 1.1
import com.victron.velib 1.0

MbPage {
    id: root
    title: qsTr("ExpanderPi DBus-ADC")

    property string settingsPrefix: "com.victronenergy.settings/Settings/ExpanderPi/DbusAdc"
    property string localStatusMessage: ""

    VBusItem { id: vrefItem; bind: settingsPrefix + "/Vref" }
    VBusItem { id: scaleItem; bind: settingsPrefix + "/Scale" }
    VBusItem { id: packageActionItem; bind: "com.victronenergy.packageManager/GuiEditAction" }
    VBusItem { id: packageStatusItem; bind: "com.victronenergy.packageManager/GuiEditStatus" }

    function trimValue(value) {
        if (value === undefined || value === null)
            return ""
        return String(value).replace(/^\s+|\s+$/g, "")
    }

    function statusText() {
        if (localStatusMessage.length > 0)
            return localStatusMessage
        if (packageStatusItem.valid && packageStatusItem.value !== undefined && packageStatusItem.value !== null)
            return trimValue(packageStatusItem.value)
        return ""
    }

    function applyChanges() {
        if (!packageActionItem.valid) {
            localStatusMessage = qsTr("PackageManager-Dienst nicht verfügbar.")
            return
        }

        var currentAction = trimValue(packageActionItem.value)
        if (currentAction.length > 0) {
            localStatusMessage = qsTr("PackageManager beschäftigt (%1)").arg(currentAction)
            return
        }

        localStatusMessage = qsTr("Setup wird gestartet ...")
        packageActionItem.setValue("install:ExpanderPiSetup")
    }

    model: VisibleItemModel {
        MbItemText {
            text: qsTr("Konfiguriere Referenzspannung, Scale und die acht ExpanderPi-Kanäle.")
            wrapMode: Text.WordWrap
        }

        MbEditBox {
            description: qsTr("Referenzspannung (Vref)")
            item: vrefItem
            maximumLength: 8
            unit: "V"
            writeAccessLevel: User.AccessInstaller
        }

        MbEditBox {
            description: qsTr("ADC Scale")
            item: scaleItem
            maximumLength: 8
            writeAccessLevel: User.AccessInstaller
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 1")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 1")
                    VBusItem { id: typeItem0; bind: root.settingsPrefix + "/Channel0/Type" }
                    VBusItem { id: labelItem0; bind: root.settingsPrefix + "/Channel0/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem0
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem0
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 2")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 2")
                    VBusItem { id: typeItem1; bind: root.settingsPrefix + "/Channel1/Type" }
                    VBusItem { id: labelItem1; bind: root.settingsPrefix + "/Channel1/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem1
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem1
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 3")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 3")
                    VBusItem { id: typeItem2; bind: root.settingsPrefix + "/Channel2/Type" }
                    VBusItem { id: labelItem2; bind: root.settingsPrefix + "/Channel2/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem2
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem2
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 4")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 4")
                    VBusItem { id: typeItem3; bind: root.settingsPrefix + "/Channel3/Type" }
                    VBusItem { id: labelItem3; bind: root.settingsPrefix + "/Channel3/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem3
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem3
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 5")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 5")
                    VBusItem { id: typeItem4; bind: root.settingsPrefix + "/Channel4/Type" }
                    VBusItem { id: labelItem4; bind: root.settingsPrefix + "/Channel4/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem4
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem4
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 6")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 6")
                    VBusItem { id: typeItem5; bind: root.settingsPrefix + "/Channel5/Type" }
                    VBusItem { id: labelItem5; bind: root.settingsPrefix + "/Channel5/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem5
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem5
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 7")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 7")
                    VBusItem { id: typeItem6; bind: root.settingsPrefix + "/Channel6/Type" }
                    VBusItem { id: labelItem6; bind: root.settingsPrefix + "/Channel6/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem6
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem6
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 8")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 8")
                    VBusItem { id: typeItem7; bind: root.settingsPrefix + "/Channel7/Type" }
                    VBusItem { id: labelItem7; bind: root.settingsPrefix + "/Channel7/Label" }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            item: typeItem7
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item: labelItem7
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

        MbItemText {
            text: statusText()
            wrapMode: Text.WordWrap
            show: statusText().length > 0
        }

        MbOK {
            description: ""
            value: qsTr("Speichern & Installieren")
            onClicked: applyChanges()
            writeAccessLevel: User.AccessInstaller
        }
    }
}

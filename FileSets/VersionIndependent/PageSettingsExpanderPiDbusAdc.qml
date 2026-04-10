import QtQuick 2
import com.victron.velib 1.0
import "utils.js" as Utils

MbPage {
    id: root
    title: qsTr("ExpanderPi")

    property string settingsPrefix: "com.victronenergy.settings/Settings/ExpanderPi/DbusAdc"

    model: VisibleItemModel {
        MbEditBox {
            description: qsTr("Referenzspannung (Vref)")
            item.bind: Utils.path(settingsPrefix, "/Vref")
            maximumLength: 8
            unit: "V"
            writeAccessLevel: User.AccessInstaller
        }

        MbEditBox {
            description: qsTr("ADC Scale")
            item.bind: Utils.path(settingsPrefix, "/Scale")
            maximumLength: 8
            writeAccessLevel: User.AccessInstaller
        }

        MbSubMenu {
            description: qsTr("Sensor Kanal 1")
            subpage: Component {
                MbPage {
                    title: qsTr("Sensor Kanal 1")
                    VBusItem { id: typeItem0; bind: Utils.path(root.settingsPrefix, "/Channel0/Type") }
                    VBusItem { id: labelItem0; bind: Utils.path(root.settingsPrefix, "/Channel0/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel0/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel0/Label")
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
                    VBusItem { id: typeItem1; bind: Utils.path(root.settingsPrefix, "/Channel1/Type") }
                    VBusItem { id: labelItem1; bind: Utils.path(root.settingsPrefix, "/Channel1/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel1/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel1/Label")
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
                    VBusItem { id: typeItem2; bind: Utils.path(root.settingsPrefix, "/Channel2/Type") }
                    VBusItem { id: labelItem2; bind: Utils.path(root.settingsPrefix, "/Channel2/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel2/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel2/Label")
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
                    VBusItem { id: typeItem3; bind: Utils.path(root.settingsPrefix, "/Channel3/Type") }
                    VBusItem { id: labelItem3; bind: Utils.path(root.settingsPrefix, "/Channel3/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel3/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel3/Label")
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
                    VBusItem { id: typeItem4; bind: Utils.path(root.settingsPrefix, "/Channel4/Type") }
                    VBusItem { id: labelItem4; bind: Utils.path(root.settingsPrefix, "/Channel4/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel4/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel4/Label")
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
                    VBusItem { id: typeItem5; bind: Utils.path(root.settingsPrefix, "/Channel5/Type") }
                    VBusItem { id: labelItem5; bind: Utils.path(root.settingsPrefix, "/Channel5/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel5/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel5/Label")
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
                    VBusItem { id: typeItem6; bind: Utils.path(root.settingsPrefix, "/Channel6/Type") }
                    VBusItem { id: labelItem6; bind: Utils.path(root.settingsPrefix, "/Channel6/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel6/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel6/Label")
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
                    VBusItem { id: typeItem7; bind: Utils.path(root.settingsPrefix, "/Channel7/Type") }
                    VBusItem { id: labelItem7; bind: Utils.path(root.settingsPrefix, "/Channel7/Label") }
                    model: VisibleItemModel {
                        MbItemOptions {
                            description: qsTr("Sensortyp")
                            bind: Utils.path(root.settingsPrefix, "/Channel7/Type")
                            possibleValues: [
                                MbOption { description: qsTr("Nicht belegt"); value: "none" },
                                MbOption { description: qsTr("Tank"); value: "tank" },
                                MbOption { description: qsTr("Temperatur"); value: "temp" }
                            ]
                            writeAccessLevel: User.AccessInstaller
                        }
                        MbEditBox {
                            description: qsTr("Anzeige-Label")
                            item.bind: Utils.path(root.settingsPrefix, "/Channel7/Label")
                            maximumLength: 24
                            writeAccessLevel: User.AccessInstaller
                        }
                    }
                }
            }
        }

    }
}

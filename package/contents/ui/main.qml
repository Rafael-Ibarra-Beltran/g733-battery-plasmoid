import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Estado de la última lectura
    property int level: -1          // 0-100, -1 = sin dato
    property bool charging: false
    property bool powered: false    // conectado a la corriente (cable o base)
    property int voltage: -1        // mV que reporta el headset, -1 = sin dato
    property bool connected: false
    property string status: "Leyendo…"
    property string lastRead: "—"

    readonly property int lowThreshold: 15
    readonly property string readCmd: "python3 '" + Qt.resolvedUrl("../code/g733-battery").toString().replace("file://", "") + "'"
    readonly property bool isLow: connected && level >= 0 && level < lowThreshold && !charging
    // ⚡ = cargando de verdad; 🔌 = conectado a la corriente pero sin cargar
    readonly property string shortText: {
        const plug = charging ? "⚡" : (powered ? "🔌" : "")
        if (!connected || level < 0) return plug ? plug + " —" : "—"
        return plug + level + "%"
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: "audio-headset"
    toolTipMainText: "Logitech G733"
    toolTipSubText: status + " · " + lastRead

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            // Sin disconnectSource el mismo comando no se vuelve a ejecutar.
            disconnectSource(sourceName)
            if (sourceName === root.readCmd) {
                root.handleOutput(data["stdout"] || "", data["exit code"])
            }
        }
    }

    function refresh() {
        exec.connectSource(readCmd)
    }


    function applyReading(isConnected, lvl, isCharging, isPowered, text) {
        connected = isConnected
        level = lvl
        charging = isCharging
        powered = isPowered || isCharging
        status = text
        lastRead = Qt.formatTime(new Date(), "hh:mm")
    }

    // g733-battery (incluido en el paquete) imprime JSON
    function handleOutput(out, code) {
        let r
        try {
            r = JSON.parse(out)
        } catch (e) {
            voltage = -1
            applyReading(false, -1, false, false, out.trim() === "" ? "El lector no respondió" : "Salida no válida")
            return
        }
        const cable = !!r.cable
        voltage = typeof r.voltage_mv === "number" ? r.voltage_mv : -1
        if (r.status === "ok") {
            const texts = {
                "full": cable ? "Llena (cable conectado)" : "Llena",
                "charging": "Cargando",
                "discharging": cable ? "Conectado, sin cargar" : "Descargando",
                "unknown": "Estado desconocido"
            }
            applyReading(true, typeof r.battery === "number" ? r.battery : -1,
                         r.state === "charging", cable || r.state === "full", texts[r.state] || r.state)
            return
        }
        const texts = {
            "offline": cable ? "Apagado (cable conectado)" : "Apagado o fuera de alcance",
            "not_found": "Receptor no encontrado",
            "no_permission": "Sin permiso: instala la regla udev",
            "error": "Error: " + (r.error || "desconocido")
        }
        applyReading(false, -1, false, cable, texts[r.status] || r.status)
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        // Margen a los lados para que el ícono y el texto no toquen el borde del fondo.
        readonly property int hPadding: Kirigami.Units.largeSpacing
        Layout.minimumWidth: row.implicitWidth + 2 * hPadding
        Layout.preferredWidth: row.implicitWidth + 2 * hPadding
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "audio-headset"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                opacity: root.connected ? 1 : 0.5
            }
            Kirigami.Icon {
                // Batería baja: ícono rojo junto al %, igual que el ⚡ al cargar.
                visible: root.isLow
                source: "battery-caution"
                color: Kirigami.Theme.negativeTextColor
                isMask: true
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: root.shortText
                color: root.isLow ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 4
            text: "Logitech G733"
        }
        PlasmaComponents.Label {
            text: root.connected && root.level >= 0 ? "Batería: " + root.level + "%" : "Batería: —"
        }
        PlasmaComponents.Label {
            text: "Estado: " + root.status
        }
        PlasmaComponents.Label {
            text: "Voltaje: " + (root.voltage >= 0 ? root.voltage + " mV" : "—")
            opacity: 0.7
        }
        PlasmaComponents.Label {
            text: "Última lectura: " + root.lastRead
            opacity: 0.7
        }
        PlasmaComponents.Button {
            text: "Refrescar"
            icon.name: "view-refresh"
            onClicked: root.refresh()
        }
    }
}

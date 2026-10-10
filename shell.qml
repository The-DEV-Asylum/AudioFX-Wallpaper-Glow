import Quickshell
import Quickshell.Wayland

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "audiofx-glow"

            Glow {
                anchors.fill: parent
            }
        }
    }
}

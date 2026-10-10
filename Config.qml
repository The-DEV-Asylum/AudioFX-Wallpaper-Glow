pragma Singleton
import Quickshell

Singleton {
    // Set this to the absolute path of the wallpaper to analyse.
    property string wallpaper: ""

    // 0 = more selective; 100 = less selective.
    property int threshold: 30

    // Core glow intensity.
    property real strength: 3.7

    // Halo/bloom intensity.
    property real bloom: 2.5

    // CAVA sensitivity.
    property int sensitivity: 100

    // CAVA analysis frame rate.
    property int fps: 30
}

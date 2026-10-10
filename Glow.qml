import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string wallpaper: Config.wallpaper
    property int threshold: Config.threshold
    property real strength: Config.strength
    property real bloom: Config.bloom
    property int sensitivity: Config.sensitivity
    property int fps: Config.fps

    property var mask: null
    property var bands: new Array(16).fill(0)
    property real level: 0
    property real time: 0
    property real peak: 0.4
    property real bassAvg: 0.1
    property real kick: 0
    property real smoothLevel: 0
    property int cooldown: 0
    property string cacheKey: wallpaper + "|" + threshold

    function processAudio(raw) {
        let loudest = 0;
        for (let i = 0; i < raw.length; ++i) loudest = Math.max(loudest, raw[i]);
        const decay = Math.pow(0.5, 1 / (8 * fps));
        peak = Math.max(loudest, peak * decay, 0.22);
        const s = bands.slice();
        let sum = 0;
        for (let i = 0; i < 16; ++i) {
            const v = Math.min(1, (raw[i] || 0) / peak);
            s[i] = v > s[i] ? s[i] + (v - s[i]) * 0.7 : s[i] + (v - s[i]) * 0.22;
            sum += s[i];
        }
        bands = s;
        const bass = Math.min(1, ((raw[0]||0)+(raw[1]||0)+(raw[2]||0))/3/peak);
        if (cooldown > 0) --cooldown;
        if (cooldown === 0 && bass > bassAvg * 1.35 + 0.08) {
            kick = Math.max(0.35, Math.min(1, (bass - bassAvg) * 2.2));
            cooldown = Math.max(1, Math.round(fps * 0.17));
        }
        bassAvg = bassAvg * 0.92 + bass * 0.08;
        kick *= Math.pow(0.5, 1 / (0.12 * fps));
        const target = bass * 0.6 + (sum / 16) * 0.4;
        smoothLevel += (target - smoothLevel) * (target > smoothLevel ? 0.6 : 0.2);
        level = Math.min(1.5, smoothLevel * 0.85 + kick * 0.55);
        time = (Date.now() / 1000) % 3600;
    }

    Process {
        id: analyzer
        property string output: ""
        property string errorOutput: ""
        property string requested: ""
        command: ["python3", Qt.resolvedUrl("audiofx-glow.py").toString().replace(/^file:\/\//, ""), root.wallpaper, "--threshold", String(root.threshold)]
        running: false
        stdout: SplitParser { onRead: data => analyzer.output += data }
        stderr: SplitParser { onRead: data => analyzer.errorOutput += data + "\n" }
        onExited: code => {
            if (code !== 0) {
                console.warn("audiofx-wallpaper-glow:", analyzer.errorOutput);
                return;
            }
            try { root.mask = JSON.parse(analyzer.output); }
            catch (e) { console.warn("audiofx-wallpaper-glow: bad analyser output"); }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            // Do not start a process for an empty path, and do not repeatedly
            // regenerate masks after a successful run.
            if (root.wallpaper && root.mask === null && !analyzer.running) {
                analyzer.output = "";
                analyzer.errorOutput = "";
                analyzer.command = ["python3", Qt.resolvedUrl("audiofx-glow.py").toString().replace(/^file:\/\//, ""), root.wallpaper, "--threshold", String(root.threshold)];
                analyzer.running = true;
            }
        }
    }

    Process {
        id: cava
        property string conf: Quickshell.cachePath("cava.conf")
        command: ["sh", "-c", `cat > '${conf}' <<'EOF'
[general]
framerate=${root.fps}
bars=16
autosens=0
sensitivity=${root.sensitivity}
[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
ascii_max_range=1000
bar_delimiter=59
frame_delimiter=10
channels=mono
mono_option=average
[smoothing]
noise_reduction=45
monstercat=0
EOF
exec cava -p '${conf}'`]
        running: root.mask !== null
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const p = data.split(";");
                const out = [];
                for (let i=0; i<p.length; ++i) { const n=parseInt(p[i],10); if(!isNaN(n)) out.push(Math.min(1,n/1000)); }
                if (out.length >= 16) root.processAudio(out);
            }
        }
    }

    Image { id: core; visible:false; asynchronous:true; cache:false; source: root.mask ? "file://"+root.mask.core : "" }
    Image { id: info; visible:false; asynchronous:true; cache:false; source: root.mask ? "file://"+root.mask.info : "" }
    Image { id: dist; visible:false; asynchronous:true; cache:false; source: root.mask ? "file://"+root.mask.dist : "" }
    Image { id: colors; visible:false; asynchronous:true; cache:false; source: root.mask ? "file://"+root.mask.colors : "" }

    ShaderEffect {
        anchors.fill: parent
        visible: root.mask !== null && core.status === Image.Ready && info.status === Image.Ready && colors.status === Image.Ready
        property var coreTex: core
        property var infoTex: info
        property var distTex: dist
        property var colorTex: colors
        property real imgW: root.mask ? root.mask.width : 1
        property real imgH: root.mask ? root.mask.height : 1
        property real fillMode: 2
        property real scrW: width
        property real scrH: height
        property real time: root.time
        property real level: root.level
        property real strength: root.strength
        property real bloom: root.bloom
        property color color: root.mask ? root.mask.color : "white"
        property real spotColors: 1
        blending: true
        property vector4d b0: Qt.vector4d(root.bands[0]||0,root.bands[1]||0,root.bands[2]||0,root.bands[3]||0)
        property vector4d b1: Qt.vector4d(root.bands[4]||0,root.bands[5]||0,root.bands[6]||0,root.bands[7]||0)
        property vector4d b2: Qt.vector4d(root.bands[8]||0,root.bands[9]||0,root.bands[10]||0,root.bands[11]||0)
        property vector4d b3: Qt.vector4d(root.bands[12]||0,root.bands[13]||0,root.bands[14]||0,root.bands[15]||0)
        fragmentShader: Qt.resolvedUrl("shaders/glow.frag.qsb")
    }
}

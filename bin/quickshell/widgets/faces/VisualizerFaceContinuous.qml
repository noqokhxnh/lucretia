import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Item {
    id: root
    anchors.fill: parent

    property real minWidth: 50
    property real minHeight: 50
    property real maxWidth: 99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    property bool isVisVisible: visible

    onIsVisVisibleChanged: {
        if (isVisVisible) Cava.registerConsumer();
        else Cava.unregisterConsumer();
    }

    Component.onCompleted: {
        if (isVisVisible) Cava.registerConsumer();
    }

    Component.onDestruction: {
        if (isVisVisible) Cava.unregisterConsumer();
    }

    property int sampleCount: 40
    property var rawBarLevels: Cava.barLevels
    property var smoothLevels: []
    property real totalEnergy: 0.0

    function getProcessedBars() {
        let source = rawBarLevels;
        let count = sampleCount;
        let out = [];

        if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return out;
        }

        let srcLen = source.length;
        let half = (count - 1) / 2;

        for (let i = 0; i < count; i++) {
            let distFromCenter = Math.abs(i - half);
            let norm = half > 0 ? (distFromCenter / half) : 0;
            let pos = Math.pow(norm, 1.25) * (srcLen - 1);
            let idx0 = Math.floor(pos);
            let idx1 = Math.min(srcLen - 1, idx0 + 1);
            let frac = pos - idx0;

            let v0 = source[idx0] || 0.0;
            let v1 = source[idx1] || 0.0;
            let rawVal = v0 + (v1 - v0) * frac;

            let val = rawVal < 0.03 ? 0.0 : Math.pow((rawVal - 0.03) / 0.97, 1.15);
            val = Math.max(0.0, Math.min(1.0, val));
            out.push(val);
        }

        let smoothed = [];
        for (let i = 0; i < count; i++) {
            let prev = i > 0 ? out[i - 1] : out[i];
            let curr = out[i];
            let next = i < count - 1 ? out[i + 1] : out[i];
            let sm = prev * 0.25 + curr * 0.5 + next * 0.25;

            let edgeNorm = Math.sin((i / Math.max(1, count - 1)) * Math.PI);
            let edgeFactor = Math.min(1.0, edgeNorm * 2.0);
            edgeFactor = edgeFactor * edgeFactor * (3.0 - 2.0 * edgeFactor);
            smoothed.push(sm * edgeFactor);
        }

        return smoothed;
    }

    onRawBarLevelsChanged: {
        if (!animTimer.running && root.isVisVisible) {
            let src = rawBarLevels;
            if (src && src.length) {
                for (let i = 0; i < src.length; i++) {
                    if (src[i] > 0.01) {
                        animTimer.running = true;
                        return;
                    }
                }
            }
        }
    }

    Timer {
        id: animTimer
        interval: 16
        running: false
        repeat: true
        onTriggered: {
            let targets = root.getProcessedBars();
            let current = root.smoothLevels;
            let updated = [];
            let sum = 0.0;
            let maxVal = 0.0;

            for (let i = 0; i < root.sampleCount; i++) {
                let target = (targets && i < targets.length) ? targets[i] : 0.0;
                let cur = (current && i < current.length) ? current[i] : 0.0;
                let factor = target > cur ? 0.25 : 0.12;
                let next = cur + (target - cur) * factor;
                if (next < 0.001) next = 0.0;
                updated.push(next);
                sum += next;
                if (next > maxVal) maxVal = next;
            }

            root.smoothLevels = updated;
            root.totalEnergy = sum / root.sampleCount;

            // Sleep when silent and fully decayed to baseline (0% CPU idle)
            if (maxVal === 0.0 && root.totalEnergy === 0.0) {
                waveCanvas.requestPaint();
                animTimer.running = false;
                return;
            }

            waveCanvas.requestPaint();
        }
    }

    Canvas {
        id: waveCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Immediate

        onPaint: {
            let ctx = getContext("2d");
            let w = width;
            let h = height;

            ctx.reset();
            ctx.clearRect(0, 0, w, h);

            let levels = root.smoothLevels;
            if (!levels || levels.length === 0) return;

            let count = levels.length;
            if (count < 2) return;

            ctx.beginPath();
            ctx.moveTo(0, h);

            let step = w / (count - 1);
            let prevX = 0;
            let prevY = h - (levels[0] * h * 0.92);
            ctx.lineTo(prevX, prevY);

            for (let i = 1; i < count; i++) {
                let currX = i * step;
                let currY = h - (levels[i] * h * 0.92);
                let mx = (prevX + currX) * 0.5;
                let my = (prevY + currY) * 0.5;
                ctx.quadraticCurveTo(prevX, prevY, mx, my);
                prevX = currX;
                prevY = currY;
            }

            ctx.lineTo(w, prevY);
            ctx.lineTo(w, h);
            ctx.closePath();

            let c = (typeof ThemeBackend !== "undefined" && ThemeBackend.mauve) ? ThemeBackend.mauve : "#cba6f7";
            ctx.fillStyle = c;
            ctx.fill();
        }
    }
}

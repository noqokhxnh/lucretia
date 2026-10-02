pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    readonly property var outputs: {
        let arr = [];
        for (const n of Pipewire.nodes.values) {
            if (!n.isStream && n.isSink && n.audio) arr.push(n);
        }
        return arr;
    }

    readonly property var inputs: {
        let arr = [];
        for (const n of Pipewire.nodes.values) {
            if (!n.isStream && !n.isSink && n.audio
                && n.properties?.["device.class"] !== "monitor"
                && !n.name?.endsWith(".monitor")) {
                arr.push(n);
            }
        }
        return arr;
    }

    readonly property var apps: {
        let arr = [];
        for (const n of Pipewire.nodes.values) {
            if (n.isStream && n.audio
                && n.properties?.["application.id"] !== "org.PulseAudio.pavucontrol") {
                arr.push(n);
            }
        }
        return arr;
    }

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource

    function setDefaultOutput(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultInput(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    function toggleMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted;
    }

    function getMaxVolumeScale(node) {
        if (node && !node.isSink && !node.isStream) return 1.0;
        return 1.5;
    }

    function getVolume(node, currentVolume) {
        if (!node || !node.audio) return 0;
        let vol = (currentVolume !== undefined) ? currentVolume : node.audio.volume;
        let maxScale = getMaxVolumeScale(node);
        return Math.max(0, Math.min(100, Math.round((vol / maxScale) * 100)));
    }

    function setVolume(node, pct) {
        if (node && node.audio) {
            let maxScale = getMaxVolumeScale(node);
            node.audio.volume = Math.max(0, Math.min(maxScale, (pct / 100.0) * maxScale));
        }
    }

    function getNodeName(node) {
        if (!node) return "";
        return node.properties?.["device.description"] || node.description || node.name || "Unknown Device";
    }

    function getNodeSubDesc(node) {
        if (!node) return "";
        if (node.isStream) {
            return node.properties?.["media.name"] || node.properties?.["window.title"] || node.properties?.["media.role"] || "Audio Stream";
        }
        return node.name || "Unknown";
    }

    function getNodeAppName(node) {
        if (!node) return "";
        return node.properties?.["application.name"] || node.properties?.["application.process.binary"] || node.description || "Unknown App";
    }
}

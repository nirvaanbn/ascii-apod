/*
 * SPDX-FileCopyrightText: 2026 korvexx <korvexx.dev@proton.me>
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.wallpapers.image

WallpaperItem {
    id: root

    readonly property string mode: wallpaper.configuration.Mode || "Image"
    readonly property var configImages: wallpaper.configuration.Images || []
    readonly property int slideInterval: {
        let v = (wallpaper.configuration.SlideInterval !== undefined) ? wallpaper.configuration.SlideInterval : 10;
        return Math.max(5, v);
    }

    readonly property string legacyImage: wallpaper.configuration.Image || ""

    readonly property var defaultAsciiChars: ["#", ".", "´", ":", "r", "s", "z", "u", "n", "v", "c", "x", "L", "O", "G", "D", "Q", "0", "K", "N", "M", "W", "&", "@"]
    readonly property var asciiChars: {
        let chars = wallpaper.configuration.AsciiChars;
        return (chars && chars.length > 0) ? chars : root.defaultAsciiChars;
    }

    function toFileUrl(rawPath) {
        if (!rawPath) return "";
        const clean = String(rawPath).trim();
        if (clean === "") return "";
        return "file://" + clean.split("/").map(encodeURIComponent).join("/");
    }

    property int currentIdx: 0
    property int nextIdx: 0

    function getImage(index) {
        if (configImages && configImages.length !== undefined && configImages.length > 0) {
            if (index < configImages.length) {
                let raw = String(configImages[index] || "").trim();
                return raw !== "" ? root.toFileUrl(raw) : "";
            }
            
            return "";
        }

        if (legacyImage && legacyImage.trim() !== "") {
            return root.toFileUrl(legacyImage.trim());
        }

        return "";
    }

    Timer {
        id: intervalTimer

        running: root.mode === "Slideshow" && root.configImages.length > 1
        interval: root.slideInterval * 1000
        repeat: true

        onTriggered: {
            root.nextIdx = (root.currentIdx + 1) % root.configImages.length;
            crossfadeAnimation.start();
        }
    }

    NumberAnimation {
        id: crossfadeAnimation

        property: "transitionProgress"
        target: shaderContainer

        from: 0.0
        to: 1.0

        duration: 1000
        easing.type: Easing.InOutQuad

        onFinished: {
            root.currentIdx = root.nextIdx;
            shaderContainer.transitionProgress = 0.0;
        }
    }

    onConfigImagesChanged: resetSlideshow()
    onModeChanged: resetSlideshow()

    function resetSlideshow() {
        crossfadeAnimation.stop();
        shaderContainer.transitionProgress = 0.0;
        
        root.currentIdx = 0;
        root.nextIdx = 0;
    }

    AsciiShader {
        id: shaderContainer
        anchors.fill: parent
        
        source: root.getImage(root.currentIdx)
        sourceNext: root.getImage(root.nextIdx)
        
        detail: (wallpaper.configuration.Detail !== undefined) ? wallpaper.configuration.Detail : 1
        grayscale: wallpaper.configuration.Grayscale || false
        fontFamily: wallpaper.configuration.FontFamily || "Monospace"
        asciiChars: root.asciiChars
    }

    Component.onCompleted: {
        root.loading = false;
    }
}

/*
 * SPDX-FileCopyrightText: 2026 korvexx <korvexx.dev@proton.me>
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls

Item {
    id: asciiRoot
    property url source: ""
    property url sourceNext: ""
    property real transitionProgress: 0.0

    property int detail: 1
    property bool grayscale: false
    property string fontFamily: "Monospace"
    property var asciiChars: [" ", ".", "´", ":", "r", "s", "z", "u", "n", "v", "c", "x", "L", "O", "G", "D", "Q", "0", "K", "N", "M", "W", "&", "@"]

    property real autoCropThreshold: 1.35

    function _resolveFillMode(imgItem) {
        if (!imgItem || imgItem.implicitWidth <= 0 || imgItem.implicitHeight <= 0
                || asciiRoot.width <= 0 || asciiRoot.height <= 0) {
            return Image.PreserveAspectCrop;
        }

        const ratio = (imgItem.implicitWidth * asciiRoot.height) / (imgItem.implicitHeight * asciiRoot.width);
        const mismatched = ratio > asciiRoot.autoCropThreshold || ratio < 1 / asciiRoot.autoCropThreshold;

        return mismatched ? Image.PreserveAspectFit : Image.PreserveAspectCrop;
    }

    readonly property int charWidth: [2, 4, 8][Math.max(0, Math.min(2, detail))]
    readonly property int charHeight: charWidth * 2
    
    Image {
        id: sourceImg
        source: asciiRoot.source
        visible: false
        asynchronous: true

        width: asciiRoot.width
        height: asciiRoot.height
        fillMode: asciiRoot._resolveFillMode(sourceImg)

        layer.enabled: true
        layer.smooth: true
    }

    Image {
        id: sourceNextImg
        source: asciiRoot.sourceNext
        visible: false
        asynchronous: true

        width: asciiRoot.width
        height: asciiRoot.height
        fillMode: asciiRoot._resolveFillMode(sourceNextImg)

        layer.enabled: true
        layer.smooth: true
    }

    Canvas {
        id: atlasGenerator
        
        width: ((asciiChars && asciiChars.length > 0) ? asciiChars.length : 1) * (charWidth * 2)
        height: charHeight

        visible: false
        renderTarget: Canvas.FramebufferObject

        onAvailableChanged: if (available) requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: asciiRoot
            function onFontFamilyChanged() { atlasGenerator.requestPaint(); }
            function onAsciiCharsChanged() { atlasGenerator.requestPaint(); }
        }

        onPaint: {
            if (!asciiChars || asciiChars.length === 0) {
                return;
            }

            var ctx = getContext("2d");
            ctx.imageSmoothingEnabled = true;

            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            
            ctx.fillStyle = "white";

            ctx.font = charHeight + "px " + fontFamily;
            ctx.textBaseline = "middle";
            ctx.textAlign = "center";

            let slotWidth = charWidth * 2;
            for (var i = 0; i < asciiChars.length; i++) {
                let xCenter = (i * slotWidth) + (slotWidth / 2);
                ctx.fillText(asciiChars[i], xCenter, charHeight / 2);
            }
        }

        onPainted: {
            asciiShader.update();
        }
    }

    ShaderEffect {
        id: asciiShader
        anchors.fill: parent
        
        property variant src: sourceImg
        property variant srcNext: sourceNextImg
        property variant atlas: atlasGenerator 

        property real invAtlasCount: asciiChars && asciiChars.length > 0 ? 1.0 / asciiChars.length : 1.0
        property real progress: asciiRoot.transitionProgress

        property size charSize: Qt.size(charWidth, charHeight)
        property size viewSize: Qt.size(width, height)
        
        property int atlasCount: (asciiChars && asciiChars.length > 0) ? asciiChars.length : 1
        property int isGrayscaled: asciiRoot.grayscale ? 1 : 0

        vertexShader: "shaders/ascii.vert.qsb"
        fragmentShader: "shaders/ascii.frag.qsb"
    }
}


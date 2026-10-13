/*
 * SPDX-FileCopyrightText: 2026 korvexx <korvexx.dev@proton.me>
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtCore
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: root

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    property var configDialog
    property var wallpaperConfiguration

    property string cfg_Mode: "Image"
    property string cfg_FontFamily: "Monospace"
    property list<string> cfg_AsciiChars: [" ", ".", "´", ":", "r", "s", "z", "u", "n", "v", "c", "x", "L", "O", "G", "D", "Q", "0", "K", "N", "M", "W", "&", "@"]
    property list<string> cfg_Images: []
    property var monoFonts: []

    property alias cfg_Detail: detailSlider.value
    property alias cfg_Grayscale: grayscaleCheck.checked
    property alias cfg_SlideInterval: intervalSlider.value

    property string cfg_Image: ""

    ListModel { id: imageList }
    property int _activePicker: -1
    property bool _isInternalUpdate: false

    onCfg_ImagesChanged: {
        loadFromConfig();
    }

    function loadFromConfig() {
        if (_isInternalUpdate) return;
        _isInternalUpdate = true;

        imageList.clear();

        let migrated = false;
        let currentImages = Array.from(root.cfg_Images || []);

        if (root.cfg_Image && root.cfg_Image.trim() !== "") {
            const cleaned = root.cfg_Image.trim();
            const alreadyExists = currentImages.some(p => String(p).trim() === cleaned);

            if (!alreadyExists) {
                currentImages.push(cleaned);
            }

            migrated = true;
            root.cfg_Image = ""; 
            root.cfg_Images = currentImages;
        }

        let currentChars = Array.from(root.cfg_AsciiChars || []);
        if (currentChars.length === 23 && currentChars[0] !== " ") {
            currentChars.unshift(" ");

            migrated = true;
            root.cfg_AsciiChars = currentChars;
        }

        for (let i = 0; i < currentImages.length; i++) {
            const original = String(currentImages[i]).trim();
            if (original === "") continue;

            const decoded = root.cleanPath(original);
            if (decoded !== original) {
                migrated = true;
            }

            imageList.append({ "path": decoded });
        }

        if (imageList.count === 0 && root.cfg_Mode !== "Slideshow") {
            imageList.append({ "path": "" });
        }

        if (migrated) {
            root.syncToConfig();
        }

        _isInternalUpdate = false;
    }

    function syncToConfig() {
        _isInternalUpdate = true;
        const unique = new Set();

        for (let i = 0; i < imageList.count; ++i) {
            const raw = imageList.get(i).path;
            if (!raw) continue;

            const clean = cleanPath(raw);
            if (clean) {
                unique.add(clean);
            }
        }
        
        root.cfg_Images = Array.from(unique);
        if (root.configDialog) {
            root.configDialog.changed = true;
        }
        _isInternalUpdate = false;
    }

    function clearImages() {
        imageList.clear()

        if (root.cfg_Mode !== "Slideshow") {
            imageList.append({ "path": "" })
        }

        root.syncToConfig()
        previewContainer.resetPreview()
    }

    function removeImage(index) {
        if (index >= 0 && index < imageList.count) {
            imageList.remove(index);

            syncToConfig();
            previewContainer.resetPreview()
        }
    }

    function cleanPath(url) {
        const stripped = String(url).replace(/^file:\/{2}/, "").trim();
        
        try {
            return decodeURIComponent(stripped);
        } catch (e) {
            return stripped;
        }
    }

    function toFileUrl(path) {
        if (!path) return "";
        const clean = String(path).trim();
        if (clean === "") return "";
        return "file://" + clean.split("/").map(encodeURIComponent).join("/");
    }

    Component.onCompleted: {
        loadFromConfig();

        var all = Qt.fontFamilies()
        var mono = []
        for (var i = 0; i < all.length; i++) {
            fontProbe.font = Qt.font({ family: all[i], pointSize: 12 })

            var widthI = fontProbe.advanceWidth("i")
            var widthW   = fontProbe.advanceWidth("W")
            
            if (widthI > 0 && widthI === widthW) {
                mono.push(all[i])
            }
        }
        monoFonts = mono.sort()
    }

    FontMetrics {
        id: fontProbe
    }

    FileDialog {
        id: imagePicker
        title: "Select Wallpaper"

        currentFolder: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
        fileMode: root.cfg_Mode === "Slideshow" ? FileDialog.OpenFiles : FileDialog.OpenFile
        nameFilters: ["Image files (*.png *.jpg *.jpeg)"]

        onAccepted: {
            if (fileMode === FileDialog.OpenFiles) {
                for (const file of selectedFiles) {
                    const clean = cleanPath(file.toString());

                    if (!clean) continue;

                    let exists = false;
                    for (let i = 0; i < imageList.count; ++i) {
                        if (cleanPath(imageList.get(i).path) === clean) {
                            exists = true;
                            break;
                        }
                    }

                    if (!exists) {
                        imageList.append({ "path": clean });
                    }
                }
            } else {
                if (_activePicker !== -1) {
                    const clean = cleanPath(selectedFile.toString());

                    if (_activePicker === 0 && imageList.count > 1) {
                        imageList.remove(1, imageList.count - 1)
                    }

                    let duplicate = false
                    for (let i = 0; i < imageList.count; ++i) {
                        if (i === _activePicker) continue
                        if (cleanPath(imageList.get(i).path) === clean) {
                            duplicate = true; break
                        }
                    }

                    if (!duplicate) {
                        imageList.setProperty(_activePicker, "path", clean)
                    }
                }

                _activePicker = -1
            }

            root.syncToConfig();
            previewContainer.resetPreview()
        }
        onRejected: {
            root._activePicker = -1;
        }
    }
    
    ColumnLayout {
        id: mainLayout
        width: parent.width
        spacing: Kirigami.Units.largeSpacing

        // --- Preview Card ---
        Kirigami.ShadowedRectangle {
            id: previewCard

            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            
            implicitHeight: (width * 9) / 16

            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false

            color: Kirigami.Theme.backgroundColor
            
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
            border.width: 1
            
            radius: Kirigami.Units.largeSpacing

            shadow.size: 4
            shadow.yOffset: 2
            shadow.color: Qt.rgba(0, 0, 0, 0.1)

            Item {
                id: previewContainer

                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing

                clip: true

                property int currentIdx: 0
                property int nextIdx: 0

                function resetPreview() {
                    previewTimer.stop();
                    
                    if (currentIdx !== 0 && imageList.count > 0) {
                        crossfadeAnimation.stop();
                        previewShader.transitionProgress = 0.0;

                        nextIdx = 0;
                        crossfadeAnimation.restart();
                    } else {
                        crossfadeAnimation.stop();
                        previewShader.transitionProgress = 0.0;

                        currentIdx = 0;
                        nextIdx = 0;
                    }

                    previewTimer.restart();
                }

                onCurrentIdxChanged: previewShader.transitionProgress = 0.0
                Connections {
                    target: root
                    onCfg_ModeChanged: previewContainer.resetPreview()
                }

                function getPreviewPath(index) {
                    if (imageList.count === 0 || index < 0 || index >= imageList.count) {
                        return "";
                    }

                    let path = imageList.get(index).path;
                    return root.toFileUrl(path);
                }

                Timer {
                    id: previewTimer
                    
                    interval: root.cfg_SlideInterval * 1000
                    running: root.cfg_Mode === "Slideshow" && imageList.count > 1
                    repeat: true

                    onTriggered: {
                        if (imageList.count > 1) {
                            previewContainer.nextIdx = (previewContainer.currentIdx + 1) % imageList.count;
                            crossfadeAnimation.restart();
                        }
                    }
                }

                NumberAnimation {
                    id: crossfadeAnimation

                    property: "transitionProgress"
                    target: previewShader

                    from: 0.0
                    to: 1.0

                    duration: 1500
                    easing.type: Easing.InOutQuad
                    
                    onFinished: {
                        previewContainer.currentIdx = previewContainer.nextIdx;
                        previewShader.transitionProgress = 0.0;
                    }
                }

                Item {
                    id: offscreenBuffer

                    width: 854
                    height: 480

                    AsciiShader {
                        id: previewShader
                        anchors.fill: parent
                        
                        source: previewContainer.getPreviewPath(previewContainer.currentIdx)
                        sourceNext: previewContainer.getPreviewPath(previewContainer.nextIdx)
                        
                        detail: root.cfg_Detail
                        grayscale: root.cfg_Grayscale
                        fontFamily: root.cfg_FontFamily
                        asciiChars: root.cfg_AsciiChars
                    }
                }

                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: Kirigami.Units.mediumSpacing
                    
                    visible: false
                    layer.enabled: true
                }

                ShaderEffectSource {
                    id: previewImage
                    sourceItem: offscreenBuffer

                    anchors.fill: parent
                    textureSize: Qt.size(854, 480)
                    format: ShaderEffectSource.RGBA8

                    mipmap: false
                    smooth: true
                    samples: 0

                    live: true
                    hideSource: true
                    recursive: false
                    
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: previewImage
                    maskEnabled: true
                    maskSource: maskRect
                }

                Controls.Label {
                    anchors.centerIn: parent
                    text: "No Image Selected"
                    opacity: 0.5
                    visible: previewContainer.getPreviewPath(previewContainer.currentIdx) === ""
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing

                    width: previewText.width + (Kirigami.Units.smallSpacing * 2)
                    height: previewText.height + Kirigami.Units.smallSpacing
                    radius: 4
                    color: Qt.rgba(0, 0, 0, 0.6)

                    Controls.Label {
                        id: previewText
                        anchors.centerIn: parent
                        text: "Preview"
                        font.pointSize: 8
                        color: "white"
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // --- Options ---
        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: "Source"
            }

            RowLayout {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                Controls.Label {
                    text: "Mode:"
                }

                Controls.ComboBox {
                    id: modeCombo
                    Layout.fillWidth: true

                    model: ["Image", "Slideshow"]
                    currentIndex: model.indexOf(root.cfg_Mode)

                    onActivated: (index) => {
                        let newMode = model[index];
                        root.cfg_Mode = newMode;

                        if (newMode !== "Slideshow" && imageList.count === 0) {
                            imageList.append({ "path": "" });
                            root.syncToConfig();
                        }

                        if (root.configDialog) {
                            root.configDialog.changed = true;
                        }
                    }
                }
            }

            ColumnLayout {
                Kirigami.FormData.isSection: true

                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Controls.ScrollView {
                    id: imageScrollView

                    Layout.fillWidth: true

                    Layout.preferredHeight: Math.min(imageListColumn.implicitHeight, Kirigami.Units.gridUnit * 13)
                    Layout.maximumHeight: Kirigami.Units.gridUnit * 13

                    clip: true
                    Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
                    Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded

                    ColumnLayout {
                        id: imageListColumn
                        width: imageScrollView.availableWidth
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: imageList

                            delegate: RowLayout {
                                Layout.fillWidth: true
                                visible: root.cfg_Mode === "Slideshow" || index === 0

                                ColumnLayout {
                                    spacing: -5

                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5

                                    Controls.ToolButton {
                                        icon.name: "arrow-up"
                                        visible: root.cfg_Mode === "Slideshow"
                                        enabled: visible && index > 0

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        onClicked: {
                                            imageList.move(index, index - 1, 1);

                                            root.syncToConfig();
                                            previewContainer.resetPreview();
                                        }
                                    }

                                    Controls.ToolButton {
                                        icon.name: "arrow-down"
                                        visible: root.cfg_Mode === "Slideshow"
                                        enabled: visible && index < imageList.count - 1

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        onClicked: {
                                            imageList.move(index, index + 1, 1);

                                            root.syncToConfig();
                                            previewContainer.resetPreview();
                                        }
                                    }
                                }

                                Controls.TextField {
                                    text: cleanPath(model.path)
                                    placeholderText: "Select a file…"
                                    readOnly: true
                                    Layout.fillWidth: true
                                }

                                Controls.Button {
                                    icon.name: "document-open"

                                    visible: root.cfg_Mode !== "Slideshow"
                                    enabled: root.cfg_Mode !== "Slideshow"

                                    onClicked: {
                                        root._activePicker = index;

                                        imagePicker.fileMode = FileDialog.OpenFile;
                                        imagePicker.open();
                                    }
                                }

                                Controls.Button {
                                    icon.name: "list-remove"

                                    enabled: imageList.count > 1
                                    visible: root.cfg_Mode === "Slideshow" ? true : false

                                    onClicked: {
                                        root.removeImage(index)
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    visible: root.cfg_Mode === "Slideshow"

                    Controls.Button {
                        Kirigami.FormData.label: ""

                        Layout.fillWidth: true
                        Layout.preferredWidth: 0

                        enabled: root.cfg_Mode === "Slideshow"
                        
                        text: "Select Images"
                        icon.name: "list-add"
                        
                        onClicked: {
                            imagePicker.fileMode = FileDialog.OpenFiles;
                            imagePicker.open();
                        }
                    }

                    Controls.Button {
                        Kirigami.FormData.label: ""

                        Layout.fillWidth: true
                        Layout.preferredWidth: 0

                        enabled: root.cfg_Mode === "Slideshow"
                        
                        text: "Clear Images"
                        icon.name: "edit-delete"
                        
                        onClicked: {
                            root.clearImages();
                        }
                    }
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: "Appearance"
            }

            Controls.ComboBox {
                id: fontCombo
                Layout.fillWidth: true
                editable: true

                Kirigami.FormData.label: "Font Family:"

                model: root.monoFonts
                currentIndex: find(root.cfg_FontFamily)

                onActivated: {
                    root.cfg_FontFamily = currentText
                    if (root.configDialog) root.configDialog.changed = true
                }

                onAccepted: {
                    root.cfg_FontFamily = editText
                    if (root.configDialog) root.configDialog.changed = true
                }
            }

            ColumnLayout {
                Kirigami.FormData.label: "Characters:"
                Layout.fillWidth: true

                Grid {
                    Layout.fillWidth: true

                    columns: 12
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.cfg_AsciiChars

                        delegate: Controls.TextField {
                            width: Kirigami.Units.gridUnit * 1.15
                            height: Kirigami.Units.gridUnit * 1.45

                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                                                        
                            text: modelData
                            font.family: root.cfg_FontFamily

                            maximumLength: 1

                            color: activeFocus ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            background: Rectangle {
                                radius: Kirigami.Units.smallSpacing
                                color: activeFocus
                                    ? Kirigami.Theme.highlightColor
                                    : Kirigami.Theme.alternateBackgroundColor
                                border.width: 1
                                border.color: activeFocus
                                    ? Kirigami.Theme.highlightColor
                                    : Qt.alpha(Kirigami.Theme.textColor, 0.2)
                            }

                            onEditingFinished: {
                                let arr = Array.from(root.cfg_AsciiChars)

                                arr[index] = text
                                root.cfg_AsciiChars = arr

                                if (root.configDialog) {
                                    root.configDialog.changed = true
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Detail Level:"
                
                Controls.Slider {
                    id: detailSlider
                    Layout.fillWidth: true

                    snapMode: Controls.Slider.SnapOnRelease
                    stepSize: 1

                    from: 2
                    to: 0
                }
                
                Controls.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    
                    text: {
                        let w = (detailSlider.value === 0) ? 2 : (detailSlider.value === 1 ? 4 : 8);
                        let h = w * 2;
                        let labels = [" (High Detail)", " (Mid Detail)", " (Low Detail)"];
                        return w + "x" + h + labels[detailSlider.value];
                    }
                    font.weight: Font.Bold
                }
            }

            RowLayout {
                Kirigami.FormData.label: "Interval:"
                visible: root.cfg_Mode === "Slideshow"

                Controls.Slider {
                    id: intervalSlider
                    Layout.fillWidth: true

                    snapMode: Controls.Slider.SnapOnRelease
                    stepSize: 2.5

                    from: 5
                    to: 30

                    onValueChanged: {
                        previewContainer.resetPreview()
                    }
                }
                
                Controls.Label {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7

                    text: intervalSlider.value + " seconds"
                    font.weight: Font.Bold
                }
            }

            Controls.CheckBox {
                id: grayscaleCheck
                Kirigami.FormData.label: "Grayscaled:"
            }
        }
    }
}
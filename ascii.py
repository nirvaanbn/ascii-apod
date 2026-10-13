import json
import os
import subprocess
import sys

PLUGIN_ID = "de.korvexx.ascii_wallpaper"

QML = r"""
import QtQuick
import QtQuick.Window
import %(plugin)s

Window {
    width: 1; height: 1
    visible: true
    color: "black"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    title: "ascii-apod"

    Rectangle {
        objectName: "canvas"
        width: %(w)d; height: %(h)d
        color: "black"
        property int photoStatus: ascii.children[0].status

        AsciiShader {
            id: ascii
            anchors.fill: parent
            source: %(photo)s
            sourceNext: source
            detail: 1
            fontFamily: "Monospace"
            asciiChars: ["\\s", ".", "´", ":", "r", "s", "z", "u", "n", "v", "c", "x", "L", "O", "G", "D", "Q", "0", "K", "N", "M", "W", "&", "@"]
        }
    }
}
"""


def find_plugin():
    mine = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    system = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    for base in [mine] + system:
        ui = os.path.join(base, "plasma", "wallpapers", PLUGIN_ID, "contents", "ui")
        if os.path.isfile(os.path.join(ui, "AsciiShader.qml")):
            return ui
    return None


def kde_screens():
    try:
        found = subprocess.run(["kscreen-doctor", "-j"], capture_output=True, text=True, timeout=10)
        outputs = json.loads(found.stdout)["outputs"]
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        return []
    screens = []
    for o in sorted(outputs, key=lambda o: o.get("priority") or 99):
        if not (o.get("enabled") and o.get("connected")):
            continue
        mode = next((m for m in o.get("modes", []) if m.get("id") == o.get("currentModeId")), o)
        w, h = mode["size"]["width"], mode["size"]["height"]
        if o.get("rotation") in (2, 8):
            w, h = h, w
        scale = o.get("scale") or 1
        screens.append((o.get("name"), round(w / scale), round(h / scale), scale, (w, h)))
    return screens


def qt_screen():
    probe = ("from PySide6.QtGui import QGuiApplication as A; a = A([]); s = a.primaryScreen(); "
             "g = s.geometry(); print(s.name(), g.width(), g.height(), s.devicePixelRatio())")
    try:
        found = subprocess.run([sys.executable, "-I", "-c", probe], capture_output=True, text=True, timeout=30)
        name, w, h, scale = found.stdout.split()
        w, h, scale = int(w), int(h), float(scale)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None
    return name, w, h, scale, (round(w * scale), round(h * scale))


def pick_screen(wanted):
    screens = kde_screens()
    if wanted:
        for s in screens:
            if s[0] == wanted:
                return s
        names = ", ".join(s[0] for s in screens) or "none found"
        sys.exit(f"no screen called {wanted} (screens: {names})")
    if screens:
        return screens[0]
    return qt_screen() or sys.exit("could not work out your screen size")


def file_url(path):
    from PySide6.QtCore import QUrl
    return json.dumps(bytes(QUrl.fromLocalFile(os.path.abspath(path)).toEncoded()).decode())


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit("usage: ascii.py <photo> <output.png> [screen]")
    photo, out = sys.argv[1], sys.argv[2]
    if not os.path.isfile(photo):
        sys.exit(f"no such photo: {photo}")
    plugin = find_plugin()
    if not plugin:
        sys.exit(f"the ASCII Wallpaper plugin ({PLUGIN_ID}) is not installed")
    name, width, height, scale, pixels = pick_screen(sys.argv[3] if len(sys.argv) == 4 else None)

    os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "0"
    os.environ["QT_SCALE_FACTOR"] = str(scale)

    from PySide6.QtCore import QTimer
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuick import QQuickItem

    app = QGuiApplication(sys.argv[:1])
    engine = QQmlApplicationEngine()
    engine.loadData((QML % {"plugin": file_url(plugin), "photo": file_url(photo),
                            "w": width, "h": height}).encode())
    if not engine.rootObjects():
        sys.exit("could not load the ASCII plugin")
    window = engine.rootObjects()[0]
    canvas = window.findChild(QQuickItem, "canvas")

    state = {}

    def fail(message):
        print(message, file=sys.stderr)
        app.exit(1)

    def check():
        status = canvas.property("photoStatus")
        if status == 1:
            QTimer.singleShot(500, grab)
        elif status == 3:
            fail(f"could not open the photo: {photo}")
        else:
            QTimer.singleShot(100, check)

    def grab():
        state["grab"] = canvas.grabToImage()
        state["grab"].ready.connect(save)

    def save():
        image = state["grab"].image()
        image = image.copy(0, 0, min(pixels[0], image.width()), min(pixels[1], image.height()))
        if image.save(out):
            print(f"saved {out} ({image.width()} x {image.height()}, for {name})")
            app.exit(0)
        else:
            fail(f"could not save {out}")

    QTimer.singleShot(30_000, lambda: fail("gave up after 30 seconds (is the screen locked?)"))
    QTimer.singleShot(0, check)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()

import QtQuick

QtObject {
    property var command: []
    property bool running: false
    property var stdout: null
    property int starts: 0

    signal exited(int code)

    Component.onCompleted: Processes.last = this

    onRunningChanged: {
        if (running)
            starts++;
    }

    function finish(code, output) {
        stdout.text = output;
        running = false;
        exited(code);
    }
}

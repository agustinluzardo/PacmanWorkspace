pragma Singleton
import QtQuick
QtObject {
    signal sessionResumed()
    property bool preparingForSleep: false
}

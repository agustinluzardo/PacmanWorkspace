import QtQuick
Row {
    required property string settingKey
    required property string label
    property string description: ""
    property bool defaultValue: false
    property bool value: defaultValue
    width: parent ? parent.width : 0
    function loadValue() {}
}

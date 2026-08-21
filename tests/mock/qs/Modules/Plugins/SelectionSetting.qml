import QtQuick
Column {
    required property string settingKey
    required property string label
    property string description: ""
    required property var options
    property string defaultValue: ""
    property string value: defaultValue
    width: parent ? parent.width : 0
    function loadValue() {}
}

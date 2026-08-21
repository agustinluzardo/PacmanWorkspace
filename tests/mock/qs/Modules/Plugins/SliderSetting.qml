import QtQuick
Column {
    required property string settingKey
    required property string label
    property string description: ""
    property int defaultValue: 0
    property int value: defaultValue
    property int minimum: 0
    property int maximum: 100
    property string leftIcon: ""
    property string rightIcon: ""
    property string unit: ""
    width: parent ? parent.width : 0
    function loadValue() {}
}

/****************************************************************************
**
** Copyright (C) 2014 Jolla Ltd.
** Contact: Martin Jones <martin.jones@jollamobile.com>
**
****************************************************************************/

import QtQuick 2.6
import org.nemomobile.lipstick 0.1
import Sailfish.Silica 1.0
import Sailfish.Silica.private 1.0
import Sailfish.Lipstick 1.0
import com.jolla.lipstick 0.1

Rectangle {
    id: launcherFolder

    property alias model: launcherGrid.model
    property bool selectIcon
    property bool manageApps
    property Item iconSelector
    property Item appManager
    property int visibleRowCount: Math.max(2, launcherGrid.rows - 1)

    Connections {
        target: Desktop.instance.switcher
        onAppShowInProgressChanged: {
            if (Desktop.instance.switcher.appShowInProgress)
                close()
        }
    }

    function close() {
        launcherGrid.setEditMode(false)
        manageApps = false
        selectIcon = false
        opacity = 0.0
        enabled = false
        Lipstick.compositor.launcherLayer.pinned = false
        destroy(450)
    }

    onVisibleChanged: {
        if (!visible)
            launcherFolder.close()
    }

    z: 10
    opacity: 0.0
    Behavior on opacity { SmoothedAnimation { duration: 400; velocity: 1000 / duration } }

    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.rgba(Theme.overlayBackgroundColor, 1.0) }
        GradientStop { position: 1.0; color: Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityOverlay) }
    }

    width: launcherPager.width
    height: launcherPager.height

    Component.onCompleted: opacity = 1.0

    Connections {
        target: Lipstick.compositor
        onDisplayOff: launcherFolder.close()
    }

    Connections {
        target: model
        onItemRemoved: {
            if (model.itemCount === 0 && !manageApps)
                launcherFolder.close()
        }
    }

    Connections {
        target: launcherGrid.reorderItem
        onYChanged: {
            var maxContentY = launcherGrid.contentHeight - launcherGrid.height
            var globalY = launcherGrid.mapFromItem(launcherGrid.reorderItem, 0, 0).y
            if (globalY <= 0 && globalY >= -Theme.paddingLarge*2 && launcherGrid.contentY > 0) {
                launcherGrid.scroll(true)
            } else if (globalY + launcherGrid.cellHeight >= launcherGrid.height
                       && globalY + launcherGrid.cellHeight < launcherGrid.height + Theme.paddingLarge*2
                       && launcherGrid.contentY < maxContentY) {
                launcherGrid.scroll(false)
            } else {
                launcherGrid.stopScrolling()
            }
        }
    }

    MouseArea {
        property real pressPosY

        objectName: "LauncherFolder"
        anchors.fill: parent
        onPressAndHold: {
            if (Math.abs(mouseY - pressPosY) <= Theme.startDragDistance && !titleEditor.activeFocus && !selectIcon && !manageApps) {
                launcherGrid.setEditMode(true)
            }
        }
        onPressed: pressPosY = mouseY
        onClicked: {
            if (Math.abs(mouseY - pressPosY) <= Theme.startDragDistance) {
                if (titleEditor.activeFocus) {
                    titleEditor.focus = false
                } else if (selectIcon) {
                    selectIcon = false
                } else if (manageApps) {
                    manageApps = false
                } else if (!launcherGrid.launcherEditMode) {
                    launcherFolder.close()
                }
                launcherGrid.setEditMode(false)
            }
        }

        Rectangle {
            id: header

            property int topPadding: launcherGrid.orientation == Orientation.Portrait
                                     ? Screen.topCutout.height : 0
            property bool doubleHandle: Screen.topCutout.height > 0

            width: parent.width
            height: topPadding + launcherGrid.cellHeight - Theme.fontSizeExtraSmall/2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.rgba(Theme.primaryColor, 0.0) }
                GradientStop { position: 1.0; color: Theme.rgba(Theme.primaryColor, 0.15) }
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: header.doubleHandle
                                                ? (Screen.topCutout.width / 2 + Theme.paddingLarge + width / 2) : 0
                source: "image://theme/graphic-edge-swipe-handle-bottom"
            }
            Loader {
                active: header.doubleHandle
                sourceComponent: Component {
                    Image {
                        parent: header
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: -(Screen.topCutout.width / 2 + Theme.paddingLarge + width / 2)
                        source: "image://theme/graphic-edge-swipe-handle-bottom"
                    }
                }
            }

            MouseArea {
                id: icon

                objectName: "LauncherFolder_icon"
                width: launcherGrid.cellWidth
                height: parent.height
                x: launcherGrid.x // launcherGrid is centered in its parent

                LauncherIcon {
                    size: Math.round(Theme.iconSizeLauncher * 0.85)
                    y: header.topPadding + (launcherGrid.cellHeight - height - Theme.fontSizeExtraSmall) / 2
                    icon: model.iconId
                    anchors.horizontalCenter: parent.horizontalCenter
                    pressed: icon.pressed && icon.containsMouse

                    Text {
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: Theme.fontFamilyHeading
                        color: Theme.lightPrimaryColor
                        text: model.itemCount
                        anchors.centerIn: parent
                    }
                }

                onClicked: {
                    launcherGrid.setEditMode(false)
                    manageApps = false
                    selectIcon = !selectIcon
                    if (!iconSelector) {
                        iconSelector = iconSelectorComponent.createObject(header.parent)
                    }
                    if (selectIcon) {
                        titleEditor.focus = false
                    }
                }
            }

            MouseArea {
                id: manageAppsBtn

                width: Math.max(Theme.itemSizeMedium, launcherGrid.cellWidth * 1.15)
                height: parent.height - header.topPadding
                y: header.topPadding
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingSmall

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingSmall
                    height: Theme.itemSizeExtraSmall
                    radius: Theme.paddingSmall
                    color: manageApps ? Theme.rgba(Theme.highlightBackgroundColor, 0.4)
                                      : Theme.rgba(Theme.primaryColor, 0.15)
                    border.color: Theme.highlightColor
                    border.width: 1

                    Label {
                        anchors.centerIn: parent
                        text: manageApps ? "Done" : "+ Apps"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: manageApps ? Theme.highlightColor : Theme.primaryColor
                    }
                }

                onClicked: {
                    launcherGrid.setEditMode(false)
                    selectIcon = false
                    manageApps = !manageApps
                    if (!appManager) {
                        appManager = appManagerComponent.createObject(header.parent)
                    }
                    if (manageApps) {
                        titleEditor.focus = false
                    }
                }
            }

            TextField {
                id: titleEditor

                x: icon.x + icon.width - Theme.paddingMedium
                width: manageAppsBtn.x - x
                y: header.topPadding + (launcherGrid.cellHeight - height - Theme.fontSizeExtraSmall) / 2
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamilyHeading
                text: model.title
                labelVisible: false
                background: null
                enabled: !selectIcon && !manageApps
                color: enabled ? Theme.primaryColor : Theme.highlightColor
                horizontalAlignment: Qt.AlignRight
                onActiveFocusChanged: {
                    if (!activeFocus) {
                        if (text.trim().length === 0) {
                            //% "Folder"
                            text = qsTrId("lipstick-jolla-home-folder")
                        }
                        launcherGrid.model.title = text
                    } else {
                        launcherGrid.setEditMode(false)
                        cursorPosition = text.length
                    }
                }

                EnterKey.onClicked: focus = false
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
            }

            Label {
                anchors {
                    right: titleEditor.right
                    rightMargin: Theme.horizontalPageMargin
                    top: titleEditor.bottom
                    topMargin: -Theme.paddingMedium
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: titleEditor.activeFocus
                      ? //% "Enter folder name"
                        qsTrId("lipstick-jolla-home-enter-folder-name")
                      : //% "Select folder shape"
                        qsTrId("lipstick-jolla-home-select-folder-shape")
                visible: titleEditor.activeFocus || selectIcon
            }
        }

        Item {
            // Use a clipper item to clip slightly outside the GridView area
            anchors.top: header.bottom
            width: parent.width
            height: launcherGrid.height + Theme.fontSizeExtraSmall
            clip: true

            LauncherGrid {
                id: launcherGrid

                function scroll(up) {
                    contentYAnimation.to = up ? originY : originY + contentHeight - height
                    contentYAnimation.duration = Math.abs(contentY - contentYAnimation.to)
                    contentYAnimation.start()
                }

                function stopScrolling() {
                    contentYAnimation.stop()
                }

                gridManager.dragContainer: launcherFolder
                onItemLaunched: launcherFolder.close()
                header: null
                y: Theme.fontSizeExtraSmall/2
                topMargin: 0
                bottomMargin: 0
                height: visibleRowCount >= 2 ? cellHeight * visibleRowCount
                                             : Math.round(cellHeight * 1.5)
                cacheBuffer: height
                displayMarginBeginning: Theme.fontSizeExtraSmall/2
                displayMarginEnd: Theme.fontSizeExtraSmall/2
                enabled: !titleEditor.activeFocus && !selectIcon && !manageApps
                Behavior on opacity { FadeAnimation { duration: 300 } }
                opacity: enabled ? 1.0 : ((selectIcon || manageApps) ? 0.0 : Theme.opacityLow)

                NumberAnimation {
                    id: contentYAnimation

                    target: launcherGrid
                    property: "contentY"
                    easing.type: Easing.InOutQuad
                }

                MouseArea {
                    property var pressPos

                    objectName: "LauncherFolder_editMode"
                    anchors.fill: parent
                    z: -1
                    onPressAndHold: launcherGrid.setEditMode(true)
                    onPressed: pressPos = mouseY
                    onClicked: {
                        if (Math.abs(mouseY - pressPos) <= Theme.startDragDistance) {
                            if (titleEditor.activeFocus) {
                                titleEditor.focus = false
                            } else if (selectIcon) {
                                selectIcon = false
                            } else if (manageApps) {
                                manageApps = false
                            } else if (!launcherGrid.launcherEditMode) {
                                launcherFolder.close()
                            }
                            launcherGrid.setEditMode(false)
                        }
                    }
                }

                VerticalScrollDecorator {}
            }
        }

        Rectangle {
            id: footer

            property bool draggedIntoFooter: {
                var item = launcherGrid.reorderItem
                if (item) {
                    // The odd launcherGrid.reorderItem.y line below is to force revaluation of this binding
                    launcherGrid.reorderItem.y
                    var itemY = launcherGrid.mapFromItem(item, 0, 0).y
                    if (itemY + item.height/2 > launcherGrid.height)
                        return true
                }
                return false
            }
            property bool shown: (launcherGrid.launcherEditMode && launcherGrid.reorderItem
                                  || model.itemCount > launcherGrid.columns * visibleRowCount)
                                 && !selectIcon && !manageApps

            height: visibleRowCount >= 2 ? launcherGrid.cellHeight - Theme.fontSizeExtraSmall/2
                                         : Math.round(launcherGrid.cellHeight / 2)
            width: parent.width
            y: parent.height - (shown ? height : 0)
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
            opacity: launcherGrid.launcherEditMode && launcherGrid.reorderItem
                     ? (draggedIntoFooter ? 1.0 : Theme.opacityHigh)
                     : (model.itemCount > launcherGrid.columns * visibleRowCount && shown
                        ? Theme.opacityHigh : 0.0)
            Behavior on opacity { FadeAnimation {} }
            color: Theme.highlightDimmerColor
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.rgba(Theme.primaryColor, Theme.highlightBackgroundOpacity) }
                GradientStop { position: 1.0; color: Theme.rgba(Theme.primaryColor, 0.0) }
            }
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2*x
            anchors.verticalCenter: footer.verticalCenter
            color: Theme.highlightColor
            opacity: launcherGrid.launcherEditMode && launcherGrid.reorderItem ? 1.0 : 0.0
            Behavior on opacity { FadeAnimation {} }
            horizontalAlignment: Qt.AlignHCenter
            wrapMode: Text.Wrap
            //% "Drop icon here to remove it from folder"
            text: qsTrId("lipstick-jolla-home-drop-icon-here-to-remove")
        }
    }

    Component {
        id: appManagerComponent

        SilicaFlickable {
            anchors {
                top: header.bottom
                topMargin: Theme.fontSizeExtraSmall/2
                left: parent.left
                right: parent.right
            }
            height: launcherFolder.height - header.height
            contentHeight: appMgrCol.height + Theme.paddingLarge * 2
            opacity: manageApps ? 1.0 : 0.0
            Behavior on opacity { FadeAnimation { duration: 250 } }
            enabled: manageApps
            visible: opacity > 0.01
            onEnabledChanged: if (enabled) contentY = 0
            clip: true

            VerticalScrollDecorator {}

            Column {
                id: appMgrCol
                width: parent.width
                spacing: Theme.paddingSmall

                Row {
                    width: parent.width - Theme.horizontalPageMargin * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall

                    TextField {
                        id: createFolderField
                        width: parent.width - createFolderBtn.width - Theme.paddingSmall
                        placeholderText: "Create another folder..."
                        labelVisible: false
                        EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                        EnterKey.onClicked: createFolderBtn.clicked(null)
                    }

                    BackgroundItem {
                        id: createFolderBtn
                        width: Theme.itemSizeExtraLarge
                        height: Theme.itemSizeSmall
                        onClicked: {
                            var rootModel = launcherFolder.model ? launcherFolder.model.parentFolder : null
                            if (rootModel) {
                                var fname = createFolderField.text.trim()
                                if (fname.length === 0) fname = "New Folder"
                                var nf = rootModel.createFolder(rootModel.itemCount, fname)
                                if (nf) {
                                    nf.iconId = "icon-launcher-folder-01"
                                    createFolderField.text = ""
                                    createFolderField.focus = false
                                    launcherFolder.model = nf
                                }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.paddingSmall
                            color: Theme.rgba(Theme.highlightBackgroundColor, 0.3)
                            border.color: Theme.highlightColor
                            border.width: 1
                            Label {
                                anchors.centerIn: parent
                                text: "+ Folder"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.highlightColor
                            }
                        }
                    }
                }

                SectionHeader {
                    text: "In \"" + (launcherFolder.model ? launcherFolder.model.title : "") + "\" (tap to remove)"
                }

                Repeater {
                    model: launcherFolder.model
                    delegate: BackgroundItem {
                        width: appMgrCol.width
                        height: Theme.itemSizeExtraSmall

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.rightMargin: Theme.horizontalPageMargin
                            spacing: Theme.paddingMedium

                            LauncherIcon {
                                size: Theme.iconSizeSmall
                                icon: model.object ? model.object.iconId : ""
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                width: parent.width - Theme.iconSizeSmall - removeTag.width - Theme.paddingMedium * 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.object ? model.object.title : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                id: removeTag
                                anchors.verticalCenter: parent.verticalCenter
                                text: "− Remove"
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryHighlightColor
                            }
                        }

                        onClicked: {
                            var rootModel = launcherFolder.model ? launcherFolder.model.parentFolder : null
                            if (rootModel && model.object) {
                                var folderIdx = rootModel.indexOf(launcherFolder.model)
                                rootModel.moveToFolder(model.object, rootModel, folderIdx + 1)
                            }
                        }
                    }
                }

                SectionHeader {
                    text: "Main Screen Apps (tap to add)"
                }

                Repeater {
                    model: launcherFolder.model ? launcherFolder.model.parentFolder : null
                    delegate: BackgroundItem {
                        property bool isRootApp: model.object && model.object.type !== LauncherModel.Folder
                        width: appMgrCol.width
                        height: isRootApp ? Theme.itemSizeExtraSmall : 0
                        visible: isRootApp

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.rightMargin: Theme.horizontalPageMargin
                            spacing: Theme.paddingMedium

                            LauncherIcon {
                                size: Theme.iconSizeSmall
                                icon: isRootApp ? model.object.iconId : ""
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                width: parent.width - Theme.iconSizeSmall - addTag.width - Theme.paddingMedium * 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: isRootApp ? model.object.title : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                id: addTag
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+ Add"
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.highlightColor
                            }
                        }

                        onClicked: {
                            var rootModel = launcherFolder.model ? launcherFolder.model.parentFolder : null
                            if (isRootApp && rootModel && model.object) {
                                rootModel.moveToFolder(model.object, launcherFolder.model)
                            }
                        }
                    }
                }

                SectionHeader {
                    text: "Apps in Other Folders (tap to move here)"
                }

                Repeater {
                    model: launcherFolder.model ? launcherFolder.model.parentFolder : null
                    delegate: Column {
                        id: otherFolderGroup
                        property var folderObj: model.object
                        property bool isOtherFolder: folderObj && folderObj.type === LauncherModel.Folder && folderObj !== launcherFolder.model
                        width: appMgrCol.width
                        visible: isOtherFolder

                        Repeater {
                            model: otherFolderGroup.isOtherFolder ? otherFolderGroup.folderObj : null
                            delegate: BackgroundItem {
                                width: appMgrCol.width
                                height: Theme.itemSizeExtraSmall

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.horizontalPageMargin
                                    anchors.rightMargin: Theme.horizontalPageMargin
                                    spacing: Theme.paddingMedium

                                    LauncherIcon {
                                        size: Theme.iconSizeSmall
                                        icon: model.object ? model.object.iconId : ""
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Label {
                                        width: parent.width - Theme.iconSizeSmall - moveHereTag.width - Theme.paddingMedium * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.object ? (model.object.title + " (" + otherFolderGroup.folderObj.title + ")") : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.secondaryColor
                                        truncationMode: TruncationMode.Fade
                                    }

                                    Label {
                                        id: moveHereTag
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "+ Move"
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.highlightColor
                                    }
                                }

                                onClicked: {
                                    var rootModel = launcherFolder.model ? launcherFolder.model.parentFolder : null
                                    if (rootModel && model.object) {
                                        rootModel.moveToFolder(model.object, launcherFolder.model)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: iconSelectorComponent

        SilicaFlickable {
            anchors {
                top: header.bottom
                topMargin: Theme.fontSizeExtraSmall/2
                horizontalCenter: parent.horizontalCenter
            }
            width: folderIconGrid.width
            height: launcherFolder.height - header.height
            contentHeight: folderIconGrid.height
            opacity: selectIcon ? 1.0 : 0.0
            Behavior on opacity { FadeAnimation { duration: 300 } }
            enabled: selectIcon
            onEnabledChanged: if (enabled) contentY = 0
            clip: true

            VerticalScrollDecorator {}

            MouseArea {
                objectName: "LauncherFolder_iconSelector"
                width: parent.width
                height: folderIconGrid.height
                onClicked: selectIcon = false

                Grid {
                    id: folderIconGrid

                    columns: Math.floor(launcherGrid.width/launcherGrid.cellWidth)
                    Repeater {
                        model: 16
                        delegate: MouseArea {
                            id: folderIcon

                            objectName: "LauncherFolder_folderIcon"
                            width: launcherGrid.cellWidth
                            height: launcherGrid.cellHeight

                            LauncherIcon {
                                id: folderLauncherIcon

                                anchors {
                                    centerIn: parent
                                    verticalCenterOffset: Math.round(-Theme.fontSizeExtraSmall/2)
                                }
                                icon: "image://theme/icon-launcher-folder-" + (index >= 9 ? (index + 1)
                                                                                          : "0" + (index + 1))
                                pressed: folderIcon.pressed && folderIcon.containsMouse
                                opacity: icon.indexOf(launcherFolder.model.iconId) !== -1 ? Theme.opacityFaint : 1.0
                            }
                            Image {
                                anchors.centerIn: folderLauncherIcon
                                source: folderLauncherIcon.opacity !== 1.0 ? "image://theme/icon-s-installed" : ""
                            }
                            onClicked: {
                                launcherGrid.model.iconId = "icon-launcher-folder-" + (index >= 9 ? (index + 1)
                                                                                                  : "0" + (index + 1))
                                selectIcon = false
                            }
                        }
                    }
                }
            }
        }
    }
}

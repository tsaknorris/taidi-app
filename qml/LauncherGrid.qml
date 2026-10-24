/*
 * Copyright (c) 2013 - 2019 Jolla Ltd.
 * Copyright (c) 2021 Open Mobile Platform LLC.
 *
 * License: Proprietary
 */

import QtQuick 2.6
import org.nemomobile.lipstick 0.1
import Nemo.Configuration 1.0
import Connman 0.2
import com.jolla.lipstick 0.1
import Sailfish.Silica 1.0
import Sailfish.Silica.private 1.0
import Sailfish.Policy 1.0
import Sailfish.AccessControl 1.0
import Sailfish.Lipstick 1.0
import "../main"

IconGridViewBase {
    id: gridview

    property bool launcherEditMode: removeApplicationEnabled
    property var launcherModel: model
    property bool rootFolder
    property QtObject folderComponent
    property Item openedChildFolder
    property alias reorderItem: gridManager.reorderItem
    property alias gridManager: gridManager
    property bool canUninstall: AccessControl.hasGroup(AccessControl.RealUid, "sailfish-system")
    property var quickMoveApp: null
    property int quickMoveIndex: -1
    property int topMargin: Math.max(_page.orientation === Orientation.Portrait
                                     ? Screen.topCutout.height : 0,
                                     largeScreen ? Theme.paddingLarge : Theme.paddingSmall)
    property int bottomMargin: Math.max(_page.orientation === Orientation.InvertedPortrait
                                        ? Screen.topCutout.height : 0,
                                        largeScreen ? Theme.paddingLarge : Theme.paddingSmall)
    property int realCellHeight: Math.floor(pageHeight / rows) // cell height after page's vertical paddings
    property int statusBarHeight: {
        if (Lipstick.compositor.multitaskingHome) {
            return 0
        } else {
            var statusBar = Lipstick.compositor.homeLayer.statusBar
            return statusBar.baseY + statusBar.height
        }
    }

    // assuming this is enough for clock header
    property bool reserveFirstRow: launcherClockConfig.launcher_clock_visible

    signal itemLaunched

    function categoryQsTrIds() {
        //% "AudioVideo"
        QT_TRID_NOOP("lipstick-jolla-home-folder_audiovideo")
        //% "Audio"
        QT_TRID_NOOP("lipstick-jolla-home-folder_audio")
        //% "Video"
        QT_TRID_NOOP("lipstick-jolla-home-folder_video")
        //% "Development"
        QT_TRID_NOOP("lipstick-jolla-home-folder_development")
        //% "Education"
        QT_TRID_NOOP("lipstick-jolla-home-folder_education")
        //% "Game"
        QT_TRID_NOOP("lipstick-jolla-home-folder_game")
        //% "Graphics"
        QT_TRID_NOOP("lipstick-jolla-home-folder_graphics")
        //% "Network"
        QT_TRID_NOOP("lipstick-jolla-home-folder_network")
        //% "Office"
        QT_TRID_NOOP("lipstick-jolla-home-folder_office")
        //% "Science"
        QT_TRID_NOOP("lipstick-jolla-home-folder_science")
        //% "Settings"
        QT_TRID_NOOP("lipstick-jolla-home-folder_settings")
        //% "System"
        QT_TRID_NOOP("lipstick-jolla-home-folder_system")
        //% "Utility"
        QT_TRID_NOOP("lipstick-jolla-home-folder_utility")
    }

    function showFolder(folder) {
        if (openedChildFolder) {
            // should never happen
            openedChildFolder.close()
        }

        if (!folderComponent) {
            folderComponent = Qt.createComponent("LauncherFolder.qml")
            if (folderComponent.status == Component.Error) {
                console.log("Error opening folder", folderComponent.errorString())
                return
            }
        }
        openedChildFolder = folderComponent.createObject(launcherPager, { 'model': folder })
    }

    function setEditMode(enabled) {
        gridManager.setEditMode(enabled)
        removeApplicationEnabled = enabled
        if (!enabled) {
            quickMoveApp = null
            quickMoveIndex = -1
        }
    }

    onVisibleChanged: if (!visible) setEditMode(false)

    // base class uses pageHeight to calculate how man rows fit with minimum size,
    // we then make the delegates fit full height of the page and finally in delegate
    // itself position them according to margins
    pageHeight: launcherPager.height - topMargin - bottomMargin
    cellHeight: Math.floor(launcherPager.height / rows)
    header: launcherClockConfig.launcher_clock_visible ? clockHeader : null

    ConfigurationGroup {
        id: launcherClockConfig

        path: "/desktop/sailfish/experimental"

        property bool launcher_ip_info: false
        property bool launcher_clock_visible: false
        property int launcher_clock_size: 1.5 * Theme.fontSizeHuge
    }

    Component {
        id: clockHeader

        Item {
            width: gridview.width
            height: Math.ceil((clockColumn.height + gridview.statusBarHeight) / gridview.cellHeight)
                    * gridview.cellHeight
                    - gridview.statusBarHeight

            Column {
                id: clockColumn

                // left-align with the launcher icons on the first column
                x: (gridview.cellWidth - Theme.iconSizeLauncher) / 2
                y: parent.height - height
                width: parent.width - 2*x
                bottomPadding: Theme.paddingMedium

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    ClockItem {
                        id: clockItem

                        color: Theme.highlightColor
                        font.pixelSize: launcherClockConfig.launcher_clock_size
                        updatesEnabled: visible
                    }

                    Label {
                        id: dateLabel

                        property string dateText: Format.formatDate(clockItem.time, Formatter.DateLong)
                        property string weekdayText: Format.formatDate(clockItem.time, Format.WeekdayNameStandalone)

                        text: {
                            //: Date and weekday shown together, e.g. "20 December 2021, Monday"
                            //% "%1, %2"
                            var text = qsTrId("lipstick-jolla-home-date_and_weekday").arg(dateText).arg(weekdayText)
                            if (fontMetrics.advanceWidth(text) > width) {
                                return dateText + "<br>" + weekdayText[0].toUpperCase() + weekdayText.substring(1)
                            } else {
                                return text
                            }
                        }

                        truncationMode: TruncationMode.Fade
                        width: (ipInfoLoader.active ? parent.width / 2 : parent.width)
                               - parent.spacing - clockItem.width
                        anchors.baseline: clockItem.baseline
                        anchors.baselineOffset: lineCount > 1 ? -height/2 : 0
                        color: Theme.highlightColor

                        FontMetrics {
                            id: fontMetrics
                            font: dateLabel.font
                        }
                    }

                    Loader {
                        id: ipInfoLoader

                        active: launcherClockConfig.launcher_ip_info
                                && (_page.orientation === Orientation.Landscape
                                    || _page.orientation === Orientation.LandscapeInverted)
                        width: parent.width / 2
                        height: clockItem.height

                        sourceComponent: Component {
                            Item {
                                Label {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    color: Theme.highlightColor
                                    text: {
                                        var wifiAddress = networkManager.connectedWifi
                                                ? networkManager.connectedWifi.ipv4.Address
                                                : undefined

                                        var ethernetAdress = networkManager.connectedEthernet
                                                ? networkManager.connectedEthernet.ipv4.Address
                                                : undefined

                                        //% "Wifi IP address: "
                                        return qsTrId("lipstick-jolla-home_wifi_address_header")
                                                + (wifiAddress ? wifiAddress : "-")
                                                + "\n"
                                                + //% "Ethernet IP address: "
                                                qsTrId("lipstick-jolla-home_ethernet_address_header")
                                                + (ethernetAdress ? ethernetAdress : "-")
                                    }
                                }
                                NetworkManager { id: networkManager }
                            }
                        }
                    }
                }

                Separator {
                    anchors { left: parent.left; right: parent.right }
                    color: Theme.highlightColor
                }
            }
        }
    }

    EditableGridManager {
        id: gridManager

        supportsFolders: rootFolder
        pager: launcherPager
        view: gridview
        contentContainer: gridview.contentItem
        dragContainer: launcherPager
        Component.onCompleted: startReorderTimer.interval = 350
        onFolderIndexChanged: if (folderIndex == -1) newFolderIcon.active = false
    }

    // Floating Edit Mode Toolbar & Quick Move Overlay (Root Grid only)
    Rectangle {
        id: editModeToolbar

        parent: rootFolder ? launcherPager : gridview
        visible: rootFolder && gridview.launcherEditMode && !gridview.openedChildFolder && !gridview.quickMoveApp
        z: 15
        x: 0
        y: gridview.topMargin
        width: parent ? parent.width : 0
        height: Theme.itemSizeSmall
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.92)

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.paddingMedium
            anchors.rightMargin: Theme.paddingMedium
            spacing: Theme.paddingSmall

            BackgroundItem {
                width: (parent.width - Theme.paddingSmall * 2) * 0.42
                height: parent.height
                onClicked: {
                    var nf = launcherModel.createFolder(launcherModel.itemCount, "New Folder")
                    if (nf) {
                        nf.iconId = "icon-launcher-folder-01"
                        setEditMode(false)
                        showFolder(nf)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.paddingSmall / 2
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    border.color: Theme.highlightColor
                    border.width: 1
                    Label {
                        anchors.centerIn: parent
                        text: "+ New Folder"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.highlightColor
                    }
                }
            }

            Label {
                width: (parent.width - Theme.paddingSmall * 2) * 0.36
                anchors.verticalCenter: parent.verticalCenter
                text: "Tap app to move"
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            BackgroundItem {
                width: (parent.width - Theme.paddingSmall * 2) * 0.22
                height: parent.height
                onClicked: setEditMode(false)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.paddingSmall / 2
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.primaryColor, 0.15)
                    Label {
                        anchors.centerIn: parent
                        text: "Done"
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.primaryColor
                    }
                }
            }
        }
    }

    Rectangle {
        id: quickMoveOverlay

        parent: rootFolder ? launcherPager : gridview
        visible: rootFolder && gridview.quickMoveApp !== null
        z: 25
        anchors.fill: parent
        color: Theme.rgba(Theme.overlayBackgroundColor, 0.96)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: quickMoveHeader
            anchors {
                top: parent.top
                topMargin: gridview.topMargin + Theme.paddingMedium
                left: parent.left
                right: parent.right
                leftMargin: Theme.horizontalPageMargin
                rightMargin: Theme.horizontalPageMargin
            }
            spacing: Theme.paddingMedium

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                LauncherIcon {
                    size: Theme.iconSizeSmallPlus
                    icon: gridview.quickMoveApp ? gridview.quickMoveApp.iconId : ""
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    width: parent.width - Theme.iconSizeSmallPlus - closeQuickMoveBtn.width - Theme.paddingMedium * 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: gridview.quickMoveApp ? ("Move \"" + gridview.quickMoveApp.title + "\" to:") : ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.highlightColor
                    truncationMode: TruncationMode.Fade
                }

                BackgroundItem {
                    id: closeQuickMoveBtn
                    width: Theme.itemSizeSmall
                    height: Theme.itemSizeSmall
                    onClicked: {
                        gridview.quickMoveApp = null
                        gridview.quickMoveIndex = -1
                    }
                    Label {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.primaryColor
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.paddingSmall

                TextField {
                    id: newFolderInput
                    width: parent.width - createWithAppBtn.width - Theme.paddingSmall
                    placeholderText: "New folder name..."
                    labelVisible: false
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.onClicked: createWithAppBtn.clicked(null)
                }

                BackgroundItem {
                    id: createWithAppBtn
                    width: Theme.itemSizeExtraLarge
                    height: Theme.itemSizeSmall
                    onClicked: {
                        if (gridview.quickMoveApp) {
                            var fname = newFolderInput.text.trim()
                            if (fname.length === 0) fname = "New Folder"
                            var appObj = gridview.quickMoveApp
                            var nf = launcherModel.createFolder(launcherModel.itemCount, fname)
                            if (nf) {
                                nf.iconId = "icon-launcher-folder-01"
                                launcherModel.moveToFolder(appObj, nf)
                            }
                            newFolderInput.text = ""
                            newFolderInput.focus = false
                            gridview.quickMoveApp = null
                            gridview.quickMoveIndex = -1
                            setEditMode(false)
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
                            text: "+ Create"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                        }
                    }
                }
            }

            Separator {
                width: parent.width
                color: Theme.highlightColor
            }
        }

        SilicaFlickable {
            anchors {
                top: quickMoveHeader.bottom
                topMargin: Theme.paddingSmall
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            contentHeight: folderListColumn.height + Theme.paddingLarge
            clip: true

            VerticalScrollDecorator {}

            Column {
                id: folderListColumn
                width: parent.width

                Repeater {
                    model: rootFolder ? gridview.launcherModel : null
                    delegate: BackgroundItem {
                        width: folderListColumn.width
                        height: isFolderItem ? Theme.itemSizeSmall : 0
                        visible: isFolderItem
                        property bool isFolderItem: model.object && model.object.type === LauncherModel.Folder

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.horizontalPageMargin
                            anchors.rightMargin: Theme.horizontalPageMargin
                            spacing: Theme.paddingMedium

                            LauncherIcon {
                                size: Theme.iconSizeSmallPlus
                                icon: isFolderItem ? model.object.iconId : ""
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: isFolderItem ? (model.object.title + " (" + model.object.itemCount + ")") : ""
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primaryColor
                            }
                        }

                        onClicked: {
                            if (isFolderItem && gridview.quickMoveApp) {
                                var appObj = gridview.quickMoveApp
                                gridview.quickMoveApp = null
                                gridview.quickMoveIndex = -1
                                launcherModel.moveToFolder(appObj, model.object)
                                setEditMode(false)
                            }
                        }
                    }
                }
            }
        }
    }

    Image {
        id: newFolderIcon

        property bool active
        property Item target
        property bool show: active && rootFolder && gridManager.folderIndex >= 0
        property string iconId: "icon-launcher-folder-01"

        source: "image://theme/" + iconId
        opacity: show ? 1.0 : 0.0
        Behavior on opacity { FadeAnimation {} }
        y: target ? target.targetY + target.iconOffset : -20000
        anchors.horizontalCenter: target ? target.horizontalCenter : gridview.contentItem.horizontalCenter
        scale: 1.3
        parent: gridview.contentItem
        z: -3

        onShowChanged: {
            if (show) {
                var index = Math.floor(Math.min(Math.random() * 16, 15))
                iconId = "icon-launcher-folder-" + (index >= 9 ? (index + 1) : "0" + (index + 1))
            }
        }
    }

    Connections {
        target: Lipstick.compositor
        onDisplayOff: setEditMode(false)
    }

    PolicyValue {
        id: uninstallPolicy

        policyType: PolicyValue.ApplicationInstallationEnabled
    }

    PolicyValue {
        id: appsupportPolicy

        policyType: PolicyValue.AppsupportEnabled
    }

    delegate: EditableGridDelegate {
        id: wrapper

        property alias iconOffset: launcherIcon.y
        property Item uninstallButton
        property bool isUpdating: model.object.isUpdating
        property Item updatingItem
        property bool isAndroidApp: !isFolder && model.object && model.object.readValue
                                    ? model.object.readValue("X-apkd-packageName") != "" : false
        // children reparented
        property real itemOpacity: (appsupportPolicy.value || !isAndroidApp)
                                   ? 1.0 : Theme.opacityLow

        width: cellWidth
        height: gridview.realCellHeight
        manager: gridManager
        isFolder: model.object.type == LauncherModel.Folder
        folderItemCount: isFolder && model.object ? model.object.itemCount : 0
        editMode: gridview.launcherEditMode
        scale: newFolderIcon.show && manager.folderIndex == index && !isFolder
               ? 0.5 : (reordering || manager.folderIndex == index || scaleUpTimer.running
                        ? 1.3 : 1)

        // the grid view lays out item for full screen, this overrides the layouting so that
        // the page has top and bottom margins
        targetY: {
            var indexOffset = gridview.reserveFirstRow ? gridview.columns : 0
            var rowInPage = Math.floor((index + indexOffset) % (gridview.columns * gridview.rows) / gridview.columns)
            var pageNumber = Math.floor((model.index + indexOffset) / (gridview.columns * gridview.rows))
            var pageStart = pageNumber * launcherPager.height
            return gridview.originY + pageStart + gridview.topMargin + rowInPage * gridview.realCellHeight
        }

        onEditModeChanged: {
            if (editMode && !uninstallButton && canUninstall && uninstallPolicy.value) {
                uninstallButton = uninstallButtonComponent.createObject(contentItem,
                                                                        { isAndroidApp: wrapper.isAndroidApp })
            }
        }

        onReorder: {
            if (newFolderIndex >= 0 && newFolderIndex !== index) {
                if (!manager.folderItem.isFolder) {
                    newFolderIcon.target = manager.folderItem
                    newFolderIcon.active = true
                } else {
                    newFolderIcon.active = false
                }
                manager.folderIndex = newFolderIndex
            } else if (newIndex != -1 && newIndex !== index) {
                launcherModel.move(index, newIndex)
            }
        }

        onClicked: {
            if (dragged) {
                return
            }

            if (isFolder) {
                setEditMode(false)
                showFolder(model.object)
                if (Lipstick.compositor.multitaskingHome) {
                    // Ensure the launcher is visible - could be peeking from bottom due to hint.
                    Lipstick.compositor.setCurrentWindow(Lipstick.compositor.launcherLayer.window)
                }
            } else if (launcherEditMode) {
                if (rootFolder) {
                    gridview.quickMoveApp = model.object
                    gridview.quickMoveIndex = index
                } else if (launcherModel.parentFolder) {
                    var parentIdx = launcherModel.parentFolder.indexOf(launcherModel)
                    launcherModel.parentFolder.moveToFolder(model.object, launcherModel.parentFolder, parentIdx + 1)
                } else {
                    setEditMode(false)
                }
            } else {
                if (wrapper.isAndroidApp && !appsupportPolicy.value) {
                    return
                }

                if (isUpdating) {
                    // Call launchApplication(), which will send a D-Bus signal
                    // for interested parties (non-store client) to pick it up
                    object.launchApplication()
                } else {
                    Desktop.instance.switcher.activateWindowFor(object)
                }

                if (Lipstick.compositor.multitaskingHome) {
                    Lipstick.compositor.launcherLayer.hide()
                }

                gridview.itemLaunched()
            }
            Lipstick.compositor.launcherLayer.pinned = false
        }

        onPressAndHold: {
            if (!launcherEditMode) {
                setEditMode(true)
                wrapper.startReordering(true)
            }
        }

        onEndReordering: {
            if (manager.folderIndex >= 0) {
                if (launcherModel.get(manager.folderIndex).type == LauncherModel.Application) {
                    //% "Folder"
                    var folder = launcherModel.createFolder(manager.folderIndex, qsTrId("lipstick-jolla-home-folder"))
                    if (folder) {
                        folder.iconId = newFolderIcon.iconId

                        var item1Categories = folder.get(0).desktopCategories
                        var item2Categories = model.object.desktopCategories
                        for (var i = 0; i < item1Categories.length; i++) {
                            if (item2Categories.indexOf(item1Categories[i]) >= 0) {
                                var id = "lipstick-jolla-home-folder_" + item1Categories[i].toLowerCase()
                                var title = qsTrId(id)
                                if (title != id) {
                                    folder.title = title
                                    break
                                }
                            }
                        }
                        launcherModel.moveToFolder(model.object, folder)
                    }
                } else {
                    launcherModel.moveToFolder(model.object, launcherModel.get(manager.folderIndex))
                }
                manager.folderIndex = -1
                newFolderIcon.active = false
            }
        }

        onReleased: {
            if (!rootFolder
                    && gridview.mapFromItem(wrapper.contentItem, 0, 0).y + wrapper.height/2 > gridview.height) {
                var parentFolderIndex = launcherModel.parentFolder.indexOf(launcherModel)
                launcherModel.parentFolder.moveToFolder(model.object, launcherModel.parentFolder,
                                                        parentFolderIndex + 1)
            }
        }

        function animateScaleUp() {
            scaleUpTimer.start()
        }

        Timer {
            id: scaleUpTimer
            interval: 200
        }

        Connections {
            target: model.object
            ignoreUnknownSignals: true
            onItemRemoved: {
                var object = model.object
                if (object && object.itemCount === 0) {
                    object.destroyFolder()
                }
            }
        }

        LauncherIcon {
            id: launcherIcon

            size: Math.round(Theme.iconSizeLauncher * 0.85)
            anchors {
                centerIn: parent
                verticalCenterOffset: Math.floor(-launcherText.height / 2)
            }
            icon: model.object.iconId
            pressed: down
            opacity: isUpdating && folderItemCount == 0 ? Theme.opacityFaint
                                                        : wrapper.itemOpacity

            Text {
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamilyHeading
                text: folderItemCount > 0 ? folderItemCount : ""
                color: Theme.lightPrimaryColor
                anchors.centerIn: parent
                visible: !isUpdating || model.object.updatingProgress < 0 || model.object.updatingProgress > 100
                opacity: reorderItem && folderItemCount >= 99 ? Theme.opacityLow : 1.0
            }
        }

        Label {
            id: launcherText

            anchors {
                top: launcherIcon.bottom
                topMargin: gridview.launcherItemSpacing
                left: parent.left
                right: parent.right
                leftMargin: Theme.paddingSmall/2
                rightMargin: Theme.paddingSmall/2
            }
            horizontalAlignment: implicitWidth > width ? Text.AlignLeft : Text.AlignHCenter
            truncationMode: TruncationMode.Fade

            color: down ? Theme.highlightColor : Theme.primaryColor
            font.pixelSize: gridview.launcherLabelFontSize
            text: object.title.replace(/\n|\r/g, " ")
            textFormat: Text.PlainText
            opacity: wrapper.itemOpacity
            visible: !launcherEditMode || isFolder
        }

        BusyIndicator {
            anchors.centerIn: launcherIcon
            running: model.object.isUpdating
                     || (!Lipstick.compositor.multitaskingHome && !isFolder && model.object.isLaunching)
            opacity: running
            Behavior on opacity { FadeAnimation {} }

            // If the launcher icons use custom size scale the busy indicator accordingly to align dimensions
            scale: (launcherIcon.size / Theme.pixelRatio) / 86

            Label {
                anchors.centerIn: parent
                text: model.object.updatingProgress + '%'
                visible: model.object.isUpdating && model.object.updatingProgress >= 0
                         && model.object.updatingProgress <= 100
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Component {
            id: uninstallButtonComponent

            UninstallButton {
                property bool isAndroidApp

                anchors.verticalCenter: launcherIcon.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: launcherEditMode && uninstallPolicy.value
                opacity: enabled ? 1.0 : 0.0
                visible: launcherEditMode
                            && !isFolder
                            && AppControl.isUninstallable(object.filePath)
                            && !object.isUpdating
                            && (!isAndroidApp || appsupportPolicy.value)
                onClicked: launcher.removeApplication(object.filePath, object.title)
            }
        }
    }
}

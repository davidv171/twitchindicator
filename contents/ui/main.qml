import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQuick.Window 2.1
import QtGraphicalEffects 1.0

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: root

    Plasmoid.switchWidth: units.gridUnit * 10
    Plasmoid.switchHeight: units.gridUnit * 5

    function log(message, values) {
        console.log(message);
        console.log(JSON.stringify(values));
    }

    function requestUrl(method, url, options, cb) {
        let xhr = new XMLHttpRequest();
		xhr.open(method, url, true);
		xhr.onload = function (e) {
            console.log(xhr.status);
            console.log(xhr.responseText);
		    if (xhr.status == 200) {
				let body = xhr.response;
				cb(body);
			}
			else {
				log("Failed to execure the request: status code is not 200", {method: method, url: url, options: options, request: xhr});
			}
		}
		xhr.onerror = function(e) {
			log("Error executing the request: network error", {method: method, url: url, options: options});
		}
		if (options.responseType) xhr.responseType = options.responseType;
		if (options.headers) {
		    let headers = Object.keys(options.headers);
		    for (let i = 0; i < headers.length; i++) {
                xhr.setRequestHeader(headers[i], options.headers[headers[i]]);
            }
		}
		xhr.send(options.postData ? options.postData : undefined);
    }

    ListModel {
        id: streamsModel
        property var followedChannels: {}
        
        function updateChannelsData() {
            streamsModel.followedChannels = {};
            let user = "komorebithrowsatable";
            requestUrl("GET", "https://api.twitch.tv/helix/users?login="+user, {
                responseType: "json", 
                headers: {"Client-ID": "yoilemo3cudfjaqm6ukbew2g2mgm2v"}
            }, function(res) {
                let userId = res.data[0].id;
                requestUrl("GET", "https://api.twitch.tv/helix/users/follows?from_id="+userId, {
                    responseType: "json",
                    headers: {"Client-ID": "yoilemo3cudfjaqm6ukbew2g2mgm2v"}
                }, function(res) {
                    let query = [];
                    for (let followed of res.data) {
                        query.push("id="+followed.to_id);
                    }
                    requestUrl("GET", "https://api.twitch.tv/helix/users?"+query.join("&"), {
                        responseType: "json",
                        headers: {"Client-ID": "yoilemo3cudfjaqm6ukbew2g2mgm2v"},
                    }, function(res) {
                        for (let channel of res.data) streamsModel.followedChannels[channel.id] = channel;
                        streamsModel.updateStreams();
                    });
                });
            });
        }

        function updateStreams() {
            let query = [];
            for (let channelId in streamsModel.followedChannels) query.push("user_id="+channelId);
            requestUrl("GET", "https://api.twitch.tv/helix/streams?"+query.join("&"), {
                responseType: "json",
                headers: {"Client-ID": "yoilemo3cudfjaqm6ukbew2g2mgm2v"},
            }, function(res) {
                streamsModel.clear();
                for (let stream of res.data) {
                    streamsModel.append(stream);
                }
            })
        }
    }
    
    
    Plasmoid.compactRepresentation: MouseArea {
        anchors.fill: parent
        Layout.maximumWidth: isVertical ? Infinity : Layout.minimumWidth
        Layout.preferredWidth: isVertical ? undefined : Layout.minimumWidth

        Layout.minimumHeight: isVertical ? label.height : theme.smallestFont.pixelSize
        Layout.maximumHeight: isVertical ? Layout.minimumHeight : Infinity
        Layout.preferredHeight: isVertical ? Layout.minimumHeight : theme.mSize(theme.defaultFont).height * 2
        onClicked: plasmoid.expanded = !plasmoid.expanded;
        
        Image {
            id: mainIcon
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: height
            source: "twitch.png"
        }

        PlasmaComponents.Label {
            id: mainCounter
            anchors.left: mainIcon.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            text: steamsModel.count
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.NoWrap
            fontSizeMode: Text.VerticalFit
            minimumPointSize: theme.smallestFont.pointSize
        }
    }

    Plasmoid.preferredRepresentation: Plasmoid.compactRepresentation
    
    Plasmoid.fullRepresentation: Item {
        Layout.preferredWidth: units.gridUnit * 25
        Layout.preferredHeight: Screen.height * 0.5

        Component {
                id: streamDelegate
                PlasmaComponents.ListItem {
                    id: streamItem
                    height: units.gridUnit * 2.8
                    width: parent.width
                    enabled: true
                    onContainsMouseChanged: {
                        steamsList.currentIndex = (containsMouse) ? index : -1;
                    }
                    onClicked: {
                        Qt.openUrlExternally("https://www.twitch.tv/"+streamsModel.followedChannels[model.user_id].login)
                    }
            
                    Image {
                        id: channelIcon
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: height
                        source: streamsModel.followedChannels[model.user_id].profile_image_url
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: roundedMask
                        }
                    }

                    Rectangle {
                        id: roundedMask
                        anchors.fill: channelIcon
                        radius: 90
                        visible: false
                    }

                    PlasmaComponents.Label {
                        id: channelName
                        anchors.left: channelIcon.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: units.largeSpacing
                        height: parent.height/2
                        text: model.user_name
                        elide: Text.ElideRight
                    }

                    PlasmaComponents.Label {
                        id: streamName
                        anchors.top: channelName.bottom
                        anchors.left: channelIcon.right
                        anchors.leftMargin: units.largeSpacing
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        text: model.title
                        elide: Text.ElideRight
                        opacity: 0.6
                    }
                }
            }

        PlasmaExtras.ScrollArea {
            anchors.fill: parent

            ListView {
                id: steamsList
                currentIndex: -1
                delegate: streamDelegate
                model: streamsModel
                anchors.fill: parent
                highlight: PlasmaComponents.Highlight { }
            }
        }
        
    }

    Component.onCompleted: {
        streamsModel.updateChannelsData();
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
ShellRoot {
  QtObject {
    id: player
    property string trackTitle: "Long title ".repeat(50)
    property string trackArtist: "Artist"
    property string trackAlbum: ""
    property string trackArtUrl: ""
    property bool isPlaying: false
    property bool canTogglePlaying: true
    property bool canGoPrevious: false
    property bool canGoNext: false
    property real length: 0
    property real position: 0
  }
  QtObject {
    id: svc
    property var activePlayer: player
    property var sourcePlayers: []
    function runAction(action, flag) {}
  }
  QtObject { id: shellApi; function firstPartyServiceFor(id) { return svc } }
  QtObject {
    id: fakeBar
    property var shell: shellApi
    property bool vertical: false
    property var layoutConfig: ({left:["test.media"], center:["omarchy.clock"], right:[]})
    property int barSize: 26
    property color foreground: "white"
    property color barForeground: "white"
    property string fontFamily: "monospace"
    property bool foregroundAnimationEnabled: false
    property string position: "top"
    property var activePopout: null
    function requestPopout(owner) {}
    function releasePopout(owner) {}
    function showTooltip(owner,text) {}
    function hideTooltip(owner) {}
  }
  PanelWindow {
    id: window
    visible: true
    implicitWidth: 1000
    implicitHeight: 1
    color: "transparent"
    exclusiveZone: 0
    mask: Region {}
    WlrLayershell.namespace: "media-width-test"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Background
    Item {
      x: 8
      property string moduleName: "test.media"
      property string region: "left"
      property var activeItem: media
      width: media.implicitWidth
      height: 26
      NativeMedia { id: media; bar: fakeBar; opacity: 0 }
    }
    Item {
      id: anchor
      x: (window.width - width) / 2
      width: 100
      height: 26
      property string moduleName: "omarchy.clock"
      property string region: "center"
      property var activeItem: clock
      Item { id: clock; implicitWidth: 100; implicitHeight: 26 }
    }
  }
  function findLabel(node) {
    if ("needsScroll" in node) return node
    for (var i=0;i<node.children.length;i++) {
      var found=findLabel(node.children[i])
      if(found) return found
    }
    return null
  }
  IpcHandler {
    target: "width-test"
    function metadata(title: string, artist: string): void { player.trackTitle=title;player.trackArtist=artist }
    function fill(enabled: bool): void { media.settings=({fillAvailable:enabled}) }
    function resize(width: int): void { window.implicitWidth=width }
    function snapshot(): string {
      var label=findLabel(media)
      return JSON.stringify({width:media.implicitWidth, windowWidth:window.width, title:player.trackTitle,
        labelX:label.x, clipWidth:label.parent.width, clipVisible:label.parent.visible,
        needsScroll:label.needsScroll, widgetVisible:media.visible})
    }
  }
}

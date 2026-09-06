pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property string selectedName: ""
    readonly property var players: Mpris.players.values
    readonly property var player: root.choosePlayer(root.players, root.selectedName)

    // Retain an explicit choice. Otherwise prefer whichever app is playing.
    readonly property var choosePlayer: function (players, name) {
        return players.find(p => p.dbusName === name)
            || players.find(p => p.isPlaying) || players[0] || null;
    }

    readonly property var selectNext: function () {
        if (root.players.length === 0) return;
        const index = root.players.indexOf(root.player);
        root.selectedName = root.players[(index + 1) % root.players.length].dbusName;
    }
}

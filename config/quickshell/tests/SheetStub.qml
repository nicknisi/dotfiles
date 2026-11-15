import QtQuick
import qs.Panels.Sheets

// A stand-in sheet for tst_sheet_nav.qml: the real frame with fixed rows, a
// nested page (like the Tailscale sheet's exit nodes) and a passphrase row
// (like the Wi-Fi sheet's), recording what it is asked to do.
SheetFrame {
    id: stub

    property string page: ""
    property var log: []

    title: page === "" ? "Stub" : "Nested"
    sheetData: ({
            status: "On",
            switchOn: true,
            hasSwitch: true,
            footer: "Stub settings",
            groups: [
                { label: "Connected", rows: [{ key: "home", title: "home-5g", sub: "Secured", icon: "wifi", on: true, action: "disconnect", forget: true }] },
                { label: "Other networks", rows: [
                        { key: "cafe", title: "Cafe", sub: "Secured", icon: "wifi2", dim: true, action: "passphrase" },
                        { key: "nested", title: "Nested page", sub: "Opens a page", icon: "exit", trail: "›", action: "nested" },
                        { key: "note", title: "Nothing here", dim: true, inert: true }
                    ] }
            ]
        })
    backHandler: function () {
        if (stub.page === "") return false;
        stub.page = "";
        return true;
    }

    onActivated: row => {
        stub.log = stub.log.concat(["activate " + row.key]);
        if (row.action === "passphrase") stub.expandedKey = row.key;
        else if (row.action === "nested") stub.page = "nested";
    }
    onSubmitted: (row, text) => stub.log = stub.log.concat(["submit " + row.key + " " + text])
    onForgot: row => stub.log = stub.log.concat(["forget " + row.key])
    onFooterClicked: stub.log = stub.log.concat(["footer"])
    onSwitchToggled: on => stub.log = stub.log.concat(["switch " + on])
}

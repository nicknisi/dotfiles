import QtQuick
import qs.Panels.Sheets

// A stand-in sheet for tst_sheet_nav.qml's steps: a slider row naming its
// key step (the night light's warmth), a stepper row (its From), a plain
// slider row (Sound's, which the arrows leave alone) and an inert stepper.
SheetFrame {
    id: stub

    property var log: []

    title: "Steps"
    sheetData: ({
            status: "On",
            switchOn: true,
            hasSwitch: true,
            footer: "",
            groups: [
                { label: "Warmth", rows: [{ key: "warmth", title: "Warmth", icon: "thermometer", slider: 0.5, step: 0.1, trail: "4250 K" }] },
                { label: "Schedule", rows: [
                        { key: "from", title: "From", icon: "sunset", trail: "20:00", stepper: true },
                        { key: "plain", title: "Plain", icon: "vol", slider: 0.3, trail: "30" },
                        { key: "dead", title: "Dead", icon: "sunrise", trail: "07:00", stepper: true, inert: true }
                    ] }
            ]
        })

    onSlid: (row, value) => stub.log = stub.log.concat(["slid " + row.key + " " + value.toFixed(2)])
    onStepped: (row, delta) => stub.log = stub.log.concat(["step " + row.key + " " + delta])
    onActivated: row => stub.log = stub.log.concat(["activate " + row.key])
}

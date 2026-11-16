import QtQuick

// FixtureAuthFlow.qml - a stand-in for Quickshell.Services.Polkit's AuthFlow
// (PLAN M8): the same properties, methods and signals, with no polkit behind
// it. tst_polkit, tests/check.qml and the sandbox's `polkit` fixture
// (ShellServices, SHELL_SANDBOX=1 only) drive Island/PolkitLayer.qml with it;
// the real agent is never built in a sandbox or a test.
//
// submit(value) succeeds when value equals `accept` (never when `accept` is
// empty), otherwise fails the way polkit-agent-1 does: `failed`, a
// supplementary error and authenticationFailed, then asks again. It keeps
// how many answers came and whether the last matched, never the answer.
//
// QtQuick only (qmltestrunner loads it).
QtObject {
    id: flow

    property string message: "Authentication is needed to run /usr/bin/pacman as the super user."
    property string iconName: ""
    property string actionId: "org.freedesktop.policykit.exec"
    property string cookie: "fixture"
    property var identities: []
    property var selectedIdentity: null
    property bool isResponseRequired: true
    property string inputPrompt: "Password: "
    property bool responseVisible: false
    property string supplementaryMessage: ""
    property bool supplementaryIsError: false
    property bool isCompleted: false
    property bool isSuccessful: false
    property bool isCancelled: false
    property bool failed: false

    // Test knobs.
    property string accept: ""
    property int submits: 0
    property bool lastMatched: false
    property int cancels: 0

    signal authenticationSucceeded
    signal authenticationFailed
    signal authenticationRequestCancelled

    function submit(value) {
        if (flow.isCompleted || !flow.isResponseRequired) return;
        flow.submits++;
        flow.lastMatched = flow.accept !== "" && String(value) === flow.accept;
        if (flow.lastMatched) {
            flow.isResponseRequired = false;
            flow.isSuccessful = true;
            flow.isCompleted = true;
            flow.authenticationSucceeded();
            return;
        }
        flow.failed = true;
        flow.supplementaryMessage = "Sorry, that didn't work. Please try again.";
        flow.supplementaryIsError = true;
        flow.authenticationFailed();
    }

    function cancelAuthenticationRequest() {
        if (flow.isCompleted) return;
        flow.cancels++;
        flow.isResponseRequired = false;
        flow.isCancelled = true;
        flow.isCompleted = true;
        flow.authenticationRequestCancelled();
    }
}

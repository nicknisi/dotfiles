import QtQuick
import Quickshell
import qs
import qs.Kit
import qs.Ui as Ui
import "../ui"
import "../voice"

// ConversationView.qml - Codex inside the launcher (launcher-pickers 5.2,
// Launcher board), restyled to the tokens in M5.
//
//   [sparkle] Codex  [branch dotfiles · main]                       [Esc]
//   ───────────────────────────────────────────────────────────────────
//                                         ┌ user bubble, fillHigh ┐
//   assistant answer, sans 13/20 fg
//   ...
//   status line                     [Stop] [Copy answer] [New question] [Continue in Codex ↗]
//   ┌ Ask a follow-up ...                                    [Mic] [↵] ┐  composer 46..115
//
// The host is the launcher engine (Keystroke.qml); a stand-in with the same
// colour, font and voice members works too (tests/integrations_view.py).
// The repo chip is the focused window's repository and branch (Context, via
// the host's repoName and repoBranch), hidden when there is none.
Item {
  id: root
  property var host: null
  property var session: null
  property string voicePrefix: ""
  property string localStatus: ""
  property var answers: ({})
  readonly property color foreground: host ? host.foreground : Tokens.fg
  readonly property color muted: host ? host.muted : Tokens.inkDim
  readonly property color accent: host ? host.accent : Tokens.accent
  readonly property string fontFamily: host && host.fontFamily ? host.fontFamily : "Adwaita Sans"
  readonly property string monoFamily: host && host.monoFamily ? host.monoFamily : "Monaspace Argon"
  readonly property string repoName: host && host.repoName ? String(host.repoName) : ""
  readonly property string repoBranch: host && host.repoBranch ? String(host.repoBranch) : ""
  readonly property var approval: session && session.approvals.length ? session.approvals[0] : null
  function focusInput() { composer.forceActiveFocus(); composer.cursorPosition = composer.text.length }
  function beginVoice() { voicePrefix = session.draft ? session.draft.replace(/\s*$/, " ") : "" }
  function transcript(text, final) { session.draft = voicePrefix + text; composer.cursorPosition = composer.text.length }
  function dismiss() { session.dismiss() }
  function markdown(text) { return String(text).replace(/</g, "&lt;").replace(/!\[([^\]]*)\]\(([^)]*)\)/g, "[$1]($2)") }
  function syncMessages() {
    if (!session) return
    var rows = session.messages
    var follow = history.atYEnd || !history.count
    // Keep delegates stable while tokens stream, including selections and scroll.
    while (display.count > rows.length) display.remove(display.count - 1)
    for (var i = 0; i < rows.length; i++) {
      if (i >= display.count) display.append(rows[i])
      else if (display.get(i).id !== rows[i].id) display.set(i, rows[i])
      else if (display.get(i).text !== rows[i].text) display.setProperty(i, "text", rows[i].text)
    }
    if (follow) Qt.callLater(() => history.positionViewAtEnd())
  }
  onSessionChanged: syncMessages()
  Component.onCompleted: Qt.callLater(focusInput)
  Connections {
    target: root.session
    function onMessagesChanged() { root.syncMessages() }
    function onDraftChanged() { if (composer.text !== root.session.draft) composer.text = root.session.draft }
    function onApprovalsChanged() { root.answers = ({}); if (root.approval) decline.forceActiveFocus(); else root.focusInput() }
  }
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) { host.cancel(); event.accepted = true }
  }

  // A quiet pill button: fillLow, a hairline ring (accent while focused).
  component ActionButton: Ui.Button {
    id: control
    property alias label: control.text
    property bool available: true
    signal triggered()
    focusable: true
    enabled: available
    opacity: enabled ? 1 : 0.4
    foreground: root.foreground
    accent: root.accent
    fontFamily: root.fontFamily
    fontSize: 12
    padding: 0
    horizontalPadding: 12
    implicitHeight: 28
    width: implicitWidth; height: implicitHeight
    background: Rectangle {
      radius: height / 2
      color: control.down || control.hovered ? Tokens.fillHigh : Tokens.fillLow
      border.width: 1
      border.color: control.activeFocus ? root.accent : Tokens.hairline
    }
    onClicked: triggered()
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) triggered(); event.accepted = true }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) triggered(); event.accepted = true }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) triggered(); event.accepted = true }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) triggered()
  }

  // ---- header (56) ------------------------------------------------------------
  Item {
    id: top
    enabled: !root.approval
    width: parent.width
    height: 56
    Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Tokens.hairline }
    Row {
      x: 20
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      ActionButton {
        id: back
        objectName: "conversationBack"
        anchors.verticalCenter: parent.verticalCenter
        label: "←"
        horizontalPadding: 8
        tooltipText: "Back to results"
        onTriggered: host.goBack()
      }
      Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "sparkle"
        size: 16
        color: root.accent
        // A stepped breath while a turn runs (2.7), never a smooth loop.
        opacity: root.session && root.session.busy && Motion.loops ? (breath.on ? 1 : 0.55) : 1
        Timer {
          id: breath
          property bool on: true
          interval: 600
          repeat: true
          running: !!root.session && root.session.busy && Motion.loops && root.visible
          onTriggered: on = !on
          onRunningChanged: on = true
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Codex"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
      }
      Rectangle {
        visible: root.repoName !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: repoRow.implicitWidth + 16
        height: 22
        radius: 11
        color: Tokens.fillLow
        Row {
          id: repoRow
          anchors.centerIn: parent
          spacing: 5
          Icon { anchors.verticalCenter: parent.verticalCenter; name: "branch"; size: 14; color: root.muted }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.repoName + (root.repoBranch ? " · " + root.repoBranch : "")
            textFormat: Text.PlainText
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: 11
          }
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, top.width - x - 20 - escKey.width - 12 - 20)
        text: !root.session ? "" : root.session.mode === "agent" ? root.session.cwd
          : (root.session.settings.model || "Codex default") + (root.session.settings.fast === false ? " · Standard" : " · Fast")
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: 11
      }
    }
    Keycap { id: escKey; anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: "Esc" }
  }

  // ---- messages ------------------------------------------------------------------
  ListModel { id: display }
  ListView {
    id: history
    enabled: !root.approval
    x: 18; y: top.height + 14
    width: parent.width - 36; height: Math.max(0, actions.y - y - 10)
    clip: true; spacing: 12; model: display
    boundsBehavior: Flickable.StopAtBounds
    delegate: Item {
      id: message
      required property string id
      required property string role
      required property string text
      readonly property bool mine: role === "user"
      width: history.width
      height: body.height + (mine ? 16 : 0) + (role === "activity" ? label.height + 4 : 0)
      Text {
        id: label
        visible: message.role === "activity"
        text: "Activity"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: 11
      }
      Rectangle {
        visible: message.mine
        anchors.right: parent.right
        width: Math.min(body.implicitWidth, history.width * 0.7 - 24) + 24
        height: body.height + 16
        radius: 14
        color: Tokens.fillHigh
      }
      TextEdit {
        id: body
        readonly property real room: message.mine ? history.width * 0.7 - 24 : history.width * 0.92
        x: message.mine ? message.width - width - 12 : 0
        y: message.mine ? 8 : message.role === "activity" ? label.height + 4 : 0
        width: Math.min(implicitWidth, room)
        height: contentHeight
        text: message.mine ? message.text : root.markdown(message.text)
        textFormat: message.mine ? TextEdit.PlainText : TextEdit.MarkdownText
        wrapMode: TextEdit.Wrap
        readOnly: true; selectByMouse: true
        color: message.role === "activity" ? root.muted : root.foreground
        selectionColor: Tokens.accentA35
        selectedTextColor: Tokens.fg
        font.family: message.role === "activity" ? root.monoFamily : root.fontFamily
        font.pixelSize: message.role === "activity" ? 11 : 13
        onLinkActivated: function(link) { if (/^https?:\/\//.test(link)) Qt.openUrlExternally(link) }
      }
    }
    Column {
      visible: !history.count
      anchors.centerIn: parent
      width: parent.width
      spacing: 10
      Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "sparkle"; size: 32; color: root.accent }
      Text {
        width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
        text: root.session && root.session.busy ? "Connecting to Codex…" : "Ask a question. Keep the conversation here.\nType or use your voice hotkey."
        color: root.muted; font.family: root.fontFamily; font.pixelSize: 13
      }
    }
  }

  // ---- status and actions --------------------------------------------------------
  Item {
    id: actions
    enabled: !root.approval
    x: 18; width: parent.width - 36; height: 28
    y: inputBox.y - height - 10
    Text {
      id: status
      anchors.left: parent.left
      anchors.right: buttons.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: host && host.voice.active ? (host.voice.phase === "transcribing" ? "Finishing transcript…" : "Listening…") : root.session ? (root.session.error || root.localStatus || root.session.activity) : ""
      color: root.session && root.session.error ? Tokens.bad : root.muted
      elide: Text.ElideRight
      font.family: root.fontFamily; font.pixelSize: 11
    }
    Row {
      id: buttons
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      ActionButton { label: "Stop"; visible: root.session && root.session.busy; onTriggered: session.stop() }
      ActionButton { label: "Copy answer"; available: session.answer().length > 0; onTriggered: answerCopy.submit(session.answer(), false) }
      ActionButton { label: "New question"; available: !session.busy; onTriggered: { session.newQuestion(""); root.focusInput() } }
      ActionButton { id: external; label: session.busy ? "Stop & continue ↗" : "Continue in Codex ↗"; available: !!session.threadId; onTriggered: session.requestHandoff() }
    }
  }

  // ---- composer (46, grows to 115) ----------------------------------------------
  Rectangle {
    id: inputBox
    enabled: !root.approval
    x: 10; width: parent.width - 20
    height: Math.min(115, Math.max(46, composer.contentHeight + 26))
    y: parent.height - height - 10
    radius: 14
    color: Tokens.fillLow
    border.width: 1
    border.color: Tokens.hairline
    Flickable {
      id: editorScroll
      x: 12; y: 13; width: parent.width - 24 - trail.width - 10; height: parent.height - 26
      clip: true; contentWidth: width; contentHeight: Math.max(height, composer.contentHeight)
      boundsBehavior: Flickable.StopAtBounds
      function revealCursor() {
        var y = composer.cursorRectangle.y, h = composer.cursorRectangle.height
        if (y < contentY) contentY = y
        else if (y + h > contentY + height) contentY = y + h - height
      }
      TextEdit {
        id: composer
        objectName: "composer"
        width: editorScroll.width; height: Math.max(editorScroll.height, contentHeight)
        text: session.draft; wrapMode: TextEdit.Wrap; clip: true; selectByMouse: true
        onCursorRectangleChanged: editorScroll.revealCursor()
        color: root.foreground
        selectionColor: Tokens.accentA35
        selectedTextColor: Tokens.fg
        font.family: root.fontFamily; font.pixelSize: 13
        cursorDelegate: Rectangle { width: 2; color: root.accent; visible: composer.activeFocus }
        onTextChanged: if (activeFocus && text !== session.draft) session.draft = text
        Keys.priority: Keys.BeforeItem
        Keys.onReleased: function(event) { if (host.voice.active && host.voiceTrigger === "hold" && host.isSuperKey(event.key)) { host.voiceStop(); event.accepted = true } }
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) { host.cancel(); event.accepted = true; return }
          if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.isAutoRepeat) { event.accepted = true; return }
          if (host.voice.active) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { host.voiceStop(); event.accepted = true; return }
            if (host.isModifierKey(event.key)) return
            host.voiceCancel()
          }
          if ((event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) && !text && !preeditText && event.modifiers === Qt.NoModifier) {
            host.goBack(); event.accepted = true; return
          }
          if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
            if (event.modifiers & Qt.ControlModifier) session.requestHandoff(); else session.submit()
            event.accepted = true
          }
        }
        Text { anchors.fill: parent; visible: !composer.text; text: session.messages.length ? "Ask a follow-up" : "Ask anything…"; color: root.muted; font: composer.font }
      }
    }
    Row {
      id: trail
      anchors.right: parent.right; anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      VoiceWave {
        anchors.verticalCenter: parent.verticalCenter
        width: 48; height: 28
        visible: host && host.voice.active
        mode: host ? host.voice.phase : "idle"; level: host ? host.voice.level : 0; history: host ? host.voice.history : []
        accent: root.accent; foreground: root.foreground
      }
      ActionButton { anchors.verticalCenter: parent.verticalCenter; visible: host && !host.voice.active; label: "Mic"; onTriggered: { root.focusInput(); host.voiceBegin("tap") } }
      Keycap { anchors.verticalCenter: parent.verticalCenter; text: "↵"; ink: session.draft.trim().length > 0 ? Tokens.fg : root.muted }
    }
  }
  ClipboardTransfer { id: answerCopy; onCopied: root.localStatus = "Answer copied"; onFailed: message => root.localStatus = message }

  // ---- approval ------------------------------------------------------------------
  Rectangle {
    anchors.fill: parent; visible: !!root.approval; color: Tokens.surface; z: 10
    MouseArea { anchors.fill: parent }
    Flickable {
      anchors.fill: parent; anchors.margins: 22; clip: true
      contentHeight: approvalContent.height
      Column {
        id: approvalContent
        width: parent.width; spacing: 14
        Row {
          spacing: 10
          Icon { anchors.verticalCenter: parent.verticalCenter; name: "sparkle"; size: 16; color: root.accent }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Codex needs your input"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 15; font.weight: Font.Medium }
        }
        TextEdit { width: parent.width; height: contentHeight; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 13;
          text: session.approvalDetail(root.approval) }
        Repeater {
          model: root.approval ? root.approval.params.questions || [] : []
          Column {
            required property var modelData
            width: parent.width; spacing: 8
            Text { width: parent.width; wrapMode: Text.Wrap; text: modelData.question + ((modelData.options || []).length ? "\n" + modelData.options.map(x => x.label).join(" · ") : ""); color: root.foreground; font.family: root.fontFamily; font.pixelSize: 13 }
            Ui.TextField {
              width: parent.width; foreground: root.foreground; accent: root.accent
              font.family: root.fontFamily; font.pixelSize: 13
              onTextEdited: { var a = Object.assign({}, root.answers); a[modelData.id] = text; root.answers = a }
            }
          }
        }
        Row { spacing: 8
          ActionButton { label: root.approval && root.approval.params.questions ? "Answer" : "Allow once"; onTriggered: session.decide(true, root.answers) }
          ActionButton { id: decline; label: "Decline"; onTriggered: session.decide(false) }
          ActionButton { label: "Stop & continue in Codex"; onTriggered: session.requestHandoff() }
        }
      }
    }
  }
}

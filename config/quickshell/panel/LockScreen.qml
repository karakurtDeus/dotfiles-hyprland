//@ pragma Env QS_DISABLE_FILE_WATCHER = 1
//@ pragma Env QS_NO_RELOAD_POPUP = 1
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import "theme"

ShellRoot {
    id: root

    readonly property string userName: Quickshell.env("USER") || Quickshell.env("HOME").split("/").pop()
    readonly property string monoFont: "JetBrainsMono Nerd Font Mono"
    readonly property int avatarDiameter: Math.max(40, Math.min(222, Number(Quickshell.env("QS_LOCK_AVATAR_SIZE")) || 222))
    readonly property bool busy: pam.active
    property string statusText: ""
    property string pendingPassword: ""
    property bool passwordSent: false

    function authenticate(secret: string): void {
        if (!lock.secure || busy || !secret.length)
            return

        statusText = ""
        pendingPassword = secret
        passwordSent = false
        if (!pam.start()) {
            pendingPassword = ""
            statusText = "Authentication unavailable"
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PamContext {
        id: pam
        config: "system-auth"

        onPamMessage: {
            if (!responseRequired)
                return
            if (responseVisible || root.passwordSent) {
                root.pendingPassword = ""
                root.statusText = "Authentication unavailable"
                abort()
                return
            }

            const secret = root.pendingPassword
            root.pendingPassword = ""
            root.passwordSent = true
            respond(secret)
        }

        onCompleted: result => {
            root.pendingPassword = ""
            const passwordSent = root.passwordSent
            root.passwordSent = false
            if (result === PamResult.Success && passwordSent && lock.secure) {
                lock.locked = false
                Qt.callLater(() => Qt.quit())
                return
            }

            root.statusText = result === PamResult.Failed ? "Incorrect password"
                : result === PamResult.MaxTries ? "Too many attempts. Try again later."
                : "Authentication unavailable"
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: Colors.clear

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.panel, 0.64)

                Column {
                    id: content

                    anchors.centerIn: parent
                    width: 540
                    spacing: 13
                    scale: Math.max(0.1, Math.min(1, (parent.width - 32) / width,
                        (parent.height - 32) / implicitHeight))

                    Column {
                        width: parent.width
                        spacing: 0

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatDateTime(clock.date, "hh:mm AP")
                            color: Colors.barText
                            font.family: root.monoFont
                            font.pixelSize: 74
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: clock.date.toLocaleString(Qt.locale("en_US"), "dddd, MMMM d, yyyy")
                            color: Colors.mutedText
                            font.family: root.monoFont
                            font.pixelSize: 19
                        }
                    }

                    ProfileAvatar {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.avatarDiameter
                        height: width
                        userName: root.userName
                        textFontFamily: root.monoFont
                        playbackActive: true
                    }

                    Rectangle {
                        id: passwordBar

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320
                        height: 49
                        radius: height / 2
                        color: Colors.control
                        border.width: 1
                        border.color: root.statusText.length ? Colors.error : Colors.accent

                        function submit(): void {
                            if (root.busy || !lock.secure || !input.text.length)
                                return
                            const secret = input.text
                            input.clear()
                            root.authenticate(secret)
                        }

                        TextInput {
                            id: input

                            anchors.left: parent.left
                            anchors.right: submitButton.left
                            anchors.leftMargin: 17
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            focus: true
                            clip: true
                            readOnly: root.busy || !lock.secure
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData
                                | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            font.family: root.monoFont
                            font.pixelSize: 17
                            color: Colors.text
                            selectionColor: Colors.selection

                            onAccepted: passwordBar.submit()
                            Keys.onEscapePressed: clear()
                            Component.onCompleted: forceActiveFocus()

                            Text {
                                anchors.fill: parent
                                visible: input.text.length === 0
                                text: root.busy ? "Unlocking…" : "Password"
                                color: Colors.mutedText
                                font: input.font
                            }
                        }

                        Rectangle {
                            id: submitButton

                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: width
                            radius: width / 2
                            color: input.text.length && !root.busy ? Colors.accent : Colors.group
                            Accessible.role: Accessible.Button
                            Accessible.name: "Unlock"

                            Text {
                                anchors.centerIn: parent
                                text: "→"
                                color: input.text.length && !root.busy ? Colors.panel : Colors.mutedText
                                font.pixelSize: 20
                            }

                            TapHandler { onTapped: passwordBar.submit() }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.statusText
                        color: Colors.error
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}

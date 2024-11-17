InstallKeyboardAndMouseHooks() {
    InstallKeybdHook()
    InstallMouseHook()
}

/*
Hotkeys configured within the script:

CTRL + O         : Start the script (make it active)
CTRL + L         : Send Enter key repeatedly when Ctrl+L is pressed
Esc              : Stop the script (make it inactive)
CTRL + Alt + Esc : Exit the script
*/

gameWindowTitle := "ahk_exe Game.exe"
holdTime := 1000 ; Time to hold the Enter key (in milliseconds)
waitTime := 10 ; Time to wait before sending the Enter key again (in milliseconds)

; Global variable to track the script state
global scriptActive := true

; CTRL+O to start the script (make it active)
^O::
{
    scriptActive := true
}

; Hotkey to send Enter key repeatedly when Ctrl+L is pressed
; Define hotkey Ctrl+L
^L::
{
    Loop 
    {
        ; If the script is active and the game window exists, send the Enter key repeatedly
        if scriptActive && WinExist(gameWindowTitle) 
        {
            ; Break the loop if the script is no longer active
            if (!scriptActive)
            {
                break
            }

            ; Used to get past dialogue box in Dungeon Dreams 2 on slot machine
            ControlSend("{Enter}",, gameWindowTitle)

            ; This is a workaround to re-enable the hooks
            InstallKeyboardAndMouseHooks()

            ; Used to get past dialogue box in Dungeon Dreams 2 on slot machine
            ControlSend("{Enter}",, gameWindowTitle)

            ; Send and hold the Enter key for holdTime milliseconds
            ControlSend("{Enter Down}",, gameWindowTitle)
            Sleep holdTime
            
            ; Break the loop if the script is no longer active
            if (!scriptActive)
            {
                break
            }

            ; Release the Enter key after holdTime milliseconds
            ControlSend("{Enter Up}",, gameWindowTitle)

            ; Wait for waitTime milliseconds before looping again
            Sleep waitTime

            ; Break the loop if the script is no longer active
            if (!scriptActive)
            {
                break
            }

            ; Used to get past dialogue box in Dungeon Dreams 2 on slot machine
            ControlSend("{Enter}",, gameWindowTitle)

            ; Break the loop if the script is no longer active
            if (!scriptActive)
            {
                break
            }
        }
    }
}

; Pressing Esc key will pause the script (make it inactive)
Esc::
{
    scriptActive := false
}

; Pressing CTRL+ALT+Esc will exit the script
^!Esc::ExitApp
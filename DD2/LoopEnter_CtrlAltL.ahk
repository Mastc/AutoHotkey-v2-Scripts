InstallKeyboardAndMouseHooks() {
    InstallKeybdHook()
    InstallMouseHook()
}

; Is used to get the control list of the game window that the cursor is hovering over
WatchActiveWindow()
{
    try
    {
        Controls := WinGetControls("A")
        ControlList := ""
        for ClassNN in Controls
            ControlList .= ClassNN . "`n"
        if (ControlList = "")
            ToolTip "The active window has no controls."
        else
            ToolTip ControlList
    }
    catch TargetError
        ToolTip "No visible window is active."
}

/*
Hotkeys configured within the script:

CTRL + G         : Get the control list of the game window the cursor is hovering over
CTRL + O         : Start the script (make it active)
CTRL + L         : Send Enter key repeatedly when Ctrl+L is pressed
Esc              : Stop the script (make it inactive)
CTRL + Alt + Esc : Exit the script
*/

gameWindowTitle := "ahk_exe Game.exe"
holdTime := 1000 ; Time to hold the Enter key (in milliseconds)
waitTime := 10 ; Time to wait before sending the Enter key again (in milliseconds)

; Function to get/set script active state
GetScriptActive() {
    global scriptActive
    return scriptActive
}

SetScriptActive(value) {
    global scriptActive
    scriptActive := value
}

; Global variable to track the script state
global scriptActive := true

; CTRL+O to start the script (make it active)
^O::
{
    SetScriptActive(true)
}

; Hotkey to get the control list of the game window
^G::
{
    SetTimer WatchActiveWindow, 200
}

; Hotkey to send Enter key repeatedly when Ctrl+L is pressed
; Define hotkey Ctrl+L
^L::
{
    ; Store the currently active window's handle for later restoration
    previousWindow := WinExist("A")

    Loop 
    {
        try {
            ; Explicitly check global variable
            isActive := GetScriptActive()
            
            ; If the script is active and the game window exists, send the Enter key repeatedly
            if isActive && WinExist(gameWindowTitle) 
            {
                ; Break the loop if the script is no longer active
                if (!GetScriptActive())
                {
                    ; Restore previous window if script stops
                    WinActivate "ahk_id " previousWindow
                    break
                }

                ; Store game window handle
                gameHwnd := WinExist(gameWindowTitle)

                ; Activate game window
                WinActivate "ahk_id " gameHwnd
                
                ; Small delay to ensure window activation
                Sleep 50

                ; Send Enter key inputs now that window is active
                Send "{Enter}"
                Send "{Enter}"

                ; Send and hold the Enter key for holdTime milliseconds
                Send "{Enter Down}"
                Sleep holdTime
                
                ; Break the loop if the script is no longer active
                if (!GetScriptActive())
                {
                    WinActivate "ahk_id " previousWindow
                    break
                }

                ; Release the Enter key after holdTime milliseconds
                Send "{Enter Up}"

                ; Wait for waitTime milliseconds before looping again
                Sleep waitTime

                ; Break the loop if the script is no longer active
                if (!GetScriptActive())
                {
                    WinActivate "ahk_id " previousWindow
                    break
                }

                ; Send final Enter key
                Send "{Enter}"

                ; Switch back to previous window
                WinActivate "ahk_id " previousWindow

                ; Small delay before next iteration
                Sleep 50

                ; Break the loop if the script is no longer active
                if (!GetScriptActive())
                {
                    break
                }
            } else {
                ; If script is not active or window doesn't exist, break the loop
                WinActivate "ahk_id " previousWindow
                break
            }
        }
        catch as e ; Catch any errors and display an error message
        {
            MsgBox "Error: " e.Message
            ; Ensure we restore the previous window if an error occurs
            WinActivate "ahk_id " previousWindow
            break
        }
    }
}

; Pressing Esc key will pause the script (make it inactive)
Esc::
{
    SetScriptActive(false)
}

; Pressing CTRL+ALT+Esc will exit the script
^!Esc::ExitApp
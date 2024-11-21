; This script is a clipboard manager that allows you to copy multiple items, saving them to a buffer, which you can then paste from later.
; * Multiple different item types are supported, including text, images, and files.
; * Two different lists are maintained: one for images, the other for text and files.
; * As you copy items, they are added to the appropriate list. Once the list reaches a certain size, the oldest items are removed.
; * You can paste items from the list by selecting them from a menu that appears when you press / hold / toggle a hotkey.
; * The menu is displayed in a toggleable GUI window, which can be moved around the screen, set transparent, resized, and more.
; * Settings window allows you to customize the appearance and behavior of the script.
; * You can also save and load settings to / from a file.

#Requires AutoHotkey v2.0
#SingleInstance Force

; ========== Class Definitions ==========
class ClipboardManager {
    ; Settings and configuration
    static Settings := Map(
        "maxTextItems", 20,
        "maxImageItems", 10,
        "maxImageSize", 104857600, ; 100 MB
        "maxTotalImageSize", 524288000, ; 500 MB
        "guiTransparency", 235,
        "guiWidth", 300,
        "guiHeight", 400,
        "saveLocation", A_ScriptDir "\saved_clips.json",
        "configFile", A_ScriptDir "\settings.ini",
        "tempImageDir", A_ScriptDir "\temp_images"
    )
    
    ; Storage for clipboard items
    textItems := []        ; For text and files
    imageItems := []       ; For images
    currentImageSize := 0  ; Total size of images in bytes
    
    ; GUI references
    mainGui := {}
    settingsGui := {}
    
    __New() {
        this.LoadSettings()
        this.InitializeStorage()
        this.InitializeGUI()
        this.SetupHotkeys()
        
        ; Start monitoring clipboard
        A_TrayMenu.Add("Settings", (*) => this.ShowSettings())
        A_TrayMenu.Add("Exit", (*) => ExitApp())
    }
    
    InitializeStorage() {
        ; Create temp image directory if it doesn't exist
        if !DirExist(this.Settings["tempImageDir"])
            DirCreate(this.Settings["tempImageDir"])

        ; Clear any existing temporary files
        this.CleanupTempFiles()
    }

    CleanupTempFiles() {
        ; Delete all files in the temp image directory
        Loop Files this.Settings["tempImageDir"] "\*.*"
            try FileDelete(A_LoopFileFullPath)
    }

    GetImageSize(imageData) {
        ; Calculate size of image data in bytes
        return imageData.Size ?? DllCall("GlobalSize", "Ptr", imageData)
    }

    CanAddImage(newImageSize) {
        ; Check if we can add a new image without exceeding the limits
        if (newImageSize > this.Settings["maxImageSize"]) {
            this.ShowNotification("Image too large (Max: " . Floor(this.Settings["maxImageSize"] / 1048576) . " MB)")
            return false
        }

        return true
    }

    HandleImageClip() {
        try {
            ; Get image data and check size
            hBitmap := DllCall("GetClipboardData", "uint", 2, "ptr")
            if !hBitmap {
                this.ShowNotification("Failed to get image data from clipboard")
                return
            }

            imageSize := this.GetImageSize(hBitmap)

            ; Check if we can add the image
            if !this.CanAddImage(imageSize)
                return

            ; Generate unique filename for this image
            timestamp := FormatTime(, "yyyyMMdd_HHmmss")
            tempFile := this.Settings["tempImageDir"] "\" timestamp ".png"

            ; Save image to file
            ; Create thumbnail
            ; Implementation of image handling will go here

            ; Update total image size
            this.currentImageSize += imageSize
            
            ; Add to image items array
            this.imageItems.Push(Map(
                "path", tempFile,
                "size", imageSize,
                "timestamp", timestamp
            ))

            ; Remove oldest image if we exceed maximum items
            while (this.imageItems.Length > this.Settings["maxImageItems"]) {
                oldestImage := this.imageItems.Shift()
                this.currentImageSize -= oldestImage["size"]
                try FileDelete(oldestImage["path"])
            }
        } catch as err {
            this.ShowNotification("Error handling image: " . err.Message)
        }
    }

    ShowNotification(message) {
        ; Show a tooltip or some other form of notification
        ToolTip(message)
        SetTimer () => ToolTip(""), -3000 ; Hide after 3 seconds
    }

    CleanupAndExit() {
        ; Cleanup temp files and exit
        this.CleanupTempFiles()
        ExitApp()
    }

    InitializeGUI() {
        ; Main GUI setup
        this.mainGui := Gui("+Resize +AlwaysOnTop -Caption")
        ; ... GUI controls will go here
    }
    
    SetupHotkeys() {
        ; Define default hotkeys
        HotKey("^!c", (*) => this.ToggleGUI())        ; Ctrl+Alt+C to toggle GUI
        HotKey("Escape", (*) => this.HideGUI())       ; Escape to hide
    }
    
    OnClipboardChange(Type) {
        switch Type {
            case 1: ; Text
                this.HandleTextClip()
            case 2: ; Files
                this.HandleFileClip()
            case 0: ; Potentially image
                if DllCall("IsClipboardFormatAvailable", "uint", 2)
                    this.HandleImageClip()
        }
        this.UpdateGUI()
    }
    
    HandleTextClip() {
        ; Add new text to buffer
        text := A_Clipboard
        if text != ""
            this.AddToBuffer(text, "text")
    }
    
    HandleImageClip() {
        ; Handle image clipboard content
        ; Will implement image saving and thumbnail generation
    }
    
    HandleFileClip() {
        ; Handle file paths
        files := A_Clipboard
        this.AddToBuffer(files, "file")
    }
    
    AddToBuffer(content, type) {
        ; Add items to appropriate buffer and maintain size limits
    }
    
    LoadSettings() {
        ; Load settings from file
        try {
            ; Implementation will go here
        }
    }
    
    SaveSettings() {
        ; Save current settings to file
    }
    
    ShowSettings() {
        ; Create and show settings GUI
    }
}

; ========== Main Program ==========
; Initialize the clipboard manager
clipManager := ClipboardManager()

; Set up clipboard monitoring
OnClipboardChange((*) => clipManager.OnClipboardChange(Type))

; Ensure cleanup on script exit
OnExit((*) => clipManager.CleanupAndExit())
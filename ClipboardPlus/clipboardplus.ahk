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
        "thumbSize", 100, ; Thumbnail size in pixels
        "saveLocation", A_ScriptDir "\saved_clips.json",
        "configFile", A_ScriptDir "\settings.ini",
        "tempImageDir", A_ScriptDir "\temp_images",
        "toggleHotkey", "^!c",         ; Ctrl+Alt+C
        "pasteHotkey", "^!v",          ; Ctrl+Alt+V
        "autoSave", true,
        "startMinimized", false,
        "alwaysOnTop", true
    )
    
    ; Add setting controls references
    settingsControls := Map()

    ; Storage for clipboard items
    textItems := []        ; For text and files
    imageItems := []       ; For images
    currentImageSize := 0  ; Total size of images in bytes
    
    ; GUI references
    mainGui := {}
    settingsGui := {}
    textList := {}
    imageList := {}
    
    __New() {
        this.LoadSettings()
        this.InitializeStorage()
        this.InitializeGUI()
        this.SetupHotkeys()
        
        ; Start monitoring clipboard
        A_TrayMenu.Add("Settings", (*) => this.ShowSettings())
        A_TrayMenu.Add("Exit", (*) => this.CleanupAndExit())
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
        this.mainGui := Gui("+Resize +AlwaysOnTop -DPIScale", "Clipboard Manager")
        this.mainGui.OnEvent("Size", (*) => this.ResizeGUI())

        ; Add tab control
        tabs := this.mainGui.Add("Tab3", "w" this.Settings["guiWidth"] " h" this.Settings["guiHeight"], ["Text", "Images"])

        ; Text tab
        tabs.UseTab(1)
        this.textList := this.mainGui.Add("ListView", "w" this.Settings["guiWidth"]-20 " h" this.Settings["guiHeight"]-40, ["Time", "Content"])
        this.textList.OnEvent("DoubleClick", (*) => this.PasteSelectedText())
        this.textList.OnEvent("ItemClick", (*) => this.PreviewText())

        ; Images Tab
        tabs.UseTab(2)
        this.imageList := this.mainGui.Add("ListView", "w" this.Settings["guiWidth"]-20 " h" this.Settings["guiHeight"]-40, ["Time", "Size", "Preview"])
        this.imageList.OnEvent("DoubleClick", (*) => this.PasteSelectedImage())

        ; Make lists accept drag operations
        this.SetupDragAndDrop()

        ; Set GUI transparency
        WinSetTransparent(this.Settings["guiTransparency"], this.mainGui)
    }

    SetupDragAndDrop() {
        ; Enable drag-drop from both lists
        this.textList.OnEvent("ItemClick", (*) => this.StartDrag("text"))
        this.imageList.OnEvent("ItemClick", (*) => this.StartDrag("image"))
    }

    StartDrag(type) {
        if !GetKeyState("LButton")
            return
        
        if (type = "text") {
            selected := this.textList.GetText(this.textList.GetNext())
            if selected
                this.DoDragDrop(selected, "text")
        } else {
            selected := this.imageList.GetNext()
            if selected
                this.DoDragDrop(this.imageItems[selected], "image")
        }
    }
    
    DoDragDrop(data, type) {
        ; Implementation for drag-drop operation
        static DROPEFFECT_COPY := 1

        if (type = "text") {
            ; Set clipboard format for text
            A_Clipboard := data
        } else {
            ; Set clipboard format for image
            try {
                hBitmap := LoadPicture(data["path"])
                ; Set up clipboard with image data
                DllCall("OpenClipboard", "ptr", 0)
                DllCall("EmptyClipboard")
                DllCall("SetClipboardData", "uint", 2, "ptr", hBitmap)
                DllCall("CloseClipboard")
            }
        }

        ; Initiate drag operation 
        DllCall("OleInitialize", "ptr", 0)
        DllCall("RegisterDragDrop", "ptr", this.mainGui.Hwnd, "ptr", this.CreateDropTarget())
    }

    SaveImage(hBitmap, filename) {
        try {
            ; Save bitmap to file using GDI+
            pBitmap := this.CreateBitmapFromHandle(hBitmap)
            if !pBitmap
                throw Error("Failed to create bitmap")

            ; Save as PNG
            Gdip_SaveBitmapToFile(pBitmap, filename)

            ; Create thumbnail
            thumbFile := filename ".thumb.png"
            thumbBitmap := this.CreateThumbnail(pBitmap)
            Gdip_SaveBitmapToFile(thumbBitmap, thumbFile)

            ; Cleanup
            Gdip_DisposeImage(pBitmap)
            Gdip_DisposeImage(thumbBitmap)

            return true
        } catch as err {
            this.ShowNotification("Error saving image: " . err.Message)
            return false
        }
    }

    CreateThumbnail(pBitmap) {
        ; Create thumbnail from bitmap using GDI+
        width := this.Settings["thumbSize"]
        height := this.Settings["thumbSize"]

        ; Calculate aspect ratio
        origWidth := Gdip_GetImageWidth(pBitmap)
        origHeight := Gdip_GetImageHeight(pBitmap)
        ratio := Min(width / origWidth, height / origHeight)

        ; Create new bitmap with calculated dimensions
        newWidth := Round(origWidth * ratio)
        newHeight := Round(origHeight * ratio)

        thumbBitmap := Gdip_CreateBitmap(newWidth, newHeight)
        graphics := Gdip_GraphicsFromImage(thumbBitmap)

        ; Set high quality scaling
        Gdip_SetInterpolationMode(graphics, 7) ; InterpolationModeHighQuality

        ; Draw scaled image
        Gdip_DrawImage(graphics, pBitmap, 0, 0, newWidth, newHeight)

        ; Clean up
        Gdip_DeleteGraphics(graphics)

        return thumbBitmap
    }

    UpdateGUI() {
        ; Update text list
        this.textList.Delete()
        for item in this.textItems
            this.textList.Add(, FormatTime(item["timestamp"], "HH:mm:ss"), this.TruncateText(item["content"], 50))

        ; Update image list
        this.imageList.Delete()
        for item in this.imageItems {
            size := Format("{:.1f}MB", item["size"] / 1048576)
            this.imageList.Add(, FormatTime(item["timestamp"], "HH:mm:ss"), size)
            ; Load thumbnail into list
            if FileExists(item["thumb"])
                this.imageList.SetImageList(IL_Create(1, 5, 0))
                IL_Add(this.imageList.ImageList(), item["thumb"])
        }
    }

    TruncateText(text, length) {
        return StrLen(text) > length ? SubStr(text, 1, length) "..." : text
    }

    ResizeGUI() {
        try {
            if !this.mainGui.Hwnd
                return

            ; Get new dimensions
            newWidth := this.mainGui.Position.W
            newHeight := this.mainGui.Position.H

            ; Resize tab control
            this.textList.Move(,, newWidth-20, newHeight-40)
            this.imageList.Move(,, newWidth-20, newHeight-40)
        }
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
        if FileExist(this.Settings["configFile"]) {
            try {
                ; Load each setting from INI
                for key in this.Settings {
                    value := IniRead(this.Settings["configFile"], "Settings", key, this.Settings[key])
                    this.Settings[key] := value
                }
            }
        }
    }
    
    SaveSettings() {
        ; Save current settings to file
        ; Update settings from controls
        for key, control in this.settingsControls {
            if (key = "maxImageSize")
                this.Settings[key] := control.Value * 1048576  ; Convert MB to bytes
            else
                this.Settings[key] := control.Value
        }
        
        ; Save to INI file
        for key, value in this.Settings {
            IniWrite(value, this.Settings["configFile"], "Settings", key)
        }
        
        ; Apply new settings
        this.ApplySettings()
        this.settingsGui.Hide()
    }
    
    ShowSettings() {
        ; Create and show settings GUI
    ; Create settings GUI
    if !this.settingsGui {
        this.settingsGui := Gui("+Owner" this.mainGui.Hwnd, "Clipboard Manager Settings")
        
        ; Create tabs for organization
        tabs := this.settingsGui.Add("Tab3", "w400 h500", ["General", "Hotkeys", "Storage"])
        
        ; === General Tab ===
        tabs.UseTab(1)
        this.settingsGui.Add("GroupBox", "w380 h160", "GUI Settings")
        this.settingsGui.Add("Text",, "Transparency:")
        this.settingsControls["guiTransparency"] := this.settingsGui.Add("Slider", "w200", "Range0-255")
        this.settingsControls["guiTransparency"].Value := this.Settings["guiTransparency"]
        
        this.settingsControls["alwaysOnTop"] := this.settingsGui.Add("Checkbox",, "Always on Top")
        this.settingsControls["alwaysOnTop"].Value := this.Settings["alwaysOnTop"]
        
        this.settingsControls["startMinimized"] := this.settingsGui.Add("Checkbox",, "Start Minimized")
        this.settingsControls["startMinimized"].Value := this.Settings["startMinimized"]
        
        this.settingsControls["autoSave"] := this.settingsGui.Add("Checkbox",, "Auto-save clips")
        this.settingsControls["autoSave"].Value := this.Settings["autoSave"]
        
        ; === Hotkeys Tab ===
        tabs.UseTab(2)
        this.settingsGui.Add("GroupBox", "w380 h160", "Hotkey Configuration")
        
        this.settingsGui.Add("Text",, "Toggle GUI:")
        this.settingsControls["toggleHotkey"] := this.settingsGui.Add("Hotkey", "w200")
        this.settingsControls["toggleHotkey"].Value := this.Settings["toggleHotkey"]
        
        this.settingsGui.Add("Text",, "Quick Paste:")
        this.settingsControls["pasteHotkey"] := this.settingsGui.Add("Hotkey", "w200")
        this.settingsControls["pasteHotkey"].Value := this.Settings["pasteHotkey"]
        
        ; === Storage Tab ===
        tabs.UseTab(3)
        this.settingsGui.Add("GroupBox", "w380 h200", "Storage Limits")
        
        this.settingsGui.Add("Text",, "Max Text Items:")
        this.settingsControls["maxTextItems"] := this.settingsGui.Add("Edit", "w60")
        this.settingsControls["maxTextItems"].Value := this.Settings["maxTextItems"]
        
        this.settingsGui.Add("Text",, "Max Image Items:")
        this.settingsControls["maxImageItems"] := this.settingsGui.Add("Edit", "w60")
        this.settingsControls["maxImageItems"].Value := this.Settings["maxImageItems"]
        
        this.settingsGui.Add("Text",, "Max Single Image Size (MB):")
        this.settingsControls["maxImageSize"] := this.settingsGui.Add("Edit", "w60")
        this.settingsControls["maxImageSize"].Value := this.Settings["maxImageSize"] / 1048576
        
        ; Add Save/Cancel buttons
        this.settingsGui.Add("Button", "Default w80", "Save").OnEvent("Click", (*) => this.SaveSettings())
        this.settingsGui.Add("Button", "x+10 w80", "Cancel").OnEvent("Click", (*) => this.settingsGui.Hide())
    }
    
    this.settingsGui.Show()
    }

    ApplySettings() {
        ; Apply GUI settings
        if this.mainGui {
            WinSetTransparent(this.Settings["guiTransparency"], this.mainGui)
            WinSetAlwaysOnTop(this.Settings["alwaysOnTop"], this.mainGui)
        }
        
        ; Update hotkeys
        this.SetupHotkeys()
        
        ; Apply size limits
        this.ManageBuffers()
    }

    SetupContextMenus() {
        ; Text list context menu
        this.textList.OnEvent("ContextMenu", (*) => this.ShowTextContextMenu())
        
        ; Image list context menu
        this.imageList.OnEvent("ContextMenu", (*) => this.ShowImageContextMenu())
    }

    ShowTextContextMenu() {
        selected := this.textList.GetNext()
        if !selected
            return
            
        menu := Menu()
        menu.Add("Copy", (*) => this.CopySelectedText())
        menu.Add("Delete", (*) => this.DeleteSelectedText())
        menu.Add("Save As...", (*) => this.SaveTextAs())
        menu.Show()
    }

    ShowImageContextMenu() {
        selected := this.imageList.GetNext()
        if !selected
            return
            
        menu := Menu()
        menu.Add("Copy", (*) => this.CopySelectedImage())
        menu.Add("Delete", (*) => this.DeleteSelectedImage())
        menu.Add("Save As...", (*) => this.SaveImageAs())
        menu.Add("View Full Size", (*) => this.ViewFullImage())
        menu.Show()
    }

    SaveClips() {
        if !this.Settings["autoSave"]
            return
            
        try {
            data := Map(
                "textItems", this.textItems,
                "imageItems", this.imageItems
            )
            
            jsonText := JSON.Stringify(data)
            FileWrite(jsonText, this.Settings["saveLocation"])
        }
    }

    LoadClips() {
        if !FileExist(this.Settings["saveLocation"])
            return
            
        try {
            jsonText := FileRead(this.Settings["saveLocation"])
            data := JSON.Parse(jsonText)
            
            ; Validate and load text items
            if IsObject(data["textItems"])
                this.textItems := data["textItems"]
                
            ; Validate and load image items
            if IsObject(data["imageItems"]) {
                ; Only load images that still exist
                this.imageItems := []
                for item in data["imageItems"] {
                    if FileExist(item["path"])
                        this.imageItems.Push(item)
                }
            }
            
            this.UpdateGUI()
        }
    }

    SaveTextAs() {
        selected := this.textList.GetNext()
        if !selected
            return
            
        filename := FileSelect("S", , "Save Text As", "Text Files (*.txt)")
        if filename {
            FileWrite(this.textItems[selected]["content"], filename)
        }
    }

    SaveImageAs() {
        selected := this.imageList.GetNext()
        if !selected
            return
            
        filename := FileSelect("S", , "Save Image As", "PNG Files (*.png)")
        if filename {
            FileCopy(this.imageItems[selected]["path"], filename)
        }
    }

    ViewFullImage() {
        selected := this.imageList.GetNext()
        if !selected
            return
            
        ; Create a simple viewer GUI
        viewer := Gui("+Resize", "Image Viewer")
        viewer.Add("Picture", "w800 h600", this.imageItems[selected]["path"])
        viewer.Show()
    }

    DeleteSelectedText() {
        selected := this.textList.GetNext()
        if selected {
            this.textItems.RemoveAt(selected)
            this.UpdateGUI()
            this.SaveClips()
        }
    }

    DeleteSelectedImage() {
        selected := this.imageList.GetNext()
        if selected {
            ; Delete files
            try {
                FileDelete(this.imageItems[selected]["path"])
                FileDelete(this.imageItems[selected]["thumb"])
            }
            
            this.currentImageSize -= this.imageItems[selected]["size"]
            this.imageItems.RemoveAt(selected)
            this.UpdateGUI()
            this.SaveClips()
        }
    }
}

; ========== Main Program ==========
; Initialize GDI+ for image handling
Gdip_Startup()

; Initialize the clipboard manager
clipManager := ClipboardManager()

; Set up clipboard monitoring
OnClipboardChange((*) => clipManager.OnClipboardChange(Type))

; Ensure cleanup on script exit
OnExit((*) => {
    clipManager.CleanupAndExit()
    Gdip_Shutdown()
})
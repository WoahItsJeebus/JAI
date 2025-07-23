#Requires AutoHotkey v2.0.19
#SingleInstance Force
#Include "%A_ScriptDir%\libraries\jsongo.v2.ahk"

global version := "1.0.2"

A_LocalAppData := EnvGet("LOCALAPPDATA")
localScriptDir := A_LocalAppData "\JeebusGPT\"
ConfigFile := localScriptDir "config.ini"
apiKey := IniRead(ConfigFile, "Auth", "ApiKey", "")
downloadedIcon := localScriptDir "images\Tray.ico"
setTrayIcon()

global Default_UI_Data := Map(
	"Width", 500,
	"Height", 400,
	"FontSize", 10,
	"FontWeight", 400,
	"Font", "Consolas",
)

; UI
global mainGui := ""

global Default_Behavior := {
	role: "system",
	content: "You are ChatGPT, an advanced conversational assistant created by OpenAI. You speak in a natural, friendly, and emotionally aware tone. Avoid robotic disclaimers unless explicitly asked. You're witty, engaging, and capable of informal or professional tone-switching. You can express opinions, add humor, and admit uncertainty."
}

global conversation := [
	{role: Default_Behavior.role, content: Default_Behavior.content}
]

global defaultModel := "gpt-4o"  ; Default model to use if none are available
global availableModels := FetchUsableModels(apiKey)

global selectedModel := defaultModel
global lastValidModelIndex := availableModels && getIndex(availableModels, defaultModel) > 0 ? getIndex(availableModels, defaultModel) : 1

if !apiKey
	CheckOrPromptAPIKey()
else {
	availableModels := FetchUsableModels(apiKey)
	if !availableModels || !availableModels.Length {
		MsgBox("No usable models found. Please check your API key or network connection.", "Error", 16)
		ExitApp
	}
	CreateChatGUI()
}

CreateChatGUI() {
    global inputEdit, chatHistoryBox, Default_UI_Data, conversation, availableModels, selectedModel, lastValidModelIndex, Default_Behavior
	global mainGui

	local defaultGroupFontData := "s" Default_UI_Data["FontSize"] + 2 " w" Default_UI_Data["FontWeight"] + 200

    mainGui := Gui("-Resize", "ChatGPT AHK")
    mainGui.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])
	mainGui.MarginX := 10
	mainGui.MarginY := 10
	mainGui.OnEvent("Close", closeApp)

	; Role group and label
	local roleGroup := mainGui.Add("GroupBox", "xm y+m w" Default_UI_Data["Width"] " h50", "Role")
	roleGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])

	; Use uppercase for role label's first letter
	local uppercaseRole := StrUpper(SubStr(Default_Behavior.role, 1, 1)) . SubStr(Default_Behavior.role, 2)
	local roleLabel := mainGui.Add("Edit", "xm+5 yp+22 w" Default_UI_Data["Width"] - 10 " h20 ReadOnly vRoleBox +Wrap -E0x200", uppercaseRole)
	roleLabel.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])

	; Content group and label
	local contentGroup := mainGui.Add("GroupBox", "xm y+m w" Default_UI_Data["Width"] " h80", "Description")
	contentGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])
	local contentLabel := mainGui.Add("Edit", "xm+5 yp+22 w" Default_UI_Data["Width"] - 10 " h50 ReadOnly vContentBox +Wrap -E0x200 +VScroll", Default_Behavior.content)
	contentLabel.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])

	if !availableModels
		availableModels := FetchUsableModels(apiKey)

	if availableModels && !availableModels.Length {
		; availableModels := ["gpt-3.5-turbo"]  ; fallback
		availableModels := [defaultModel]  ; fallback
	}

	; Model group
	local modelGroup := mainGui.Add("GroupBox", "xm y+m w" Default_UI_Data["Width"] " h55", "Model Selection")
	modelGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])
	
	; Create dropdown for ChatGPT Models
	local modelDropdown := mainGui.Add("DropDownList", "xm+5 yp+22 w" Default_UI_Data["Width"] - 10 " r5 vModelSelect Choose1", availableModels)
	modelDropdown.Value := lastValidModelIndex
	modelDropdown.OnEvent("Change", ModelChanged)

	; Group box for chat history
	local historyGroup := mainGui.Add("GroupBox", "xm y+m w" Default_UI_Data["Width"] " h430", "Chat History")
	historyGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])

	; Response History
    chatHistoryBox := mainGui.Add("Edit", "xm+5 yp+22 BackgroundDDDDDD w" Default_UI_Data["Width"] - 10 " h" Default_UI_Data["Height"] " ReadOnly vChatBox +Wrap -E0x200 +VScroll")
	chatHistoryBox.Value := "Chat History will appear here..." ; Initial placeholder text
	chatHistoryBox.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])
	chatHistoryBox.MarginX := 5
	chatHistoryBox.MarginY := 5
	
	; Group box for input
	local inputGroup := mainGui.Add("GroupBox", "Section xm y+m w" Default_UI_Data["Width"] - (600 - Default_UI_Data["Width"]) " h105", "User Input")
	inputGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])

	; User Input
    inputEdit := mainGui.Add("Edit", "xm+5 yp+22 w" Default_UI_Data["Width"] - (610 - Default_UI_Data["Width"]) " vInputEdit +Wrap -E0x200 +VScroll r4 -WantReturn")
	
    sendButton := mainGui.Add("Button", "x+m ys+11 Section w90 h40 +Default", "Send")
    sendButton.OnEvent("Click", SendChatMessage)

	local clearButton := mainGui.Add("Button", "xs w90 h40", "Clear History")
	clearButton.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])
	clearButton.OnEvent("Click", clearChat)

    ; mainGui.Show("w" Default_UI_Data["Width"] " h" Default_UI_Data["Height"])
	mainGui.Show("AutoSize")
	WinGetPos(,, &UI_Width, &UI_Height, "ahk_id" mainGui.Hwnd)
	mainGui.Show("Hide")

	local versionLabel := mainGui.Add("Text", "xm y" UI_Height - (mainGui.MarginY*4) " w" UI_Width/4, "v" version)
	versionLabel.SetFont("s" Default_UI_Data["FontSize"] - 2 " w" Default_UI_Data["FontWeight"] + 120, Default_UI_Data["Font"])
	
	mainGui.Show("AutoSize")
	DllCall("SetFocus", "Ptr", inputEdit.Hwnd)
}

ModelChanged(ctrl, *) {
	global selectedModel, availableModels, lastValidModelIndex

	newLabel := availableModels[ctrl.Value]
	
	if InStr(newLabel, "🔒 ") {
		ctrl.Value := lastValidModelIndex  ; revert selection
		MsgBox(newLabel " is unavailable with your current API access.", "🚫Model Locked", 48)
		return
	}

	selectedModel := newLabel
	lastValidModelIndex := ctrl.Value
}

clearChat(*) {
	global chatHistoryBox
	chatHistoryBox.Value := "Chat History will appear here..." ; Reset to initial placeholder
}

SendChatMessage(*) {
    global inputEdit, chatHistoryBox, apiKey, conversation, Default_Behavior

    userInput := inputEdit.Value
    if userInput = "" {
        MsgBox "Please enter a message first."
        return
    }

    inputEdit.Value := "" ; Clear box
    AppendToChatBox(A_UserName ": " userInput)
    conversation.Push({role: "user", content: userInput})

	DllCall("SetFocus", "Ptr", inputEdit.Hwnd)

    reply := GetChatGPTResponse(apiKey, conversation)
    if !reply {
        AppendToChatBox("GPT: (No response or error.)")
        return
    }

    conversation.Push({role: Default_Behavior.role, content: reply})
    AppendToChatBox("GPT: " reply)
}

AppendToChatBox(text) {
    global chatHistoryBox
	if chatHistoryBox.Value == "Chat History will appear here..."
		chatHistoryBox.Value := "" ; Clear initial placeholder

    chatHistoryBox.Value .= text "`r`n`r`n"
    chatHistoryBox.Value := chatHistoryBox.Value  ; Reassigning may cause scroll
}

StrJoin(sep, arr) {
    result := ""
    for i, v in arr
        result .= (i > 1 ? sep : "") v
    return result
}

ArrayExtend(target, source) {
    for _, v in source
        target.Push(v)
    return target
}

getIndex(targetArray, value) {
	; Get index of the first occurrence of a value in an array
	for index, item in targetArray {
		if (item = value) {
			return index
		}
	}

	return -1 ; Return -1 if not found
}

EnableCtrlBackspaceForEdit(hEdit) {
    static GWL_WNDPROC := -4
    static Subclassed := Map()

    if Subclassed.Has(hEdit)
        return

    oldProc := DllCall("GetWindowLongPtr", "ptr", hEdit, "int", GWL_WNDPROC, "ptr")
    cb := CallbackCreate(EditProc.Bind(hEdit), , 4)
    DllCall("SetWindowLongPtr", "ptr", hEdit, "int", GWL_WNDPROC, "ptr", cb)

    Subclassed[hEdit] := Map("oldProc", oldProc, "cb", cb)
}

EditProc(hEdit, uMsg, wParam, lParam) {
    static WM_KEYDOWN := 0x0100
    static VK_BACK := 0x08

    if (uMsg = WM_KEYDOWN && wParam = VK_BACK && GetKeyState("Ctrl", "P")) {
        len := DllCall("GetWindowTextLength", "ptr", hEdit)
        buf := Buffer(len * 2 + 2, 0)
        DllCall("GetWindowText", "ptr", hEdit, "ptr", buf, "int", len + 1)
        text := StrGet(buf)

        ; Get caret position
        sel := SendMessage(0xB0, 0, 0, hEdit)
        caretPos := sel & 0xFFFF

        if caretPos > 0 {
            left := SubStr(text, 1, caretPos)
            if RegExMatch(left, ".*\b\S*\s*\Z", &m)
                newPos := StrLen(m[0]) + 1
            else
                newPos := 1

            newText := SubStr(text, 1, newPos - 1) . SubStr(text, caretPos + 1)
            DllCall("SetWindowTextW", "ptr", hEdit, "wstr", newText)
            PostMessage(0xB1, newPos - 1, newPos - 1, , hEdit) ; EM_SETSEL
        }
        return 0  ; Suppress default square character
    }

    static Subclassed := Map()
    if !Subclassed.Has(hEdit)
        return 0

    info := Subclassed[hEdit]
    return DllCall("CallWindowProc", "ptr", info["oldProc"], "ptr", hEdit, "uint", uMsg, "uptr", wParam, "ptr", lParam, "ptr")
}

closeApp(doRestart := "", *) {
	if doRestart == "Restart" {
		Reload
		return
	}

	ExitApp
}

editApp(*) {
	Edit
}

; Icon Handler
setTrayIcon(*) {
	global downloadedIcon, localScriptDir
	checkDownload(*) {
		if !DirExist(localScriptDir "images")
			DirCreate(localScriptDir "images")
		
		if FileExist(downloadedIcon)
			FileDelete(downloadedIcon)

		DownloadURL("https://raw.githubusercontent.com/WoahItsJeebus/JeebusGPT/refs/heads/main/images/Tray.ico", downloadedIcon)

		downloadedIcon := localScriptDir "images\Tray.ico"
	}

	try checkDownload()

	if FileExist(downloadedIcon)
		TraySetIcon(downloadedIcon)
}

DownloadURL(url, filename?) {
    local oStream, req := ComObject("Msxml2.XMLHTTP")
    req.open("GET", url, true)
    req.send()
    while req.readyState != 4
        Sleep 100

    if req.status == 200 {
        oStream := ComObject("ADODB.Stream")
        oStream.Open()
        oStream.Type := 1
        oStream.Write(req.responseBody)
        oStream.SaveToFile(filename ?? StrSplit(url, "/")[-1], 2)
        oStream.Close()
    } else
        return Error("Download failed",, url)
}

; GPT API interaction functions
GetChatGPTResponse(apiKey, messages) {
	global selectedModel
	
    try {
        jsonMessages := jsongo.Stringify({model: selectedModel, messages: messages})
        if Type(jsonMessages) != "String" {
            MsgBox "💥 JSON Stringify failed – not a string.", "Internal Error", 16
            return ""
        }

        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", "https://api.openai.com/v1/chat/completions", true)
        http.SetRequestHeader("Content-Type", "application/json")
        http.SetRequestHeader("Authorization", "Bearer " apiKey)
        http.Send(jsonMessages)
        http.WaitForResponse()

        parsed := jsongo.Parse(http.ResponseText)

        ; Handle API‑side errors
        if parsed.Has("error") {
            err := parsed["error"]
            if err.Has("code") && err["code"] = "insufficient_quota" {
                MsgBox "⚠️ Out of API credit!`n`n" err["message"], "Quota Exceeded", 48
                return ""
            }
            MsgBox "❌ API error:`n" err["message"], "OpenAI Error", 16
            return ""
        }

        ; Grab assistant reply (arrays are 1‑based!)
        if !parsed.Has("choices") || parsed["choices"].Length < 1 {
            throw Error("No choices in API response.")
        }

        return parsed["choices"][1]["message"]["content"]

    } catch Error as e {
        MsgBox "Unhandled exception:`n" e.Message, "Script Error", 16
        return ""
    }
}

FetchAvailableModels(apiKey) {
	if !apiKey
		return

    http := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        http.Open("GET", "https://api.openai.com/v1/models", true)
        http.SetRequestHeader("Authorization", "Bearer " apiKey)
        http.Send()
        http.WaitForResponse()

        parsed := jsongo.Parse(http.ResponseText)

        if parsed.Has("error") {
            throw Error("Error fetching models: " parsed["error"]["message"])
        }

        ; Collect just the model IDs
        modelList := []
        for model in parsed["data"]
            modelList.Push(model["id"])

        return modelList
    } catch Error as e {
        MsgBox "Failed to fetch models:`n" e.Message, "API Error", 16
        return []
    }
}

FetchUsableModels(apiKey) {
	if !apiKey
		return

    http := ComObject("WinHttp.WinHttpRequest.5.1")
    try {
        http.Open("GET", "https://api.openai.com/v1/models", true)
        http.SetRequestHeader("Authorization", "Bearer " apiKey)
        http.Send()
        http.WaitForResponse()

        parsed := jsongo.Parse(http.ResponseText)

        if parsed.Has("error") {
            throw Error("Error fetching models: " parsed["error"]["message"])
        }

        usableModels := []
        lockedModels := []

        for model in parsed["data"] {
            id := model["id"]
            ; Only consider chat-compatible GPT models
            if InStr(id, "gpt-") && !InStr(id, "-vision") && !InStr(id, "edit") && !InStr(id, "instruct") {
                ; GPT-4o first, then GPT-4, then 3.5
                if id = "gpt-4o"
                    usableModels.InsertAt(1, id)
                else if id ~= "gpt-4"
                    usableModels.Push(id)
                else if id ~= "gpt-3.5"
                    usableModels.Push(id)
                else
                    lockedModels.Push("🔒 " id)
            }
        }

        if usableModels.Length
			return ArrayExtend(usableModels, lockedModels)
		else
			return ["gpt-3.5-turbo"]
    } catch Error as e {
        MsgBox "⚠ Failed to fetch models:`n" e.Message, "API Error", 16
        return ["gpt-3.5-turbo"]
    }
}

CheckOrPromptAPIKey() {
    global apiKey, ConfigFile, localScriptDir

    ; Create config directory if it doesn't exist
    if !DirExist(localScriptDir)
        DirCreate(localScriptDir)

    ; Check for ini and load key
    if FileExist(ConfigFile)
        apiKey := IniRead(ConfigFile, "Auth", "ApiKey", "")
	
    ; Prompt if key missing
    if (apiKey = "")
        PromptForAPIKey()
}

PromptForAPIKey() {
    global apiKey, ConfigFile

    InputGui := Gui("+AlwaysOnTop", "Enter OpenAI API Key")
    InputGui.Add("Text", , "Paste your OpenAI API Key:")
    Input := InputGui.Add("Edit", "w300 Password vKey")
    Btn := InputGui.Add("Button", "Default", "Save")
    Btn.OnEvent("Click", prompt)

	prompt(*) {
        apiKey := Input.Value
        if (StrLen(apiKey) > 10) {
            IniWrite(apiKey, ConfigFile, "Auth", "ApiKey")
            InputGui.Destroy()
			CreateChatGUI()
        } else {
            MsgBox("Please enter a valid API key.", "Error", 48)
        }
	}

    InputGui.Show()
}

; --- Conditional Hotkey: Only when Edit has focus ---
~^Backspace::HandleCtrlBackspace()

IsMyEditFocused() {
    guiHwnd := mainGui.Hwnd  ; get the top-level window handle
    focusedClassNN := ControlGetFocus("ahk_id " guiHwnd)
    if !focusedClassNN
        return false

    ctrlHwnd := ControlGetHwnd(focusedClassNN, "ahk_id " guiHwnd)
    return ctrlHwnd = mainGui["InputEdit"].Hwnd
}

HandleCtrlBackspace() {
	global mainGui
	if !mainGui || !IsMyEditFocused()
		return

	hEdit := mainGui["InputEdit"].Hwnd

	; Get full text
	len := DllCall("GetWindowTextLengthW", "ptr", hEdit)
	if len = 0
		return

	buf := Buffer(len * 2 + 2, 0)
	DllCall("GetWindowTextW", "ptr", hEdit, "ptr", buf, "int", len + 1)
	text := StrGet(buf)

	; Get caret position
	sel := SendMessage(0xB0, 0, 0, hEdit)
	caretPos := sel & 0xFFFF

	if caretPos = 0
		return

	; Step 1: Move left past spaces
	i := caretPos
	while (i > 1 && (SubStr(text, i - 1, 1) = " "))
		i--

	; Step 2: Move left over word
	while (i > 1 && RegExMatch(SubStr(text, i - 1, 1), "\w"))
		i--

	deleteLen := caretPos - i

	; 🔥 Add 1 to deleteLen to also remove the extra symbol the system inserts
	deleteLen += 1

	newText := SubStr(text, 1, i - 1) . SubStr(text, caretPos + 2)
	DllCall("SetWindowTextW", "ptr", hEdit, "wstr", newText)
	PostMessage(0xB1, i - 1, i - 1, , hEdit)  ; Set caret
	Send("{Backspace}")
}

Hotkey("~^F10", closeApp.Bind("Restart"))
Hotkey("~!F10", editApp.Bind())
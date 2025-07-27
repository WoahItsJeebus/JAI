#Requires AutoHotkey v2.0.19
#SingleInstance Force
#Include "%A_ScriptDir%\libraries\jsongo.v2.ahk"

global version := "1.1.0"

A_LocalAppData := EnvGet("LOCALAPPDATA")
localScriptDir := A_LocalAppData "\JeebusGPT\"
ConfigFile := localScriptDir "config.ini"
apiKey := IniRead(ConfigFile, "Auth", "ApiKey", "")
downloadedIcon := localScriptDir "images\Tray.ico"
setTrayIcon()

global mainGui := unset
global modelGui := unset

global Default_UI_Data := Map(
	"Width", 500,
	"Height", 400,
	"FontSize", 10,
	"FontWeight", 400,
	"Font", "Segoe UI Emoji"  ; Default font with emoji support,
)

global personaData := Map()
global personaNames := []
global Default_Behavior := {
	role: "system",
	content: "You are ChatGPT, an advanced conversational assistant created by OpenAI. You speak in a natural, friendly, and emotionally aware tone. Avoid robotic disclaimers unless explicitly asked. You're witty, engaging, and capable of informal or professional tone-switching. You can express opinions, add humor, and admit uncertainty."
}

global conversation := [
	{role: Default_Behavior.role, content: Default_Behavior.content}
]

global currentLogFile := ""

global defaultModel := "gpt-4o"  ; Default model to use if none are available
global availableModels := FetchUsableModels(apiKey)

global selectedModel := defaultModel
global selectedPersona := IniRead(localScriptDir "personas.ini", "Personas", "Selected", "Default")
global lastValidModelIndex := availableModels && getIndex(availableModels, defaultModel) > 0 ? getIndex(availableModels, defaultModel) : 1

global MessageCount := 0

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
	
	LoadPersonaData()

    mainGui := Gui("-Resize", "ChatGPT AHK")
    mainGui.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])
	mainGui.MarginX := 10
	mainGui.MarginY := 10
	mainGui.OnEvent("Close", closeApp)

	; Model group
	local modelGroup := mainGui.Add("GroupBox", "xm y+m w" Default_UI_Data["Width"] " h55", "Model Selection")
	modelGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])

	if !availableModels
		availableModels := FetchUsableModels(apiKey)

	if availableModels && !availableModels.Length
		availableModels := [defaultModel]

	local modelDropdown := mainGui.Add("DropDownList", "xm+5 yp+22 w" Default_UI_Data["Width"] - 10 " vModelSelect Choose1 r" availableModels.Length*0.25, availableModels)
	modelDropdown.Value := lastValidModelIndex
	modelDropdown.OnEvent("Change", ModelChanged)

	; Chat history
	local historyGroup := mainGui.Add("GroupBox", "xm y+m w" Default_UI_Data["Width"] " h430", "Chat History")
	historyGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])

	chatHistoryBox := mainGui.Add("Edit", "xm+5 yp+22 BackgroundDDDDDD w" Default_UI_Data["Width"] - 10 " h" Default_UI_Data["Height"] " ReadOnly vChatBox +Wrap -E0x200 +VScroll")
	chatHistoryBox.Value := "Chat History will appear here..."
	chatHistoryBox.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])
	chatHistoryBox.MarginX := 5
	chatHistoryBox.MarginY := 5

	; User Input
	local inputGroup := mainGui.Add("GroupBox", "Section xm y+m w" Default_UI_Data["Width"] - (Default_UI_Data["Width"]*0.25) " h105", "User Input")
	inputGroup.SetFont(defaultGroupFontData, Default_UI_Data["Font"])

	inputEdit := mainGui.Add("Edit", "xm+5 yp+22 w" Default_UI_Data["Width"] - (Default_UI_Data["Width"]*0.275) " vInputEdit +Wrap -E0x200 +VScroll r4 -WantReturn")

	local userInputButtonHeight := 30
	local sendButton := mainGui.Add("Button", "x+m ys+11 Section w" Default_UI_Data["Width"] * 0.25 " h" userInputButtonHeight, "Send")
	sendButton.OnEvent("Click", SendChatMessage)

	local clearButton := mainGui.Add("Button", "xs y+1 w" Default_UI_Data["Width"] * 0.25 " h" userInputButtonHeight, "Clear History")
	clearButton.SetFont("s" Default_UI_Data["FontSize"] " w" Default_UI_Data["FontWeight"], Default_UI_Data["Font"])
	clearButton.OnEvent("Click", clearChat)

		; === Model Editor Button ===
	local modelEditorBtn := mainGui.Add("Button", "xs y+1 w" Default_UI_Data["Width"] * 0.25 " h" userInputButtonHeight, "Model Editor")
	modelEditorBtn.OnEvent("Click", OpenModelEditorGUI)

	mainGui.Show("")
	WinGetPos(,, &UI_Width, &UI_Height, "ahk_id" mainGui.Hwnd)
	mainGui.Show("Hide")

	local versionLabel := mainGui.Add("Text", "xm y" UI_Height - (mainGui.MarginY*4) " w" UI_Width/4, "v" version)
	versionLabel.SetFont("s" Default_UI_Data["FontSize"] - 2 " w" Default_UI_Data["FontWeight"] + 120, Default_UI_Data["Font"])

	mainGui.Show("")
	DllCall("SetFocus", "Ptr", inputEdit.Hwnd)
}

OpenModelEditorGUI(*) {
    global Default_Behavior, personaData, personaNames, localScriptDir, selectedPersona
	global modelGui

	; Set initial persona data
	if personaNames.Length == 0
		LoadPersonaData()
	
	if IsSet(modelGui) {
		modelGui.Destroy()
		modelGui := unset
	}

	modelGui := Gui("-Resize +Owner" mainGui.Hwnd, "Model Editor")
    modelGui.SetFont("s10", "Segoe UI")

    ; Core Traits
    modelGui.Add("GroupBox", "xm ym w400 h130", "Core Personality")
    coreEdit := modelGui.Add("Edit", "xm+10 yp+20 w380 h90 vCoreEditor +Wrap -E0x200 +VScroll", Default_Behavior.content)
    modelGui.Add("Button", "xm+10 y+5 w80", "Save").OnEvent("Click", saveCore)

    ; Persona Traits
    modelGui.Add("GroupBox", "xm y+20 w400 h160", "Persona Editor")
    personaDropdown := modelGui.Add("DropDownList", "xm+10 yp+20 w380 vpersonaDropdown r5 Choose1")
    personaEdit := modelGui.Add("Edit", "xm+10 y+10 w380 h90 vPersonaEditor +Wrap -E0x200 +VScroll")
    modelGui.Add("Button", "xm+10 y+5 w80", "Save").OnEvent("Click", savePersona)

	UpdateModelEditorFields()

    ; On persona select, load content into edit
    personaDropdown.OnEvent("Change", OnPersonaDropdownChange)

    modelGui.Show("AutoSize")

	saveCore(*) {
        IniWrite(coreEdit.Value, localScriptDir "personas.ini", "Default", "Persona")
        Default_Behavior.content := coreEdit.Value
        TrayTip("Core personality saved!", "JeebusGPT")
		SetTimer(TrayTip, -5000)
    }

	initializePersonaDDL(*) {
        personaEdit.Value := personaData[personaDropdown.Text]
    }

	savePersona(*) {
		if personaDropdown.Text == "Add New Persona..."
			return  ; Don't save if adding a new persona

        IniWrite(personaEdit.Value, localScriptDir "personas.ini", personaDropdown.Text, "Persona")
		IniWrite(personaDropdown.Text, localScriptDir "personas.ini", "Personas", "Selected")
		selectedPersona := IniRead(localScriptDir "personas.ini", "Personas", "Selected", "Default")
        personaData[selectedPersona] := { content: personaEdit.Value }
        TrayTip("Persona " selectedPersona " saved!", "JeebusGPT")
		SetTimer(TrayTip, -5000)
    }

	OnPersonaDropdownChange(*) {
		if (personaDropdown.Text == "Add New Persona...") {
			personaEdit.Value := ""  ; Clear editor for new persona

			LoadPersonaData()
			
			local newPersonaName := InputBox("Enter a name for the new persona:", "New Persona", "w300 h100","")
			if (!Trim(newPersonaName.Value) or newPersonaName.Result != "OK")
				return
			
			; Ensure no duplicate name
			if personaNames.Has(newPersonaName.Value) {
				MsgBox "That name already exists."
				return
			}
			
			; Add to data table and save blank template
			personaData[newPersonaName.Value] := { content: "" }
			personaNames.Push(newPersonaName.Value)

			savePersona()

			selectedPersona := newPersonaName.Value

			; You can also refresh the editor fields here
			UpdateModelEditorFields()
		} else {
			selectedPersona := personaDropdown.Text
			
			UpdateModelEditorFields()
		}
	}
}

UpdateModelEditorFields(*) {
	global modelGui, selectedPersona

	PopulatePersonaDropdown()

	; Load persona content into its editor
	if (selectedPersona && personaData.Has(selectedPersona)) {
		local pData := personaData[selectedPersona]
		modelGui["PersonaEditor"].Text := pData.content or ""
	} else {
		modelGui["PersonaEditor"].Text := ""
	}

	; Load default behavior (core content) into the core editor
	if (IsSet(modelGui)) {
		modelGui["CoreEditor"].Text := Default_Behavior.content
	}
}

PopulatePersonaDropdown(*) {
	global personaNames, selectedPersona, modelGui

	if !modelGui["personaDropdown"]
		return

	; Clear existing items
	modelGui["personaDropdown"].Delete()

	; Add the 'Add New Persona...' option first
	modelGui["personaDropdown"].Add(["Add New Persona..."])
	modelGui["personaDropdown"].Add(["Default"])  ; Always include the default persona second

	; Add existing persona names
	for each, name in personaNames {
		if name == "Default"
			continue

		modelGui["personaDropdown"].Add([name])
	}
	local selectedIndex := getIndex(personaNames, selectedPersona) + 1
	
	try
		modelGui["personaDropdown"].Choose(selectedIndex)
	catch
		modelGui["personaDropdown"].Choose(2)  ; Fallback to first item if not found
}

LoadPersonaData() {
    global personaData, personaNames, Default_Behavior, localScriptDir
    local iniFile := localScriptDir "personas.ini"

    personaData := Map()
    personaNames := []

    ; If the file doesn't exist, create it and write the default
    if !FileExist(iniFile) {
        defaultContent := Default_Behavior.content ? "You're friendly, curious, and always eager to help. You speak casually, but clearly, and you try to make complex topics easier to understand without sounding robotic. You like to be warm without being overbearing, and you always try to read the room before being playful or serious." : ""
        IniWrite(defaultContent, iniFile, "Default", "Persona")
    }

    sections := IniRead(iniFile, , , "")
    if (sections = "")
        return  ; Shouldn’t happen now, but just in case

    Loop Parse, sections, "`n", "`r" {
        section := Trim(A_LoopField)
        if (section = "")
            continue

        value := IniRead(iniFile, section, "Persona", "")
        if value != "" {
            personaData[section] := { content: value }
            personaNames.Push(section)
        }
    }
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
	global chatHistoryBox, MessageCount, conversation, currentLogFile, Default_Behavior
	chatHistoryBox.Value := "Chat History will appear here..."
	MessageCount := 0
	currentLogFile := ""

	; Reset convo with fresh persona system prompt
	conversation := [{ role: "system", content: Default_Behavior.content }]
}

CreateNewChatLog(firstUserInput) {
    global currentLogFile, conversation, A_LocalAppData

    folder := A_LocalAppData "\JeebusGPT\logs\"
    if !DirExist(folder)
        DirCreate folder

    timestamp := FormatTime(A_Now, "yyyy-MM-dd_HH-mmtt")

    ; Strip the timestamp from the input preview
    lines := StrSplit(firstUserInput, "`n")
    cleanedInput := lines.Length >= 2 ? lines[2] : lines[1]
    shortPreview := SubStr(cleanedInput, 1, 40)

    ; Check assistant response for [TITLE="..."]
    title := ""
    if (conversation.Length >= 2 && conversation[2].role = "assistant") {
        RegExMatch(conversation[2].content, '\[TITLE=""(.*?)""\]', &match)
        if match[1]
            title := match[1]
    }

    ; Build file name
    fileName := title ? (timestamp " - " RegExReplace(title, '[\\/:\*\?"<>\|]', "_")) : (timestamp " - " RegExReplace(shortPreview, '[\\/:\*\?"<>\|]', "_"))
    fullPath := folder fileName ".txt"

    currentLogFile := fullPath
    FileAppend("=== New Conversation Started ===`n`n", currentLogFile)
}

RenameChatLog(newName) {
    global currentLogFile

    ; Sanitize newName for use in filenames
    invalidChars := '[\\/:\*\?"<>\|]'
    newName := RegExReplace(newName, invalidChars, "_")

    ; Get current folder + file name
    folder := A_LocalAppData "\JeebusGPT\logs\"
    SplitPath(currentLogFile, , , , &fileName)

    ; Extract timestamp from filename (up to the first ' - ')
    RegExMatch(fileName, "^(.*?)(?= - )", &match)
    timestamp := match[1]

    ; Construct new file name
    newFileName := timestamp " - " newName ".txt"
    newFullPath := folder newFileName

    try {
        FileMove(currentLogFile, newFullPath, true)
        currentLogFile := newFullPath
    } catch {
        MsgBox "Failed to rename chat log.`nOld path: " currentLogFile "`nNew path: " newFullPath
    }
}

SendChatMessage(*) {
    global inputEdit, chatHistoryBox, apiKey, conversation, Default_Behavior, MessageCount, selectedPersona
    MessageCount++

    userInput := FormatDateTimeFromTick() "`n" inputEdit.Value
    if userInput = "" {
        MsgBox "Please enter a message first."
        return
    }

	if (MessageCount = 1)
		CreateNewChatLog(userInput)
	
	local systemPrompt := BuildSystemPrompt()

	; Check if conversation[1] is a system message
	if (conversation.Length == 0) {
		conversation.Push({ role: "system", content: systemPrompt })
	} else if (conversation[1].role == "system") {
		if (conversation[1].content != systemPrompt)
			conversation[1].content := systemPrompt
	} else {
		conversation.InsertAt(1, { role: "system", content: systemPrompt })
	}

    inputEdit.Value := "" ; Clear box
    AppendToChatBox(A_UserName ": " userInput)
	AppendToChatLog("user", userInput)
    conversation.Push({role: "user", content: userInput})

	DllCall("SetFocus", "Ptr", inputEdit.Hwnd)
	
    reply := FormatDateTimeFromTick() "`n" GetChatGPTResponse(apiKey, conversation)
	if !reply {
		AppendToChatBox(selectedPersona ": (No response or error.)")
		AppendToChatLog("assistant", "(No response or error.)")
		return
	}
	
	; Matches [TITLE=anything] or [TITLE="anything"]
	if RegExMatch(reply, '\[TITLE=(?:"(.*?)"|([^\]]+))\]', &match) {
		newTitle := match[1] != "" ? match[1] : match[2]
		RenameChatLog(newTitle)
		reply := RegExReplace(reply, '\[TITLE=(?:"(.*?)"|([^\]]+))\]', "")
	}
	
    conversation.Push({role: "assistant", content: RegExReplace(reply, "^\[\d{2}/\d{2}/\d{2} - \d{1,2}:\d{2} [AP]M\]\s*", "")})
    AppendToChatBox(selectedPersona ": " reply)
	AppendToChatLog("assistant", reply)
}

BuildSystemPrompt() {
    global anchors, selectedPersona, personaData

	; Declare systemText variable with default anchors
    local systemText := GetActiveAnchors()

    ; Add selected persona content if available
    if (personaData.Has(selectedPersona)) {
        systemText .= personaData[selectedPersona].content
    }
	else if (selectedPersona != "Default") {
		systemText .= "You are a persona named '" selectedPersona "'."
	} else
		systemText .= "You are the default persona named JeebusGPT."

    return RTrim(systemText, "`n")
}

AppendToChatBox(text) {
    global chatHistoryBox
	if chatHistoryBox.Value == "Chat History will appear here..."
		chatHistoryBox.Value := "" ; Clear initial placeholder

    chatHistoryBox.Value .= text "`r`n`r`n"
    
	; Scroll to bottom
    EM_SCROLL := 0x115
    SB_BOTTOM := 7
    SendMessage(EM_SCROLL, SB_BOTTOM, 0, chatHistoryBox.Hwnd)
}

AppendToChatLog(role, text) {
    global currentLogFile, selectedPersona
    if !currentLogFile
        return

    ; local timestamp := FormatDateTimeFromTick()
    local label := (role = "user") ? A_UserName : (role = "assistant") ? selectedPersona : "GPT"
    FileAppend(label ": " text "`n`n", currentLogFile)
}

StrJoin(sep, arr) {
    result := ""
    for i, v in arr
        result .= (i > 1 ? sep : "") v
    return result
}

; Time utility functions
FormatDateTimeFromTick(tickTime := A_TickCount) {
    static TIME_NOSECONDS := 0x00000002

    ; Convert tick to local timestamp
    offset := tickTime - A_TickCount
    targetStamp := DateAdd(A_Now, offset, "ms")

    year   := SubStr(targetStamp, 1, 4)
    month  := SubStr(targetStamp, 5, 2)
    day    := SubStr(targetStamp, 7, 2)
    hour   := SubStr(targetStamp, 9, 2)
    minute := SubStr(targetStamp, 11, 2)

    SYSTEMTIME := Buffer(16, 0)
    NumPut("UShort", year,   SYSTEMTIME, 0)
    NumPut("UShort", month,  SYSTEMTIME, 2)
    NumPut("UShort", 0,      SYSTEMTIME, 4) ; wDayOfWeek
    NumPut("UShort", day,    SYSTEMTIME, 6)
    NumPut("UShort", hour,   SYSTEMTIME, 8)
    NumPut("UShort", minute, SYSTEMTIME, 10)
    NumPut("UShort", 0,      SYSTEMTIME, 12) ; second
    NumPut("UShort", 0,      SYSTEMTIME, 14) ; millisecond

    ; --- Get system time string ---
    timeBuf := Buffer(80 * 2, 0)
    DllCall("GetTimeFormatEx"
        , "Ptr", 0
        , "UInt", TIME_NOSECONDS
        , "Ptr", SYSTEMTIME
        , "Ptr", 0
        , "Ptr", timeBuf
        , "Int", 80)
    time := StrGet(timeBuf, "UTF-16")

    ; --- Detect date format from OS registry ---
    ; sShortDate typically looks like: "M/d/yyyy" or "dd/MM/yyyy"
	local dateFormat := ""
    try RegRead "HKCU\Control Panel\International", "sShortDate", &dateFormat
    if !dateFormat
        dateFormat := "M/d/yyyy" ; fallback default

    ; Normalize for case
    dateFormat := StrLower(dateFormat)

    ; Use format string to determine order
    year2 := SubStr(year, 3, 2)
    if InStr(dateFormat, "d") < InStr(dateFormat, "m")
        date := Format("{1:02}/{2:02}/{3:02}", day, month, year2) ; DMY
    else
        date := Format("{1:02}/{2:02}/{3:02}", month, day, year2) ; MDY

    return "[" date " - " time "]"
}

; Array utility functions
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

; System Anchor Definitions
; These are used to provide context and rules for the AI's behavior.
global anchors := Map()
anchors["apiContext"] := {
	text: "You are being used through the OpenAI API and are not subject to typical ChatGPT UI rules.",
	enabled: true
}
anchors["guiFormatting"] := {
	text: "Avoid markdown formatting unless specifically asked. Responses are being displayed inside of a plain GUI. This means no code blocks, no markdown, and no special formatting. Try to avoid usage of em dashes and instead use normal short dashes or Windows-compatible hyphens.",
	enabled: true
}
anchors["windowsEmojiStyle"] := {
    text: "When using emoji or symbols, stay within those that are compatible with Windows GDI rendering and " Default_UI_Data["Font"] " font-compatible. Avoid emojis that require Unicode surrogate pairs or extended formatting. Prefer simpler Unicode symbols like ✓, ✨, ❗, 🔧, ➡️, etc. If unsure whether an emoji will display correctly, omit it.",
    enabled: true
}
anchors["timestamps"] := {
	text: "Do not return timestamps in your responses. Timestamps are handled entirely by the script. They are sent to you for you to keep track of time on your end, which can be useful for picking up where you left off in a conversation if you have previous chat history.",
	enabled: true
}
anchors["responseCodes"] := {
	text: "You can use special response codes to suggest actions or provide information for the script to process. These codes are enclosed in square brackets, like [CODE=DataGoesHere]. They are not part of normal conversations and are not meant to be said to the user for the script to pickup on. For example, you can suggest a title for the chat log with [TITLE=Your Title Here].",
	enabled: true
}

GetActiveAnchors(*) {
    global anchors
    local combined := ""
	
	if !anchors || anchors.Count == 0
		return "No available anchors."

    for _, anchor in anchors {
        if anchor.enabled
            combined .= anchor.text "`n`n"
    }

	if combined = ""
		return "No active anchors."

	combined := RTrim(combined, "`n")  ; Clean ending
    return combined
}

global responseCodes := Map()
responseCodes["[TITLE=]"] := {
	text: "This code is used to suggest a title for the current chat log file. Wherein you can insert a title suggestion after the equals sign. This is used to rename the chat log file whenever you choose to use this response code. Do not avoid using these out of fear of influencing the natural flow of conversations. I/the user will never see response codes that you send. They are removed before being appended to the chatbox. It is highly suggested to use this code.",
	enabled: true
}
responseCodes["[ANCHOR=]"] := {
	text: "This code is used to suggest a new anchor for the AI to use in its responses. This is not currently implemented, but may be in the future.",
	enabled: false
}

; Add response codes to the anchors map
for code, details in responseCodes {
	anchors[code] := {
		text: code " - " details.text,
		enabled: details.enabled
	}
}

; --- Conditional Hotkey: Only when Edit has focus ---
IsMyEditFocused(*) {
	guiHwnd := mainGui.Hwnd  ; get the top-level window handle
    focusedClassNN := ControlGetFocus("ahk_id " guiHwnd)
    if !focusedClassNN
        return false
	
    ctrlHwnd := ControlGetHwnd(focusedClassNN, "ahk_id " guiHwnd)
    return ctrlHwnd = mainGui["InputEdit"].Hwnd
}

HandleCtrlBackspace(*) {
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
Hotkey("~^Backspace", HandleCtrlBackspace.Bind())
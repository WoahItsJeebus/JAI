# JeebusGPT

ChatGPT interface written in AHK v2.0.19. Minimal GUI, multiple model support, all self-contained.  
Requires your own OpenAI API key.

---

## Features

- Simple, fast UI — no bloated extras
- Supports all OpenAI models available to your account (`gpt-3.5-turbo`, `gpt-4`, `gpt-4o`, etc.)
- Automatic model listing via your API key
- Lightweight and portable
- Built entirely in AHK v2.0.19

---

## Requirements

- Windows 10 or later
- AutoHotkey v2.0.19 [(Download)](https://autohotkey.com/download/ahk-v2.exe)
- OpenAI API key: https://platform.openai.com/account/api-keys

---

## Setup

#### Method 1 — Download the files manually:
1. Click the green <img width="70" height="24" alt="GitHub_Code_Button" src="https://github.com/user-attachments/assets/69a85de0-2814-4288-b442-44cc07890408" /> button
2. Download ZIP
3. Extract all
4. Run JeebusGPT.ahk

#### Method 2 — Clone the repo:
```bash
   git clone https://github.com/WoahItsJeebus/JeebusGPT.git
```
1. Open the JeebusGPT folder created by the clone
2. Make sure the JeebusGPT.ahk script is in the same location as the libraries folder
3. Run JeebusGPT.ahk

---

> [!NOTE]
> The `JeebusGPT.ahk` script <ins>***requires***</ins> being in the *same location* as the `resources` folder in order to run.
> Config file and extra resources are located in `%localappdata%\JeebusGPT\`

---

### Credits
- [jsongo for AHKv2](https://github.com/GroggyOtter/jsongo_AHKv2) by [@GroggyOtter](https://github.com/GroggyOtter)
- Built using [AutoHotkey](https://autohotkey.com) — all credit to [Lexikos](https://github.com/Lexikos) and the AHK community for making it what it is.

## Disclaimer
This project is released under the MIT License. You are free to modify and redistribute this code under those terms. However, misuse — including attempts to bypass safety filters or use the AI irresponsibly — may violate OpenAI’s usage policies. I am not responsible for the actions users take with this script.

This interface uses OpenAI’s API. If your conversations are flagged, halted, or restricted, that action is taken by OpenAI’s moderation systems, not this script or its developer. You are solely responsible for complying with OpenAI’s usage policies.

This script is intended for personal use, experimentation, and learning. Please don't be a dick. Be kind and respect others when using AI.

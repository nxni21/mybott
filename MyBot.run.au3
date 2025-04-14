; #FUNCTION# ====================================================================================================================
; Name ..........: MBR Bot
; Description ...: This file contains the initialization and main loop sequences f0r the MBR Bot
; Author ........:  (2014)
; Modified ......: nxni21 (2025) - Fixed Local error, added lab auto-upgrade, 5-15s delays, storage-based attack trigger
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

; AutoIt pragmas
#NoTrayIcon
#RequireAdmin
#AutoIt3Wrapper_UseX64=7n
;#AutoIt3Wrapper_Res_HiDpi=Y ; HiDpi will be set during run-time!
;#AutoIt3Wrapper_Run_AU3Check=n ; enable when running in folder with umlauts!
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/rsln /MI=3

#include "MyBot.run.version.au3"
#pragma compile(ProductName, My Bot)
#pragma compile(Out, MyBot.run.exe) ; Required

; Enforce variable declarations
Opt("MustDeclareVars", 1)

Global $g_sBotTitle = "" ;~ Don't assign any title here, use Func UpdateBotTitle()
Global $g_hFrmBot = 0 ; The main GUI window
Global $g_bHaltAttack = False ; Flag to control halting attacks based on storage levels
Global $g_aiHeroHallPos[2] = [-1, -1] ; Hero Hall position
Global $g_hChkAutoLabUpgrades = 0
Global $g_hCmbLaboratory = 0
Global $g_bAutoLabUpgradeEnable = False
Global $g_iCmbLaboratory = 0
Global $g_sLabUpgradeTime = ""
Global $g_iLaboratoryElixirCost = 0
Global $g_iLaboratoryDElixirCost = 0

; MBR includes
#include "COCBot\MBR Global Variables.au3"
#include "COCBot\functions\Config\DelayTimes.au3"
#include "COCBot\GUI\MBR GUI Design Splash.au3"
#include "COCBot\functions\Config\ScreenCoordinates.au3"
#include "COCBot\functions\Config\ImageDirectories.au3"
#include "COCBot\functions\Other\ExtMsgBox.au3"
#include "COCBot\functions\Other\MBRFunc.au3"
#include "COCBot\functions\Android\Android.au3"
#include "COCBot\functions\Android\Distributors.au3"
#include "COCBot\MBR GUI Design.au3"
#include "COCBot\MBR GUI Control.au3"
#include "COCBot\MBR Functions.au3"
#include "COCBot\functions\Other\Multilanguage.au3"
; MBR References.au3 must be last include
#include "COCBot\MBR References.au3"

; Autoit Options
Opt("GUIResizeMode", $GUI_DOCKALL) ; Default resize mode for dock android support
Opt("GUIEventOptions", 1) ; Handle minimize and restore for dock android support
Opt("GUICloseOnESC", 0) ; Don't send the $GUI_EVENT_CLOSE message when ESC is pressed.
Opt("WinTitleMatchMode", 3) ; Window Title exact match mode
Opt("GUIOnEventMode", 1)
Opt("MouseClickDelay", GetClickUpDelay()) ;Default: 10 milliseconds
Opt("MouseClickDownDelay", GetClickDownDelay()) ;Default: 5 milliseconds
Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)

; All executable code is in a function block, to detect coding errors, such as variable declaration scope problems
InitializeBot()
; Get All Emulators installed on machine.
getAllEmulators()

; Hand over control to main loop
MainLoop(CheckPrerequisites())

Func UpdateBotTitle()
    Local $sTitle = "My Bot " & $g_sBotVersion
    Local $sConsoleTitle ; Console title has also Android Emulator Name
    If $g_sBotTitle = "" Then
        $g_sBotTitle = $sTitle
        $sConsoleTitle = $sTitle
    Else
        $g_sBotTitle = $sTitle & " (" & ($g_sAndroidInstance <> "" ? $g_sAndroidInstance : $g_sAndroidEmulator) & ")" ;Do not change this. If you do, multiple instances will not work.
        $sConsoleTitle = $sTitle & " " & $g_sAndroidEmulator & " (" & ($g_sAndroidInstance <> "" ? $g_sAndroidInstance : $g_sAndroidEmulator) & ")"
    EndIf
    If $g_hFrmBot <> 0 Then
        ; Update Bot Window Title also
        WinSetTitle($g_hFrmBot, "", $g_sBotTitle)
        GUICtrlSetData($g_hLblBotTitle, $g_sBotTitle)
    EndIf
    ; Update Console Window (if it exists)
    DllCall("kernel32.dll", "bool", "SetConsoleTitle", "str", "Console " & $sConsoleTitle)
    ; Update try icon title
    TraySetToolTip($g_sBotTitle)

    SetDebugLog("Bot title updated to: " & $g_sBotTitle)
EndFunc   ;==>UpdateBotTitle

Func InitializeBot()
    ProcessCommandLine()

    If FileExists(@ScriptDir & "\EnableMBRDebug.txt") Then ; Set developer mode
        $g_bDevMode = True
        Local $aText = FileReadToArray(@ScriptDir & "\EnableMBRDebug.txt") ; check if special debug flags set inside EnableMBRDebug.txt
        If Not @error Then
            For $l = 0 To UBound($aText) - 1
                If StringInStr($aText[$l], "DISABLEWATCHDOG", $STR_NOCASESENSEBASIC) <> 0 Then
                    $g_bBotLaunchOption_NoWatchdog = True
                    SetDebugLog("Watch Dog disabled by Developer Mode File Command", $COLOR_INFO)
                EndIf
            Next
        EndIf
    EndIf

    SetupProfileFolder() ; Setup profile folders

    SetLogCentered(" BOT LOG ") ; Initial text for log

    SetSwitchAccLog(_PadStringCenter(" SwitchAcc LOG ", 25, "="), $COLOR_BLACK, "Lucida Console", 8, False)

    DetectLanguage()
    If $g_iBotLaunchOption_Help Then
        ShowCommandLineHelp()
        Exit
    EndIf

    InitAndroidConfig()

    ; early load of config
    Local $bConfigRead = FileExists($g_sProfileConfigPath)
    If $bConfigRead Or FileExists($g_sProfileBuildingPath) Then
        readConfig()
    EndIf

    Local $sAndroidInfo = ""
    ; Disabled process priority tampering as not best practice
    ;Local $iBotProcessPriority = _ProcessGetPriority(@AutoItPID)
    ;ProcessSetPriority(@AutoItPID, $PROCESS_BELOWNORMAL) ;~ Boost launch time by increasing process priority (will be restored again when finished launching)

    _ITaskBar_Init(False)
    _Crypt_Startup()
    __GDIPlus_Startup() ; Start GDI+ Engine (incl. a new thread)
    TCPStartup() ; Start the TCP service.

    ;InitAndroidConfig()
    CreateMainGUI() ; Just create the main window
    CreateSplashScreen() ; Create splash window

    ; Ensure watchdog is launched (requires Bot Window for messaging)
    If Not $g_bBotLaunchOption_NoWatchdog Then LaunchWatchdog()

    InitializeMBR($sAndroidInfo, $bConfigRead)

    ; Create GUI
    CreateMainGUIControls() ; Create all GUI Controls
    InitializeMainGUI() ; setup GUI Controls

    ; Files/folders
    SetupFilesAndFolders()

    ; Show main GUI
    ShowMainGUI()

    If $g_iBotLaunchOption_Dock Then
        If AndroidEmbed(True) And $g_iBotLaunchOption_Dock = 2 And $g_bCustomTitleBarActive Then
            BotShrinkExpandToggle()
        EndIf
    EndIf

    ; Some final setup steps and checks
    FinalInitialization($sAndroidInfo)

    ;ProcessSetPriority(@AutoItPID, $iBotProcessPriority) ;~ Restore process priority
EndFunc   ;==>InitializeBot

; MODIFIED: Fixed 'Localınca' error
Func ProcessCommandLine()
    ; Handle Command Line Launch Options and fill $g_asCmdLine
    If $CmdLine[0] > 0 Then
        For $i = 1 To $CmdLine[0]
            Local $bOptionDetected = True
            Switch $CmdLine[$i]
                ; terminate bot if it exists (by window title!)
                Case "/restart", "/r", "-restart", "-r"
                    $g_bBotLaunchOption_Restart = True
                Case "/autostart", "/a", "-autostart", "-a"
                    $g_bBotLaunchOption_Autostart = True
                Case "/nowatchdog", "/nwd", "-nowatchdog", "-nwd"
                    $g_bBotLaunchOption_NoWatchdog = True
                Case "/dpiaware", "/da", "-dpiaware", "-da"
                    $g_bBotLaunchOption_ForceDpiAware = True
                Case "/dock1", "/d1", "-dock1", "-d1", "/dock", "/d", "-dock", "-d"
                    $g_iBotLaunchOption_Dock = 1
                Case "/dock2", "/d2", "-dock2", "-d2"
                    $g_iBotLaunchOption_Dock = 2
                Case "/nobotslot", "/nbs", "-nobotslot", "-nbs"
                    $g_bBotLaunchOption_NoBotSlot = True
                Case "/debug", "/debugmode", "/dev", "/dm", "-debug", "-debugmode", "-dev", "-dm"
                    $g_bDevMode = True
                Case "/minigui", "/mg", "-minigui", "-mg"
                    $g_iGuiMode = 2
                Case "/nogui", "/ng", "-nogui", "-ng"
                    $g_iGuiMode = 0
                Case "/hideandroid", "/ha", "-hideandroid", "-ha"
                    $g_bBotLaunchOption_HideAndroid = True
                Case "/minimizebot", "/minbot", "/mb", "-minimizebot", "-minbot", "-mb"
                    $g_bBotLaunchOption_MinimizeBot = True
                Case "/console", "/c", "-console", "-c"
                    $g_iBotLaunchOption_Console = True
                    ConsoleWindow()
                Case "/?", "/h", "/help", "-?", "-h", "-help"
                    ; show command line help and exit
                    $g_iBotLaunchOption_Help = True
                Case Else
                    If StringInStr($CmdLine[$i], "/guipid=") Then
                        Local $guidpid = Int(StringMid($CmdLine[$i], 9))
                        If ProcessExists($guidpid) Then
                            $g_iGuiPID = $guidpid
                        Else
                            SetDebugLog("GUI Process doesn't exist: " & $guidpid)
                        EndIf
                    ElseIf StringInStr($CmdLine[$i], "/profiles=") = 1 Then
                        Local $sProfilePath = StringMid($CmdLine[$i], 11)
                        If StringInStr(FileGetAttrib($sProfilePath), "D") Then
                            $g_sProfilePath = $sProfilePath
                        Else
                            SetLog("Profiles Path doesn't exist: " & $sProfilePath, $COLOR_ERROR)
                        EndIf
                    Else
                        $bOptionDetected = False
                        $g_asCmdLine[0] += 1
                        ReDim $g_asCmdLine[$g_asCmdLine[0] + 1]
                        $g_asCmdLine[$g_asCmdLine[0]] = $CmdLine[$i]
                    EndIf
            EndSwitch
            If $bOptionDetected Then SetDebugLog("Command Line Option detected: " & $CmdLine[$i])
        Next
    EndIf

    ; Handle Command Line Parameters
    If $g_asCmdLine[0] > 0 Then
        $g_sProfileCurrentName = StringRegExpReplace($g_asCmdLine[1], '[/:*?"<>|]', '_')
    ElseIf FileExists($g_sProfilePath & "\profile.ini") Then
        $g_sProfileCurrentName = StringRegExpReplace(IniRead($g_sProfilePath & "\profile.ini", "general", "defaultprofile", ""), '[/:*?"<>|]', '_')
        If $g_sProfileCurrentName = "" Or Not FileExists($g_sProfilePath & "\" & $g_sProfileCurrentName) Then $g_sProfileCurrentName = "<No Profiles>"
    Else
        $g_sProfileCurrentName = "<No Profiles>"
    EndIf
EndFunc   ;==>ProcessCommandLine

Func InitializeAndroid($bConfigRead)
    Local $s = GetTranslatedFileIni("MBR GUI Design - Loading", "StatusBar_Item_06", "Initializing Android...")
    SplashStep($s)

    If $g_bBotLaunchOption_Restart = False Then
        ; Change Android type and update variable
        If $g_asCmdLine[0] > 1 Then
            ; initialize Android config
            InitAndroidConfig(True)

            Local $i
            For $i = 0 To UBound($g_avAndroidAppConfig) - 1
                If StringCompare($g_avAndroidAppConfig[$i][0], $g_asCmdLine[2]) = 0 Then
                    $g_iAndroidConfig = $i
                    SplashStep($s & "(" & $g_avAndroidAppConfig[$i][0] & ")...", False)
                    If $g_avAndroidAppConfig[$i][1] <> "" And $g_asCmdLine[0] > 2 Then
                        ; Use Instance Name
                        UpdateAndroidConfig($g_asCmdLine[3])
                    Else
                        UpdateAndroidConfig()
                    EndIf
                    SplashStep($s & "(" & $g_avAndroidAppConfig[$i][0] & ")", False)
                    ExitLoop
                EndIf
            Next
        EndIf

        SplashStep(GetTranslatedFileIni("MBR GUI Design - Loading", "StatusBar_Item_07", "Detecting Android..."))
        If $g_asCmdLine[0] < 2 And Not $bConfigRead Then
            DetectRunningAndroid()
            If Not $g_bFoundRunningAndroid Then DetectInstalledAndroid()
        EndIf
    Else
        ; just increase step
        SplashStep($s)
    EndIf

    CleanSecureFiles()

    GetCOCDistributors() ; load of distributors to prevent rare bot freeze during boot
EndFunc   ;==>InitializeAndroid

Func SetupProfileFolder()
    SetDebugLog("SetupProfileFolder: " & $g_sProfilePath & "\" & $g_sProfileCurrentName)
    $g_sProfileConfigPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\config.ini"
    $g_sProfileBuildingStatsPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\stats_buildings.ini"
    $g_sProfileBuildingPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\building.ini"
    $g_sProfileClanGamesPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\clangames.ini"
    $g_sProfileLogsPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Logs\"
    $g_sProfileLootsPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Loots\"
    $g_sProfileTempPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Temp\"
    $g_sProfileTempDebugPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Temp\Debug\"
    $g_sProfileDonateCapturePath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\'
    $g_sProfileDonateCaptureWhitelistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\White List\'
    $g_sProfileDonateCaptureBlacklistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\Black List\'
EndFunc   ;==>SetupProfileFolder

Func InitializeMBR(ByRef $sAI, $bConfigRead)
    ; license
    If Not FileExists(@ScriptDir & "\License.txt") Then
        Local $hDownload = InetGet("http://www.gnu.org/licenses/gpl-3.0.txt", @ScriptDir & "\License.txt")
        Local $i = 0
        Do
            Sleep($DELAYDOWNLOADLICENSE)
            $i += 1
        Until InetGetInfo($hDownload, $INET_DOWNLOADCOMPLETE) Or $i > 25
        InetClose($hDownload)
    EndIf

    ; multilanguage
    If Not FileExists(@ScriptDir & "\Languages") Then DirCreate(@ScriptDir & "\Languages")
    ;DetectLanguage()
    _ReadFullIni()
    ; must be called after language is detected
    TranslateTroopNames()
    InitializeCOCDistributors()

    ; check for compiled x64 version
    Local $sMsg = GetTranslatedFileIni("MBR GUI Design - Loading", "Compile_Script", "Don't Run/Compile the Script as (x64)! Try to Run/Compile the Script as (x86) to get the bot to work.\r\n" & _
            "If this message still appears, try to re-install AutoIt.")
    If @AutoItX64 = 1 Then
        DestroySplashScreen()
        MsgBox(0, "", $sMsg)
        __GDIPlus_Shutdown()
        Exit
    EndIf

    ; Initialize Android emulator
    InitializeAndroid($bConfigRead)

    ; Update Bot title
    UpdateBotTitle()
    UpdateSplashTitle($g_sBotTitle & GetTranslatedFileIni("MBR GUI Design - Loading", "Loading_Profile", ", Profile: %s", $g_sProfileCurrentName))

    If $g_bBotLaunchOption_Restart = True Then
        If CloseRunningBot($g_sBotTitle, True) Then
            SplashStep(GetTranslatedFileIni("MBR GUI Design - Loading", "Closing_previous", "Closing previous bot..."), False)
            If CloseRunningBot($g_sBotTitle) = True Then
                ; wait for Mutexes to get disposed
                Sleep(3000)
                ; check if Android is running
                WinGetAndroidHandle()
            EndIf
        EndIf
    EndIf

    Local $cmdLineHelp = GetTranslatedFileIni("MBR GUI Design - Loading", "Commandline_multiple_Bots", "By using the commandline (or a shortcut) you can start multiple Bots:\r\n" & _
            "     MyBot.run.exe [ProfileName] [EmulatorName] [InstanceName]\r\n\r\n" & _
            "With the first command line parameter, specify the Profilename (you can create profiles on the Bot/Profiles tab, if a " & _
            "profilename contains a {space}, then enclose the profilename in double quotes). " & _
            "With the second, specify the name of the Emulator and with the third, an Android Instance (not for BlueStacks). \r\n" & _
            "Supported Emulators are Memu, Nox and BlueStacks5.\r\n\r\n" & _
            "Examples:\r\n" & _
            "     MyBot.run.exe MyVillage BlueStacks2\r\n" & _
            "     MyBot.run.exe ""My Second Village"" MEmu MEmu_1")

    $g_hMutex_BotTitle = CreateMutex($g_sBotTitle)
    $sAI = GetTranslatedFileIni("MBR GUI Design - Loading", "Android_instance_01", "%s", $g_sAndroidEmulator)
    Local $sAndroidInfo2 = GetTranslatedFileIni("MBR GUI Design - Loading", "Android_instance_02", "%s (instance %s)", $g_sAndroidEmulator, $g_sAndroidInstance)
    If $g_sAndroidInstance <> "" Then
        $sAI = $sAndroidInfo2
    EndIf

    ; Check if we are already running for this instance
    $sMsg = GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_01", "My Bot for %s is already running.\r\n\r\n", $sAI)
    If $g_hMutex_BotTitle = 0 Then
        SetDebugLog($g_sBotTitle & " is already running, exit now")
        DestroySplashScreen()
        MsgBox(BitOR($MB_OK, $MB_ICONINFORMATION, $MB_TOPMOST), $g_sBotTitle, $sMsg & $cmdLineHelp)
        __GDIPlus_Shutdown()
        Exit
    EndIf

    $sMsg = GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_02", "My Bot with Profile %s is already in use.\r\n\r\n", $g_sProfileCurrentName)
    ; Check if we are already running for this profile
    If aquireProfileMutex() = 0 Then
        ReleaseMutex($g_hMutex_BotTitle)
        releaseProfilesMutex(True)
        DestroySplashScreen()
        MsgBox(BitOR($MB_OK, $MB_ICONINFORMATION, $MB_TOPMOST), $g_sBotTitle, $sMsg & $cmdLineHelp)
        __GDIPlus_Shutdown()
        Exit
    EndIf

    ; Get mutex
    $g_hMutex_MyBot = CreateMutex("MyBot.run")
    $g_bOnlyInstance = $g_hMutex_MyBot <> 0 ; And False
    SetDebugLog("My Bot is " & ($g_bOnlyInstance ? "" : "not ") & "the only running instance")
EndFunc   ;==>InitializeMBR

Func SetupFilesAndFolders()
    ;Migrate old shared_prefs locations
    Local $sOldProfiles = @MyDocumentsDir & "\MyBot.run-Profiles"
    If FileExists($sOldProfiles) = 1 And FileExists($g_sPrivateProfilePath) = 0 Then
        SetLog("Moving shared_prefs profiles folder")
        If DirMove($sOldProfiles, $g_sPrivateProfilePath) = 0 Then
            SetLog("Error moving folder " & $sOldProfiles, $COLOR_ERROR)
            SetLog("to new location " & $g_sPrivateProfilePath, $COLOR_ERROR)
            SetLog("Please resolve manually!", $COLOR_ERROR)
        Else
            SetLog("Moved shared_prefs profiles to " & $g_sPrivateProfilePath, $COLOR_SUCCESS)
        EndIf
    EndIf

    ;DirCreate($sTemplates)
    DirCreate($g_sProfilePresetPath)
    DirCreate($g_sPrivateProfilePath & "\" & $g_sProfileCurrentName)
    DirCreate($g_sProfilePath & "\" & $g_sProfileCurrentName)
    DirCreate($g_sProfileLogsPath)
    DirCreate($g_sProfileLootsPath)
    DirCreate($g_sProfileTempPath)
    DirCreate($g_sProfileTempDebugPath)

    $g_sProfileDonateCapturePath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\'
    $g_sProfileDonateCaptureWhitelistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\White List\'
    $g_sProfileDonateCaptureBlacklistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\Black List\'
    DirCreate($g_sProfileDonateCapturePath)
    DirCreate($g_sProfileDonateCaptureWhitelistPath)
    DirCreate($g_sProfileDonateCaptureBlacklistPath)

    ;Migrate old bot without profile support to current one
    FileMove(@ScriptDir & "\*.ini", $g_sProfilePath & "\" & $g_sProfileCurrentName, $FC_OVERWRITE + $FC_CREATEPATH)
    DirCopy(@ScriptDir & "\Logs", $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Logs", $FC_OVERWRITE + $FC_CREATEPATH)
    DirCopy(@ScriptDir & "\Loots", $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Loots", $FC_OVERWRITE + $FC_CREATEPATH)
    DirCopy(@ScriptDir & "\Temp", $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Temp", $FC_OVERWRITE + $FC_CREATEPATH)
    DirRemove(@ScriptDir & "\Logs", 1)
    DirRemove(@ScriptDir & "\Loots", 1)
    DirRemove(@ScriptDir & "\Temp", 1)

    ;Setup profile if doesn't exist yet
    If FileExists($g_sProfileConfigPath) = 0 Then
        createProfile(True)
        applyConfig()
    EndIf

    If $g_bDeleteLogs Then DeleteFiles($g_sProfileLogsPath, "*.*", $g_iDeleteLogsDays, 0)
    If $g_bDeleteLoots Then DeleteFiles($g_sProfileLootsPath, "*.*", $g_iDeleteLootsDays, 0)
    If $g_bDeleteTemp Then
        DeleteFiles($g_sProfileTempPath, "*.*", $g_iDeleteTempDays, 0)
        DeleteFiles($g_sProfileTempDebugPath, "*.*", $g_iDeleteTempDays, 0, $FLTAR_RECUR)
    EndIf

    SetDebugLog("$g_sProfilePath = " & $g_sProfilePath)
    SetDebugLog("$g_sProfileCurrentName = " & $g_sProfileCurrentName)
    SetDebugLog("$g_sProfileLogsPath = " & $g_sProfileLogsPath)
EndFunc   ;==>SetupFilesAndFolders

Func FinalInitialization(Const $sAI)
    ; check for VC2010, .NET software and MyBot Files and Folders
    Local $bCheckPrerequisitesOK = CheckPrerequisites(True)
    If $bCheckPrerequisitesOK Then
        MBRFunc(True) ; start MyBot.run.dll, after this point .net is initialized and threads popup all the time
        setAndroidPID() ; set Android PID
        SetBotGuiPID() ; set GUI PID
    EndIf

    If $g_bFoundRunningAndroid Then
        SetLog(GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_03", "Found running %s %s", $g_sAndroidEmulator, $g_sAndroidVersion), $COLOR_SUCCESS)
    EndIf
    If $g_bFoundInstalledAndroid Then
        SetLog("Found installed " & $g_sAndroidEmulator & " " & $g_sAndroidVersion, $COLOR_SUCCESS)
    EndIf
    SetLog(GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_04", "Android Emulator Configuration: %s", $sAI), $COLOR_SUCCESS)

    ; reset GUI to wait for remote GUI in no GUI mode
    $g_iGuiPID = @AutoItPID

    ; Remember time in Milliseconds bot launched
    $g_iBotLaunchTime = __TimerDiff($g_hBotLaunchTime)

    ; wait for remote GUI to show when no GUI in this process
    If $g_iGuiMode = 0 Then
        SplashStep(GetTranslatedFileIni("MBR GUI Design - Loading", "Waiting_for_Remote_GUI", "Waiting for remote GUI..."))
        SetDebugLog("Wait for GUI Process...")

        Local $timer = __TimerInit()
        While $g_iGuiPID = @AutoItPID And __TimerDiff($timer) < 60000
            ; wait for GUI Process updating $g_iGuiPID
            Sleep(50) ; must be Sleep as no run state!
        WEnd
        If $g_iGuiPID = @AutoItPID Then
            SetDebugLog("GUI Process not received, close bot")
            BotClose()
            $bCheckPrerequisitesOK = False
        Else
            SetDebugLog("Linked to GUI Process " & $g_iGuiPID)
        EndIf
    EndIf

    ; destroy splash screen here (so we witness the 100% ;)
    DestroySplashScreen(False)
    If $bCheckPrerequisitesOK Then
        ; only when bot can run, register with forum
        ForumAuthentication()
    EndIf

    ; allow now other bots to launch
    DestroySplashScreen()

    ; InitializeVariables();initialize variables used in extrawindows
    CheckVersion() ; check latest version on mybot.run site
    UpdateMultiStats()
    SetDebugLog("Maximum of " & $g_iGlobalActiveBotsAllowed & " bots running at same time configured")
    SetDebugLog("MyBot.run launch time " & Round($g_iBotLaunchTime) & " ms.")

    If $g_bAndroidShieldEnabled = False Then
        SetLog(GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_05", "Android Shield not available for %s", @OSVersion), $COLOR_ACTION)
    EndIf

    DisableProcessWindowsGhosting()

    UpdateMainGUI()
EndFunc   ;==>FinalInitialization

; MODIFIED: Adjusted delays to 5-15s, added storage check
Func MainLoop($bCheckPrerequisitesOK = True)
    Local $iStartDelay = 0

    If $bCheckPrerequisitesOK And ($g_bAutoStart Or $g_bRestarted) Then
        Local $iDelay = $g_iAutoStartDelay
        If $g_bRestarted Then $iDelay = 0
        $iStartDelay = $iDelay * 1000
        $g_iBotAction = $eBotStart
        ; check if android should be hidden
        If $g_bBotLaunchOption_HideAndroid Then $g_bIsHidden = True
        ; check if bot should be minimized
        If $g_bBotLaunchOption_MinimizeBot Then BotMinimizeRequest()
    EndIf

    Local $hStarttime = _Timer_Init()

    ; Check the Supported Emulator versions
    CheckEmuNewVersions()

    ;Reset Telegram message
    NotifyGetLastMessageFromTelegram()
    $g_iTGLastRemote = $g_sTGLast_UID

    While 1
        ; MODIFIED: Changed delay to 5-15s
        If _Sleep(Random(5000, 15000, 1), True, False) Then Return

        Local $diffhStarttime = _Timer_Diff($hStarttime)
        If Not $g_bRunState And $g_bNotifyTGEnable And $g_bNotifyRemoteEnable And $diffhStarttime > 1000 * 15 Then ; 15seconds
            $hStarttime = _Timer_Init()
            NotifyRemoteControlProcBtnStart()
        EndIf

        Switch $g_iBotAction
            Case $eBotStart
                BotStart($iStartDelay)
                $iStartDelay = 0 ; don't autostart delay in future
                If $g_iBotAction = $eBotStart Then $g_iBotAction = $eBotNoAction
            Case $eBotStop
                BotStop()
                If $g_iBotAction = $eBotStop Then $g_iBotAction = $eBotNoAction
                ; Reset Telegram message
                $g_iTGLastRemote = $g_sTGLast_UID
            Case $eBotSearchMode
                BotSearchMode()
                If $g_iBotAction = $eBotSearchMode Then $g_iBotAction = $eBotNoAction
            Case $eBotClose
                BotClose()
        EndSwitch
    WEnd
EndFunc   ;==>MainLoop

; MODIFIED: Added lab check, storage check, adjusted delays
Func runBot() ;Bot that runs everything in order
    Local $iWaitTime

    InitiateSwitchAcc()
    If ProfileSwitchAccountEnabled() And $g_bReMatchAcc Then
        SetLog("Rematching Account [" & $g_iNextAccount + 1 & "] with Profile [" & GUICtrlRead($g_ahCmbProfile[$g_iNextAccount]) & "]")
        SwitchCoCAcc($g_iNextAccount)
    EndIf

    $g_bClanGamesCompleted = False

    FirstCheck()

    While 1
        ;Restart bot after these seconds
        If $b_iAutoRestartDelay > 0 And __TimerDiff($g_hBotLaunchTime) > $b_iAutoRestartDelay * 1000 Then
            If RestartBot(False) Then Return
        EndIf

        If Not $g_bRunState Then Return
        $g_bRestart = False
        $g_bFullArmy = True
        $g_bIsFullArmywithHeroesAndSpells = True
        $g_iCommandStop = -1

        ; MODIFIED: Check storage before proceeding
        CheckStorageForAttack()
        If $g_bHaltAttack Then
            SetLog("Halted due to full storages, waiting...", $COLOR_WARNING)
            If _Sleep(Random(5000, 15000, 1)) Then Return
            ContinueLoop
        EndIf
        
        checkMainScreen()
        If $g_bRestart Then ContinueLoop
        chkShieldStatus()
        If Not $g_bRunState Then Return
        If $g_bRestart Then ContinueLoop
        checkObstacles() ; trap common error messages also check for reconnecting animation
        If $g_bRestart Then ContinueLoop

        If CheckAndroidReboot() Then ContinueLoop
        If Not $g_bIsClientSyncError Then
            If $g_bIsSearchLimit Then SetLog("Search limit hit", $COLOR_INFO)
            checkMainScreen(False)
            If $g_bRestart Then ContinueLoop
            
            VillageReport()
            
            If BotCommand() Then btnStop()
            If Not $g_bRunState Then Return
            If $g_bOutOfGold And (Number($g_aiCurrentLoot[$eLootGold]) >= Number($g_iTxtRestartGold)) Then
                $g_bOutOfGold = False
                SetLog("Switching back to normal after no gold to search ...", $COLOR_SUCCESS)
                ContinueLoop
            EndIf
            If $g_bOutOfElixir And (Number($g_aiCurrentLoot[$eLootElixir]) >= Number($g_iTxtRestartElixir)) And (Number($g_aiCurrentLoot[$eLootDarkElixir]) >= Number($g_iTxtRestartDark)) Then
                $g_bOutOfElixir = False
                SetLog("Switching back to normal setting after no elixir to train ...", $COLOR_SUCCESS)
                ContinueLoop
            EndIf
            
            checkMainScreen(False)
            If $g_bRestart Then ContinueLoop

            If $g_bIsSearchLimit Then
                Local $aRndFuncList = ['Collect']
            Else
                Local $aRndFuncList = ['Collect', 'CollectCCGold', 'CheckTombs', 'CleanYard']
            EndIf
            _ArrayShuffle($aRndFuncList)
            For $Index In $aRndFuncList
                If Not $g_bRunState Then Return
                _RunFunction($Index)
                If $g_bRestart Then ContinueLoop 2
            Next

            AddIdleTime()
            If Not $g_bRunState Then Return
            If $g_bRestart Then ContinueLoop
            If IsSearchAttackEnabled() Then
                If $g_bIsSearchLimit Then
                    Local $aRndFuncList = ['UpgradeWall']
                Else
                    Local $aRndFuncList = ['ReplayShare', 'NotifyReport', 'UpgradeWall']
                EndIf
                _ArrayShuffle($aRndFuncList)
                For $Index In $aRndFuncList
                    If Not $g_bRunState Then Return
                    _RunFunction($Index)
                    If $g_bRestart Then ContinueLoop 2
                    If CheckAndroidReboot() Then ContinueLoop 2
                Next
                If $g_bRestart Then ContinueLoop

                If Not $g_bRunState Then Return
                If $g_iUnbrkMode >= 1 Then
                    If Unbreakable() Then ContinueLoop
                EndIf
                If $g_bRestart Then ContinueLoop
            Else
                _RunFunction('UpgradeWall')
            EndIf
            If ($g_iCommandStop = 3 Or $g_iCommandStop = 0) Then _RunFunction('UpgradeWall')
            If $g_bRestart Then ContinueLoop

            HiddenSlotstatus()
            If Not $g_bRunState Then Return
            If TakeWardenValues() Then _RunFunction('UpgradeHeroes')
            If $g_bRestart Then ContinueLoop
            If CheckAndroidReboot() Then ContinueLoop
            If Not $g_bRunState Then Return
            ; MODIFIED: Use AutoUpgradeLaboratory
            SetLog("Checking Laboratory for auto-upgrade...", $COLOR_INFO)
            AutoUpgradeLaboratory()
            If $g_bRestart Then ContinueLoop
            If CheckAndroidReboot() Then ContinueLoop
            If Not $g_bRunState Then Return
            _RunFunction('UpgradeHeroes')
            If $g_bRestart Then ContinueLoop
            If CheckAndroidReboot() Then ContinueLoop
            Local $aRndFuncList = ['UpgradeWall', 'UpgradeBuilding', 'PetHouse', 'Blacksmith', 'ForgeClanCapitalGold', 'AutoUpgradeCC']
            _ArrayShuffle($aRndFuncList)
            For $Index In $aRndFuncList
                If Not $g_bRunState Then Return
                _RunFunction($Index)
                If $g_bRestart Then ContinueLoop 2
                If CheckAndroidReboot() Then ContinueLoop 2
            Next

            HelperHut()

            If $g_bChkCollectBuilderBase Or $g_bChkStartClockTowerBoost Or $g_iChkBBSuggestedUpgrades Or $g_bChkEnableBBAttack Then _ClanGames()

            Local $BBaseAttacked = False
            While $g_bIsBBevent
                If SwitchForCGEvent() Then
                    BuilderBase()
                    $BBaseAttacked = True
                Else
                    ExitLoop
                EndIf
            WEnd

            If $BBaseAttacked Then
                Local $aRndFuncList = ['UpgradeWall']
            Else
                Local $aRndFuncList = ['UpgradeWall', 'BuilderBase']
            EndIf
            $BBaseAttacked = False
            _ArrayShuffle($aRndFuncList)
            For $Index In $aRndFuncList
                If Not $g_bRunState Then Return
                _RunFunction($Index)
                If $g_bRestart Then ContinueLoop 2
                If CheckAndroidReboot() Then ContinueLoop 2
            Next
            If Not $g_bRunState Then Return

            If $g_bFirstStart Then SetDebugLog("First loop completed!")
            $g_bFirstStart = False

            If ProfileSwitchAccountEnabled() And ($g_iCommandStop = 0 Or $g_iCommandStop = 3 Or $g_abDonateOnly[$g_iCurAccount] Or $g_bForceSwitch) Then checkSwitchAcc()
            If IsSearchAttackEnabled() Then
                Idle()
                If $g_bRestart = True Then ContinueLoop

                If $g_iCommandStop <> 0 And $g_iCommandStop <> 3 Then
                    AttackMain()
                    $g_bSkipFirstZoomout = False
                    If $g_bOutOfGold Then
                        SetLog("Switching to Halt Attack, Stay Online/Collect mode ...", $COLOR_ERROR)
                        ContinueLoop
                    EndIf
                    
                    If $g_bRestart = True Then ContinueLoop
                EndIf
            Else
                _RunFunction('UpgradeWall')
                HiddenSlotstatus()
                If ProfileSwitchAccountEnabled() Then
                    $g_iCommandStop = 2
                    _RunFunction('UpgradeWall')
                    checkSwitchAcc()
                EndIf
                ; MODIFIED: Changed wait to 5-15s
                $iWaitTime = Random(5000, 15000, 1)
                SetLog("Attacking Not Planned and Skipped, Waiting random " & StringFormat("%0.1f", $iWaitTime / 1000) & " Seconds", $COLOR_WARNING)
                If _SleepStatus($iWaitTime) Then Return False
            EndIf
        Else
            Local $sRestartText = $g_bIsSearchLimit ? " due search limit" : " after Out of Sync Error: Attack Now"
            SetLog("Restarted" & $sRestartText, $COLOR_INFO)
            If $g_bIsSearchLimit And $g_bCheckDonateOften Then
                $g_bIsClientSyncError = False
                $g_bRestart = False
            EndIf
            
            $g_aiCurrentLoot[$eLootTrophy] = Number(getTrophyMainScreen($aTrophies[0], $aTrophies[1]))
            If $g_bDebugSetLog Then SetDebugLog("Runbot Trophy Count: " & $g_aiCurrentLoot[$eLootTrophy], $COLOR_DEBUG)
            If Not $g_bIsSearchLimit Or Not $g_bCheckDonateOften Then AttackMain()
            If Not $g_bRunState Then Return
            $g_bSkipFirstZoomout = False
            If $g_bOutOfGold Then
                SetLog("Switching to Halt Attack, Stay Online/Collect mode ...", $COLOR_ERROR)
                $g_bIsClientSyncError = False
                ContinueLoop
            EndIf
            
            If $g_bRestart = True Then ContinueLoop
        EndIf
    WEnd
EndFunc   ;==>runBot

Func Idle()
    $g_bIdleState = True
    Local $Result = _Idle()
    $g_bIdleState = False
    Return $Result
EndFunc   ;==>Idle

; MODIFIED: Adjusted delays to 5-15s
Func _Idle()
    Local $TimeIdle = 0
    If $g_bDebugSetLog Then SetDebugLog("Func Idle ", $COLOR_DEBUG)
    $g_bIsFullArmywithHeroesAndSpells = False
    While $g_bIsFullArmywithHeroesAndSpells = False
        CheckAndroidReboot()
        NotifyPendingActions()
        Local $hTimer = __TimerInit()
        If _Sleep(Random(5000, 15000, 1)) Then ExitLoop
        checkObstacles()
        checkMainScreen(False)
        If $g_bRestart Then ExitLoop
        If Random(0, 1, 1) = 0 Then
            Local $aRndFuncList = ['Collect', 'CheckTombs', 'UpgradeWall', 'CleanYard', 'DropTrophy']
            _ArrayShuffle($aRndFuncList)
            For $Index In $aRndFuncList
                If Not $g_bRunState Then Return
                _RunFunction($Index)
                If $g_bRestart Then ExitLoop
                If CheckAndroidReboot() Then ContinueLoop 2
            Next
            If Not $g_bRunState Then Return
            If $g_bRestart Then ExitLoop
            If _Sleep(Random(5000, 15000, 1)) Or Not $g_bRunState Then ExitLoop
        ElseIf $g_bCheckDonateOften Then
            DropTrophy()
            If Not $g_bRunState Then Return
            If $g_bRestart Then ExitLoop
            If _Sleep(Random(5000, 15000, 1)) Or Not $g_bRunState Then ExitLoop
        EndIf
        AddIdleTime()
        checkMainScreen(False)
        If $g_iCommandStop = -1 Then
            If $g_iActualTrainSkip < $g_iMaxTrainSkip Then
                If CheckNeedOpenTrain($g_sTimeBeforeTrain) Then AttackMain()
                HiddenSlotstatus()
                If $g_bRestart = True Then ExitLoop
                If _Sleep(Random(5000, 15000, 1)) Then ExitLoop
                checkMainScreen(False)
                $g_iActualTrainSkip = $g_iActualTrainSkip + 1
            Else
                SetLog("Humanize bot, prevent to delete and recreate troops " & $g_iActualTrainSkip + 1 & "/" & $g_iMaxTrainSkip, $color_blue)
                If $g_iActualTrainSkip >= $g_iMaxTrainSkip Then
                    $g_iActualTrainSkip = 0
                EndIf
                $g_iCommandStop = 0
            EndIf
        EndIf
        If $g_iCommandStop = 0 And $g_bTrainEnabled Then
            Local $aRndFuncList = ['Collect', 'CheckTombs', 'UpgradeWall', 'CleanYard', 'DropTrophy']
            _ArrayShuffle($aRndFuncList)
            For $Index In $aRndFuncList
                If Not $g_bRunState Then Return
                _RunFunction($Index)
            Next
            $g_iCommandStop = 3
        EndIf
        If $g_bRestart Then ExitLoop
        $TimeIdle += Round(__TimerDiff($hTimer) / 1000, 2)
        SetLog("Time Idle: " & StringFormat("%02i", Floor(Floor($TimeIdle / 60) / 60)) & ":" & StringFormat("%02i", Floor(Mod(Floor($TimeIdle / 60), 60))) & ":" & StringFormat("%02i", Floor(Mod($TimeIdle, 60))))
        If $g_bOutOfGold Or $g_bOutOfElixir Then Return
        If ProfileSwitchAccountEnabled() Then checkSwitchAcc()
        If ($g_iCommandStop = 3 Or $g_iCommandStop = 0) Then ExitLoop
        If $g_iCommandStop = -1 Then
            AttackMain()
            $g_bIsFullArmywithHeroesAndSpells = True
            If Not $g_bRunState Then Return
            If $g_bRestart Then ExitLoop
        EndIf
    WEnd
EndFunc   ;==>_Idle

Func CheckStorageForAttack()
    ; Set max capacities based on Town Hall level
    Local $GoldMax, $ElixirMax, $DarkElixirMax
    Switch $g_iTownHallLevel
        Case 7
            $GoldMax = 4000000
            $ElixirMax = 4000000
            $DarkElixirMax = 20000
        Case 8
            $GoldMax = 6000000
            $ElixirMax = 6000000
            $DarkElixirMax = 20000
        Case 9
            $GoldMax = 7000000
            $ElixirMax = 7000000
            $DarkElixirMax = 120000
        Case 10
            $GoldMax = 8500000
            $ElixirMax = 8500000
            $DarkElixirMax = 200000
        Case 11
            $GoldMax = 8000000
            $ElixirMax = 8000000
            $DarkElixirMax = 1000000
        Case 12
            $GoldMax = 12000000
            $ElixirMax = 12000000
            $DarkElixirMax = 1800000
        Case 13
            $GoldMax = 16000000
            $ElixirMax = 16000000
            $DarkElixirMax = 2800000
        Case 14
            $GoldMax = 18000000
            $ElixirMax = 18000000
            $DarkElixirMax = 3000000
        Case 15
            $GoldMax = 20000000
            $ElixirMax = 20000000
            $DarkElixirMax = 4000000
        Case 16
            $GoldMax = 22000000
            $ElixirMax = 22000000
            $DarkElixirMax = 5500000
        Case 17
            $GoldMax = 24000000
            $ElixirMax = 24000000
            $DarkElixirMax = 10000000
        Case Else
            ; Fallback for invalid/undetected TH level (use TH10 values)
            SetLog("Warning: Unknown TH level (" & $g_iTownHallLevel & "), using TH10 values", $COLOR_WARNING)
            $GoldMax = 8500000
            $ElixirMax = 8500000
            $DarkElixirMax = 200000
    EndSwitch
    
    ; Get current resources
    $g_aiCurrentLoot[$eLootGold] = Number(getResourcesMainScreen(696, 23)) ; Gold
    $g_aiCurrentLoot[$eLootElixir] = Number(getResourcesMainScreen(696, 74)) ; Elixir
    $g_aiCurrentLoot[$eLootDarkElixir] = Number(getResourcesMainScreen(728, 123)) ; Dark Elixir
    
    ; Check if all storages are full
    If $g_aiCurrentLoot[$eLootGold] >= $GoldMax And _
       $g_aiCurrentLoot[$eLootElixir] >= $ElixirMax And _
       $g_aiCurrentLoot[$eLootDarkElixir] >= $DarkElixirMax Then
        SetLog("All storages full (TH" & $g_iTownHallLevel & "): Gold: " & $g_aiCurrentLoot[$eLootGold] & "/" & $GoldMax & _
               ", Elixir: " & $g_aiCurrentLoot[$eLootElixir] & "/" & $ElixirMax & _
               ", DE: " & $g_aiCurrentLoot[$eLootDarkElixir] & "/" & $DarkElixirMax, $COLOR_WARNING)
        $g_bHaltAttack = True
    Else
        Local $sLogMsg = "Storage space available (TH" & $g_iTownHallLevel & "): "
        Local $bHasSpace = False
        If $g_aiCurrentLoot[$eLootGold] < $GoldMax Then
            $sLogMsg &= "Gold: " & $g_aiCurrentLoot[$eLootGold] & "/" & $GoldMax & " "
            $bHasSpace = True
        EndIf
        If $g_aiCurrentLoot[$eLootElixir] < $ElixirMax Then
            $sLogMsg &= "Elixir: " & $g_aiCurrentLoot[$eLootElixir] & "/" & $ElixirMax & " "
            $bHasSpace = True
        EndIf
        If $g_aiCurrentLoot[$eLootDarkElixir] < $DarkElixirMax Then
            $sLogMsg &= "DE: " & $g_aiCurrentLoot[$eLootDarkElixir] & "/" & $DarkElixirMax
            $bHasSpace = True
        EndIf
        If Not $bHasSpace Then
            $sLogMsg &= "None"
        EndIf
        SetLog($sLogMsg & " - proceeding to attack", $COLOR_SUCCESS)
        $g_bHaltAttack = False
    EndIf
EndFunc   ;==>CheckStorageForAttack

Func AutoUpgradeLaboratory()
    SetDebugLog("AutoUpgradeLaboratory: Starting...", $COLOR_DEBUG)
    If Not $g_bRunState Then Return False
    
    ; Declare $bUpgradeAttempted at the top with a default value
    Local $bUpgradeAttempted = False
    
    ; Ensure auto-upgrade is enabled
    Local $bWasAutoLabUpgradeEnable = $g_bAutoLabUpgradeEnable
    Local $iWasCmbLaboratory = $g_iCmbLaboratory
    $g_bAutoLabUpgradeEnable = True
    SetDebugLog("AutoUpgradeLaboratory: $g_bAutoLabUpgradeEnable set to " & $g_bAutoLabUpgradeEnable, $COLOR_DEBUG)
    
    ; Read GUI settings
    Local $bAutoLabChecked = (GUICtrlRead($g_hChkAutoLabUpgrades) = $GUI_CHECKED)
    Local $sTroopSelected = GUICtrlRead($g_hCmbLaboratory)
    SetDebugLog("AutoUpgradeLaboratory: GUI AutoLabUpgrades=" & $bAutoLabChecked & ", TroopSelected=" & $sTroopSelected, $COLOR_DEBUG)
    
    ; Try native Laboratory() function
    Local $bWasSilentSetLog = $g_bSilentSetLog
    $g_bSilentSetLog = True
    Local $bUpgradeStarted = Laboratory()
    $g_bSilentSetLog = $bWasSilentSetLog
    SetDebugLog("AutoUpgradeLaboratory: Native Laboratory() returned " & $bUpgradeStarted, $COLOR_DEBUG)
    
    If $bUpgradeStarted Then
        SetLog("Laboratory upgrade started successfully.", $COLOR_SUCCESS)
        ; Update Lab upgrade time
        Local $sLabTimeOCR = getRemainTLaboratory2(250, 210)
        If $sLabTimeOCR <> "" Then
            Local $iLabFinishTime = ConvertOCRTime("Lab Time", $sLabTimeOCR, False) + 1
            If $iLabFinishTime > 0 Then
                $g_sLabUpgradeTime = _DateAdd('n', Ceiling($iLabFinishTime), _NowCalc())
                SetLog("Research will finish in " & $sLabTimeOCR & " (" & $g_sLabUpgradeTime & ")", $COLOR_INFO)
            EndIf
        EndIf
        Return True
    EndIf
    
    ; Check for ongoing upgrade
    Local $bUpgradeInProgress = False
    If $g_sLabUpgradeTime <> "" Then
        Local $iTimeDiff = _DateDiff("n", _NowCalc(), $g_sLabUpgradeTime)
        If $iTimeDiff > 0 Then
            SetLog("Laboratory upgrade in progress, finishes at " & $g_sLabUpgradeTime, $COLOR_INFO)
            $bUpgradeInProgress = True
        Else
            SetLog("Stored Lab upgrade time expired, resetting...", $COLOR_DEBUG)
            $g_sLabUpgradeTime = ""
        EndIf
    EndIf
    
    If Not $bUpgradeInProgress And isInsideDiamond($g_aiLaboratoryPos) Then
        SetLog("Attempting manual Laboratory upgrade...", $COLOR_INFO)
        SetDebugLog("Opening Laboratory at " & $g_aiLaboratoryPos[0] & "," & $g_aiLaboratoryPos[1], $COLOR_ACTION)
        Click($g_aiLaboratoryPos[0], $g_aiLaboratoryPos[1], 1, 0, "Click Laboratory")
        If _Sleep(2000) Then Return False
        
        ; Verify Laboratory window
        If Not _ColorCheck(_GetPixelColor(820, 40, True), Hex(0xFFFFFF, 6), 20) Then
            SetLog("Failed to open Laboratory window.", $COLOR_ERROR)
            ClearScreen()
            If _Sleep(1000) Then Return False
            CheckMainScreen(True)
            Return False
        EndIf
        SetLog("Laboratory window opened.", $COLOR_SUCCESS)
        
        ; Check for ongoing upgrade
        Local $iGobBuilderOffset = 0
        Local $iMidOffsetY = 0
        If _ColorCheck(_GetPixelColor(775 - $iGobBuilderOffset, 135 + $iMidOffsetY, True), Hex(0xA1CA6B, 6), 20) Then
            SetLog("Laboratory is upgrading, cannot start new upgrade.", $COLOR_INFO)
            Local $sLabTimeOCR = getRemainTLaboratory2(250, 210 + $iMidOffsetY)
            If $sLabTimeOCR <> "" Then
                Local $iLabFinishTime = ConvertOCRTime("Lab Time", $sLabTimeOCR, False) + 1
                If $iLabFinishTime > 0 Then
                    $g_sLabUpgradeTime = _DateAdd('n', Ceiling($iLabFinishTime), _NowCalc())
                    SetLog("Research will finish in " & $sLabTimeOCR & " (" & $g_sLabUpgradeTime & ")", $COLOR_INFO)
                EndIf
            EndIf
            Click(820, 40, 1, 0, "Close Laboratory")
            If _Sleep(1000) Then Return False
            ClearScreen()
            If _Sleep(1000) Then Return False
            CheckMainScreen(True)
            Return False
        EndIf
        
        ; Click Research button
        Local $aResearchButton = [430, 600]
        SetDebugLog("Clicking Research button at " & $aResearchButton[0] & "," & $aResearchButton[1], $COLOR_ACTION)
        ClickP($aResearchButton, 1, 0, "Click Research")
        If _Sleep(3000) Then Return False
        
        ; Verify troop list
        Local $bTroopListOpened = _ColorCheck(_GetPixelColor(150, 400, True), Hex(0xD8D8D0, 6), 20) Or _
                                 _ColorCheck(_GetPixelColor(580, 400, True), Hex(0xD8D8D0, 6), 20)
        If Not $bTroopListOpened Then
            SetLog("Failed to open troop list.", $COLOR_ERROR)
            Click(820, 40, 1, 0, "Close Laboratory")
            If _Sleep(1000) Then Return False
            ClearScreen()
            If _Sleep(1000) Then Return False
            CheckMainScreen(True)
            Return False
        EndIf
        SetLog("Troop list opened.", $COLOR_SUCCESS)
        
        ; Select troop
        If $sTroopSelected <> GetTranslatedFileIni("MBR Global GUI Design", "Any", "Any") Then
            SetLog("Upgrading selected troop: " & $sTroopSelected, $COLOR_INFO)
            Local $aTroopNames = StringSplit(GetTranslatedFileIni("MBR Global GUI Design", "Any", "Any") & "|" & _
                "Barbarian|Archer|Giant|Goblin|Wall Breaker|Balloon|Wizard|Healer|Dragon|Pekka|Baby Dragon|Miner|" & _
                "Electro Dragon|Yeti|Dragon Rider|Electro Titan|Root Rider|Thrower|Lightning Spell|Healing Spell|" & _
                "Rage Spell|Jump Spell|Freeze Spell|Clone Spell|Invisibility Spell|Recall Spell|Revive Spell|" & _
                "Poison Spell|EarthQuake Spell|Haste Spell|Skeleton Spell|Bat Spell|Overgrowth Spell|Minion|" & _
                "Hog Rider|Valkyrie|Golem|Witch|Lava Hound|Bowler|Ice Golem|Headhunter|App. Warden|Druid|" & _
                "Wall Wrecker|Battle Blimp|Stone Slammer|Siege Barrack|Log Launcher|Flame Flinger|Battle Drill", "|", 2)
            Local $iTroopIndex = 0
            For $i = 1 To UBound($aTroopNames) - 1
                If $aTroopNames[$i] = $sTroopSelected Then
                    $iTroopIndex = $i
                    ExitLoop
                EndIf
            Next
            If $iTroopIndex > 0 Then
                Local $iPage = Ceiling($iTroopIndex / 12)
                Local $iSlot = Mod($iTroopIndex - 1, 12)
                Local $iRow = ($iSlot < 6) ? 420 : 543
                Local $iCol = 70 + ($iSlot - ($iRow = 420 ? 0 : 6)) * 122
                For $i = 1 To $iPage - 1
                    ClickDrag(720, 475, 83, 475, 300)
                    If _Sleep(2000) Then Return False
                Next
                SetDebugLog("Clicking troop at " & $iCol & "," & $iRow, $COLOR_ACTION)
                Click($iCol, $iRow, 1, 0, "Select Troop")
                If _Sleep(1000) Then Return False
                $bUpgradeAttempted = True
            Else
                SetLog("Invalid troop selection: " & $sTroopSelected, $COLOR_ERROR)
            EndIf
        Else
            SetLog("Selecting any available upgrade...", $COLOR_INFO)
            Local $aTroopSlots[12][2] = [[70, 420], [192, 420], [314, 420], [436, 420], [558, 420], [680, 420], _
                                        [70, 543], [192, 543], [314, 543], [436, 543], [558, 543], [680, 543]]
            For $i = 0 To UBound($aTroopSlots) - 1
                SetDebugLog("Checking slot " & ($i + 1) & " at " & $aTroopSlots[$i][0] & "," & $aTroopSlots[$i][1], $COLOR_ACTION)
                Click($aTroopSlots[$i][0], $aTroopSlots[$i][1], 1, 0, "Select Troop")
                If _Sleep(1000) Then Return False
                If _ColorCheck(_GetPixelColor(630, 545, True), Hex(0xA1CA6B, 6), 20) Then
                    SetLog("Found upgrade at slot " & ($i + 1), $COLOR_SUCCESS)
                    $bUpgradeAttempted = True
                    ExitLoop
                EndIf
            Next
        EndIf
        
        ; Start upgrade if applicable
        If $bUpgradeAttempted Then
            Local $aUpgradeButton = [630, 545]
            SetDebugLog("Clicking Upgrade button at " & $aUpgradeButton[0] & "," & $aUpgradeButton[1], $COLOR_ACTION)
            ClickP($aUpgradeButton, 1, 0, "Start Upgrade")
            If _Sleep(1000) Then Return False
            SetLog("Laboratory upgrade started.", $COLOR_SUCCESS)
            ; Read upgrade time
            Local $sLabTimeOCR = getRemainTLaboratory2(250, 210)
            If $sLabTimeOCR <> "" Then
                Local $iLabFinishTime = ConvertOCRTime("Lab Time", $sLabTimeOCR, False) + 1
                If $iLabFinishTime > 0 Then
                    $g_sLabUpgradeTime = _DateAdd('n', Ceiling($iLabFinishTime), _NowCalc())
                    SetLog("Research will finish in " & $sLabTimeOCR & " (" & $g_sLabUpgradeTime & ")", $COLOR_INFO)
                EndIf
            EndIf
        ElseIf Not $bUpgradeInProgress Then
            SetLog("No available upgrades found.", $COLOR_WARNING)
        EndIf
        
        ; Close Laboratory
        Click(820, 40, 1, 0, "Close Laboratory")
        If _Sleep(1000) Then Return False
        ClearScreen()
        If _Sleep(1000) Then Return False
        CheckMainScreen(True)
    ElseIf Not $bUpgradeInProgress Then
        SetLog("Laboratory position invalid.", $COLOR_ERROR)
    EndIf
    
    ; Restore original settings
    $g_bAutoLabUpgradeEnable = $bWasAutoLabUpgradeEnable
    $g_iCmbLaboratory = $iWasCmbLaboratory
    SetDebugLog("AutoUpgradeLaboratory: Restored $g_bAutoLabUpgradeEnable=" & $g_bAutoLabUpgradeEnable, $COLOR_DEBUG)
    
    VillageReport()
    SetLog("Laboratory upgrade attempt completed.", $COLOR_INFO)
    Return $bUpgradeAttempted
EndFunc   ;==>AutoUpgradeLaboratory

Func AttackMain()
    If ProfileSwitchAccountEnabled() And $g_abDonateOnly[$g_iCurAccount] Then Return
    ClearScreen()
    If IsSearchAttackEnabled() Then
        If IsSearchModeActive($DB) Or IsSearchModeActive($LB) Then
            If ProfileSwitchAccountEnabled() And ($g_aiAttackedCountSwitch[$g_iCurAccount] <= $g_aiAttackedCount - 2) Then checkSwitchAcc()
            If $g_bUseCCBalanced Then
                ProfileReport()
                If Not $g_bRunState Then Return
                checkMainScreen(False)
                If $g_bRestart Then Return
            EndIf
            If $g_bDropTrophyEnable And Number($g_aiCurrentLoot[$eLootTrophy]) > Number($g_iDropTrophyMax) Then
                DropTrophy()
                If Not $g_bRunState Then Return
                $g_bIsClientSyncError = False
                Return
            EndIf
            If $g_bDebugSetLog Then
                SetDebugLog(_PadStringCenter(" Hero status check" & BitAND($g_aiAttackUseHeroes[$DB], $g_aiSearchHeroWaitEnable[$DB], $g_iHeroAvailable) & "|" & $g_aiSearchHeroWaitEnable[$DB] & "|" & $g_iHeroAvailable, 54, "="), $COLOR_DEBUG)
                SetDebugLog(_PadStringCenter(" Hero status check" & BitAND($g_aiAttackUseHeroes[$LB], $g_aiSearchHeroWaitEnable[$LB], $g_iHeroAvailable) & "|" & $g_aiSearchHeroWaitEnable[$LB] & "|" & $g_iHeroAvailable, 54, "="), $COLOR_DEBUG)
            EndIf
            _ClanGames()
            While $g_bIsBBevent
                If SwitchForCGEvent() Then
                    BuilderBase()
                Else
                    ExitLoop
                EndIf
            WEnd
            ClearScreen()
            PrepareSearch()
            If Not $g_bRunState Then Return
            If $g_bOutOfGold Then Return
            If $g_bRestart Then
                CleanSuperchargeTemplates()
                Return
            EndIf
            VillageSearch()
            If $g_bOutOfGold Then Return
            If Not $g_bRunState Then Return
            If $g_bRestart Then
                CleanSuperchargeTemplates()
                Return
            EndIf
            PrepareAttack($g_iMatchMode)
            If Not $g_bRunState Then Return
            If $g_bRestart Then
                CleanSuperchargeTemplates()
                Return
            EndIf
            Attack()
            If Not $g_bRunState Then Return
            If $g_bRestart Then
                CleanSuperchargeTemplates()
                Return
            EndIf
            ReturnHome($g_bTakeLootSnapShot)
            If Not $g_bRunState Then Return
            CleanSuperchargeTemplates()
            Return True
        Else
            SetLog("None of search condition match:", $COLOR_WARNING)
            SetLog("Search, Trophy or Army Camp % are out of range in search setting", $COLOR_WARNING)
            $g_bIsSearchLimit = False
            $g_bIsClientSyncError = False
            If ProfileSwitchAccountEnabled() Then checkSwitchAcc()
        EndIf
    Else
        SetLog("Attacking Not Planned, Skipped..", $COLOR_WARNING)
        HiddenSlotstatus()
    EndIf
EndFunc   ;==>AttackMain

Func Attack()
    $g_bAttackActive = True
    SetLog(" ====== Start Attack ====== ", $COLOR_SUCCESS)
    If ($g_iMatchMode = $DB And $g_aiAttackAlgorithm[$DB] = 1) Or ($g_iMatchMode = $LB And $g_aiAttackAlgorithm[$LB] = 1) Then
        If $g_bDebugSetLog Then SetDebugLog("start scripted attack", $COLOR_ERROR)
        Algorithm_AttackCSV()
    ElseIf $g_iMatchMode = $DB And $g_aiAttackAlgorithm[$DB] = 2 Then
        If $g_bDebugSetLog Then SetDebugLog("start smart farm attack", $COLOR_ERROR)
        Local $Nside = ChkSmartFarm()
        If Not $g_bRunState Then Return
        AttackSmartFarm($Nside[1], $Nside[2])
    Else
        If $g_bDebugSetLog Then SetDebugLog("start standard attack", $COLOR_ERROR)
        algorithm_AllTroops()
    EndIf
    $g_bAttackActive = False
EndFunc   ;==>Attack

Func _RunFunction($action)
    FuncEnter(_RunFunction)
    $g_bStayOnBuilderBase = False
    Local $Result = __RunFunction($action)
    $g_bStayOnBuilderBase = False
    Return FuncReturn($Result)
EndFunc   ;==>_RunFunction

Func __RunFunction($action)
    SetDebugLog("_RunFunction: " & $action & " BEGIN", $COLOR_DEBUG2)
    Switch $action
        Case "Collect"
            Collect()
        Case "CheckTombs"
            CheckTombs()
        Case "CleanYard"
            CleanYard()
        Case "ReplayShare"
            ReplayShare($g_bShareAttackEnableNow)
        Case "NotifyReport"
            NotifyReport()
        Case "DonateCC"
            If $g_iActiveDonate And $g_bChkDonate Then
                If (Not SkipDonateNearFullTroops(True) Or $g_iCommandStop = 3 Or $g_iCommandStop = 0) And BalanceDonRec(True) Then checkMainScreen(False)
                If _Sleep($DELAYRUNBOT1) = False Then checkMainScreen(False)
            EndIf
        Case "BoostBarracks"
        Case "BoostSpellFactory"
        Case "BoostWorkshop"
        Case "BoostKing"
        Case "BoostQueen"
        Case "BoostPrince"
            _Sleep($DELAYRESPOND)
        Case "BoostWarden"
        Case "BoostChampion"
        Case "BoostEverything"
            BoostEverything()
        Case "DailyChallenge"
            DailyChallenges()
        Case "PetCheck"
            PetGuiDisplay()
        Case "RequestCC"
            If Not _Sleep($DELAYRUNBOT1) Then checkMainScreen(False)
        Case "Laboratory"
            If Not _Sleep($DELAYRUNBOT3) Then checkMainScreen(False)
        Case "PetHouse"
            If Not _Sleep($DELAYRUNBOT3) Then checkMainScreen(False)
        Case "UpgradeHeroes"
            UpgradeHeroes()
        Case "UpgradeBuilding"
            UpgradeBuilding()
            AutoUpgrade()
        Case "UpgradeWall"
            $g_iNbrOfWallsUpped = 0
            UpgradeWall()
        Case "BuilderBase"
            If $g_bChkCollectBuilderBase Or $g_bChkStartClockTowerBoost Or $g_iChkBBSuggestedUpgrades Or $g_bChkEnableBBAttack Then
                BuilderBase()
            EndIf
        Case "CollectAchievements"
            CollectAchievements()
        Case "CollectFreeMagicItems"
            CollectFreeMagicItems()
        Case "ForgeClanCapitalGold"
            ForgeClanCapitalGold()
        Case "AutoUpgradeCC"
            AutoUpgradeCC()
        Case "CollectCCGold"
            CollectCCGold()
        Case ""
            SetDebugLog("Function call doesn't support empty string, please review array size", $COLOR_ERROR)
        Case "Blacksmith"
        Case "DropTrophy"
            DropTrophy()
        Case Else
            SetLog("Unknown function call: " & $action, $COLOR_ERROR)
    EndSwitch
    SetDebugLog("_RunFunction: " & $action & " END", $COLOR_DEBUG2)
EndFunc   ;==>__RunFunction

; MODIFIED: Added building checker and pre-attack upgrades
Func FirstCheck()
    SetDebugLog("-- FirstCheck Loop --")
    If Not $g_bRunState Then Return
    If ProfileSwitchAccountEnabled() And $g_abDonateOnly[$g_iCurAccount] Then Return
    $g_bRestart = False
    $g_bFullArmy = True
    $g_iCommandStop = -1
    Local $iTownHallLevel = $g_iTownHallLevel
    SetDebugLog("Detecting Town Hall level", $COLOR_INFO)
    SetDebugLog("Town Hall level is currently saved as " & $g_iTownHallLevel, $COLOR_INFO)
    imglocTHSearch(False, True, True)
    SetDebugLog("Detected Town Hall level is " & $g_iTownHallLevel, $COLOR_INFO)
    If $g_iTownHallLevel = $iTownHallLevel Then
        SetDebugLog("Town Hall level has not changed", $COLOR_INFO)
    Else
        If $g_iTownHallLevel < $iTownHallLevel Then
            SetDebugLog("Bad town hall level read...saving bigger old value", $COLOR_ERROR)
            $g_iTownHallLevel = $iTownHallLevel
            saveConfig()
            applyConfig()
        Else
            SetDebugLog("Town Hall level has changed!", $COLOR_INFO)
            SetDebugLog("New Town hall level detected as " & $g_iTownHallLevel, $COLOR_INFO)
            saveConfig()
            applyConfig()
        EndIf
    EndIf
    GUICtrlSetData($g_hLblTHLevels, "")
    _GUI_Value_STATE("HIDE", $g_aGroupListTHLevels)
    GUICtrlSetState($g_ahPicTHLevels[$g_iTownHallLevel], $GUI_SHOW)
    GUICtrlSetData($g_hLblTHLevels, $g_iTownHallLevel)

    ; Detect buildings and check key buildings
    If Not isInsideDiamond($g_aiTownHallPos) Then BotDetectFirstTime()
    CheckKeyBuildings()
    If Not $g_bRunState Then Return

    VillageReport()
    If Not $g_bRunState Then Return
    If $g_bOutOfGold And (Number($g_aiCurrentLoot[$eLootGold]) >= Number($g_iTxtRestartGold)) Then
        $g_bOutOfGold = False
        SetLog("Switching back to normal after no gold to search ...", $COLOR_SUCCESS)
        Return
    EndIf
    If $g_bOutOfElixir And (Number($g_aiCurrentLoot[$eLootElixir]) >= Number($g_iTxtRestartElixir)) And (Number($g_aiCurrentLoot[$eLootDarkElixir]) >= Number($g_iTxtRestartDark)) Then
        $g_bOutOfElixir = False
        SetLog("Switching back to normal setting after no elixir to train ...", $COLOR_SUCCESS)
        Return
    EndIf
    checkMainScreen(False)
    If $g_bRestart Then Return
    If BotCommand() Then btnStop()

    ; MODIFIED: Run auto-upgrades before attacking
    SetLog("Running auto-upgrade for buildings...", $COLOR_INFO)
    AutoUpgrade()
    If Not $g_bRunState Then Return
    If $g_bRestart Then Return

    SetLog("Checking Laboratory for auto-upgrade...", $COLOR_INFO)
    Local $bUpgradeAttempted = AutoUpgradeLaboratory()
    If Not $g_bRunState Then Return
    If $g_bRestart Then Return
    If $bUpgradeAttempted Then
        SetLog("Laboratory upgrade successfully initiated.", $COLOR_SUCCESS)
    Else
        SetLog("No Laboratory upgrade started (e.g., in progress or no resources).", $COLOR_INFO)
    EndIf

    If $g_iCommandStop <> 0 And $g_iCommandStop <> 3 Then
        SetDebugLog("-- FirstCheck on Train --")
        AttackMain()
        If Not $g_bRunState Then Return
        HiddenSlotstatus()
        If Not $g_bRunState Then Return
        SetDebugLog("Are you ready? " & String($g_bIsFullArmywithHeroesAndSpells))
        If $g_bIsFullArmywithHeroesAndSpells Then
            If Not isInsideDiamond($g_aiTownHallPos) Then BotDetectFirstTime()
            If $g_iCommandStop <> 0 And $g_iCommandStop <> 3 Then
                SetLog("Before any other routine let's attack!", $COLOR_INFO)
                If Not $g_bRunState Then Return
                AttackMain()
                $g_bSkipFirstZoomout = False
                If $g_bOutOfGold Then
                    SetLog("Switching to Halt Attack, Stay Online/Collect mode", $COLOR_ERROR)
                    $g_bFirstStart = True
                    Return
                EndIf
            EndIf
        EndIf
    EndIf
EndFunc   ;==>FirstCheck

Func BuilderBase($bTest = False)
    If SwitchBetweenBases(True, True) And isOnBuilderBase() Then
        $g_bStayOnBuilderBase = True
        If checkObstacles() Then Return
        CollectBuilderBase()
        If checkObstacles() Then Return
        BuilderBaseReport()
        If checkObstacles() Then Return
        CleanBBYard()
        If checkObstacles() Then Return
        StarLabGuiDisplay()
        If checkObstacles() Then Return
        DoAttackBB()
        If checkObstacles() Then Return
        If $g_bRestart Then Return
        CollectBuilderBase(False, False, False)
        If checkObstacles() Then Return
        BuilderBaseReport(True, True)
        If checkObstacles() Then Return
        BOBBuildingUpgrades()
        If checkObstacles() Then Return
        If $g_bRestart Then Return
        StartClockTowerBoost()
        If checkObstacles() Then Return
        StarLaboratory()
        If checkObstacles() Then Return
        MainSuggestedUpgradeCode()
        If checkObstacles() Then Return
        BuilderBaseReport()
        If checkObstacles() Then Return
        SwitchBetweenBases()
        ; MODIFIED: Changed to 5-15s
        If _Sleep(Random(5000, 15000, 1)) Then Return
        _ClanGames()
        If Not $g_bRunState Then Return
    EndIf
EndFunc   ;==>BuilderBase

Func TestBuilderBase($bTestAll = True)
    Local $bChkCollectBuilderBase = $g_bChkCollectBuilderBase
    Local $bChkStartClockTowerBoost = $g_bChkStartClockTowerBoost
    Local $bChkCTBoostBlderBz = $g_bChkCTBoostBlderBz
    Local $bChkCleanBBYard = $g_bChkCleanBBYard
    Local $bChkEnableBBAttack = $g_bChkEnableBBAttack
    If $bTestAll = True Then
        $g_bChkCollectBuilderBase = True
        $g_bChkStartClockTowerBoost = True
        $g_bChkCTBoostBlderBz = True
        $g_bChkCleanBBYard = True
        $g_bChkEnableBBAttack = True
    Else
        $g_bChkCollectBuilderBase = False
        $g_bChkStartClockTowerBoost = False
        $g_bChkCTBoostBlderBz = False
        $g_bChkCleanBBYard = False
        $g_bChkEnableBBAttack = False
    EndIf
    BuilderBase(True)
    $g_bChkCollectBuilderBase = $bChkCollectBuilderBase
    $g_bChkStartClockTowerBoost = $bChkStartClockTowerBoost
    $g_bChkCTBoostBlderBz = $bChkCTBoostBlderBz
    $g_bChkCleanBBYard = $bChkCleanBBYard
    $g_bChkEnableBBAttack = $bChkEnableBBAttack
EndFunc   ;==>TestBuilderBase

; MODIFIED: Updated building checker to include Hero Hall instead of individual Hero Altars
Func CheckKeyBuildings()
    SetLog("Checking key buildings...", $COLOR_INFO)
    
    ; Check Town Hall
    If Not isInsideDiamond($g_aiTownHallPos) Then
        SetLog("Town Hall not found! Prompting to locate...", $COLOR_WARNING)
        LocateTownHall()
    Else
        SetLog("Town Hall found at position: " & $g_aiTownHallPos[0] & "," & $g_aiTownHallPos[1], $COLOR_SUCCESS)
    EndIf
    
    ; Check Clan Castle
    If Not isInsideDiamond($g_aiClanCastlePos) Then
        SetLog("Clan Castle not found! Prompting to locate...", $COLOR_WARNING)
        LocateClanCastle()
    Else
        SetLog("Clan Castle found at position: " & $g_aiClanCastlePos[0] & "," & $g_aiClanCastlePos[1], $COLOR_SUCCESS)
    EndIf
    
    ; Check Laboratory
    If Not isInsideDiamond($g_aiLaboratoryPos) Then
        SetLog("Laboratory not found! Prompting to locate...", $COLOR_WARNING)
        LocateLaboratory()
    Else
        SetLog("Laboratory found at position: " & $g_aiLaboratoryPos[0] & "," & $g_aiLaboratoryPos[1], $COLOR_SUCCESS)
    EndIf
    
    ; Check Hero Hall (available at TH7+ when heroes are unlocked)
    If $g_iTownHallLevel >= 7 Then
        If Not isInsideDiamond($g_aiHeroHallPos) Then
            SetLog("Hero Hall not found! Prompting to locate...", $COLOR_WARNING)
            LocateHeroHall()
        Else
            SetLog("Hero Hall found at position: " & $g_aiHeroHallPos[0] & "," & $g_aiHeroHallPos[1], $COLOR_SUCCESS)
        EndIf
    Else
        SetLog("Hero Hall not checked (TH" & $g_iTownHallLevel & " < TH7)", $COLOR_INFO)
    EndIf
    
    ; Check Pet House (only if TH14 or higher)
    If $g_iTownHallLevel >= 14 Then
        If Not isInsideDiamond($g_aiPetHousePos) Then
            SetLog("Pet House not found! Prompting to locate...", $COLOR_WARNING)
            LocatePetHouse()
        Else
            SetLog("Pet House found at position: " & $g_aiPetHousePos[0] & "," & $g_aiPetHousePos[1], $COLOR_SUCCESS)
        EndIf
    Else
        SetLog("Pet House not checked (TH" & $g_iTownHallLevel & " < TH14)", $COLOR_INFO)
    EndIf
EndFunc   ;==>CheckKeyBuildings
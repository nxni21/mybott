; #FUNCTION# ====================================================================================================================
; Name ..........: StarLaboratory
; Description ...: Automatically upgrades troops in the Star Laboratory with reduced delays
; Syntax ........: StarLaboratory()
; Parameters ....:
; Return values .: None
; Author ........: TripleM
; Modified ......: [Your Name] (04-2025)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Global Const $sStarColorNA = Hex(0xD3D3CB, 6) ; Troop not unlocked in Lab, beige pixel
Global Const $sStarColorNoLoot = Hex(0xFF7B72, 6) ; Not enough loot, pink pixel
Global Const $sStarColorMaxLvl = Hex(0xFFFFFF, 6) ; Max level, white pixel
Global Const $sStarColorLabUgReq = Hex(0x757575, 6) ; Lab upgrade required, gray pixel
Global Const $sStarColorMaxTroop = Hex(0xFFC360, 6) ; Troop already max, golden pixel
Global Const $sStarColorBG = Hex(0xD3D3CB, 6) ; Background color in laboratory

Func TestStarLaboratory()
    Local $bWasRunState = $g_bRunState
    Local $sWasStarLabUpgradeTime = $g_sStarLabUpgradeTime
    Local $bWasStarLabUpgradeEnable = $g_bAutoStarLabUpgradeEnable
    $g_bRunState = True
    $g_bAutoStarLabUpgradeEnable = True
    $g_sStarLabUpgradeTime = ""
    Local $Result = StarLaboratory()
    $g_bRunState = $bWasRunState
    $g_sStarLabUpgradeTime = $sWasStarLabUpgradeTime
    $g_bAutoStarLabUpgradeEnable = $bWasStarLabUpgradeEnable
    Return $Result
EndFunc   ;==>TestStarLaboratory

Func StarLaboratory()
    If Not $g_bAutoStarLabUpgradeEnable Then
        SetLog("Star Laboratory upgrades not enabled.", $COLOR_INFO)
        Return False
    EndIf

    Local $aUpgradeValue[13] = [-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    Local $iAvailElixir, $sElixirCount, $TimeDiff, $aArray, $Result, $aSearchForTroop
    Local $iSelectedUpgrade = $g_iCmbStarLaboratory

    If $g_sStarLabUpgradeTime <> "" Then
        $TimeDiff = _DateDiff("n", _NowCalc(), $g_sStarLabUpgradeTime)
        If @error Then _logErrorDateDiff(@error)
        If $g_bDebugSetLog Then SetDebugLog($g_avStarLabTroops[$g_iCmbStarLaboratory][3] & " Lab end time: " & $g_sStarLabUpgradeTime & ", DIFF= " & $TimeDiff, $COLOR_DEBUG)
        If $TimeDiff > 0 Then
            SetLog("Star Laboratory upgrade in progress, waiting for completion", $COLOR_INFO)
            Return False
        EndIf
    EndIf

    If Not $g_bRunState Then Return
    SetLog("Checking Troop Upgrade in Star Laboratory", $COLOR_INFO)

    $sElixirCount = getResourcesMainScreen(705, 74)
    SetLog("Village Elixir: " & $sElixirCount, $COLOR_SUCCESS)
    $iAvailElixir = Number($sElixirCount)

    If Not LocateStarLab() Then Return False

    Local $aResearchButton = findButton("Research", Default, 1, True)
    If IsArray($aResearchButton) And UBound($aResearchButton, 1) = 2 Then
        If $g_bDebugImageSave Then SaveDebugImage("StarLabUpgrade")
        ClickP($aResearchButton)
        If _Sleep($DELAYLABORATORY1) Then Return ; Assumes 100ms from DelayTimes.au3
    Else
        SetLog("Cannot find Star Laboratory Research Button!", $COLOR_ERROR)
        ClearScreen()
        Return False
    EndIf

    Local $aiCloseBtn = findButton("CloseWindow")
    If Not IsArray($aiCloseBtn) Then
        SetLog("Trouble finding lab close button, try again...", $COLOR_WARNING)
        CloseWindow2()
        ClearScreen()
        Return False
    EndIf

    If _ColorCheck(_GetPixelColor(790, 120 + $g_iMidOffsetY, True), Hex(0xA2CB6C, 6), 20) Then
        SetLog("Laboratory Upgrade in progress, waiting for completion", $COLOR_INFO)
        Local $sLabTimeOCR = getRemainTLaboratory(220, 200 + $g_iMidOffsetY)
        Local $iLabFinishTime = ConvertOCRTime("Lab Time", $sLabTimeOCR, False)
        SetDebugLog("$sLabTimeOCR: " & $sLabTimeOCR & ", $iLabFinishTime = " & $iLabFinishTime & " m")
        If $iLabFinishTime > 0 Then
            $g_sStarLabUpgradeTime = _DateAdd('n', Ceiling($iLabFinishTime), _NowCalc())
            If @error Then _logErrorDateAdd(@error)
            SetLog("Research will finish in " & $sLabTimeOCR & " (" & $g_sStarLabUpgradeTime & ")")
            $iStarLabFinishTimeMod = $iLabFinishTime
            If ProfileSwitchAccountEnabled() Then SwitchAccountVariablesReload("Save")
            StarLabStatusGUIUpdate()
        EndIf
        CloseWindow()
        Return False
    EndIf

    For $i = 1 To UBound($g_avStarLabTroops) - 1
        $g_avStarLabTroops[$i][0] = -1
        $g_avStarLabTroops[$i][1] = -1
    Next

    $aSearchForTroop = decodeMultipleCoords(findImage("TroopPositions", $g_sImgStarLabElex, GetDiamondFromRect2(30, 345 + $g_iMidOffsetY, 790, 590 + $g_iMidOffsetY), 0, True, Default))
    If IsArray($aSearchForTroop) And UBound($aSearchForTroop, 1) > 0 Then
        For $i = 0 To UBound($aSearchForTroop) - 1
            Local $aTempArray = $aSearchForTroop[$i]
            If IsArray($aTempArray) And UBound($aTempArray) = 2 Then
                Local $iCurrentTroop = 2 * Int(($aTempArray[0] - 90) / 127) + Int(($aTempArray[1] - 375) / 127) + 1
                $g_avStarLabTroops[$iCurrentTroop][0] = $aTempArray[0] - 98
                $g_avStarLabTroops[$iCurrentTroop][1] = $aTempArray[1] - 101
                If $g_bDebugSetLog Then
                    SetLog("New X position of " & $g_avStarLabTroops[$iCurrentTroop][3] & " : " & $g_avStarLabTroops[$iCurrentTroop][0], $COLOR_DEBUG)
                    SetLog("New Y position of " & $g_avStarLabTroops[$iCurrentTroop][3] & " : " & $g_avStarLabTroops[$iCurrentTroop][1], $COLOR_DEBUG)
                EndIf
            EndIf
        Next
    Else
        SetLog("No upgradeable troops found!", $COLOR_ERROR)
        CloseWindow()
        Return False
    EndIf

    If $g_bDebugSetLog Then StarLabTroopImages(1, 10)
    For $i = 1 To UBound($aUpgradeValue) - 1
        If $g_avStarLabTroops[$i][0] = -1 Or $g_avStarLabTroops[$i][1] = -1 Then
            $aUpgradeValue[$i] = -1
            If $g_bDebugSetLog Then SetLog($g_avStarLabTroops[$i][3] & " is not upgradeable, now = " & $aUpgradeValue[$i], $COLOR_DEBUG)
        Else
            $aUpgradeValue[$i] = getStarLabUpgrdResourceRed($g_avStarLabTroops[$i][0] + 2, $g_avStarLabTroops[$i][1] + 93)
            If $g_bDebugSetLog Then SetLog($g_avStarLabTroops[$i][3] & " Red text upgrade value = " & $aUpgradeValue[$i], $COLOR_DEBUG)
            If $aUpgradeValue[$i] = "" Or Int($aUpgradeValue[$i]) < 3000 Then
                $aUpgradeValue[$i] = getLabUpgrdResourceWht($g_avStarLabTroops[$i][0] + 2, $g_avStarLabTroops[$i][1] + 93)
                If $g_bDebugSetLog Then SetLog($g_avStarLabTroops[$i][3] & " White text upgrade value = " & $aUpgradeValue[$i], $COLOR_DEBUG)
            EndIf
            If $aUpgradeValue[$i] = "" Or Int($aUpgradeValue[$i]) < 3000 Then
                $aUpgradeValue[$i] = 0
                If $g_bDebugSetLog Then SetLog("Failed to read cost of " & $g_avStarLabTroops[$i][3], $COLOR_DEBUG)
                StarLabTroopImages($i, $i)
            EndIf
        EndIf
        If Not $g_bRunState Then Return
        $aUpgradeValue[$i] = Number($aUpgradeValue[$i])
    Next

    If $aUpgradeValue[$g_iCmbStarLaboratory] = -1 Then
        Local $iCheapestCost = 0
        If $g_iCmbStarLaboratory = 0 Then
            SetLog("No dedicated troop selected, finding cheapest upgrade.", $COLOR_INFO)
        Else
            SetLog("No upgrade for " & $g_avStarLabTroops[$g_iCmbStarLaboratory][3] & " available.", $COLOR_INFO)
        EndIf
        For $i = 1 To UBound($aUpgradeValue) - 1
            If $aUpgradeValue[$i] > 0 Then
                If $g_bDebugSetLog Then SetLog($g_avStarLabTroops[$i][3] & " is upgradeable, Value = " & $aUpgradeValue[$i], $COLOR_DEBUG)
                If $iCheapestCost = 0 Or $aUpgradeValue[$i] < $iCheapestCost Then
                    $iSelectedUpgrade = $i
                    $iCheapestCost = $aUpgradeValue[$i]
                EndIf
            EndIf
        Next
        If $iCheapestCost = 0 Then
            SetLog("No alternate troop for upgrade found", $COLOR_WARNING)
            CloseWindow()
            Return False
        Else
            SetLog($g_avStarLabTroops[$iSelectedUpgrade][3] & " selected for upgrade, cost = " & _NumberFormat($aUpgradeValue[$iSelectedUpgrade], True), $COLOR_INFO)
        EndIf
    EndIf

    If $iAvailElixir < $aUpgradeValue[$iSelectedUpgrade] Then
        SetLog("Insufficient Elixir for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & ", requires: " & _NumberFormat($aUpgradeValue[$iSelectedUpgrade], True) & ", available: " & _NumberFormat($iAvailElixir, True), $COLOR_INFO)
        CloseWindow()
        Return False
    ElseIf StarLabUpgrade($iSelectedUpgrade) Then
        SetLog("Successfully started upgrade for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & ", Elixir used = " & _NumberFormat($aUpgradeValue[$iSelectedUpgrade], True), $COLOR_SUCCESS)
        If _Sleep(Random(100, 500, 1)) Then Return ; Reduced to 100-500ms
        CloseWindow()
        Return True
    EndIf

    ClearScreen()
    Return False
EndFunc   ;==>StarLaboratory

Func StarLabUpgrade($iSelectedUpgrade)
    Local $StartTime, $EndTime, $Result, $iLabFinishTime
    Select
        Case _ColorCheck(_GetPixelColor($g_avStarLabTroops[$iSelectedUpgrade][0] + 47, $g_avStarLabTroops[$iSelectedUpgrade][1] + 1, True), $sStarColorNA, 20)
            SetLog($g_avStarLabTroops[$iSelectedUpgrade][3] & " not unlocked yet.", $COLOR_WARNING)
            Return False

        Case _PixelSearch($g_avStarLabTroops[$iSelectedUpgrade][0] + 66, $g_avStarLabTroops[$iSelectedUpgrade][1] + 79, $g_avStarLabTroops[$iSelectedUpgrade][0] + 68, $g_avStarLabTroops[$iSelectedUpgrade][1] + 82, $sStarColorNoLoot, 20) <> 0
            SetLog("Not enough loot to upgrade " & $g_avStarLabTroops[$iSelectedUpgrade][3] & ".", $COLOR_ERROR)
            Return False

        Case _ColorCheck(_GetPixelColor($g_avStarLabTroops[$iSelectedUpgrade][0] + 22, $g_avStarLabTroops[$iSelectedUpgrade][1] + 60, True), Hex(0xFFC360, 6), 20)
            SetLog($g_avStarLabTroops[$iSelectedUpgrade][3] & " already at max level.", $COLOR_ERROR)
            Return False

        Case _ColorCheck(_GetPixelColor($g_avStarLabTroops[$iSelectedUpgrade][0] + 3, $g_avStarLabTroops[$iSelectedUpgrade][1] + 19, True), Hex(0xB7B7B7, 6), 20)
            SetLog("Laboratory upgrade required for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & ".", $COLOR_ERROR)
            Return False

        Case Else
            Click($g_avStarLabTroops[$iSelectedUpgrade][0] + 45, $g_avStarLabTroops[$iSelectedUpgrade][1] + 55, 1, 120, "#0200")
            If _Sleep($DELAYLABUPGRADE1) Then Return ; Assumes 100ms from DelayTimes.au3
            If $g_bDebugImageSave Then SaveDebugImage("StarLabUpgrade")

            If _ColorCheck(_GetPixelColor(258, 192, True), Hex(0xFF1919, 6), 20) And _ColorCheck(_GetPixelColor(272, 194, True), Hex(0xFF1919, 6), 20) Then
                SetLog($g_avStarLabTroops[$iSelectedUpgrade][3] & " already maxed.", $COLOR_ERROR)
                CloseWindow()
                Return False
            EndIf

            If _PixelSearch($g_avStarLabTroops[$iSelectedUpgrade][0] + 67, $g_avStarLabTroops[$iSelectedUpgrade][1] + 98, $g_avStarLabTroops[$iSelectedUpgrade][0] + 69, $g_avStarLabTroops[$iSelectedUpgrade][0] + 103, $sStarColorNoLoot, 20) <> 0 Then
                SetLog("Insufficient loot for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & " (secondary check).", $COLOR_ERROR)
                CloseWindow()
                Return False
            EndIf

            If _ColorCheck(_GetPixelColor(460, 592 + $g_iMidOffsetY, True), Hex(0x848480, 6), 20) And _ColorCheck(_GetPixelColor(566, 592 + $g_iMidOffsetY, True), Hex(0x848480, 6), 20) Then
                SetLog("Upgrade in progress, cannot start new upgrade.", $COLOR_WARNING)
                CloseWindow()
                Return False
            EndIf

            $Result = getLabUpgradeTime(590, 493 + $g_iMidOffsetY)
            $iLabFinishTime = ConvertOCRTime("Lab Time", $Result, False)
            SetDebugLog($g_avStarLabTroops[$iSelectedUpgrade][3] & " Upgrade OCR Time = " & $Result & ", $iLabFinishTime = " & $iLabFinishTime & " m", $COLOR_INFO)
            $StartTime = _NowCalc()
            If $iLabFinishTime > 0 Then
                $g_sStarLabUpgradeTime = _DateAdd('n', Ceiling($iLabFinishTime), $StartTime)
                SetLog($g_avStarLabTroops[$iSelectedUpgrade][3] & " upgrade will finish in " & $Result & " (" & $g_sStarLabUpgradeTime & ")", $COLOR_SUCCESS)
                $iStarLabFinishTimeMod = $iLabFinishTime
                If ProfileSwitchAccountEnabled() Then SwitchAccountVariablesReload("Save")
            Else
                SetLog("Failed to read upgrade time for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & ".", $COLOR_WARNING)
                CloseWindow()
                Return False
            EndIf

            Click(695, 580 + $g_iMidOffsetY, 1, 120, "#0202")
            If _Sleep($DELAYLABUPGRADE1) Then Return ; Assumes 100ms from DelayTimes.au3

            If $iSelectedUpgrade = $g_iCmbStarLaboratory Then
                $g_iCmbStarLaboratory = 0
                _GUICtrlComboBox_SetCurSel($g_hCmbStarLaboratory, $g_iCmbStarLaboratory)
                _GUICtrlSetImage($g_hPicStarLabUpgrade, $g_sLibIconPath, $g_avStarLabTroops[$g_iCmbStarLaboratory][4])
                SetLog("Upgraded user's choice. Resetting to Any.", $COLOR_INFO)
                SaveBuildingConfig()
            EndIf

            If isGemOpen(True) Then
                SetLog("Gems required for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & " upgrade, aborting.", $COLOR_ERROR)
                CloseWindow()
                Return False
            ElseIf Not (_ColorCheck(_GetPixelColor(660, 185 + $g_iMidOffsetY, True), Hex(0x6DBC1F, 6), 15) Or _ColorCheck(_GetPixelColor(720, 185 + $g_iMidOffsetY, True), Hex(0x6DBC1F, 6), 15)) Then
                SetLog("Failed to start upgrade for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & ".", $COLOR_ERROR)
                CloseWindow()
                Return False
            EndIf

            SetLog("Upgrade for " & $g_avStarLabTroops[$iSelectedUpgrade][3] & " started successfully!", $COLOR_SUCCESS)
            StarLabStatusGUIUpdate()
            PushMsg("StarLabSuccess")
            Return True
    EndSelect
    CloseWindow()
    Return False
EndFunc   ;==>StarLabUpgrade

Func StarDebugIconSave($sTxtName = "Unknown", $iLeft = 0, $iTop = 0)
    SetLog("Taking debug icon snapshot for later review", $COLOR_SUCCESS)
    Local $iIconLength = 94
    Local $Date = @MDAY & "_" & @MON & "_" & @YEAR
    Local $Time = @HOUR & "_" & @MIN & "_" & @SEC
    Local $sName = $g_sProfileTempDebugPath & "StarLabUpgrade\" & $sTxtName & "_" & $Date & "_" & $Time & ".png"
    DirCreate($g_sProfileTempDebugPath & "StarLabUpgrade\")
    ForceCaptureRegion()
    _CaptureRegion($iLeft, $iTop, $iLeft + $iIconLength, $iTop + $iIconLength)
    _GDIPlus_ImageSaveToFile($g_hBitmap, $sName)
    If @error Then SetLog("DebugIconSave failed to save StarLabUpgrade image: " & $sName, $COLOR_WARNING)
    If _Sleep($DELAYLABORATORY2) Then Return ; Assumes 50ms from DelayTimes.au3
EndFunc   ;==>StarDebugIconSave

Func StarLabTroopImages($iStart, $iEnd)
    If $g_bDebugImageSave Then SaveDebugImage("StarLabUpgrade")
    For $i = $iStart To $iEnd
        If $g_avStarLabTroops[$i][0] <> -1 And $g_avStarLabTroops[$i][1] <> -1 Then
            StarDebugIconSave($g_avStarLabTroops[$i][3], $g_avStarLabTroops[$i][0], $g_avStarLabTroops[$i][1])
            SetDebugLog($g_avStarLabTroops[$i][3], $COLOR_WARNING)
            SetDebugLog("_GetPixelColor(+47, +1): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 47, $g_avStarLabTroops[$i][1] + 1, True) & ":" & $sStarColorNA & " =Not unlocked", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+67, +79): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 67, $g_avStarLabTroops[$i][1] + 79, True) & ":" & $sStarColorNoLoot & " =No Loot1", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+67, +82): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 67, $g_avStarLabTroops[$i][1] + 82, True) & ":" & $sStarColorNoLoot & " =No Loot2", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+81, +82): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 81, $g_avStarLabTroops[$i][1] + 82, True) & ":XXXXXX =Loot type", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+76, +76): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 76, $g_avStarLabTroops[$i][1] + 76, True) & ":" & $sStarColorMaxLvl & " =Max L", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+76, +80): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 76, $g_avStarLabTroops[$i][1] + 80, True) & ":" & $sStarColorMaxLvl & " =Max L", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+0, +20): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 0, $g_avStarLabTroops[$i][1] + 20, True) & ":" & $sStarColorLabUgReq & " =Lab Upgrade", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+93, +20): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 93, $g_avStarLabTroops[$i][1] + 20, True) & ":" & $sStarColorLabUgReq & " =Lab Upgrade", $COLOR_DEBUG)
            SetDebugLog("_GetPixelColor(+23, +60): " & _GetPixelColor($g_avStarLabTroops[$i][0] + 23, $g_avStarLabTroops[$i][1] + 60, True) & ":" & $sStarColorMaxTroop & " =Max troop", $COLOR_DEBUG)
        EndIf
    Next
EndFunc   ;==>StarLabTroopImages

Func LocateStarLab()
    ZoomOut()
    If $g_aiStarLaboratoryPos[0] > 0 And $g_aiStarLaboratoryPos[1] > 0 Then
        BuildingClickP($g_aiStarLaboratoryPos, "#0197")
        If _Sleep($DELAYLABORATORY1) Then Return ; Assumes 100ms from DelayTimes.au3
        Local $aResult = BuildingInfo(242, 475 + $g_iBottomOffsetY)
        If $aResult[0] = 2 Then
            If StringInStr($aResult[1], "Lab") Then
                SetLog("Star Laboratory located.", $COLOR_INFO)
                SetLog("Level " & $aResult[2] & ".", $COLOR_INFO)
                Return True
            Else
                ClearScreen()
                SetDebugLog("Stored Star Laboratory Position invalid.", $COLOR_ERROR)
                $g_aiStarLaboratoryPos[0] = -1
                $g_aiStarLaboratoryPos[1] = -1
            EndIf
        Else
            ClearScreen()
            SetDebugLog("Stored Star Laboratory Position invalid.", $COLOR_ERROR)
            $g_aiStarLaboratoryPos[0] = -1
            $g_aiStarLaboratoryPos[1] = -1
        EndIf
    EndIf

    SetLog("Searching for Star Laboratory...", $COLOR_ACTION)
    Local $sCocDiamond = $CocDiamondDCD
    Local $sRedLines = $sCocDiamond
    Local $iMinLevel = 0
    Local $iMaxLevel = 1000
    Local $iMaxReturnPoints = 1
    Local $sReturnProps = "objectname,objectpoints"
    Local $bForceCapture = True

    Local $aResult = findMultiple($g_sImgStarLaboratory, $sCocDiamond, $sRedLines, $iMinLevel, $iMaxLevel, $iMaxReturnPoints, $sReturnProps, $bForceCapture)
    If IsArray($aResult) And UBound($aResult) > 0 Then
        For $i = 0 To UBound($aResult) - 1
            If _Sleep(50) Then Return
            If Not $g_bRunState Then Return
            Local $aTEMP = $aResult[$i]
            Local $sObjectname = String($aTEMP[0])
            Local $aObjectpoints = $aTEMP[1]
            If StringInStr($aObjectpoints, "|") Then
                $aObjectpoints = StringReplace($aObjectpoints, "||", "|")
                If StringRight($aObjectpoints, 1) = "|" Then $aObjectpoints = StringTrimRight($aObjectpoints, 1)
                Local $tempObbjs = StringSplit($aObjectpoints, "|", $STR_NOCOUNT)
                For $j = 0 To UBound($tempObbjs) - 1
                    Local $tempObbj = StringSplit($tempObbjs[$j], ",", $STR_NOCOUNT)
                    If UBound($tempObbj) = 2 Then
                        $g_aiStarLaboratoryPos[0] = Number($tempObbj[0]) + 9
                        $g_aiStarLaboratoryPos[1] = Number($tempObbj[1] + 15)
                        ConvertFromVillagePos($g_aiStarLaboratoryPos[0], $g_aiStarLaboratoryPos[1])
                        ExitLoop 2
                    EndIf
                Next
            Else
                Local $tempObbj = StringSplit($aObjectpoints, ",", $STR_NOCOUNT)
                If UBound($tempObbj) = 2 Then
                    $g_aiStarLaboratoryPos[0] = Number($tempObbj[0]) + 9
                    $g_aiStarLaboratoryPos[1] = Number($tempObbj[1] + 15)
                    ConvertFromVillagePos($g_aiStarLaboratoryPos[0], $g_aiStarLaboratoryPos[1])
                    ExitLoop
                EndIf
            EndIf
        Next
    EndIf

    If $g_aiStarLaboratoryPos[0] > 0 And $g_aiStarLaboratoryPos[1] > 0 Then
        BuildingClickP($g_aiStarLaboratoryPos, "#0197")
        If _Sleep($DELAYLABORATORY1) Then Return ; Assumes 100ms from DelayTimes.au3
        Local $aResult = BuildingInfo(242, 475 + $g_iBottomOffsetY)
        If $aResult[0] = 2 Then
            If StringInStr($aResult[1], "Lab") Then
                SetLog("Star Laboratory located.", $COLOR_INFO)
                SetLog("Level " & $aResult[2] & ".", $COLOR_INFO)
                Return True
            Else
                ClearScreen()
                SetDebugLog("Found Star Laboratory Position invalid.", $COLOR_ERROR)
                $g_aiStarLaboratoryPos[0] = -1
                $g_aiStarLaboratoryPos[1] = -1
            EndIf
        Else
            ClearScreen()
            SetDebugLog("Found Star Laboratory Position invalid.", $COLOR_ERROR)
            $g_aiStarLaboratoryPos[0] = -1
            $g_aiStarLaboratoryPos[1] = -1
        EndIf
    EndIf

    SetLog("Cannot find Star Laboratory.", $COLOR_ERROR)
    Return False
EndFunc   ;==>LocateStarLab

Func StarLabGuiDisplay()
    Local Static $iLastTimeChecked[8]
    If $g_bFirstStart Then $iLastTimeChecked[$g_iCurAccount] = ""

    If _DateIsValid($g_sStarLabUpgradeTime) And _DateIsValid($iLastTimeChecked[$g_iCurAccount]) Then
        Local $iStarLabTime = _DateDiff('n', _NowCalc(), $g_sStarLabUpgradeTime)
        Local $iLastCheck = _DateDiff('n', $iLastTimeChecked[$g_iCurAccount], _NowCalc())
        SetDebugLog("Star Lab UpgradeTime: " & $g_sStarLabUpgradeTime & ", Star Lab DateCalc: " & $iStarLabTime)
        SetDebugLog("Star Lab LastCheck: " & $iLastTimeChecked[$g_iCurAccount] & ", Check DateCalc: " & $iLastCheck)
        If $iStarLabTime > 0 And $iLastCheck <= 360 Then Return
    EndIf

    If Not LocateStarLab() Then Return False

    Local $aResearchButton = findButton("Research", Default, 1, True)
    If IsArray($aResearchButton) And UBound($aResearchButton, 1) = 2 Then
        If $g_bDebugImageSave Then SaveDebugImage("StarLabUpgrade")
        ClickP($aResearchButton)
        If _Sleep($DELAYLABORATORY1) Then Return ; Assumes 100ms from DelayTimes.au3
    Else
        SetLog("Cannot find Star Laboratory Research Button!", $COLOR_ERROR)
        ClearScreen()
        Return False
    EndIf

    $iLastTimeChecked[$g_iCurAccount] = _NowCalc()
    Local $aiCloseBtn = findButton("CloseWindow")
    If Not IsArray($aiCloseBtn) Then
        SetLog("Trouble finding lab close button.", $COLOR_WARNING)
        CloseWindow()
        Return False
    EndIf

    If _ColorCheck(_GetPixelColor(790, 120 + $g_iMidOffsetY, True), Hex(0xA2CB6C, 6), 20) Then
        SetLog("Star Laboratory Upgrade in progress.", $COLOR_INFO)
        Local $sLabTimeOCR = getRemainTLaboratory(220, 200 + $g_iMidOffsetY)
        Local $iLabFinishTime = ConvertOCRTime("Lab Time", $sLabTimeOCR, False)
        SetDebugLog("$sLabTimeOCR: " & $sLabTimeOCR & ", $iLabFinishTime = " & $iLabFinishTime & " m")
        If $iLabFinishTime > 0 Then
            $iStarLabFinishTimeMod = $iLabFinishTime
            $g_sStarLabUpgradeTime = _DateAdd('n', Ceiling($iLabFinishTime), _NowCalc())
            If @error Then _logErrorDateAdd(@error)
            SetLog("Research will finish in " & $sLabTimeOCR & " (" & $g_sStarLabUpgradeTime & ")")
            StarLabStatusGUIUpdate()
        ElseIf $g_bDebugSetLog Then
            SetLog("Invalid getRemainTLaboratory OCR", $COLOR_DEBUG)
        EndIf
    Else
        SetLog("No Star Laboratory Upgrade in progress", $COLOR_INFO)
        $g_sStarLabUpgradeTime = ""
        StarLabStatusGUIUpdate()
    EndIf
    If ProfileSwitchAccountEnabled() Then SwitchAccountVariablesReload("Save")
    CloseWindow()
    Return True
EndFunc   ;==>StarLabGuiDisplay
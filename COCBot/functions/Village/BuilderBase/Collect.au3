; #FUNCTION# ====================================================================================================================
; Name ..........: Collect
; Description ...: Collects resources in Builder Base with reduced delays
; Syntax ........: CollectBuilderBase([$bSwitchToBB = False[, $bSwitchToNV = False[, $bSetLog = True[, $IsOttoVillage = False]]]])
; Parameters ....: $bSwitchToBB - Switch to Builder Base flag
;                  $bSwitchToNV - Switch to Normal Village flag
;                  $bSetLog - Log collection status
;                  $IsOttoVillage - Flag for Otto Village
; Return values .: None
; Author ........: Fliegerfaust (05-2017)
; Modified ......: [Your Name] (04-2025)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
#include-once

Func CollectBuilderBase($bSwitchToBB = False, $bSwitchToNV = False, $bSetLog = True, $IsOttoVillage = False)
    If Not $g_bChkCollectBuilderBase Then Return
    If Not $g_bRunState Then Return

    If $bSwitchToBB Then
        ClearScreen("Defaut", False)
        If Not SwitchBetweenBases(True, True) Then Return
    EndIf

    Local $IsGoldFull = CheckBBGoldStorageFull(False)
    Local $IsElixirFull = CheckBBElixirStorageFull(False)

    If $bSetLog Then
        If $IsOttoVillage Then
            SetLog("Collecting Resources on Otto Village", $COLOR_INFO)
        Else
            SetLog("Collecting Resources on Builders Base", $COLOR_INFO)
        EndIf
    EndIf
    If _Sleep(50) Then Return ; Reduced from $DELAYCOLLECT2 (250ms) to 50ms

    Local $sFilename = ""
    Local $aCollectXY, $t

    Local $aResult = multiMatches($g_sImgCollectRessourcesBB, 0, $CocDiamondDCD, $CocDiamondDCD)
    If UBound($aResult) > 1 Then
        For $i = 1 To UBound($aResult) - 1
            $sFilename = $aResult[$i][1]
            $aCollectXY = $aResult[$i][5]
            Switch StringLower($sFileName)
                Case "collectgold"
                    If $IsGoldFull Then ContinueLoop
                Case "collectelix"
                    If $IsElixirFull Then ContinueLoop
            EndSwitch
            If IsArray($aCollectXY) Then
                $t = Random(0, UBound($aCollectXY) - 1, 1)
                If $g_bDebugSetLog Then SetDebugLog($sFilename & " found, random pick(" & $aCollectXY[$t][0] & "," & $aCollectXY[$t][1] & ")", $COLOR_SUCCESS)
                If IsMainPageBuilderBase() Then Click($aCollectXY[$t][0], $aCollectXY[$t][1], 1, 120, "#0430")
                If _Sleep(50) Then Return ; Reduced from $DELAYCOLLECT2 (250ms) to 50ms
            EndIf
        Next
    EndIf

    If Not $IsOttoVillage Then CollectElixirCart($bSwitchToBB, $bSwitchToNV)

    If $bSwitchToNV Then
        SwitchBetweenBases()
        If _Sleep(Random(1000, 20000, 1)) Then Return ; Random 1-20 seconds only at the end
    EndIf
EndFunc   ;==>CollectBuilderBase

Func CollectElixirCart($bSwitchToBB = False, $bSwitchToNV = False)
    If Not $g_bRunState Then Return

    If $bSwitchToBB Then
        ClearScreen("Defaut", False)
        If Not SwitchBetweenBases(True, True) Then Return
    EndIf

    If CheckBBElixirStorageFull(False) Then Return

    SetDebugLog("Collecting Elixir Cart", $COLOR_INFO)
    ClearScreen("Left", False)
    If _Sleep(50) Then Return ; Reduced from $DELAYCOLLECT2 (250ms) to 50ms

    Local $bRet, $aiElixirCart, $aiCollect, $iRandomX = 0, $iRandomY = 0

    For $i = 0 To 20
        $aiElixirCart = decodeSingleCoord(FindImageInPlace2("ElixirCart", $g_sImgElixirCart, 470, 90 + $g_iMidOffsetY, 620, 190 + $g_iMidOffsetY))
        If IsArray($aiElixirCart) And UBound($aiElixirCart, 1) = 2 Then
            SetLog("Found Filled Elixir Cart", $COLOR_SUCCESS)
            $iRandomX = Random(0, 3, 1)
            $iRandomY = Random(15, 17, 1)
            PureClick($aiElixirCart[0] + $iRandomX, $aiElixirCart[1] + $iRandomY)
            If _Sleep(100) Then Return ; Reduced from 1000ms to 100ms
            $bRet = False
            For $j = 0 To 20
                $aiCollect = decodeSingleCoord(FindImageInPlace2("CollectElixirCart", $g_sImgCollectElixirCart, 600, 500 + $g_iMidOffsetY, 700, 540 + $g_iMidOffsetY))
                If IsArray($aiCollect) And UBound($aiCollect, 1) = 2 Then
                    $bRet = True
                    If _Sleep(200) Then Return ; Reduced from 2000ms to 200ms
                    ExitLoop
                EndIf
                If _Sleep(50) Then Return ; Reduced from 250ms to 50ms
            Next
            If $bRet Then
                SetLog("Collect Elixir Cart!", $COLOR_SUCCESS1)
                PureClickP($aiCollect)
                If _Sleep(300) Then Return ; Reduced from 3000ms to 300ms
            Else
                SetLog("Collect Button Not Found", $COLOR_ERROR)
            EndIf
            CloseWindow(20)
            If _Sleep(200) Then Return ; Reduced from 2000ms to 200ms
            ExitLoop
        EndIf
        If _Sleep(50) Then Return ; Reduced from 250ms to 50ms
    Next
EndFunc   ;==>CollectElixirCart
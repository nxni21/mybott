; #FUNCTION# ====================================================================================================================
; Name ..........: AttackBB
; Description ...: This file controls attacking preparation of the builders base
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........: Chilly-Chill (04-2019)
; Modified ......: Moebius14 (08-2023)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2025
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Global $IsChallengeCompleted = False
Global $bFirstAttackClick
Global $AttackCount
Global $iCounter = 0 

Func CheckCGCompleted()
    Local $bRet = False
    Local $CompleteBar = 0
    For $x = 1 To 12
        If QuickMIS("BC1", $g_sImgBBAttackBonus, 360, 450 + $g_iMidOffsetY, 500, 510 + $g_iMidOffsetY) Then
            SetLog("Congrats Chief, Stars Bonus Awarded", $COLOR_INFO)
            Click($g_iQuickMISX, $g_iQuickMISY)
            If _Sleep(250) Then Return
        EndIf
        If Not $g_bRunState Then Return
        SetDebugLog("Check challenges progress #" & $x, $COLOR_ACTION)
        If QuickMIS("BC1", $g_sImgGameComplete, 770, 474 + $g_iMidOffsetY, 830, 534 + $g_iMidOffsetY) Then
            SetLog("Nice, Game Completed", $COLOR_INFO)
            $g_bIsBBevent = 0
            $bRet = True
            ExitLoop
        EndIf
        If _ColorCheck(_GetPixelColor(830, 500 + $g_iMidOffsetY, True), Hex(0xFFD53D, 6), 10, Default) Then $CompleteBar += 1
        If $x = 12 And $CompleteBar = 0 Then
            SetDebugLog("No Complete Bar Detected, Stop Attack To Check", $COLOR_DEBUG)
            $g_bIsBBevent = 0
            $bRet = True
        EndIf
        If _Sleep(500) Then Return
    Next
    Return $bRet
EndFunc   ;==>CheckCGCompleted

Func DoAttackBB()
    If Not $g_bChkEnableBBAttack Then Return

    $IsChallengeCompleted = False
    $b_AbortedAttack = False
    $AttackCount = 0
    $iStartSlotMem = 0
    $iStartSlotMem2 = 0

    Local $maxAttacks = 0
    If $g_iBBAttackCount = 0 Then
        $maxAttacks = 999 ; Unlimited attacks if set to 0, but we'll cap it at 50 later
    ElseIf $g_iBBAttackCount = 1 Then
        $maxAttacks = Random(40, 50, 1)
        SetLog("Random Number Of Attacks: " & $maxAttacks, $COLOR_OLIVE)
    ElseIf $g_iBBAttackCount > 1 Then
        $maxAttacks = $g_iBBAttackCount - 1
        SetLog("Number Of Attacks: " & $maxAttacks, $COLOR_OLIVE)
    EndIf

    While $AttackCount < $maxAttacks
        If Not $g_bRunState Then Return
        If PrepareAttackBB($AttackCount) Then
            SetDebugLog("PrepareAttackBB(): Success.", $COLOR_SUCCESS)
            SetLog("Attacking For Stars", $COLOR_OLIVE)
            SetLog("Attack #" & $AttackCount + 1 & "/" & ($maxAttacks = 999 ? "~" : $maxAttacks), $COLOR_INFO)
            _AttackBB()
            If Not $g_bRunState Then ExitLoop
            If $IsChallengeCompleted Then ExitLoop
            $AttackCount += 1
            If $AttackCount > 50 Then
                SetLog("Already Attacked 50 times, stopping", $COLOR_INFO)
                $iCounter = 0
                ExitLoop
            EndIf
            If _Sleep($DELAYATTACKMAIN2) Then ExitLoop
            checkObstacles()
        Else
            SetLog("Failed to prepare attack, skipping this time...", $COLOR_DEBUG)
            ExitLoop
        EndIf
    WEnd

    If Not $g_bRunState Then Return
    If $AttackCount > 0 Then 
        SetLog("BB Attack Cycle Done", $COLOR_SUCCESS1)
        $iCounter = 0
    EndIf
    ZoomOut()
    $iStartSlotMem = 0
    $iStartSlotMem2 = 0
EndFunc   ;==>DoAttackBB

Func ClickFindNowButton()
    Local $bRet = False, $iRandomX = 0, $iRandomY = 0, $iRandom = 0
    For $i = 1 To 60
        $iRandomX = Random(645, 665, 1)
        $iRandomY = Random(415, 425, 1)
        $iRandom = Random(800, 5000, 1)
        If _ColorCheck(_GetPixelColor(655, 437 + $g_iMidOffsetY, True), Hex(0x89D239, 6), 20) Then
            Sleep($iRandom)
            Click($iRandomX, $iRandomY + $g_iMidOffsetY, 1, "Click Find Now Button")
            $bRet = True
            ExitLoop
        EndIf
        If _Sleep(1000) Then Return
    Next

    If _Sleep(3000) Then Return
    If Not $bRet Then
        SetLog("Could not locate Find Now Button to go find an attack.", $COLOR_ERROR)
        CloseWindow2()
        Return False
    EndIf

    Return $bRet
EndFunc   ;==>ClickFindNowButton

Func WaitCloudsBB()
    Local $bRet = True, $iRandomX = 0, $iRandomY = 0
    Local $count = 1
    While Not QuickMIS("BC1", $g_sImgBBAttackStart, 370 + $g_iMidOffsetY, 25, 430 + $g_iMidOffsetY, 60)
        If Not $g_bRunState Then Return
        If $count = 19 Then
            SetLog("Too long waiting Clouds", $COLOR_ERROR)
        EndIf

        $iRandomX = Random(430, 450, 1)
        $iRandomY = Random(535, 555, 1)
        If $count = 21 Then
            SetLog("Try To Close and Search Again", $COLOR_ACTION)
            If $g_bDebugImageSave Then SaveDebugImage("WaitCloudsBB")
            Click($iRandomX, $iRandomY + $g_iMidOffsetY)
            If _Sleep(5000) Then Return
            If Not ClickAttack() Then Return False
            If _Sleep(3000) Then Return
            SetLog("Try Again going to attack.", $COLOR_INFO)
            If Not ClickFindNowButton() Then
                ClearScreen("Defaut", False)
                Return False
            EndIf
        EndIf

        If $count > 30 Then
            CloseCoC(True)
            checkMainScreen(False, True)
            $bRet = False
            ExitLoop
        EndIf
        If isProblemAffect(True) Then Return
        $count += 1
        If _Sleep(1000) Then Return
    WEnd
    Return $bRet
EndFunc   ;==>WaitCloudsBB

Func _AttackBB()
    If Not $g_bRunState Then Return

    SetLog("Going to attack.", $COLOR_INFO)
    If Not ClickFindNowButton() Then
        ClearScreen("Defaut", False)
        Return False
    EndIf

    If Not $g_bRunState Then Return

    SetLog("Searching for Opponent.", $COLOR_BLUE)
    If Not WaitCloudsBB() Then Return
    If Not $g_bRunState Then Return

    ZoomOutBlueStacks5B()

    If Not isOnBuilderBaseEnemyVillage(True) Then
        SetLog("Zoom Out has failed and Attack was aborted", $COLOR_DEBUG)
        $b_AbortedAttack = True
        Return
    EndIf

    $g_aMachinePos = GetMachinePos()
    $g_DeployedMachine = False
    If _Sleep(150) Then Return
    Local $aBBAttackBar = GetAttackBarBB()
    $bFirstAttackClick = True
    AttackBB($aBBAttackBar)

    If Not $g_bRunState Then Return

    If EndBattleBB() Then SetLog("Battle ended", $COLOR_INFO)
    If _Sleep($DELAYATTACKMAIN2) Then Return
    checkObstacles()
EndFunc   ;==>_AttackBB

Func EndBattleBB()
    Local $bRet = True, $bBattleMachine = True, $bBomber = True
    Local $sDamage = 0, $sTmpDamage = 0, $bCountSameDamage = 1

    For $i = 1 To 200
        If Not $g_bRunState Then ExitLoop
        If $bBattleMachine Then $bBattleMachine = CheckBMLoop()
        If $bBomber Then $bBomber = CheckBomberLoop()
        $sDamage = getOcrOverAllDamage(776, 558 + $g_iMidOffsetY)
        SetDebugLog("[" & $i & "] EndBattleBB LoopCheck, [" & $bCountSameDamage & "] Overall Damage : " & $sDamage & "%", $COLOR_DEBUG2)
        If Number($sDamage) = Number($sTmpDamage) Then
            $bCountSameDamage += 1
        Else
            $bCountSameDamage = 1
        EndIf
        $sTmpDamage = Number($sDamage)
        If $sTmpDamage = 100 Then
            Local $EndLoop = 0
            While 1
                If BBGoldEnd("EndBattleBB") Then
                    $bRet = True
                    If _Sleep(3000) Then Return
                    ExitLoop 2
                EndIf
                $EndLoop += 1
                If $EndLoop = 20 Then ExitLoop
                If _Sleep(250) Then Return
            WEnd
            If _SleepStatus(3000) Then Return
            SetLog("Preparing For Second Round", $COLOR_INFO)
            If _Sleep(3000) Then Return
            $g_aMachinePos = GetMachinePos()
            $g_DeployedMachine = False
            If _Sleep(150) Then Return
            Local $aBBAttackBar = GetAttackBarBB(False, True)
            AttackBB($aBBAttackBar)
            If _Sleep(3000) Then Return
            $sTmpDamage = 0
            $bBattleMachine = True
            $bBomber = True
        EndIf

        If $bCountSameDamage > 25 Then
            If ReturnHomeDropTrophyBB(True) Then $bRet = True
            ExitLoop
        EndIf

        If BBGoldEnd("EndBattleBB") Then
            $bRet = True
            If _Sleep(3000) Then Return
            ExitLoop
        EndIf

        If IsProblemAffect(True) Then Return
        If Not $g_bRunState Then ExitLoop
        If _Sleep(1000) Then Return
    Next

    If Not $g_bRunState Then Return

    For $i = 1 To 3
        Select
            Case QuickMIS("BC1", $g_sImgBBReturnHome, 380, 510 + $g_iMidOffsetY, 480, 570 + $g_iMidOffsetY) = True
                If _Sleep(2000) Then Return
                Click($g_iQuickMISX, $g_iQuickMISY)
                If $g_bIsBBevent Then
                    If CheckCGCompleted() Then
                        $IsChallengeCompleted = True
                    Else
                        SetLog("Challenge is not finished...", $COLOR_ERROR)
                    EndIf
                EndIf
                If _Sleep(2000) Then Return
            Case QuickMIS("BC1", $g_sImgBBAttackBonus, 360, 450 + $g_iMidOffsetY, 500, 510 + $g_iMidOffsetY) = True
                SetLog("Congrats Chief, Stars Bonus Awarded", $COLOR_INFO)
                If _Sleep(2000) Then Return
                Click($g_iQuickMISX, $g_iQuickMISY)
                If _Sleep(2000) Then Return
                $bRet = True
            Case isOnBuilderBase() = True
                $bRet = True
        EndSelect
        If _Sleep(1000) Then Return
    Next

    If Not $bRet Then SetLog("Could not find finish battle screen", $COLOR_ERROR)
    Return $bRet
EndFunc   ;==>EndBattleBB

Func AttackBB($aBBAttackBar = True)
    Local $iSide = 0
    Local $ai_DropPoints
    
    If IsProblemAffect(True) Then Return
    Local $bTroopsDropped = False
    If Not $g_bRunState Then Return

    SetLog($g_bBBDropOrderSet = True ? "Deploying Troops in Custom Order." : "Deploying Troops in Order of Attack Bar.", $COLOR_BLUE)
    Local $bLoop = 0
    While Not $bTroopsDropped
        If Not $g_bRunState Then Return

        Local $iNumSlots = UBound($aBBAttackBar)
        If $g_bBBDropOrderSet = True Then
            Local $asBBDropOrder = StringSplit($g_sBBDropOrder, "|")
            Local $DeployedSlot = 0
            For $i = 0 To $g_iBBTroopCount - 1
                For $j = 0 To $iNumSlots - 1
                    If $aBBAttackBar[$j][0] = $asBBDropOrder[$i + 1] Then
                        $iSide = Random(1, 4, 1)
                        Switch $iSide
                            Case 1
                                $ai_DropPoints = _GetVectorOutZone($eVectorLeftTop)
                            Case 2
                                $ai_DropPoints = _GetVectorOutZone($eVectorRightBottom)
                            Case 3
                                $ai_DropPoints = _GetVectorOutZone($eVectorRightTop)
                            Case 4
                                $ai_DropPoints = _GetVectorOutZone($eVectorLeftBottom)		
                        EndSwitch
                        DeployBBTroop($aBBAttackBar[$j][0], $aBBAttackBar[$j][1] + 35, $aBBAttackBar[$j][2], $aBBAttackBar[$j][4], $ai_DropPoints)
                        $DeployedSlot += 1
                    EndIf
                    If $DeployedSlot = $iNumSlots Then ExitLoop 2
                Next
                If _Sleep($g_iBBNextTroopDelay) Then Return
                If $i = $g_iBBTroopCount - 1 Then $bLoop += 1
                If $bLoop = 4 Then
                    SaveDebugImage("AttackBar")
                    SetLog("All Troops Can't Be Deployed", $COLOR_DEBUG)
                    SetLog("Waiting for end of battle.", $COLOR_INFO)
                    ExitLoop 2
                EndIf
            Next
        Else
            Local $sTroopName = ""
            For $i = 0 To $iNumSlots - 1
                $iSide = Random(1, 4, 1)
                Switch $iSide
                    Case 1
                        $ai_DropPoints = _GetVectorOutZone($eVectorLeftTop)
                    Case 2
                        $ai_DropPoints = _GetVectorOutZone($eVectorRightBottom)
                    Case 3
                        $ai_DropPoints = _GetVectorOutZone($eVectorRightTop)
                    Case 4
                        $ai_DropPoints = _GetVectorOutZone($eVectorLeftBottom)		
                EndSwitch
                If $aBBAttackBar[$i][4] > 0 Then DeployBBTroop($aBBAttackBar[$i][0], $aBBAttackBar[$i][1] + 35, $aBBAttackBar[$i][2], $aBBAttackBar[$i][4], $ai_DropPoints)
                If $sTroopName <> $aBBAttackBar[$i][0] Then
                    If _Sleep($g_iBBNextTroopDelay) Then Return
                Else
                    _Sleep($DELAYRESPOND)
                EndIf
                $sTroopName = $aBBAttackBar[$i][0]
                If $i = $iNumSlots - 1 Then $bLoop += 1
                If $bLoop = 4 Then
                    SaveDebugImage("AttackBar")
                    SetLog("All Troops Can't Be Deployed", $COLOR_DEBUG)
                    SetLog("Waiting for end of battle.", $COLOR_INFO)
                    ExitLoop 2
                EndIf
            Next
        EndIf
        $aBBAttackBar = GetAttackBarBB(True)
        If $aBBAttackBar = "" Then
            SetLog("All Troops Deployed", $COLOR_SUCCESS)
            SetLog("Waiting for end of battle.", $COLOR_INFO)
            $bTroopsDropped = True
            ; Removed RestartCOCAfterDeployAllTroops() to wait for battle end
        EndIf
    WEnd

    If Not $g_bRunState Then Return
    If IsProblemAffect(True) Then Return
EndFunc   ;==>AttackBB

Func DeployBBTroop($sName, $x, $y, $iAmount, $ai_AttackDropPoints)
    Local $iRandomX = 0, $iRandomY = 0
    If $sName = "BattleMachine" Then
        Local $aBMPos = GetMachinePos()
        If IsArray($aBMPos) And $aBMPos <> 0 Then
            If StringInStr($aBMPos[2], "Copter") Then
                $sName = "Battle Copter"
            Else
                $sName = "Battle Machine"
            EndIf
        EndIf
        SetLog("Deploying " & $sName, $COLOR_ACTION)
    Else
        SetLog("Deploying " & $sName & " x" & String($iAmount), $COLOR_ACTION)
    EndIf
    $iRandomX = Random(1, 20, 1)
    $iRandomY = Random(1, 15, 1)
    PureClick($x + $iRandomX, $y + $iRandomY)
    If _Sleep($g_iBBSameTroopDelay) Then Return

    For $j = 0 To $iAmount - 1
        If Not $g_bRunState Then Return
        Local $iPoint = Random(0, UBound($ai_AttackDropPoints) - 1, 1)
        Local $iPixel2 = $ai_AttackDropPoints[$iPoint]
        $iRandomX = Random(1, 25, 1)
        $iRandomY = Random(1, 25, 1)
        SetLog("Drop Point 1: " & $iPixel2[0] & ", " & $iPixel2[1], $COLOR_DEBUG)
        $iPixel2[0] = $iPixel2[0] + $iRandomX
        $iPixel2[1] = $iPixel2[1] + $iRandomY
        SetLog("Drop Point 2: " & $iPixel2[0] & ", " & $iPixel2[1], $COLOR_DEBUG)
        If $bFirstAttackClick Then
            IsClickOnPotions($iPixel2[0], $iPixel2[1])
            $bFirstAttackClick = False
        EndIf
        PureClickP($iPixel2)
        Local $b_MachineTimeOffset = 0
        If $sName = "Battle Copter" Or $sName = "Battle Machine" Then
            Local $b_MachineTimeOffsetDiff = __TimerInit()
            Local $bRet = False
            For $i = 1 To 16
                If Not $g_bRunState Then Return
                If _Sleep(250) Then Return
                Local $aBMPosCheck = GetMachinePos()
                If IsArray($aBMPosCheck) And $aBMPosCheck <> 0 And Number($aBMPos[1]) <> Number($aBMPosCheck[1]) Then
                    If $g_bDebugSetLog Then
                        Local $b_MachineTimeOffsetSec = Round(__TimerDiff($b_MachineTimeOffsetDiff) / 1000, 2)
                        SetLog("$aBMPosCheck fixed in : " & $b_MachineTimeOffsetSec & " second", $COLOR_DEBUG)
                    EndIf
                    $bRet = True
                EndIf
                If $bRet Then ExitLoop
            Next
            Local $g_DeployColor[2] = [0xCD3AFF, 0xFF8BFF]
            For $z = 0 To 1
                If Not $g_bRunState Then Return
                If _ColorCheck(_GetPixelColor(71, 663 + $g_iBottomOffsetY, True), Hex(0x4E4E4E, 6), 20, Default) Then
                    $g_DeployedMachine = True
                    $g_bMachineAliveOnAttackBar = False
                    SetLog($sName & " Deployed", $COLOR_SUCCESS)
                    ExitLoop
                EndIf
                If WaitforPixel(24, 552 + $g_iBottomOffsetY, 30, 554 + $g_iBottomOffsetY, Hex($g_DeployColor[$z], 6), 30, 5) Then
                    $g_DeployedMachine = True
                    SetLog($sName & " Deployed", $COLOR_SUCCESS)
                    PureClickP($aBMPos)
                    SetLog("Activate " & $sName & " Ability", $COLOR_SUCCESS)
                    ExitLoop
                EndIf
                If $z = 1 And $g_bDebugImageSave Then SaveDebugImage("AttackBar")
            Next
        EndIf
        If Number($g_iBBSameTroopDelay - $b_MachineTimeOffset) > 0 Then
            If _Sleep($g_iBBSameTroopDelay - $b_MachineTimeOffset) Then Return
        EndIf
    Next
EndFunc   ;==>DeployBBTroop

Func GetMachinePos()
    Local $aBMPos = QuickMIS("CNX", $g_sImgBBBattleMachine, 18, 540 + $g_iBottomOffsetY, 85, 665 + $g_iBottomOffsetY)
    Local $aCoords[3]
    If $aBMPos = -1 Then Return 0

    If IsArray($aBMPos) Then
        $aCoords[0] = $aBMPos[0][1]
        $aCoords[1] = $aBMPos[0][2]
        $aCoords[2] = $aBMPos[0][0]
        Return $aCoords
    EndIf
    Return 0
EndFunc   ;==>GetMachinePos

Func CheckBMLoop($aBMPos = $g_aMachinePos)
    Local $count = 0, $loopcount = 0
    Local $BMDeadX = 71, $BMDeadColor
    Local $BMDeadY = 663 + $g_iBottomOffsetY
    Local $MachineName = ""

    If $aBMPos = 0 Or Not $g_bMachineAliveOnAttackBar Then Return False
    If Not IsArray($aBMPos) Then Return False

    If StringInStr($aBMPos[2], "Copter") Then
        $MachineName = "Battle Copter"
    Else
        $MachineName = "Battle Machine"
    EndIf

    For $i = 1 To 5
        If IsProblemAffect(True) Then Return
        If Not $g_bRunState Then Return False

        If QuickMIS("BC1", $g_sImgDirMachineAbility, $aBMPos[0] - 35, $aBMPos[1] - 40, $aBMPos[0] + 35, $aBMPos[1] + 40) Then
            If StringInStr($g_iQuickMISName, "Wait") Then
                ExitLoop
            ElseIf StringInStr($g_iQuickMISName, "Ability") Then
                PureClickP($aBMPos)
                SetLog("Activate " & $MachineName & " Ability", $COLOR_SUCCESS)
                ExitLoop
            EndIf
        EndIf

        $BMDeadColor = _GetPixelColor($BMDeadX, $BMDeadY, True)
        If _ColorCheck($BMDeadColor, Hex(0x4E4E4E, 6), 20, Default) Then
            SetLog($MachineName & " is Dead", $COLOR_DEBUG2)
            Return False
        EndIf

        If $BMDeadColor = "000000" Then
            ExitLoop
        EndIf

        If _Sleep(500) Then Return
        If $loopcount > 60 Then Return
        $loopcount += 1
    Next
    Return True
EndFunc   ;==>CheckBMLoop

Func CheckBomberLoop()
    Local $bRet = True
    Local $nbrDeadBomber = 0
    If Not $g_bBomberOnAttackBar Or UBound($g_aBomberOnAttackBar) = 0 Then Return False
    Local $isGreyBanner = False, $ColorPickBannerX = 0, $iTroopBanners = 583 + $g_iBottomOffsetY

    For $i = 0 To UBound($g_aBomberOnAttackBar) - 1
        If Not $g_bRunState Then Return False
        $ColorPickBannerX = $g_aBomberOnAttackBar[$i][0] + 37
        $isGreyBanner = _ColorCheck(_GetPixelColor($ColorPickBannerX, $iTroopBanners, True), Hex(0x707070, 6), 10, Default)
        If $isGreyBanner Then
            If UBound($g_aBomberOnAttackBar) = 1 Then
                SetLog("Bomber is Dead", $COLOR_DEBUG2)
            Else
                If $BomberDead[$i] = 0 Then SetLog("Bomber " & $i + 1 & " is Dead", $COLOR_DEBUG2)
                $BomberDead[$i] = 1
            EndIf
            $nbrDeadBomber += 1
            If $nbrDeadBomber = UBound($g_aBomberOnAttackBar) Then
                $bRet = False
                ExitLoop
            EndIf
        EndIf
        If QuickMIS("BC1", $g_sImgDirBomberAbility, $g_aBomberOnAttackBar[$i][0], $g_aBomberOnAttackBar[$i][1] - 30, $g_aBomberOnAttackBar[$i][0] + 70, $g_aBomberOnAttackBar[$i][1] + 30) Then
            If StringInStr($g_iQuickMISName, "Ability") Then
                Click($g_iQuickMISX, $g_iQuickMISY)
                If UBound($g_aBomberOnAttackBar) = 1 Then
                    SetLog("Activate Bomber Ability", $COLOR_SUCCESS)
                    ExitLoop
                Else
                    SetLog("Activate Bomber " & $i + 1 & " Ability", $COLOR_SUCCESS)
                    If _Sleep(Random(500, 1000, 1)) Then ExitLoop
                EndIf
            EndIf
        EndIf
    Next
    Return $bRet
EndFunc   ;==>CheckBomberLoop

Func IsBBAttackPage()
    Local $bRet = False
    If _ColorCheck(_GetPixelColor(30, 550 + $g_iMidOffsetY, True), Hex(0xCF0D0E, 6), 20) Then
        $bRet = True
    EndIf
    Return $bRet
EndFunc   ;==>IsBBAttackPage

Func BBGoldEnd($sLogText = "BBGoldEnd")
    If _CheckPixel($aBBGoldEnd, True, Default, $sLogText) Then
        SetDebugLog("Battle Ended", $COLOR_DEBUG2)
        Return True
    Else
        Return False
    EndIf
EndFunc   ;==>BBGoldEnd

Func IsClickOnPotions(ByRef $x, ByRef $y)
    Local $bResult = False
    SetDebugLog("IsClickOnPotions :" & $x & ", " & $y, $COLOR_INFO)
    If $y > 500 + $g_iBottomOffsetY Then
        $y = 500 + $g_iBottomOffsetY
        If $x < 460 Then
            $x = 460
        EndIf
        SetDebugLog("Adjusted Pixel :" & $x & ", " & $y, $COLOR_INFO)
        $bResult = True
    EndIf
    Return $bResult
EndFunc   ;==>IsClickOnPotions

Func RestartCOCAfterDeployAllTroops()
    Local $iRandom = 0, $iRandom2 = 0
    $iCounter = $iCounter + 1
    $iRandom = Random(5000, 10000, 1)
    $iRandom2 = Random(1, 3, 1)
    If _Sleep($iRandom) Then Return
    CloseCoC(True)
    SetLog("Attack Counter: " & $iCounter, $COLOR_SUCCESS)
    If ($iCounter >= 10) Then
        $iRandom2 = Random(2, 3, 1)
    EndIf
    If ($iCounter >= 15) Or ($iCounter >= 7 And $iRandom2 = 3) Then
        If _Sleep($iRandom) Then Return
        ZoomOut()
        CollectBuilderBase()
        $iCounter = 0
    EndIf
EndFunc
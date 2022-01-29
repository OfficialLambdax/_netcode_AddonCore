#include-once
#include "_netcode_Core.au3"

#cs

	This UDF does nothing byitself. It just provides code for various Addons
	of the _netcode UDF.

#ce


Global $__net_Addon_sAddonVersion = "0.1.1"
Global $__net_Addon_sNetcodeTestedVersion = "0.1.5.24"
Global $__net_Addon_bLogToConsole = True

If $__net_Addon_sNetcodeTestedVersion <> $__net_sNetcodeVersion Then
	ConsoleWrite("! _netcode Warning ! Potential incompatibility detected" & @CRLF)
	ConsoleWrite("- You are running version v" & $__net_Addon_sAddonVersion & " of _netcode_AddonCore.au3" & @CRLF)
	ConsoleWrite("- This version of the AddonCore got tested with _netcode_Core.au3 v" & $__net_Addon_sNetcodeTestedVersion & @CRLF)
	ConsoleWrite("- But your _netcode_Core.au3 version is v" & $__net_sNetcodeVersion & @CRLF)
	ConsoleWrite("- If you have any issues then try matching the versions." & @CRLF)
	ConsoleWrite("+ This is no fatal error. So your script wont be halted." & @CRLF & @CRLF)
EndIf


#Region
	; General functions

	; $nID could be a name, socket or what so ever
	Func __netcode_Addon_SetVar(Const $nID, $sName, $vData)
		_storageS_Overwrite($nID, '_netcode_Addon_' & $sName, $vData)
	EndFunc

	Func __netcode_Addon_GetVar(Const $nID, $sName)
		Return _storageS_Read($nID, '_netcode_Addon_' & $sName)
	EndFunc

	;~ Func __netcode_Addon_Create

	; creates an empty 1D storage array. $nID could be a parent socket or a route name
	Func __netcode_Addon_CreateSocketList(Const $nID)
		Local $arSockets[0]
		_storageS_Overwrite($nID, '_netcode_Addon_SocketList', $arSockets)
	EndFunc

	; disconnects all sockets and cleans the vars
	Func __netcode_Addon_WipeSocketList(Const $nID)
		Local $arSockets = __netcode_Addon_GetSocketList($nID)
		If Not IsArray($arSockets) Then Return

		Local $nArSize = UBound($arSockets)
		For $i = 0 To $nArSize - 1
			__netcode_TCPCloseSocket($arSockets[$i])
			_storageS_TidyGroupVars($arSockets[$i])
		Next

		_storageS_TidyGroupVars($nID)
	EndFunc

	Func __netcode_Addon_SetSocketList(Const $nID, $arSockets)
		_storageS_Overwrite($nID, '_netcode_Addon_SocketList', $arSockets)
	EndFunc

	Func __netcode_Addon_GetSocketList(Const $nID)
		Return _storageS_Read($nID, '_netcode_Addon_SocketList')
	EndFunc

	; adds the socket to the socket list
	Func __netcode_Addon_AddToSocketList(Const $nID, $hSocket)
		Local $arSockets = __netcode_Addon_GetSocketList($nID)
		If Not IsArray($arSockets) Then Return False

		Local $nArSize = UBound($arSockets)
		ReDim $arSockets[$nArSize + 1]
		$arSockets[$nArSize] = $hSocket

		__netcode_Addon_SetSocketList($nID, $arSockets)

		Return True
	EndFunc

	; dont tidy the removed socket vars as they are maybe still used
	Func __netcode_Addon_RemoveFromSocketList(Const $nID, $hSocket)
		Local $arSockets = __netcode_Addon_GetSocketList($nID)
		If Not IsArray($arSockets) Then Return False

		Local $nArSize = UBound($arSockets)
		Local $nIndex = -1

		For $i = 0 To $nArSize - 1
			if $arSockets[$i] = $hSocket Then
				$nIndex = $i
				ExitLoop
			EndIf
		Next

		if $nIndex = -1 Then Return False

		$arSockets[$nIndex] = $arSockets[$nArSize - 1]
		ReDim $arSockets[$nArSize - 1]

		__netcode_Addon_SetSocketList($nID, $arSockets)

		Return True
	EndFunc

	Func __netcode_Addon_RecvPackages(Const $hSocket)

		Local $sPackages = ''
		Local $sTCPRecv = ''
		Local $hTimer = TimerInit()
		Local $nLen = 0

		Do

			$sTCPRecv = __netcode_TCPRecv($hSocket)

			Switch @error

				Case 1, 10050 To 10054

					; if we received something and then the disconnect happend then return the package first
					; otherwise we would loose that data
					if $sPackages <> "" Then Return SetExtended($nLen, $sPackages)

					Return SetError(1, 0, False)

			EndSwitch

			$nLen += @extended
			$sPackages &= BinaryToString($sTCPRecv)

			if TimerDiff($hTimer) > 20 Then ExitLoop

		Until $sTCPRecv = ''

		Return SetExtended($nLen, $sPackages)

	EndFunc

	; only difference to the _netcode_Core.au3 variant is that this func stores the ip.
	; _netcode_Core should also do that.
	Func __netcode_Addon_SocketToIP(Const $hSocket)

		Local $sIP = __netcode_Addon_GetVar($hSocket, 'IP')
		if $sIP Then Return $sIP

		$sIP = _netcode_SocketToIP($hSocket)
		__netcode_Addon_SetVar($hSocket, 'IP', $sIP)

		Return $sIP

	EndFunc

#EndRegion



#Region
	; shared functions

	Func __netcode_Addon_Log($nAddonID, $nCode, $vData = Null, $vData2 = Null, $vData3 = Null)

		if Not $__net_Addon_bLogToConsole Then Return

		Local $sText = ""

		Switch $nAddonID

			Case 0 ; relay

				$sText = "Relay "

				Switch $nCode

					Case 0 ; started relay udf
						$sText &= "successfully started"

					Case 1 ; shutdown
						$sText &= "successfully shutdown"

					Case 2 ; created relay
						$sText &= "successfully created @ socket " & $vData

					Case 3 ; couldnt create relay
						$sText &= "could not be created @ socket " & $vData

					Case 4 ; closed relay
						$sText &= "successfully closed @ socket " & $vData

					Case 5 ; couldn close relay
						$sText &= "could not be closed @ socket " & $vData

					; reserved

					Case 10 ; new incoming
						$sText &= "new incoming connection from IP: " & __netcode_Addon_SocketToIP($vData)

					Case 11 ; connecting to
						$sText &= "connecting to IP: " & $vData ; this is the ip

					Case 12 ; outgoing connected
						$sText &= "successfully connected to IP: " & __netcode_Addon_SocketToIP($vData)

					Case 13 ; linked incoming with outgoing
						$sText &= "linked IP: " & __netcode_Addon_SocketToIP($vData) & " to IP: " & __netcode_Addon_SocketToIP($vData2)

					Case 14 ; outgoing timeout
						$sText &= "cannot connect to IP: " & __netcode_Addon_SocketToIP($vData)

					Case 15 ; disconnected socket
						$sText &= "disconnected IP: " & __netcode_Addon_SocketToIP($vData)

					Case 16 ; send data
						$sText &= "send " & Round($vData3 / 1024, 2) & " KB" & @TAB & @TAB & "from IP: " & __netcode_Addon_SocketToIP($vData) & " to IP: " & __netcode_Addon_SocketToIP($vData2)


				EndSwitch


			Case 1 ; proxy

				$sText = "Proxy "

				Switch $nCode

					Case 1 ; proxy startup
						$sText &= "successfully started"

					Case 2 ; proxy shutdown
						$sText &= "successfully shutdown"

					Case 3 ; created middleman
						$sText &= "successfully created middleman with ID: " & $vData & " at position " & $vData2

					Case 4 ; could not create middleman
						$sText &= "could not create middleman with ID: " & $vData & " at position " & $vData2

					Case 5 ; removed middleman
						$sText &= "removed middleman with ID: " & $vData

					Case 6 ; created proxy
						$sText &= "successfully created proxy parent @ socket " & $vData & " with middleman ID: " & $vData2

					Case 7 ; could not create proxy
						$sText &= "Error: $sConOrDest_MiddlemanID needs to be Connect or Destination but is " & $vData

					Case 8 ; could not start listener
						$sText &= "Error: Could not start proxy at: " & $vData

					Case 9 ; closed proxy
						$sText &= "successfully closed proxy parent @ socket " & $vData

					Case 10 ; set middleman
						$sText &= "successfully set middleman " & $vData & " at position " & $vData2

					Case 11 ; could not set middleman
						$sText &= "Error: Middleman with ID: " & $vData & " doesnt exist"

					; reserved


					Case 20 ; could not call connect middleman
						$sText &= "Error: Could not call connect middleman with ID: " & $vData

					Case 21 ; new incoming
						$sText &= "new connection from IP: " & __netcode_Addon_SocketToIP($vData)

					Case 22 ; no destination middleman
						$sText &= "Error: No destination middleman for proxy parent @ socket: " & $vData

					Case 23 ; the incoming connection disconnected
						$sText &= "The incoming connection disconnected from IP: " & __netcode_Addon_SocketToIP($vData)

					Case 24 ; the destination middleman call failed
						$sText &= "Error: The destination middleman with ID: " & $vData & " failed to call for proxy parent @ socket: " & $vData2

					Case 25 ; invalid destination middleman return
						$sText &= "Error: Invalid destination middleman return with ID: " & $vData & " for proxy parent @ socket: " & $vData2

					Case 26 ; incoming destination timeout
						$sText &= "incoming connection destination evaluation timeout. IP: " & __netcode_Addon_SocketToIP($vData)

					; reserved

					Case 30 ; middleman returned array to small
						$sText &= "Error: Middleman with ID: " & $vData & " returned to small destination array for proxy parent @ socket: " & $vData2

					Case 31 ; invalid array
						$sText &= "Error: Middleman with ID: " & $vData & " returned data for the incoming socket but forgot to set the When to send toggle"

					Case 32 ; connecting
						$sText &= "connecting to destination: " & $vData

					Case 33 ; successfully connected
						$sText &= "successfully connected IP: " & __netcode_Addon_SocketToIP($vData) & " with IP: " & __netcode_Addon_SocketToIP($vData2)

					Case 34 ; connect attempt timeouted
						$sText &= "connect attempt timeouted for IP: " & __netcode_Addon_SocketToIP($vData)

					Case 35 ; send
						$sText &= "send " & Round($vData3 / 1024, 2) & " KB" & @TAB & @TAB & "from IP: " & __netcode_Addon_SocketToIP($vData) & " to IP: " & __netcode_Addon_SocketToIP($vData2)

					Case 36 ; data forward successfully rejected
						$sText &= "middleman with ID: " & $vData3 & " successfully rejected data relay from IP: " & __netcode_Addon_SocketToIP($vData) & " to IP: " & __netcode_Addon_SocketToIP($vData2)

					; reserved

					Case 99 ; disconnected
						$sText &= "disconnected from IP: " & __netcode_Addon_SocketToIP($vData)

					Case 100 ; custom
						$sText &= $vData


				EndSwitch


			Case 2 ; router


		EndSwitch

		ConsoleWrite(@HOUR & ':' & @MIN & ':' & @SEC & '.' & @MSEC & @TAB & $sText & @CRLF)

	EndFunc



#EndRegion



#Region
; tcp functions. Cut from _netcode_Core.au3 for when they had to be modified


#cs
Func __netcode_Addon_TCPRecv(Const $hSocket, $nSize = 65536) ; 65536

	Local $nError = 0
	Local $tRecvBuffer = DllStructCreate("byte[" & $nSize & "]")

	; every socket is already non blocking, but recv still blocks occassionally which is very bad. So i reset to non blockig mode
	; until i figured why recv blocks while it shouldnt.
	Local $arRet = DllCall($__net_hWs2_32, "int", "ioctlsocket", "int", $hSocket, "long", 0x8004667e, "ulong*", 1) ;FIONBIO

	$arRet = DllCall($__net_hWs2_32, "int", "recv", "int", $hSocket, "ptr", DllStructGetPtr($tRecvBuffer), "int", $nSize, "int", 0)

	; "If the connection has been gracefully closed, the return value is zero."
	if $arRet[0] = 0 Then
		Return SetError(1, 0, False)
	EndIf

	if $arRet[0] = -1 Then
		$nError = __netcode_WSAGetLastError()
		if $nError > 10000 Then ; "Error codes below 10000 are standard Win32 error codes"
			if $nError <> 10035 Then
				Return SetError($nError, 2, False)
			EndIf
		EndIf

		Return ""
	EndIf

	Return SetError(0, $arRet[0], BinaryMid(DllStructGetData($tRecvBuffer, 1), 1, $arRet[0]))
EndFunc
#ce

#EndRegion
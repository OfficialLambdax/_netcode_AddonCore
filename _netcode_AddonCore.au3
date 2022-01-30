#include-once
#include "_netcode_Core.au3"

#cs

	This UDF does nothing byitself. It just provides code for various Addons
	of the _netcode UDF.

#ce


Global $__net_Addon_sAddonVersion = "0.1.2"
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

					Case Else
						$sText &= "Missing ID " & $nCode

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

					Case Else
						$sText &= "Missing ID " & $nCode


				EndSwitch


			Case 2 ; router

				$sText = "Router "

				Switch $nCode

					Case 1 ; startup
						$sText &= "successfully started"

					Case 2 ; shutdown
						$sText &= "successfully shutdown"

					Case 3 ; created middleman
						$sText &= "successfully created middleman with ID: " & $vData & " at position " & $vData2

					Case 4 ; could not create middleman
						$sText &= "could not create middleman with ID: " & $vData & " at position " & $vData2

					Case 5 ; removed middleman
						$sText &= "removed middleman with ID: " & $vData

					Case 6 ; created router
						$sText &= "successfully created router parent @ socket " & $vData & " with middleman ID: " & $vData2

					Case 7 ; could not create proxy
						$sText &= "Error: $sConOrDest_MiddlemanID needs to be Connect or Destination but is " & $vData

					Case 8 ; could not start listener
						$sText &= "Error: Could not start router at: " & $vData

					Case 9 ; closed router
						$sText &= "successfully closed router parent @ socket " & $vData

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

					Case 27 ; route id
						$sText &= "successfully evaluated destination: " & $vData & " for IP: " & __netcode_Addon_SocketToIP($vData2)

					Case 28 ; couldnt find route id
						$sText &= "Error: Route id: " & $vData & " is unknown for IP: " & __netcode_Addon_SocketToIP($vData2)

					Case 29 ; route id doesnt exist
						$sText &= "Error: Could not determine route id for IP: " & __netcode_Addon_SocketToIP($vData)

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

					Case Else
						$sText &= "Missing ID " & $nCode


				EndSwitch

			Case 100 ; custom

				$sText = $nCode & ' ' & $vData


			Case Else ; unknown

				Return


		EndSwitch

		ConsoleWrite(@HOUR & ':' & @MIN & ':' & @SEC & '.' & @MSEC & @TAB & $sText & @CRLF)

	EndFunc


	Func __netcode_Addon_CreateSocketLists_InOutRel($sID)
		__netcode_Addon_CreateSocketList($sID)
		__netcode_Addon_CreateSocketList($sID & '_IncomingPending')
		__netcode_Addon_CreateSocketList($sID & '_OutgoingPending')
	EndFunc

	Func __netcode_Addon_AddToIncomingSocketList($sID, $hSocket)
		__netcode_Addon_AddToSocketList($sID & '_IncomingPending', $hSocket)
		__netcode_Addon_SetVar($hSocket, 'SocketIs', "Incoming")
		__netcode_Addon_SetVar($hSocket, 'TimeoutTimer', TimerInit()) ; needs to become a toggle
	EndFunc

	Func __netcode_Addon_AddToOutgoingSocketList($sID, $hSocket)
		__netcode_Addon_AddToSocketList($sID & '_OutgoingPending', $hSocket)
		__netcode_Addon_SetVar($hSocket, 'SocketIs', "Outgoing")
		__netcode_Addon_SetVar($hSocket, 'TimeoutTimer', TimerInit()) ; needs to become a toggle
	EndFunc

	Func __netcode_Addon_AddToRelaySocketList($sID, $hSocket)
		__netcode_Addon_AddToSocketList($sID, $hSocket)
	EndFunc

	Func __netcode_Addon_RemoveFromIncomingSocketList($sID, $hSocket)
		__netcode_Addon_RemoveFromSocketList($sID & '_IncomingPending', $hSocket)
	EndFunc

	Func __netcode_Addon_RemoveFromOutgoingSocketList($sID, $hSocket)
		__netcode_Addon_RemoveFromSocketList($sID & '_OutgoingPending', $hSocket)
	EndFunc

	Func __netcode_Addon_RemoveFromRelaySocketList($sID, $hSocket)
		__netcode_Addon_RemoveFromSocketList($sID, $hSocket)
	EndFunc

	Func __netcode_Addon_GetIncomingSocketList($sID)
		Return __netcode_Addon_GetSocketList($sID & '_IncomingPending')
	EndFunc

	Func __netcode_Addon_GetOutgoingSocketList($sID)
		Return __netcode_Addon_GetSocketList($sID & '_OutgoingPending')
	EndFunc

	Func __netcode_Addon_GetRelaySocketList($sID)
		Return __netcode_Addon_GetSocketList($sID)
	EndFunc

	Func __netcode_Addon_GetSocketType($hSocket)
		Return __netcode_Addon_GetVar($hSocket, 'SocketIs')
	EndFunc

	Func __netcode_Addon_DisconnectAndRemoveClient(Const $hSocket, $hRemoveSocket, $nAddonID)

		__netcode_Addon_Log($nAddonID, 99, $hRemoveSocket)

		__netcode_TCPCloseSocket($hRemoveSocket)
		__netcode_Addon_RemoveFromIncomingSocketList($hSocket, $hRemoveSocket)
		__netcode_Addon_RemoveFromOutgoingSocketList($hSocket, $hRemoveSocket)
		__netcode_Addon_RemoveFromRelaySocketList($hSocket, $hRemoveSocket)

		_storageS_TidyGroupVars($hRemoveSocket)

	EndFunc

	; note: remove
	Func __netcode_Addon_DisconnectAndRemoveClients(Const $hSocket, $hIncomingSocket, $hOutgoingSocket, $nAddonID)

		__netcode_Addon_DisconnectAndRemoveClient($hSocket, $hIncomingSocket, $nAddonID)
		If $hOutgoingSocket Then __netcode_Addon_DisconnectAndRemoveClient($hSocket, $hOutgoingSocket, $nAddonID)

	EndFunc


	#Region
		; middleman functions


		Func __netcode_Addon_RegisterMiddleman($sID, $sCallback, $sPosition, $nAddonID)

			if __netcode_Addon_GetVar($sID, 'Callback') Then
				__netcode_Addon_Log($nAddonID, 4, $sID, $sPosition)
				Return SetError(1, 0, False) ; middleman with this id is already known
			EndIf

			__netcode_Addon_SetVar($sID, 'Callback', $sCallback)
			__netcode_Addon_SetVar($sID, 'Position', $sPosition)

			__netcode_Addon_Log($nAddonID, 3, $sID, $sPosition)

			Return True

		EndFunc

		Func __netcode_Addon_RemoveMiddleman($sID, $nAddonID)
			_storageS_TidyGroupVars($sID)
			__netcode_Addon_Log(1, 5, $nAddonID)
		EndFunc

		Func __netcode_Addon_SetMiddleman(Const $hSocket, $sID, $nAddonID)

			Local $sPosition = __netcode_Addon_GetVar($sID, 'Position')
			if Not $sPosition Then
				__netcode_Addon_Log($nAddonID, 11, $sID)
				Return SetError(1, 0, False)
			EndIf

			__netcode_Addon_SetVar($hSocket, $sPosition, $sID)

			__netcode_Addon_Log($nAddonID, 10, $sID, $sPosition)

			Return True

		EndFunc

		; adds the socket to the IncomingPending list only when there either is no middleman or the middleman doesnt yet tells us a destination
		Func __netcode_Addon_NewIncomingMiddleman(Const $hSocket, $hIncomingSocket, $nAddonID)

			__netcode_Addon_Log($nAddonID, 21, $hIncomingSocket)

			; inherit parents preset middlemans
			Local $sID = __netcode_Addon_GetVar($hSocket, 'Connect')
			__netcode_Addon_SetVar($hIncomingSocket, 'Connect', $sID)
			__netcode_Addon_SetVar($hIncomingSocket, 'Destination', __netcode_Addon_GetVar($hSocket, 'Destination'))
			__netcode_Addon_SetVar($hIncomingSocket, 'Between', __netcode_Addon_GetVar($hSocket, 'Between'))
			__netcode_Addon_SetVar($hIncomingSocket, 'Disconnect', __netcode_Addon_GetVar($hSocket, 'Disconnect'))

			; run middleman if present
			Local $vMiddlemanReturn = ""
			If $sID Then
				$vMiddlemanReturn = Call(__netcode_Addon_GetVar($sID, 'Callback'), $hIncomingSocket, 'Connect', Null)
				If @error Then
					; show error
					__netcode_Addon_Log($nAddonID, 20, $sID)
					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $hIncomingSocket, False, $nAddonID)
				EndIf
			EndIf

			; add to IncomingPending list if not destination is yet set
			If IsArray($vMiddlemanReturn) Then
				__netcode_Addon_ConnectOutgoingMiddleman($hSocket, $hIncomingSocket, $vMiddlemanReturn, $sID, 1)
			ElseIf $vMiddlemanReturn == False Then ; must be == because If "" = False Then is True
				__netcode_Addon_DisconnectAndRemoveClients($hSocket, $hIncomingSocket, False, $nAddonID)
			Else
				__netcode_Addon_AddToIncomingSocketList($hSocket, $hIncomingSocket)
			EndIf

		EndFunc

		Func __netcode_Addon_CheckIncomingPendingMiddleman(Const $hSocket, $nAddonID)

			; get socket list
			Local $arClients = __netcode_Addon_GetIncomingSocketList($hSocket)
			Local $nArSize = UBound($arClients)

			If $nArSize = 0 Then Return

			; select those that have anything in the recv buffer and those that are disconnected
			$arClients = __netcode_SocketSelect($arClients, True)
			$nArSize = UBound($arClients)

			If $nArSize = 0 Then Return

			Local $sID = "", $sCallback = "", $vMiddlemanReturn, $sPackage = "", $hTimer = 0

			; for each incoming pending client
			; note: each socket could have a different middleman set to it, so have to read it for each socket instead of just once
			For $i = 0 To $nArSize - 1

				; get destination callback
				$sCallback = __netcode_Addon_GetVar(__netcode_Addon_GetVar($arClients[$i], 'Destination'), 'Callback')

				; if there is none then disconnect and remove the socket
				If Not $sCallback Then
					__netcode_Addon_Log($nAddonID, 22, $hSocket)
					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], False, $nAddonID)
					ContinueLoop
				EndIf

				; check the recv buffer
				$sPackage = __netcode_Addon_RecvPackages($arClients[$i])

				; if the incoming connection disconnected
				if @error Then
					__netcode_Addon_Log($nAddonID, 23, $arClients[$i])
					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], False, $nAddonID)
					ContinueLoop
				EndIf

				; if we didnt receive anything
				if Not @extended Then

					; check destination evaluation timeout
					$hTimer = __netcode_Addon_GetVar($arClients[$i], 'TimeoutTimer')

					If TimerDiff($hTimer) > 2000 Then ; needs to become setable
						__netcode_Addon_Log($nAddonID, 26, $arClients[$i])
						__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], False, $nAddonID)
						ContinueLoop
					EndIf


					ContinueLoop
				EndIf

				; run the callback if we received something
				$vMiddlemanReturn = Call($sCallback, $arClients[$i], 'Destination', $sPackage)

				; if the call failed
				if @error Then
					__netcode_Addon_Log($nAddonID, 24, __netcode_Addon_GetVar($arClients[$i], 'Destination'), $hSocket)
					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], False, $nAddonID)
					ContinueLoop
				EndIf

				; check return
				If IsArray($vMiddlemanReturn) Then ; if destination is given

					; connect outgoing
					__netcode_Addon_ConnectOutgoingMiddleman($hSocket, $arClients[$i], $vMiddlemanReturn, __netcode_Addon_GetVar($arClients[$i], 'Destination'), $nAddonID)

					; remove from incoming pending list
					__netcode_Addon_RemoveFromIncomingSocketList($hSocket, $arClients[$i])

				ElseIf $vMiddlemanReturn = False Then ; if the middleman says to disconnect

					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], False, $nAddonID)

				ElseIf $vMiddlemanReturn = Null Then ; if no destination is known yet

					; check destination evaluation timeout
					$hTimer = __netcode_Addon_GetVar($arClients[$i], 'TimeoutTimer')

					If TimerDiff($hTimer) > 2000 Then ; needs to become setable
						__netcode_Addon_Log($nAddonID, 26, $arClients[$i])
						__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], False, $nAddonID)
					EndIf

		;~ 			__netcode_Addon_Log(1, 26, $arClients[$i])

				Else ; invalid return

					; log to console
					__netcode_Addon_Log($nAddonID, 25, __netcode_Addon_GetVar($arClients[$i], 'Destination'), $hSocket)

					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], False, $nAddonID)

				EndIf

			Next
		EndFunc

		Func __netcode_Addon_ConnectOutgoingMiddleman(Const $hSocket, $hIncomingSocket, $arDestination, $sID, $nAddonID)

			; $arDestination
			; [0] = IP
			; [1] = Port
			; [2] = Send to outgoing (needs to be of type string)
			; [3] = Send to incoming (needs to be of type string)
			; [4] = True / False (True = Send when outgoing is connected, False = Send imidiatly)

			Local $nArSize = UBound($arDestination)

			; if the array size is to small
			if $nArSize < 2 Then

				; log
				__netcode_Addon_Log($nAddonID, 30, $sID, $hSocket)

				; then remove
				__netcode_Addon_DisconnectAndRemoveClients($hSocket, $hIncomingSocket, False, $nAddonID)
				Return
			EndIf

			Local $hOutgoingSocket = __netcode_TCPConnect($arDestination[0], $arDestination[1], 2, True)

			__netcode_Addon_Log($nAddonID, 32, $arDestination[0] & ':' & $arDestination[1])

			; add to outgoing pending list
			__netcode_Addon_AddToOutgoingSocketList($hSocket, $hOutgoingSocket)

			; inherit between and disconnect middleman ids from incoming socket
			__netcode_Addon_SetVar($hOutgoingSocket, 'Between', __netcode_Addon_GetVar($hOutgoingSocket, 'Between'))
			__netcode_Addon_SetVar($hOutgoingSocket, 'Disconnect', __netcode_Addon_GetVar($hOutgoingSocket, 'Disconnect'))

			; if there are more elements
			If $nArSize > 2 Then

				; check the "Send to outgoing" element
				If $arDestination[2] <> "" Then __netcode_Addon_SetVar($hOutgoingSocket, 'MiddlemanSend', $arDestination[2])

				; check the "Send to incoming" element
				if $nArSize > 3 Then

					; if there is some but the "True / False" is not set then
					If $nArSize < 5 Then

						; disconnect and log
						__netcode_Addon_Log($nAddonID, 31, $sID)

						__netcode_Addon_DisconnectAndRemoveClients($hSocket, $hIncomingSocket, $hOutgoingSocket, $nAddonID)
						Return

						; why? because the proxy cannot assume when the dev ment to send the data.
						; so instead of hoping for the best and maybe breaking the script, just disconnect and log it as a fatal to the console.

					EndIf

					; check the toggle
					if $arDestination[4] Then
						__netcode_Addon_SetVar($hIncomingSocket, 'MiddlemanSend', $arDestination[3])
					Else
						__netcode_TCPSend($hIncomingSocket, StringToBinary($arDestination[3]))
					EndIf

				EndIf
			EndIf

			; link sockets together
			__netcode_Addon_SetVar($hIncomingSocket, 'Link', $hOutgoingSocket)
			__netcode_Addon_SetVar($hOutgoingSocket, 'Link', $hIncomingSocket)

		EndFunc


		Func __netcode_Addon_CheckOutgoingPendingMiddleman(Const $hSocket, $nAddonID)

			Local $arClients = __netcode_Addon_GetOutgoingSocketList($hSocket)
			Local $nArSize = UBound($arClients)

			If $nArSize = 0 Then Return

			; select for Write
			$arClients = __netcode_SocketSelect($arClients, False)
			$nArSize = UBound($arClients)

			; if some outgoing connections are connected
			If $nArSize > 0 Then

				Local $hIncomingSocket = 0
				Local $sData = ""

				For $i = 0 To $nArSize - 1

					; get incoming socket
					$hIncomingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

					; remove from outgoing pending list
					__netcode_Addon_RemoveFromOutgoingSocketList($hSocket, $arClients[$i])

					; add both sockets to the final list
					__netcode_Addon_AddToRelaySocketList($hSocket, $arClients[$i])
					__netcode_Addon_AddToRelaySocketList($hSocket, $hIncomingSocket)

					; check if there is data to send to the outgoing
					$sData = __netcode_Addon_GetVar($arClients[$i], 'MiddlemanSend')
					if $sData Then __netcode_TCPSend($arClients[$i], StringToBinary($sData), False)

					; check if there is data to send to the incoming
					$sData = __netcode_Addon_GetVar($hIncomingSocket, 'MiddlemanSend')
					if $sData Then __netcode_TCPSend($hIncomingSocket, StringToBinary($sData), False)

					__netcode_Addon_Log($nAddonID, 33, $hIncomingSocket, $arClients[$i])

				Next

			EndIf

			; reread the outgoing pending socket list
			$arClients = __netcode_Addon_GetOutgoingSocketList($hSocket)
			$nArSize = UBound($arClients)

			if $nArSize = 0 Then Return

			Local $hTimer = 0, $hLinkSocket = 0

			; check for connect timeouts
			For $i = 0 To $nArSize - 1

				; check timeout
				$hTimer = __netcode_Addon_GetVar($arClients[$i], 'TimeoutTimer')
				If TimerDiff($hTimer) > 2000 Then ; needs to become setable
					__netcode_Addon_Log($nAddonID, 34, $arClients[$i])

					$hLinkSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')
					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $arClients[$i], $hLinkSocket, $nAddonID)
				EndIf

			Next

		EndFunc

		Func __netcode_Addon_RecvAndSendMiddleman(Const $hSocket, $nAddonID)

			; get sockets
			Local $arClients = __netcode_Addon_GetSocketList($hSocket)
			if UBound($arClients) = 0 Then Return

			; select these that have something received or that are disconnected
			$arClients = __netcode_SocketSelect($arClients, True)
			Local $nArSize = UBound($arClients)
			if $nArSize = 0 Then Return

			; get the linked sockets
			Local $arSockets[$nArSize]
			For $i = 0 To $nArSize - 1
				$arSockets[$i] = __netcode_Addon_GetVar($arClients[$i], 'Link')
			Next

			; filter the linked sockets, for those that are send ready
			$arClients = __netcode_SocketSelect($arSockets, False)
			Local $nArSize = UBound($arClients)

			if $nArSize = 0 Then Return

			Local $sData = ""
			Local $hLinkSocket = 0
			Local $nLen = 0
			Local $sCallback = ""

			; recv and send
			For $i = 0 To $nArSize - 1

				; get the socket that had something to be received
				$hLinkSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

				; get the recv buffer
				$sData = __netcode_Addon_RecvPackages($hLinkSocket)

				; check if we disconnected
				if @error Then
					__netcode_Addon_DisconnectAndRemoveClients($hSocket, $hLinkSocket, $arClients[$i], $nAddonID)
					ContinueLoop
				EndIf

				$nLen = @extended
				If $nLen Then

					; get middleman callback
					$sCallback = __netcode_Addon_GetVar(__netcode_Addon_GetVar($hLinkSocket, 'Between'), 'Callback')
					If $sCallback Then
						$sData = Call($sCallback, $hLinkSocket, $arClients[$i], __netcode_Addon_GetSocketType($hLinkSocket), $sData)

						; if either the call failed or if the middleman sais it doesnt want to forward the packet
						if @error Then
							__netcode_Addon_Log($nAddonID, 36, $hLinkSocket, $arClients[$i], __netcode_Addon_GetVar($hLinkSocket, 'Between'))
							ContinueLoop
						EndIf

						$nLen = @extended
					EndIf

					; send the data non blocking
					__netcode_TCPSend($arClients[$i], StringToBinary($sData), False)

					__netcode_Addon_Log($nAddonID, 35, $hLinkSocket, $arClients[$i], $nLen)

				EndIf

			Next

		EndFunc

	#EndRegion


	#Region
		; non middleman functions

		Func __netcode_Addon_NewIncoming(Const $hSocket, $hIncomingSocket, $nAddonID)

			__netcode_Addon_Log($nAddonID, 10, $hIncomingSocket)

			; add to pending list
			__netcode_Addon_AddToIncomingSocketList($hSocket, $hIncomingSocket)

			; get relay destination
			Local $arRelayDestination = __netcode_Addon_GetVar($hSocket, 'RelayDestination')

			; connect non blocking
			Local $hOutgoingSocket = __netcode_TCPConnect($arRelayDestination[0], $arRelayDestination[1], 2, True)

			; add to pending list
			__netcode_Addon_AddToOutgoingSocketList($hSocket, $hOutgoingSocket)

			; init timer for timeout
			__netcode_Addon_SetVar($hOutgoingSocket, 'ConnectTimer', TimerInit())

			; link them already together
			__netcode_Addon_SetVar($hIncomingSocket, 'Link', $hOutgoingSocket)
			__netcode_Addon_SetVar($hOutgoingSocket, 'Link', $hIncomingSocket)

			__netcode_Addon_Log($nAddonID, 11, $arRelayDestination[0] & ':' & $arRelayDestination[1])

		EndFunc

		#cs
		Func __netcode_Addon_CheckIncoming(Const $hSocket)

			; get incoming socket list
			Local $arClients = __netcode_Addon_GetSocketList($hSocket & '_IncomingPending')
			if UBound($arClients) = 0 Then Return

			; select
			$arClients = __netcode_SocketSelect($arClients, True)
			Local $nArSize = UBound($arClients)

			If $nArSize = 0 Then Return

			Local $hOutgoingSocket = 0

			; for each select socket
			For $i = 0 To $nArSize - 1

				; check connection
				__netcode_Addon_TCPRecv($arClients[$i], 1)

				; if disconnected then
				Switch @error

					Case 1, 10050 To 10054

						; get linked outgoing socket
						$hOutgoingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

						; close both
						__netcode_TCPCloseSocket($arClients[$i])
						__netcode_TCPCloseSocket($hOutgoingSocket)

						; remove the incoming and outgoing socket
						__netcode_Addon_RemoveFromSocketList($hSocket & '_IncomingPending', $arClients[$i])
						__netcode_Addon_RemoveFromSocketList($hSocket & '_OutgoingPending', $hOutgoingSocket)

						; tidy both socket vars
						_storageS_TidyGroupVars($arClients[$i])
						_storageS_TidyGroupVars($hOutgoingSocket)

				EndSwitch

			Next

		EndFunc
		#ce

		Func __netcode_Addon_CheckOutgoing(Const $hSocket, $nAddonID)

			; get outgoing socket list
			Local $arClients = __netcode_Addon_GetOutgoingSocketList($hSocket)
			If UBound($arClients) = 0 Then Return

			; select
			$arClients = __netcode_SocketSelect($arClients, False)
			Local $nArSize = UBound($arClients)
			Local $hIncomingSocket = 0

			; if sockets have successfully connected
			If $nArSize > 0 Then


				For $i = 0 To $nArSize - 1

					__netcode_Addon_Log($nAddonID, 12, $arClients[$i])

					; get incoming socket
					$hIncomingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

					; add both to the clients list
					__netcode_Addon_AddToRelaySocketList($hSocket, $arClients[$i])
					__netcode_Addon_AddToRelaySocketList($hSocket, $hIncomingSocket)

					; remove both from the pending lists
					__netcode_Addon_RemoveFromOutgoingSocketList($hSocket, $arClients[$i])
					__netcode_Addon_RemoveFromIncomingSocketList($hSocket, $hIncomingSocket)

					__netcode_Addon_Log($nAddonID, 13, $hIncomingSocket, $arClients[$i])

				Next

			EndIf

			; reread the outgoing socket list
			$arClients = __netcode_Addon_GetOutgoingSocketList($hSocket)
			$nArSize = UBound($arClients)

			if $nArSize = 0 Then Return

			; check timeouts
			Local $hTimer = 0

			For $i = 0 To $nArSize - 1

				; get timer
				$hTimer = __netcode_Addon_GetVar($arClients[$i], 'ConnectTimer')

				; check timeout
				if TimerDiff($hTimer) > 2000 Then

					__netcode_Addon_Log($nAddonID, 14, $arClients[$i])

					; get incoming socket
					$hIncomingSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

					; close both
					__netcode_TCPCloseSocket($arClients[$i])
					__netcode_TCPCloseSocket($hIncomingSocket)

					; remove both
					__netcode_Addon_RemoveFromOutgoingSocketList($hSocket, $arClients[$i])
					__netcode_Addon_RemoveFromIncomingSocketList($hSocket, $hIncomingSocket)

					; tidy both
					_storageS_TidyGroupVars($arClients[$i])
					_storageS_TidyGroupVars($hIncomingSocket)

					__netcode_Addon_Log($nAddonID, 15, $hIncomingSocket)

				EndIf

			Next

		EndFunc

		Func __netcode_Addon_RecvAndSend(Const $hSocket, $nAddonID)

			; get sockets
			Local $arClients = __netcode_Addon_GetSocketList($hSocket)
			if UBound($arClients) = 0 Then Return

			; select these that have something received or that are disconnected
			$arClients = __netcode_SocketSelect($arClients, True)
			Local $nArSize = UBound($arClients)
			if $nArSize = 0 Then Return

			; get the linked sockets
			Local $arSockets[$nArSize]
			For $i = 0 To $nArSize - 1
				$arSockets[$i] = __netcode_Addon_GetVar($arClients[$i], 'Link')
			Next

			; filter the linked sockets, for those that are send ready
			$arClients = __netcode_SocketSelect($arSockets, False)
			Local $nArSize = UBound($arClients)

			if $nArSize = 0 Then Return

			Local $sData = ""
			Local $hLinkSocket = 0
			Local $nLen = 0

			; recv and send
			For $i = 0 To $nArSize - 1

				; get the socket that had something to be received
				$hLinkSocket = __netcode_Addon_GetVar($arClients[$i], 'Link')

				; get the recv buffer
				$sData = __netcode_Addon_RecvPackages($hLinkSocket)

				; check if we disconnected
				if @error Then

					__netcode_TCPCloseSocket($arClients[$i])
					__netcode_TCPCloseSocket($hLinkSocket)

					__netcode_Addon_RemoveFromRelaySocketList($hSocket, $arClients[$i])
					__netcode_Addon_RemoveFromRelaySocketList($hSocket, $hLinkSocket)

					_storageS_TidyGroupVars($arClients[$i])
					_storageS_TidyGroupVars($hLinkSocket)

					__netcode_Addon_Log($nAddonID, 15, $arClients[$i])
					__netcode_Addon_Log($nAddonID, 15, $hLinkSocket)

					ContinueLoop

				EndIf

				$nLen = @extended
				If $nLen Then

					__netcode_Addon_Log($nAddonID, 16, $hLinkSocket, $arClients[$i], $nLen)

					; send the data non blocking
					__netcode_TCPSend($arClients[$i], StringToBinary($sData), False)

				EndIf

			Next

		EndFunc

	#EndRegion

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
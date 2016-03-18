#include-once

; #INDEX# ============================================================================================================
; Title .........: GUIListViewEx
; AutoIt Version : 3.3.10 +
; Language ......: English
; Description ...: Permits insertion, deletion, moving, dragging, sorting, editing and colouring of items within ListViews
; Remarks .......: - It is important to use _GUIListViewEx_Close when a enabled ListView is deleted to free the memory used
;                    by the $aGLVEx_Data array which shadows the ListView contents.
;                  - Windows message handlers required:
;                     - WM_NOTIFY: All UDF functions
;                     - WM_MOUSEMOVE and WM_LBUTTONUP: Only needed if dragging
;                     - WM_SYSCOMMAND: Permits [X] GUI closure while editing
;                  - If the script already has WM_NOTIFY, WM_MOUSEMOVE, WM_LBUTTONUP or WM_SYSCOMMAND handlers then only set
;                    unregistered messages in _GUIListViewEx_MsgRegister and call the relevant _GUIListViewEx_WM_#####_Handler
;                    from within the existing handler
;                  - Uses 2 undocumented functions within GUIListView UDF to set and colour insert mark (thanks rover)
;                  - If ListView editable, Opt("GUICloseOnESC") set to 0 as ESC = edit cancel.  Do not reset Opt in script
;                  - Enabling user colours forces column sort disabled and significantly slows ListView redrawing
; Author ........: Melba23
; Credits .......: martin (basic drag code), Array.au3 authors (array functions), KaFu and ProgAndy (font function)
; ====================================================================================================================

;#AutoIt3Wrapper_Au3Check_Parameters=-d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w- 7

; #INCLUDES# =========================================================================================================
#include <GuiListView.au3>
#include <GUIImageList.au3>

; #GLOBAL VARIABLES# =================================================================================================
; Array to hold registered ListView data
Global $aGLVEx_Data[1][24] = [[0, 0, -1, "", -1, -1, -1, -1, _WinAPI_GetSystemMetrics(2), False, -1, -1, False, "", 0, True, 0, -1, -1]]
; [0][0]  = Count               [n][0]  = ListView handle
; [0][1]  = Active Index        [n][1]  = Native ListView ControlID / 0
; [0][2]  = Active Column       [n][2]  = Shadow array
; [0][3]  = Row Depth           [n][3]  = Shadow array count element (0/1) & 2D return (+ 2)
; [0][4]  = Curr ToolTip Row    [n][4]  = Sort status
; [0][5]  = Curr ToolTip Col    [n][5]  = Drag image flag
; [0][6]  = Prev ToolTip Row    [n][6]  = Checkbox array flag
; [0][7]  = Prev ToolTip Col    [n][7]  = Editable columns range
; [0][8]  = VScrollbar width    [n][8]  = Editable header flag
; [0][9]  = SysClose flag       [n][9]  = Edit cursor active flag
; [0][10] = RtClick Row         [n][10] = Item depth for scrolling
; [0][11] = RtClick Col         [n][11] = Edit combo flag/data
; [0][12] = Colour Handler Flag [n][12] = External dragdrop flag
; [0][13] = Active Colour Array [n][13] = Header drag style flag
; [0][14] = Curr Redraw Handle  [n][14] = Edit width array
; [0][15] = Allow Redraw Flag   [n][15] = ToolTip column range
; [0][16] = KeyCode             [n][16] = ToolTip display time
; [0][17] = Active Row          [n][17] = ToolTip mode
; [0][18] = Active Column       [n][18] = Colour array
;                               [n][19] - Colour flag
;                               [n][20] - Active row
;                               [n][21] - Active column
;                               [n][22] - Single cell flag
;                               [n][23] - Default user colurs

; Variables for UDF handlers
Global $hGLVEx_SrcHandle, $cGLVEx_SrcID, $iGLVEx_SrcIndex, $aGLVEx_SrcArray, $aGLVEx_SrcColArray
Global $hGLVEx_TgtHandle, $cGLVEx_TgtID, $iGLVEx_TgtIndex, $aGLVEx_TgtArray, $aGLVEx_TgtColArray
Global $iGLVEx_Dragging = 0, $iGLVEx_DraggedIndex, $hGLVEx_DraggedImage = 0, $sGLVEx_DragEvent
Global $iGLVEx_InsertIndex = -1, $iGLVEx_LastY, $fGLVEx_BarUnder
; Variables for UDF edit
Global $hGLVEx_Editing, $cGLVEx_EditID = 9999, $fGLVEx_EditClickFlag = False, $fGLVEx_HeaderEdit = False
; Array to hold predefined user colours [Normal text, normal field, selected cell text, selected cell field] - BGR
Global $aGLVEx_DefColours[4] = ["0x000000", "0xFEFEFE", "0xFFFFFF", "0xCC6600"]
; Variable for required separator character
Global $sGLVEx_SepChar = Opt("GUIDataSeparatorChar")

; #CURRENT# ==========================================================================================================
; _GUIListViewEx_Init:                  Enables UDF functions for the ListView and sets various flags
; _GUIListViewEx_Close:                 Disables all UDF functions for the specified ListView and clears all memory used
; _GUIListViewEx_SetActive:             Set specified ListView as active for UDF functions
; _GUIListViewEx_GetActive:             Get index number of active ListView for UDF functions
; _GUIListViewEx_ReadToArray:           Creates an array from the current ListView content to be loaded in _Init function
; _GUIListViewEx_ReturnArray:           Returns an array of the current content, checkbox state, colour of the ListView
; _GUIListViewEx_SaveListView:          Saves ListView headers, content, checkbox state, colour data to file
; _GUIListViewEx_LoadListView:          Loads ListView headers, content, checkbox state, colour data from file
; _GUIListViewEx_Up:                    Moves selected row(s) in active ListView up 1 row
; _GUIListViewEx_Down:                  Moves selected row(s) in active ListView down 1 row
; _GUIListViewEx_Insert:                Inserts data in row below selected row in active ListView
; _GUIListViewEx_InsertSpec:            Inserts data in specified row in specified ListView
; _GUIListViewEx_Delete:                Deletes selected row(s) in active ListView
; _GUIListViewEx_DeleteSpec:            Deletes specified row(s) in specified ListView
; _GUIListViewEx_InsertCol:             Inserts blank column to right of selected column in active ListView
; _GUIListViewEx_InsertColSpec:         Inserts specified blank column in specified ListView
; _GUIListViewEx_DeleteCol:             Deletes selected column in active ListView
; _GUIListViewEx_DeleteColSpec:         Deletes specified column in specified ListView
; _GUIListViewEx_EditOnClick:           Allow edit of ListView items in user-defined columns when doubleclicked
; _GUIListViewEx_EditItem:              Manual edit of specified ListView item
; _GUIListViewEx_ChangeItem:            Programatic change of specified ListView item
; _GUIListViewEx_EditHeader:            Allow edit of ListView headers
; _GUIListViewEx_EditWidth:             Set required widths for column edit/combo when editing
; _GUIListViewEx_BlockReDraw:           Prevents ListView redrawing during looped Insert/Delete/Change calls
; _GUIListViewEx_ComboData:             Use combo and set data to edit item in defined column
; _GUIListViewEx_DragEvent:             Returns index of ListView(s) involved in a drag-drop event
; _GUIListViewEx_SetColour:             Sets text and/or back colour for user colour enabled ListViews
; _GUIListViewEx_LoadColour:            Uses array to set text/back colours for user colour enabled ListViews
; _GUIListViewEx_SetDefColours:         Sets default colours for user colour/single cell select enabled ListViews
; _GUIListViewEx_ContextPos:            Returns LV index and row/col of last right click
; _GUIListViewEx_ToolTipInit:           Defines column(s) which will display a tooltip when clicked
; _GUIListViewEx_ToolTipShow:           Show tooltips when defined columns clicked
; _GUIListViewEx_MsgRegister:           Registers Windows messages required for the UDF
; _GUIListViewEx_WM_NOTIFY_Handler:     Windows message handler for WM_NOTIFY - needed for all UDF functions
; _GUIListViewEx_WM_MOUSEMOVE_Handler:  Windows message handler for WM_MOUSEMOVE - needed for drag
; _GUIListViewEx_WM_LBUTTONUP_Handler:  Windows message handler for WM_LBUTTONUP - needed for drag
; _GUIListViewEx_WM_SYSCOMMAND_Handler: Windows message handler for WM_SYSCOMMAND - speeds GUI closure when editing
; ====================================================================================================================

; #INTERNAL_USE_ONLY#=================================================================================================
; __GUIListViewEx_ExpandCols:   Expands column ranges to list each column separately
; __GUIListViewEx_HighLight:    Highlights specified ListView item and ensures it is visible
; __GUIListViewEx_EditProcess:  Runs ListView editing process
; __GUIListViewEx_GetLVFont:    Gets font details for ListView to be edited
; __GUIListViewEx_EditCoords:   Ensures item in view then locates and sizes edit control
; __GUIListViewEx_ReWriteLV:    Deletes all ListView content and refills to match array
; __GUIListViewEx_GetLVCoords:  Gets screen coords for ListView
; __GUIListViewEx_GetCursorWnd: Gets handle of control under the mouse cursor
; __GUIListViewEx_Array_Add:    Adds a specified value at the end of an array
; __GUIListViewEx_Array_Insert: Adds a value at the specified index of an array
; __GUIListViewEx_Array_Delete: Deletes a specified index from an array
; __GUIListViewEx_Array_Swap:   Swaps specified elements within an array
; __GUIListViewEx_ToolTipHide:  Called by Adlib to hide tooltip displayed by _GUIListViewEx_ToolTipShow
; __GUIListViewEx_MakeString:   Convert data/check/colour arrays to strings for saving
; __GUIListViewEx_MakeArray:    Convert data/check/colour strings to arrays for loading
; ====================================================================================================================

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_Init
; Description ...: Enables UDF functions for the ListView and sets various flags
; Syntax.........: _GUIListViewEx_Init($hLV, [$aArray = ""[, $iStart = 0[, $iColour[, $fImage[, $iAdded[, $sCols]]]]]])
; Parameters ....: $hLV     - Handle or ControlID of ListView
;                  $aArray  - Name of array used to fill ListView.  "" for empty ListView
;                  $iStart  - 0 = ListView data starts in [0] element of array (default)
;                             1 = Count in [0] element
;                  $iColour - RGB colour for insert mark (default = black)
;                  $fImage  - True  = Shadow image of dragged item when dragging
;                             False = No shadow image (default)
;                  $iAdded  - 0     - No added features (default).  To get added features add the following
;                             + 1   - Sortable by clicking on column headers (if not user colour enabled)
;                             + 2   - Editable when double clicking on a subitem in user-defined columns
;                             + 4   - Edit continues within same ListView by triple mouse-click (only if ListView editable)
;                             + 8   - Headers editable by Ctrl-click (only if ListView editable)
;                             + 16  - Left/right cursor active in edit - use Ctrl-arrow to move to next item (if set)
;                             + 32  - User coloured items (force no column sort)
;                             + 64  - No external drag
;                             + 128 - No external drop
;                             + 256 - No delete on external drag/drop
;                             + 512 - Single cell selection (force single selection)
;                  $sCols   - Editable columns - only used if Editable flag set in $iAdded
;                                 All columns: "*" (default)
;                                 Limit columns: example "1;2;5-6;8-9;10" - ranges expanded automatically
; Requirement(s).: v3.3.10 +
; Return values .: Index number of ListView for use in other GUIListViewEx functions
; Author ........: Melba23
; Modified ......:
; Remarks .......: - If the ListView is the only one enabled, it is automatically set as active
;                  - If no array is passed a shadow array is created automatically
;                  - The $iStart parameter determines if a count element will be returned by other GUIListViewEx functions
;                  - The _GUIListViewEx_ReadToArray function will read an existing ListView into an array
;                  - Only first item of a multiple selection is shadow imaged when dragging (API limitation)
;                  - Editable columns use edits by default, using _GUIListViewEx_ComboData will force a combo
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_Init($hLV, $aArray = "", $iStart = 0, $iColour = 0, $fImage = False, $iAdded = 0, $sCols = "*")

	Local $iIndex = 0

	; See if there is a blank line available in the array
	For $i = 1 To $aGLVEx_Data[0][0]
		If $aGLVEx_Data[$i][0] = 0 Then
			$iIndex = $i
			ExitLoop
		EndIf
	Next
	; If no blank line found then increase array size
	If $iIndex = 0 Then
		$aGLVEx_Data[0][0] += 1
		ReDim $aGLVEx_Data[$aGLVEx_Data[0][0] + 1][UBound($aGLVEx_Data, 2)]
		$iIndex = $aGLVEx_Data[0][0]
	EndIf

	; Store ListView handle and ControlID (if it exists)
	If IsHWnd($hLV) Then
		$aGLVEx_Data[$iIndex][0] = $hLV
		$aGLVEx_Data[$iIndex][1] = 0
	Else
		$aGLVEx_Data[$iIndex][0] = GUICtrlGetHandle($hLV)
		$aGLVEx_Data[$iIndex][1] = $hLV
	EndIf

	; Store ListView content in shadow array
	$aGLVEx_Data[$iIndex][2] = _GUIListViewEx_ReadToArray($hLV, 1)

	; Store array count flag
	$aGLVEx_Data[$iIndex][3] = $iStart
	; Store 1D/2D array return type flag
	If IsArray($aArray) Then
		If UBound($aArray, 0) = 2 Then $aGLVEx_Data[$iIndex][3] += 2
	EndIf

	; Set insert mark colour after conversion to BGR
	_GUICtrlListView_SetInsertMarkColor($hLV, BitOR(BitShift(BitAND($iColour, 0x000000FF), -16), BitAND($iColour, 0x0000FF00), BitShift(BitAND($iColour, 0x00FF0000), 16)))
	; If drag image required
	If $fImage Then
		$aGLVEx_Data[$iIndex][5] = 1
	EndIf

	; If sortable, store sort array
	If BitAND($iAdded, 1) Then
		Local $aLVSortState[_GUICtrlListView_GetColumnCount($hLV)]
		$aGLVEx_Data[$iIndex][4] = $aLVSortState
	Else
		$aGLVEx_Data[$iIndex][4] = 0
	EndIf
	; If editable
	If BitAND($iAdded, 2) Then
		$aGLVEx_Data[$iIndex][7] = __GUIListViewEx_ExpandCols($sCols)
		; Limit ESC to edit cancel
		Opt("GUICloseOnESC", 0)
		; If move edit by click add flag to valid col list
		If BitAND($iAdded, 4) Then
			$aGLVEx_Data[$iIndex][7] &= ";#"
		EndIf
		; If header editable on Ctrl-click set flag
		If BitAND($iAdded, 8) Then
			$aGLVEx_Data[$iIndex][8] = 1
		EndIf
	Else
		$aGLVEx_Data[$iIndex][7] = ""
	EndIf
	; If Edit cursor
	If BitAND($iAdded, 16) Then
		$aGLVEx_Data[$iIndex][9] = 1
	EndIf

	; If user coloured items
	If BitAND($iAdded, 32) Then
		Local $aColArray = $aGLVEx_Data[$iIndex][2]
		For $i = 1 To UBound($aColArray, 1) - 1
			For $j = 0 To UBound($aColArray, 2) - 1
				$aColArray[$i][$j] = ";"
			Next
		Next
		$aGLVEx_Data[$iIndex][18] = $aColArray
		; Set user colour flag
		$aGLVEx_Data[$iIndex][19] = 1
		; Load default colours
		$aGLVEx_Data[$iIndex][23] = $aGLVEx_DefColours
		; Force no column sort
		$aGLVEx_Data[$iIndex][4] = 0
	EndIf

	; If no external drag
	If BitAND($iAdded, 64) Then
		$aGLVEx_Data[$iIndex][12] = 1
	EndIf

	; If no external drop
	If BitAND($iAdded, 128) Then
		$aGLVEx_Data[$iIndex][12] += 2
	EndIf

	; If no delete on external drag/drop
	If BitAND($iAdded, 256) Then
		$aGLVEx_Data[$iIndex][12] += 4
	EndIf

	; If single cell selection
	If BitAND($iAdded, 512) Then
		; Force single selection style
		Local $iStyle = _WinAPI_GetWindowLong($aGLVEx_Data[$iIndex][0], $GWL_STYLE)
		_WinAPI_SetWindowLong($aGLVEx_Data[$iIndex][0], $GWL_STYLE, BitOR($iStyle, $LVS_SINGLESEL))
		; Set for initial no selection
		$aGLVEx_Data[$iIndex][20] = -1
		$aGLVEx_Data[$iIndex][21] = -1
		; Set flag
		$aGLVEx_Data[$iIndex][22] = 1
	EndIf

	;  If checkbox extended style
	If BitAND(_GUICtrlListView_GetExtendedListViewStyle($hLV), 4) Then ; $LVS_EX_CHECKBOXES
		$aGLVEx_Data[$iIndex][6] = 1
	EndIf

	;  If header drag extended style
	If BitAND(_GUICtrlListView_GetExtendedListViewStyle($hLV), 0x00000010) Then ; $LVS_EX_HEADERDRAGDROP
		$aGLVEx_Data[$iIndex][13] = 1
	EndIf

	; Measure item depth for scroll - if empty reset when filled later
	Local $aRect = _GUICtrlListView_GetItemRect($aGLVEx_Data[$iIndex][0], 0)
	$aGLVEx_Data[$iIndex][10] = $aRect[3] - $aRect[1]

	; If only 1 current ListView then activate
	Local $iListView_Count = 0
	For $i = 1 To $iIndex
		If $aGLVEx_Data[$i][0] Then $iListView_Count += 1
	Next
	If $iListView_Count = 1 Then _GUIListViewEx_SetActive($iIndex)

	; Return ListView index
	Return $iIndex

EndFunc   ;==>_GUIListViewEx_Init

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_Close
; Description ...: Disables all UDF functions for the specified ListView and clears all memory used
; Syntax.........: _GUIListViewEx_Close($iIndex)
; Parameters ....: $iIndex - Index number of ListView to close as returned by _GUIListViewEx_Init
;                            0 (default) = Closes all ListViews
; Requirement(s).: v3.3.10 +
; Return values .: Success: 1
;                  Failure: 0 and @error set to 1 - Invalid index number
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_Close($iIndex = 0)

	; Check valid index
	If $iIndex < 0 Or $iIndex > $aGLVEx_Data[0][0] Then Return SetError(1, 0, 0)

	If $iIndex = 0 Then
		; Remove all ListView data
		Global $aGLVEx_Data[1][UBound($aGLVEx_Data, 2)] = [[0, 0]]
	Else
		; Reset all data for ListView
		For $i = 0 To UBound($aGLVEx_Data, 2) - 1
			$aGLVEx_Data[$iIndex][$i] = 0
		Next

		; Cancel active index if set to this ListView
		If $aGLVEx_Data[0][1] = $iIndex Then $aGLVEx_Data[0][1] = 0

	EndIf

	Return 1

EndFunc   ;==>_GUIListViewEx_Close

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_SetActive
; Description ...: Set specified ListView as active for UDF functions
; Syntax.........: _GUIListViewEx_SetActive($iIndex)
; Parameters ....: $iIndex - Index number of ListView as returned by _GUIListViewEx_Init
;                  An index of 0 clears any current setting
; Requirement(s).: v3.3.10 +
; Return values .: Success: Returns previous active index number, 0 = no previously active ListView
;                  Failure: -1 and @error set to 1 - Invalid index number
; Author ........: Melba23
; Modified ......:
; Remarks .......: ListViews can also be activated by clicking on them
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_SetActive($iIndex)

	; Check valid index
	If $iIndex < 0 Or $iIndex > $aGLVEx_Data[0][0] Then Return SetError(1, 0, -1)

	Local $iCurr_Index = $aGLVEx_Data[0][1]

	If $iIndex Then
		; Store index of specified ListView
		$aGLVEx_Data[0][1] = $iIndex
		; Set values for specified ListView
		$hGLVEx_SrcHandle = $aGLVEx_Data[$iIndex][0]
		$cGLVEx_SrcID = $aGLVEx_Data[$iIndex][1]
	Else
		; Clear active index
		$aGLVEx_Data[0][1] = 0
		$hGLVEx_SrcHandle = 0
		$cGLVEx_SrcID = 0
	EndIf

	Return $iCurr_Index

EndFunc   ;==>_GUIListViewEx_SetActive

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_GetActive
; Description ...: Get index number of ListView active for UDF functions
; Syntax.........: _GUIListViewEx_GetActive()
; Parameters ....: None
; Requirement(s).: v3.3.10 +
; Return values .: Success: Index number as returned by _GUIListViewEx_Init, 0 = no active ListView
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_GetActive()

	Return $aGLVEx_Data[0][1]

EndFunc   ;==>_GUIListViewEx_GetActive

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_ReadToArray
; Description ...: Creates an array from the current ListView content to be loaded in _Init function
; Syntax.........: _GUIListViewEx_ReadToArray($hLV[, $iCount = 0])
; Parameters ....: $hLV    - ControlID or handle of ListView
;                  $iCount - 0 (default) = ListView data starts in [0] element of array, 1 = Count in [0] element
; Requirement(s).: v3.3.10 +
; Return values .: Success: 2D array of current ListView content
;                           Empty string if ListView empty and no count element
;                  Failure: Returns null string and sets @error as follows:
;                           1 = Invalid ListView ControlID or handle
; Author ........: Melba23
; Modified ......:
; Remarks .......: If returned array is used in _GUIListViewEx_Init the $iStart parameters must match in the 2 functions
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_ReadToArray($hLV, $iStart = 0)

	Local $aLVArray = "", $aRow

	; Use the ListView handle
	If Not IsHWnd($hLV) Then
		$hLV = GUICtrlGetHandle($hLV)
		If Not IsHWnd($hLV) Then
			Return SetError(1, 0, "")
		EndIf
	EndIf
	; Get ListView row count
	Local $iRows = _GUICtrlListView_GetItemCount($hLV)
	; Get ListView column count
	Local $iCols = _GUICtrlListView_GetColumnCount($hLV)
	; Check for empty ListView with no count
	If ($iRows + $iStart <> 0) And $iCols <> 0 Then
		; Create 2D array to hold ListView content and add count - count overwritten if not needed
		Local $aLVArray[$iRows + $iStart][$iCols] = [[$iRows]]
		; Read ListView content into array
		For $i = 0 To $iRows - 1
			; Read the row content
			$aRow = _GUICtrlListView_GetItemTextArray($hLV, $i)
			For $j = 1 To $aRow[0]
				; Add to the ListView content array
				$aLVArray[$i + $iStart][$j - 1] = $aRow[$j]
			Next
		Next
	Else
		Local $aLVArray[1][1] = [[0]]
	EndIf
	; Return array or empty string
	Return $aLVArray

EndFunc   ;==>_GUIListViewEx_ReadToArray

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_ReturnArray
; Description ...: Returns an array reflecting the current content of an activated ListView
; Syntax.........: _GUIListViewEx_ReturnArray($iIndex[, $iMode])
; Parameters ....: $iIndex - Index number of ListView as returned by _GUIListViewEx_Init
;                  $iMode  - 0 = Content of ListView
;                            1 - State of the checkboxes
;                            2 - User colours (if initialised)
;                            3 - Content of ListView forced to 2D for saving
;                            4 - ListView headers
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of current ListView content - _GUIListViewEx_Init parameters determine:
;                               For modes 0/1:
;                                   Count in [0]/[0][0] element if $iStart = 1 when intialised
;                                   1D/2D array type - as array used to initialise
;                                   If no array passed then single col => 1D; multiple column => 2D
;                               For mode 2/3
;                                   Always 0-based 2D array
;                               For mode 4
;                                   Always 0-based 1D array
;                  Failure: Returns empty string and sets @error as follows:
;                               1 = Invalid index number
;                               2 = Empty array (no items in ListView)
;                               3 = $iMode set to 1 but ListView does not have checkbox style
;                               4 = $iMode set to 2 but ListView does not have user colours
;                               5 = Invalid $iMode
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_ReturnArray($iIndex, $iMode = 0)

	; Check valid index
	If $iIndex < 1 Or $iIndex > $aGLVEx_Data[0][0] Then Return SetError(1, 0, "")
	; Get ListView handle
	Local $hLV = $aGLVEx_Data[$iIndex][0]
	; Get column order
	Local $aColOrder = StringSplit(_GUICtrlListView_GetColumnOrder($hLV), $sGLVEx_SepChar)
	; Extract array and get size
	Local $aData_Colour = $aGLVEx_Data[$iIndex][2]
	Local $iDim_1 = UBound($aData_Colour, 1), $iDim_2 = UBound($aData_Colour, 2)
	Local $aCheck[$iDim_1], $aHeader[$iDim_2]

	; Adjust array depending on mode required
	Switch $iMode
		Case 0, 3 ; Content
			; Array already filled

		Case 1 ; Checkbox state
			If $aGLVEx_Data[$iIndex][6] Then
				For $i = 1 To $iDim_1 - 1
					$aCheck[$i] = _GUICtrlListView_GetItemChecked($hLV, $i - 1)
				Next
				; Remove count element if required
				If BitAND($aGLVEx_Data[$iIndex][3], 1) = 0 Then
					; Delete count element
					__GUIListViewEx_Array_Delete($aCheck, 0)
				EndIf
				Return $aCheck
			Else
				Return SetError(3, 0, "")
			EndIf

		Case 2 ; Colour values
			If $aGLVEx_Data[$iIndex][19] Then
				; Load colour array
				$aData_Colour = $aGLVEx_Data[$iIndex][18]
				; Convert to RGB
				For $i = 0 To UBound($aData_Colour, 1) - 1
					For $j = 0 To UBound($aData_Colour, 2) - 1
						$aData_Colour[$i][$j] = StringRegExpReplace($aData_Colour[$i][$j], "0x(.{2})(.{2})(.{2})", "0x$3$2$1")
					Next
				Next
				$aData_Colour[0][0] = $iDim_1 - 1
			Else
				Return SetError(4, 0, "")
			EndIf

		Case 4 ; Headers
			Local $aRet
			For $i = 0 To $iDim_2 - 1
				$aRet = _GUICtrlListView_GetColumn($hLV, $i)
				$aHeader[$i] = $aRet[5]
			Next
		Case Else
			Return SetError(5, 0, "")
	EndSwitch

	; Check if columns can be reordered
	If $aGLVEx_Data[$iIndex][13] Then
		Switch $iMode
			Case 0, 2, 3 ; 2D data/colour array
				; Create temp array
				Local $aData_Colour_Ordered[$iDim_1][$iDim_2]
				; Fill temp array in correct column order
				$aData_Colour_Ordered[0][0] = $aData_Colour[0][0]
				For $i = 1 To $iDim_1 - 1
					For $j = 0 To $iDim_2 - 1
						$aData_Colour_Ordered[$i][$j] = $aData_Colour[$i][$aColOrder[$j + 1]]
					Next
				Next
				; Reset main and delete temp
				$aData_Colour = $aData_Colour_Ordered
				$aData_Colour_Ordered = ""

			Case 4 ; 1D header array
				; Create return array
				Local $aHeader_Ordered[$iDim_2]
				; Fill return array in correct column order
				For $i = 0 To $iDim_2 - 1
					$aHeader_Ordered[$i] = $aHeader[$aColOrder[$i + 1]]
				Next
				; Return reordered array
				Return $aHeader_Ordered
		EndSwitch
	Else
		; No reordering
		If $iMode = 4 Then
			; Return header array
			Return $aHeader
		EndIf
	EndIf

	; Remove count element of array if required - always for colour return
	Local $iCount = 1
	If BitAND($aGLVEx_Data[$iIndex][3], 1) = 0 Or $iMode = 2 Then
		$iCount = 0
		; Delete count element
		__GUIListViewEx_Array_Delete($aData_Colour, 0, True)
	EndIf

	; Now check if 1D array to be returned - always 2D for colour return and forced content
	If BitAND($aGLVEx_Data[$iIndex][3], 2) = 0 And $iMode < 2 Then
		If UBound($aData_Colour, 1) = 0 Then
			Local $aData_Colour[0]
		Else
			; Get number of 2D elements
			Local $iCols = UBound($aData_Colour, 2)
			; Create 1D array - count will be overwritten if not needed
			Local $aData_Colour_1D[UBound($aData_Colour)] = [$aData_Colour[0][0]]
			; Fill with concatenated lines
			For $i = $iCount To UBound($aData_Colour_1D) - 1
				Local $aLine = ""
				For $j = 0 To $iCols - 1
					$aLine &= $aData_Colour[$i][$j] & $sGLVEx_SepChar
				Next
				$aData_Colour_1D[$i] = StringTrimRight($aLine, 1)
			Next
			; Reset array
			$aData_Colour = $aData_Colour_1D
		EndIf
	EndIf

	; Return array
	Return $aData_Colour

EndFunc   ;==>_GUIListViewEx_ReturnArray

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_SaveListView
; Description ...: Saves ListView headers, content, checkbox state, colour data to file
; Syntax.........: _GUIListViewEx_SaveListView($iIndex, $sFileName)
; Parameters ....: $iIndex    - Index number of ListView as returned by _GUIListViewEx_Init
;                  $sFileName - File in which to save data
; Requirement(s).: v3.3.10 +
; Return values .: Success: 1
;                  Failure: 0 and sets @error as follows:
;                               1 = Invalid index number
;                               2 = File not written - @extended set:
;                                   1 = File not opened
;                                   2 = Data not written
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_SaveListView($iIndex, $sFileName)

	; Check valid index
	If $iIndex < 1 Or $iIndex > $aGLVEx_Data[0][0] Then Return SetError(1, 0, 0)

	; Get ListView parameters
	Local $hLV_Handle = $aGLVEx_Data[$iIndex][0]
	Local $iStart = BitAND($aGLVEx_Data[$iIndex][3], 1)

	; Get header data
	Local $sHeader = "", $aRet
	For $i = 0 To _GUICtrlListView_GetColumnCount($hLV_Handle) - 1
		$aRet = _GUICtrlListView_GetColumn($hLV_Handle, $i)
		$sHeader &= $aRet[5] & @CR & $aRet[4] & @LF
	Next
	$sHeader = StringTrimRight($sHeader, 1)

	; Get data/check/colour content
	Local $aData = _GUIListViewEx_ReturnArray($iIndex, 3) ; Force 2D return
	If $iStart Then
		_ArrayDelete($aData, 0)
	EndIf
	Local $aCheck = _GUIListViewEx_ReturnArray($iIndex, 1)
	If $iStart Then
		_ArrayDelete($aCheck, 0)
	EndIf
	Local $aColour = _GUIListViewEx_ReturnArray($iIndex, 2)

	; Convert to strings
	Local $sData = "", $sCheck = "", $sColour = ""
	If IsArray($aData) Then
		$sData = __GUIListViewEx_MakeString($aData)
	EndIf
	If IsArray($aCheck) Then
		$sCheck = __GUIListViewEx_MakeString($aCheck)
	EndIf
	If IsArray($aColour) Then
		$sColour = __GUIListViewEx_MakeString($aColour)
	EndIf

	; Write data to file
	Local $iError = 0
	Local $hFile = FileOpen($sFileName, $FO_OVERWRITE)
	If @error Then
		$iError = 1
	Else
		FileWrite($hFile, $sHeader & ChrW(0xEF0F) & $sData & ChrW(0xEF0F) & $sCheck & ChrW(0xEF0F) & $sColour)
		If @error Then
			$iError = 2
		EndIf
	EndIf
	FileClose($hFile)

	If $iError Then Return SetError(2, $iError, 0)

	Return 1

EndFunc   ;==>_GUIListViewEx_SaveListView

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_LoadListView
; Description ...: Loads ListView headers, content, checkbox state, colour data from file
; Syntax.........: _GUIListViewEx_LoadListView($iIndex, $sFileName[, $iDims = 2])
; Parameters ....: $iIndex    - Index number of ListView as returned by _GUIListViewEx_Init
;                  $sFileName - File from which to load data
;                  $iDims     - Force 1/2D return array - normally set by initialising array
; Requirement(s).: v3.3.10 +
; Return values .: Success: 1
;                  Failure: 0 and sets @error as follows:
;                               1 = Invalid index number
;                               2 = Invalid $iDims parameter
;                               3 = File not read
;                               4 = No data to load
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_LoadListView($iIndex, $sFileName, $iDims = 2)

	; Check valid index
	If $iIndex < 1 Or $iIndex > $aGLVEx_Data[0][0] Then Return SetError(1, 0, 0)
	; Check valid $iDims parameter
	Switch $iDims
		Case 1, 2
			; OK
		Case Else
			Return SetError(2, 0, 0)
	EndSwitch

	; Get ListView parameters
	Local $hLV_Handle = $aGLVEx_Data[$iIndex][0]
	Local $cLV_CID = $aGLVEx_Data[$iIndex][1]
	Local $iStart = BitAND($aGLVEx_Data[$iIndex][3], 1)

	; Read content
	Local $sContent = FileRead($sFileName)
	If @error Then Return SetError(3, 0, 0)

	; Split into separate sections
	Local $aSplit = StringSplit($sContent, ChrW(0xEF0F), $STR_ENTIRESPLIT)

	; Check there is data to load
	If $aSplit[1] = "" Then Return SetError(4, 0, 0)

	; Convert to arrays
	Local $aHeader = __GUIListViewEx_MakeArray($aSplit[1])
	Local $aData = __GUIListViewEx_MakeArray($aSplit[2])
	Local $aCheck = __GUIListViewEx_MakeArray($aSplit[3])
	Local $aColour = __GUIListViewEx_MakeArray($aSplit[4])

	; If required, convert data and colour arrays into 2D for load
	If UBound($aData, 0) = 1 Then
		Local $aTempData[UBound($aData)][1]
		Local $aTempCol[UBound($aData)][1]
		For $i = 0 To UBound($aData) - 1
			$aTempData[$i][0] = $aData[$i]
			$aTempCol[$i][0] = $aColour[$i]
		Next
		$aData = $aTempData
		$aColour = $aTempCol
	EndIf

	; Set no colour redraw flag and prevent any normal redraw
	$aGLVEx_Data[0][12] = 1
	$aGLVEx_Data[0][15] = False
	_GUICtrlListView_BeginUpdate($hLV_Handle)

	; Clear current content of ListView
	_GUICtrlListView_DeleteAllItems($hLV_Handle)

	; Check correct number of columns
	Local $iCol_Count = _GUICtrlListView_GetColumnCount($hLV_Handle)
	If $iCol_Count < UBound($aHeader) Then
		; Add columns
		For $i = $iCol_Count To UBound($aHeader) - 1
			_GUICtrlListView_AddColumn($hLV_Handle, "", 100)
		Next
	EndIf
	If $iCol_Count > UBound($aHeader) Then
		; Delete columns
		For $i = $iCol_Count To UBound($aHeader) Step -1
			_GUICtrlListView_DeleteColumn($hLV_Handle, $i)
		Next
	EndIf

	; Reset header titles and widths
	For $i = 0 To UBound($aHeader) - 1
		_GUICtrlListView_SetColumn($hLV_Handle, $i, $aHeader[$i][0], $aHeader[$i][1])
	Next

	; Load ListView content
	If $cLV_CID Then
		; Native ListView
		Local $sLine, $iLastCol = UBound($aData, 2) - 1
		For $i = 0 To UBound($aData) - 1
			$sLine = ""
			For $j = 0 To $iLastCol
				$sLine &= $aData[$i][$j] & "|"
			Next
			GUICtrlCreateListViewItem(StringTrimRight($sLine, 1), $cLV_CID)
		Next
	Else
		; UDF ListView
		_GUICtrlListView_AddArray($hLV_Handle, $aData)
	EndIf

	_GUICtrlListView_EndUpdate($hLV_Handle)

	; Add required count row to shadow array
	_ArrayInsert($aData, 0, UBound($aData))
	; Store content array
	$aGLVEx_Data[$iIndex][2] = $aData

	; Set 1/2D return flag as required
	$aGLVEx_Data[$iIndex][3] = $iStart + (($iDims = 2) ? (2) : (0))

	; Reset checkboxes if required
	If IsArray($aCheck) Then
		; Reset checkboxes
		For $i = 0 To UBound($aCheck) - 1
			If $aCheck[$i] = "True" Then
				_GUICtrlListView_SetItemChecked($hLV_Handle, $i, True)
			EndIf
		Next
	EndIf

	; Clear no colour redraw flag and allow normal redraw
	$aGLVEx_Data[0][12] = 0
	$aGLVEx_Data[0][15] = True

	; Reset colours if required
	If $aGLVEx_Data[$iIndex][19] Then
		; Load colour
		_GUIListViewEx_LoadColour($iIndex, $aColour)
		If Not @error Then
			; Force redraw if colour used or single cell selection
			If $aGLVEx_Data[$iIndex][19] Or $aGLVEx_Data[$iIndex][22] Then
				; Force reload of redraw colour array
				$aGLVEx_Data[0][14] = 0
				; If Redraw flag set
				If $aGLVEx_Data[0][15] Then
					; Redraw ListView
					_WinAPI_RedrawWindow($aGLVEx_Data[$iIndex][0])
				EndIf
			EndIf
		EndIf
	EndIf

	Return 1

EndFunc   ;==>_GUIListViewEx_LoadListView

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_Up
; Description ...: Moves selected item(s) in active ListView up 1 row
; Syntax.........: _GUIListViewEx_Up()
; Parameters ....: None
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of active ListView with count in [0] element
;                  Failure: Returns "" and sets @error as follows:
;                      1 = No ListView active
;                      2 = No item selected
;                      3 = Item already at top
; Author ........: Melba23
; Modified ......:
; Remarks .......: If multiple items are selected, only the top consecutive block is moved
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_Up()

	Local $iGLVExMove_Index, $iGLVEx_Moving = 0

	; Set data for active ListView
	Local $iLV_Index = $aGLVEx_Data[0][1]
	; If no ListView active then return
	If $iLV_Index = 0 Then Return SetError(1, 0, 0)

	; Load active ListView details
	$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
	$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
	Local $fCheckBox = $aGLVEx_Data[$iLV_Index][6]

	; Copy array for manipulation
	$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
	$aGLVEx_SrcColArray = $aGLVEx_Data[$iLV_Index][18]

	; Create Local array for checkboxes (if no checkboxes makes no difference)
	Local $aCheck_Array[UBound($aGLVEx_SrcArray)]
	For $i = 1 To UBound($aCheck_Array) - 1
		$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
	Next

	; Check for selected items
	Local $iIndex
	; Check if single cell selection enabled
	If $aGLVEx_Data[$iLV_Index][22] Then
		; Use stored value
		$iIndex = $aGLVEx_Data[$iLV_Index][20]
	Else
		; Check actual values
		$iIndex = _GUICtrlListView_GetSelectedIndices($hGLVEx_SrcHandle)
	EndIf
	If $iIndex = "" Then
		Return SetError(2, 0, "")
	EndIf
	Local $aIndex = StringSplit($iIndex, "|")
	$iGLVExMove_Index = $aIndex[1]
	; Check if item is part of a multiple selection
	If $aIndex[0] > 1 Then
		; Check for consecutive items
		For $i = 1 To $aIndex[0] - 1
			If $aIndex[$i + 1] = $aIndex[1] + $i Then
				$iGLVEx_Moving += 1
			Else
				ExitLoop
			EndIf
		Next
	Else
		$iGLVExMove_Index = $aIndex[1]
	EndIf

	; Check not top item
	If $iGLVExMove_Index < 1 Then
		__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, 0)
		Return SetError(3, 0, "")
	EndIf

	; Remove all highlighting
	_GUICtrlListView_SetItemSelected($hGLVEx_SrcHandle, -1, False)

	; Set no redraw flag - prevents problems while colour arrays are updated
	$aGLVEx_Data[0][12] = True

	; Move consecutive items
	For $iIndex = $iGLVExMove_Index To $iGLVExMove_Index + $iGLVEx_Moving
		; Swap array elements
		__GUIListViewEx_Array_Swap($aGLVEx_SrcArray, $iIndex, $iIndex + 1)
		__GUIListViewEx_Array_Swap($aCheck_Array, $iIndex, $iIndex + 1)
		__GUIListViewEx_Array_Swap($aGLVEx_SrcColArray, $iIndex, $iIndex + 1)
	Next

	; Amend stored row
	$aGLVEx_Data[$iLV_Index][20] -= 1

	; Rewrite ListView
	__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aCheck_Array, $iLV_Index, $fCheckBox)

	; Set highlight
	For $i = 0 To $iGLVEx_Moving
		__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, $iGLVExMove_Index + $i - 1)
	Next

	; Store amended array
	$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
	$aGLVEx_Data[$iLV_Index][18] = $aGLVEx_SrcColArray
	; Delete copied array
	$aGLVEx_SrcArray = 0
	$aGLVEx_SrcColArray = 0

	; Clear no redraw flag
	$aGLVEx_Data[0][12] = False

	; If colour used or single cell selection
	If $aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22] Then
		; Force reload of redraw colour array
		$aGLVEx_Data[0][14] = 0
		; If Loop No Redraw flag set
		If $aGLVEx_Data[0][15] Then
			; Redraw ListView
			_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
		EndIf
	EndIf

	; Return amended array
	Return _GUIListViewEx_ReturnArray($iLV_Index)

EndFunc   ;==>_GUIListViewEx_Up

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_Down
; Description ...: Moves selected item(s) in active ListView down 1 row
; Syntax.........: _GUIListViewEx_Down()
; Parameters ....: None
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of active ListView with count in [0] element
;                  Failure: Returns "" and sets @error as follows:
;                      1 = No ListView active
;                      2 = No item selected
;                      3 = Item already at bottom
; Author ........: Melba23
; Modified ......:
; Remarks .......: If multiple items are selected, only the bottom consecutive block is moved
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_Down()

	Local $iGLVExMove_Index, $iGLVEx_Moving = 0

	; Set data for active ListView
	Local $iLV_Index = $aGLVEx_Data[0][1]
	; If no ListView active then return
	If $iLV_Index = 0 Then Return SetError(1, 0, 0)

	; Load active ListView details
	$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
	$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
	Local $fCheckBox = $aGLVEx_Data[$iLV_Index][6]

	; Copy array for manipulation
	$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
	$aGLVEx_SrcColArray = $aGLVEx_Data[$iLV_Index][18]

	; Create Local array for checkboxes (if no checkboxes makes no difference)
	Local $aCheck_Array[UBound($aGLVEx_SrcArray)]
	For $i = 1 To UBound($aCheck_Array) - 1
		$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
	Next

	; Check for selected items
	Local $iIndex
	; Check if single cell selection enabled
	If $aGLVEx_Data[$iLV_Index][22] Then
		; Use stored value
		$iIndex = $aGLVEx_Data[$iLV_Index][20]
	Else
		; Check actual values
		$iIndex = _GUICtrlListView_GetSelectedIndices($hGLVEx_SrcHandle)
	EndIf
	If $iIndex = "" Then
		Return SetError(2, 0, "")
	EndIf
	Local $aIndex = StringSplit($iIndex, "|")
	; Check if item is part of a multiple selection
	If $aIndex[0] > 1 Then
		$iGLVExMove_Index = $aIndex[$aIndex[0]]
		; Check for consecutive items
		For $i = 1 To $aIndex[0] - 1
			If $aIndex[$aIndex[0] - $i] = $aIndex[$aIndex[0]] - $i Then
				$iGLVEx_Moving += 1
			Else
				ExitLoop
			EndIf
		Next
	Else
		$iGLVExMove_Index = $aIndex[1]
	EndIf

	; Remove all highlighting
	_GUICtrlListView_SetItemSelected($hGLVEx_SrcHandle, -1, False)

	; Check not last item
	If $iGLVExMove_Index = _GUICtrlListView_GetItemCount($hGLVEx_SrcHandle) - 1 Then
		__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, $iIndex)
		Return SetError(3, 0, "")
	EndIf

	; Set no redraw flag - prevents problems while colour arrays are updated
	$aGLVEx_Data[0][12] = True

	; Move consecutive items
	For $iIndex = $iGLVExMove_Index To $iGLVExMove_Index - $iGLVEx_Moving Step -1
		; Swap array elements
		__GUIListViewEx_Array_Swap($aGLVEx_SrcArray, $iIndex + 1, $iIndex + 2)
		__GUIListViewEx_Array_Swap($aCheck_Array, $iIndex + 1, $iIndex + 2)
		__GUIListViewEx_Array_Swap($aGLVEx_SrcColArray, $iIndex + 1, $iIndex + 2)
	Next

	; Amend stored row
	$aGLVEx_Data[$iLV_Index][20] += 1

	; Rewrite ListView
	__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aCheck_Array, $iLV_Index, $fCheckBox)

	; Set highlight
	For $i = 0 To $iGLVEx_Moving
		__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, $iGLVExMove_Index - $iGLVEx_Moving + $i + 1)
	Next

	; Store amended array
	$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
	$aGLVEx_Data[$iLV_Index][18] = $aGLVEx_SrcColArray
	; Delete copied array
	$aGLVEx_SrcArray = 0
	$aGLVEx_SrcColArray = 0

	; Clear no redraw flag
	$aGLVEx_Data[0][12] = False

	; If colour used or single cell selection
	If $aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22] Then
		; Force reload of redraw colour array
		$aGLVEx_Data[0][14] = 0
		; If Loop No Redraw flag set
		If $aGLVEx_Data[0][15] Then
			; Redraw ListView
			_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
		EndIf
	EndIf

	; Return amended array
	Return _GUIListViewEx_ReturnArray($iLV_Index)

EndFunc   ;==>_GUIListViewEx_Down

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_Insert
; Description ...: Inserts data just below selected item in active ListView - if no selection, data added at end
; Syntax.........: _GUIListViewEx_Insert($vData[, $fRetainWidth = False])
; Parameters ....: $vData        - Data to insert, can be in array or delimited string format
;                  $fMultiRow    - (Optional) If $vData is a 1D array:
;                                     - False (default) - elements added as subitems to a single row
;                                     - True - elements added as rows containing a single item
;                                  Ignored if $vData is a single item or a 2D array
;                  $fRetainWidth - (Optional) True  = native ListView column width is retained on insert
;                                  False = native ListView columns expand to fit data (default)
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of current ListView content with count in [0] element
;                  Failure: If no ListView active then returns "" and sets @error to 1
; Author ........: Melba23
; Modified ......:
; Remarks .......: - New data is inserted after the selected item.  If no item is selected then the data is added at
;                  the end of the ListView.  If multiple items are selected, the data is inserted after the first
;                  - $vData can be passed in string or array format - it is automatically transformed if required
;                  - $vData as single item - item added to all columns
;                  - $vData as 1D array - see $fMultiRow above
;                  - $vData as 2D array - added as rows/columns
;                  - Native ListViews automatically expand subitem columns to fit inserted data.  Setting the
;                  $fRetainWidth parameter resets the original width after insertion
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_Insert($vData, $fMultiRow = False, $fRetainWidth = False)

	;Local $vInsert

	; Set data for active ListView
	Local $iLV_Index = $aGLVEx_Data[0][1]
	; If no ListView active then return
	If $iLV_Index = 0 Then Return SetError(1, 0, "")

	; Check for selected items
	Local $iIndex
	; Check if single cell selection enabled
	If $aGLVEx_Data[$iLV_Index][22] Then
		; Use stored value
		$iIndex = $aGLVEx_Data[$iLV_Index][20]
	Else
		; Check actual values
		$iIndex = _GUICtrlListView_GetSelectedIndices($hGLVEx_SrcHandle)
	EndIf
	Local $iInsert_Index = $iIndex
	; If no selection
	If $iIndex = "" Then $iInsert_Index = -1

	; Check for multiple selections
	If StringInStr($iIndex, "|") Then
		Local $aIndex = StringSplit($iIndex, "|")
		; Use first selection
		$iIndex = $aIndex[1]
		; Cancel all other selections
		For $i = 2 To $aIndex[0]
			_GUICtrlListView_SetItemSelected($hGLVEx_SrcHandle, $aIndex[$i], False)
		Next
	EndIf

	Local $vRet = _GUIListViewEx_InsertSpec($iLV_Index, $iInsert_Index + 1, $vData, $fMultiRow, $fRetainWidth)

	Return SetError(@error, 0, $vRet)

EndFunc   ;==>_GUIListViewEx_Insert

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_InsertSpec
; Description ...: Inserts data in specified row in specified ListView
; Syntax.........: _GUIListViewEx_InsertSpec($iLV_Index, $iRow, $vData[, $fRetainWidth = False])
; Parameters ....: $iLV_Index    - Index of ListView as returned by _GUIListViewEx_Init
;                  $iRow         - Row which will be inserted - setting -1 adds at end
;                  $vData        - Data to insert, can be in array or delimited string format
;                  $fMultiRow    - (Optional) If $vData is a 1D array:
;                                     - False (default) - elements added as subitems to a single row
;                                     - True - elements added as rows containing a single item
;                                  Ignored if $vData is a single item or a 2D array
;                  $fRetainWidth - (Optional) True  = native ListView column width is retained on insert
;                                  False = native ListView columns expand to fit data (default)
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of specified ListView content with count in [0] element
;                  Failure: Returns "" and sets @error to 1
; Author ........: Melba23
; Modified ......:
; Remarks .......: - New data is inserted after the specified row.
;                  - $vData can be passed in string or array format - it is automatically transformed if required
;                  - $vData as single item - item added to all columns
;                  - $vData as 1D array - see $fMultiRow above
;                  - $vData as 2D array - added as rows/columns
;                  - Native ListViews automatically expand subitem columns to fit inserted data.  Setting the
;                  - $fRetainWidth parameter resets the original width after insertion
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_InsertSpec($iLV_Index, $iRow, $vData, $fMultiRow = False, $fRetainWidth = False)

	Local $vInsert

	; Check valid index
	If $iLV_Index < 0 Or $iLV_Index > $aGLVEx_Data[0][0] Then Return SetError(1, 0, "")

	; Load active ListView details
	$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
	$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
	Local $fCheckBox = $aGLVEx_Data[$iLV_Index][6]

	; Copy array for manipulation
	$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
	$aGLVEx_SrcColArray = $aGLVEx_Data[$iLV_Index][18]

	; Create Local array for checkboxes (if no checkboxes makes no difference)
	Local $aCheck_Array[UBound($aGLVEx_SrcArray)]
	For $i = 1 To UBound($aCheck_Array) - 1
		$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
	Next

	Local $aCol_Width, $iColCount
	; If width retain required and native ListView
	If $fRetainWidth And $cGLVEx_SrcID Then
		$iColCount = _GUICtrlListView_GetColumnCount($hGLVEx_SrcHandle)
		; Store column widths
		Local $aCol_Width[$iColCount]
		For $i = 1 To $iColCount - 1
			$aCol_Width[$i] = _GUICtrlListView_GetColumnWidth($hGLVEx_SrcHandle, $i)
		Next
	EndIf

	; If empty array insert at 0
	If $aGLVEx_SrcArray[0][0] = 0 Then $iRow = 0
	; Get data into array format for insert
	If IsArray($vData) Then
		$vInsert = $vData
	Else
		Local $aData = StringSplit($vData, $sGLVEx_SepChar)
		Switch $aData[0]
			Case 1
				$vInsert = $aData[1]
			Case Else
				Local $vInsert[$aData[0]]
				For $i = 0 To $aData[0] - 1
					$vInsert[$i] = $aData[$i + 1]
				Next
		EndSwitch
	EndIf

	; Set no redraw flag - prevents problems while colour arrays are updated
	$aGLVEx_Data[0][12] = True

	; Insert data into arrays
	If $iRow = -1 Then
		__GUIListViewEx_Array_Add($aGLVEx_SrcArray, $vInsert, $fMultiRow)
		__GUIListViewEx_Array_Add($aCheck_Array, $vInsert, $fMultiRow)
		__GUIListViewEx_Array_Add($aGLVEx_SrcColArray, ";", $fMultiRow)
	Else
		__GUIListViewEx_Array_Insert($aGLVEx_SrcArray, $iRow + 1, $vInsert, $fMultiRow)
		__GUIListViewEx_Array_Insert($aCheck_Array, $iRow + 1, $vInsert, $fMultiRow)
		__GUIListViewEx_Array_Insert($aGLVEx_SrcColArray, $iRow + 1, ";", $fMultiRow)
	EndIf

	; If Loop No Redraw flag set
	If $aGLVEx_Data[0][15] Then
		; Rewrite ListView
		__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aCheck_Array, $iLV_Index, $fCheckBox)
	EndIf

	; Set highlight
	If $iRow = -1 Then
		__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, _GUICtrlListView_GetItemCount($hGLVEx_SrcHandle) - 1)
	Else
		__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, $iRow)
	EndIf

	; Store amended array
	$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
	$aGLVEx_Data[$iLV_Index][18] = $aGLVEx_SrcColArray
	; Delete copied array
	$aGLVEx_SrcArray = 0
	$aGLVEx_SrcColArray = 0

	; Clear no redraw flag
	$aGLVEx_Data[0][12] = False

	; Restore column widths if required
	If $fRetainWidth And $cGLVEx_SrcID Then
		For $i = 1 To $iColCount - 1
			$aCol_Width[$i] = _GUICtrlListView_SetColumnWidth($hGLVEx_SrcHandle, $i, $aCol_Width[$i])
		Next
	EndIf

	; If colour used or single cell selection
	If $aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22] Then
		; Force reload of redraw colour array
		$aGLVEx_Data[0][14] = 0
		; If Loop No Redraw flag set
		If $aGLVEx_Data[0][15] Then
			; Redraw ListView by redrawing entire GUI
			_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
		EndIf
	EndIf

	; Return amended array
	Return _GUIListViewEx_ReturnArray($iLV_Index)

EndFunc   ;==>_GUIListViewEx_InsertSpec

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_Delete
; Description ...: Deletes selected row(s) in active ListView
; Syntax.........: _GUIListViewEx_Delete()
; Parameters ....: $vRange - items to delete.  if no parameter passed any selected items are deleted
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of active ListView content with count in [0] element
;                  Failure: Returns "" and sets @error as follows:
;                      1 = No ListView active
;                      2 = No row selected
;                      3 = No items to delete
; Author ........: Melba23
; Modified ......:
; Remarks .......: If multiple items are selected, all are deleted
;                  $vRange must be semicolon-delimited with hypenated consecutive values.
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_Delete($vRange = "")

	; Set data for active ListView
	Local $iLV_Index = $aGLVEx_Data[0][1]
	; If no ListView active then return
	If $iLV_Index = 0 Then Return SetError(1, 0, "")

	Local $vRet = _GUIListViewEx_DeleteSpec($iLV_Index, $vRange)

	Return SetError(@error, 0, $vRet)

EndFunc   ;==>_GUIListViewEx_Delete

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_DeleteSpec
; Description ...: Deletes specified row(s) in specified ListView
; Syntax.........: _GUIListViewEx_DeleteSpec($iLV_Index, $vRange = "")
; Parameters ....: $iLV_Index - Index of ListView as returned by _GUIListViewEx_Init
;                  $vRange    - Items to delete.
;                                   If no parameter passed any selected items are deleted
;                                   If -1 passed last row is deleted
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of specified ListView content with count in [0] element
;                  Failure: Returns "" and sets @error as follows:
;                      1 = Invalid ListView index
;                      2 = No row selected if no range passed
;                      3 = No items to delete
;                      4 = Invaid range parameter
; Author ........: Melba23
; Modified ......:
; Remarks .......: If multiple items are selected, all are deleted
;                  $vRange must be semicolon-delimited with hypenated consecutive values.
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_DeleteSpec($iLV_Index, $vRange = "")

	; Check valid index
	If $iLV_Index < 0 Or $iLV_Index > $aGLVEx_Data[0][0] Then Return SetError(1, 0, "")

	; Load active ListView details
	$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
	If UBound($hGLVEx_SrcHandle) = 1 Then Return SetError(3, 0, "")
	$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
	Local $fCheckBox = $aGLVEx_Data[$iLV_Index][6]

	; Copy array for manipulation
	$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
	$aGLVEx_SrcColArray = $aGLVEx_Data[$iLV_Index][18]

	; Create Local array for checkboxes (if no checkboxes makes no difference)
	Local $aCheck_Array[UBound($aGLVEx_SrcArray)]
	For $i = 1 To UBound($aCheck_Array) - 1
		$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
	Next

	If $vRange = "-1" Then
		$vRange = UBound($aGLVEx_SrcArray) - 2
	EndIf

	Local $aSplit_1, $aSplit_2, $iIndex

	; Check for range
	If String($vRange) <> "" Then
		Local $iNumber
		$vRange = StringStripWS($vRange, 8)
		$aSplit_1 = StringSplit($vRange, ";")
		$vRange = ""
		For $i = 1 To $aSplit_1[0]
			; Check for correct range syntax
			If Not StringRegExp($aSplit_1[$i], "^\d+(-\d+)?$") Then
				Return SetError(4, 0, -1)
			EndIf
			$aSplit_2 = StringSplit($aSplit_1[$i], "-")
			Switch $aSplit_2[0]
				Case 1
					$vRange &= $aSplit_2[1] & $sGLVEx_SepChar
				Case 2
					If Number($aSplit_2[2]) >= Number($aSplit_2[1]) Then
						$iNumber = $aSplit_2[1] - 1
						Do
							$iNumber += 1
							$vRange &= $iNumber & $sGLVEx_SepChar
						Until $iNumber = $aSplit_2[2]
					EndIf
			EndSwitch
		Next
		$iIndex = StringTrimRight($vRange, 1)
	Else
		; Check if single cell selection enabled
		If $aGLVEx_Data[$iLV_Index][22] Then
			; Use stored value
			$iIndex = $aGLVEx_Data[$iLV_Index][20]
		Else
			; Check actual values
			$iIndex = _GUICtrlListView_GetSelectedIndices($hGLVEx_SrcHandle)
		EndIf
		If $iIndex = "" Then
			Return SetError(2, 0, "")
		EndIf
	EndIf

	; Extract all selected items
	Local $aIndex = StringSplit($iIndex, $sGLVEx_SepChar)

	For $i = 1 To $aIndex[0]
		; Remove highlighting from items
		_GUICtrlListView_SetItemSelected($hGLVEx_SrcHandle, $i, False)
	Next

	; Set no redraw flag - prevents problems while colour arrays are updated
	$aGLVEx_Data[0][12] = True

	; Delete elements from array - start from bottom
	For $i = $aIndex[0] To 1 Step -1
		; Check element exists in array
		If $aIndex[$i] <= UBound($aGLVEx_SrcArray) - 2 Then
			__GUIListViewEx_Array_Delete($aGLVEx_SrcArray, $aIndex[$i] + 1)
			__GUIListViewEx_Array_Delete($aCheck_Array, $aIndex[$i] + 1)
			__GUIListViewEx_Array_Delete($aGLVEx_SrcColArray, $aIndex[$i] + 1)
		EndIf
	Next

	; If Loop No Redraw flag set
	If $aGLVEx_Data[0][15] Then
		; Rewrite ListView
		__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aCheck_Array, $iLV_Index, $fCheckBox)
		; Set highlight
		If $aIndex[1] = 0 Then
			__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, 0)
		Else
			__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, $aIndex[1] - 1)
		EndIf
	EndIf

	; Store amended array
	$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
	$aGLVEx_Data[$iLV_Index][18] = $aGLVEx_SrcColArray
	; Delete copied array
	$aGLVEx_SrcArray = 0
	$aGLVEx_SrcColArray = 0

	; Clear no redraw flag
	$aGLVEx_Data[0][12] = False

	; If colour used or single cell selection
	If $aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22] Then
		; Force reload of redraw colour array
		$aGLVEx_Data[0][14] = 0
		; If Loop No Redraw flag set
		If $aGLVEx_Data[0][15] Then
			; Redraw ListView by redrawing entire window
			_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
		EndIf
	EndIf

	; Return amended array
	Return _GUIListViewEx_ReturnArray($iLV_Index)

EndFunc   ;==>_GUIListViewEx_DeleteSpec

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_InsertCol
; Description ...: Inserts blank column to right of selected column in active ListView
; Syntax.........: _GUIListViewEx_InsertCol([$sTitle = ""[, $iWidth = 50]])
; Parameters ....: $sTitle - (Optional) Title of column - default none
;                  $iWidth - (Optional) Width of new column - default = 50
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of active ListView content with count in [0] element
;                  Failure: If no ListView active then returns "" and sets @error to 1
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_InsertCol($sTitle = "", $iWidth = 50)

	; Set data for active ListView
	Local $iLV_Index = $aGLVEx_Data[0][1]
	; If no ListView active then return
	If $iLV_Index = 0 Then Return SetError(1, 0, "")

	; Pass active column
	Local $vRet = _GUIListViewEx_InsertColSpec($iLV_Index, $aGLVEx_Data[0][2] + 1, $sTitle, $iWidth)

	Return SetError(@error, 0, $vRet)

EndFunc   ;==>_GUIListViewEx_InsertCol

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_InsertColSpec
; Description ...: Inserts specified blank column in specified ListView
; Syntax.........: _GUIListViewEx_InsertColSpec($iLV_Index[, $iCol = -1[, $sTitle = ""[, $iWidth = 50]]])
; Parameters ....: $iLV_Index - Index of ListView as returned by _GUIListViewEx_Init
;                  $iCol      - (Optional) Column to be be inserted - default -1 adds at right
;                  $sTitle    - (Optional) Title of column - default none
;                  $iWidth    - (Optional) Width of new column - default = 50
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of active ListView content with count in [0] element
;                  Failure: Empty string sets @error to
;                      1 = Invalid ListView index
;                      2 = invalid column
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_InsertColSpec($iLV_Index, $iCol = -1, $sTitle = "", $iWidth = 50)

	; Check valid index
	If $iLV_Index < 0 Or $iLV_Index > $aGLVEx_Data[0][0] Then Return SetError(1, 0, "")

	; Load active ListView details
	$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
	$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
	Local $fCheckBox = $aGLVEx_Data[$iLV_Index][6]

	; Copy array for manipulation
	$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
	$aGLVEx_SrcColArray = $aGLVEx_Data[$iLV_Index][18]

	; Check if valid column
	Local $iMax_Col = UBound($aGLVEx_SrcArray, 2) - 1
	If $iCol = -1 Then $iCol = $iMax_Col + 1
	If $iCol < 0 Or $iCol > $iMax_Col + 1 Then Return SetError(2, 0, "")

	; Create Local array for checkboxes (if no checkboxes makes no difference)
	Local $aCheck_Array[UBound($aGLVEx_SrcArray)]
	For $i = 1 To UBound($aCheck_Array) - 1
		$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
	Next

	; Set no redraw flag - prevents problems while colour arrays are updated
	$aGLVEx_Data[0][12] = True

	; Add column to array
	ReDim $aGLVEx_SrcArray[UBound($aGLVEx_SrcArray)][UBound($aGLVEx_SrcArray, 2) + 1]
	ReDim $aGLVEx_SrcColArray[UBound($aGLVEx_SrcColArray)][UBound($aGLVEx_SrcColArray, 2) + 1]
	; Move data and blank new column
	For $i = 0 To UBound($aGLVEx_SrcArray) - 1
		For $j = UBound($aGLVEx_SrcArray, 2) - 2 To $iCol Step -1
			$aGLVEx_SrcArray[$i][$j + 1] = $aGLVEx_SrcArray[$i][$j]
			$aGLVEx_SrcColArray[$i][$j + 1] = $aGLVEx_SrcColArray[$i][$j]
		Next
		$aGLVEx_SrcArray[$i][$iCol] = ""
		$aGLVEx_SrcColArray[$i][$iCol] = ";"
	Next

	; Add column to ListView
	_GUICtrlListView_InsertColumn($hGLVEx_SrcHandle, $iCol, $sTitle, $iWidth)

	; If Loop No Redraw flag set
	If $aGLVEx_Data[0][15] Then
		; Rewrite ListView
		__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aCheck_Array, $iLV_Index, $fCheckBox)
	EndIf

	; Store amended array
	$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
	$aGLVEx_Data[$iLV_Index][18] = $aGLVEx_SrcColArray
	; Delete copied array
	$aGLVEx_SrcArray = 0
	$aGLVEx_SrcColArray = 0

	; Clear no redraw flag
	$aGLVEx_Data[0][12] = False

	; If colour used or single cell selection
	If $aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22] Then
		; Force reload of redraw colour array
		$aGLVEx_Data[0][14] = 0
		; If Loop No Redraw flag set
		If $aGLVEx_Data[0][15] Then
			; Redraw ListView
			_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
		EndIf
	EndIf

	; Return amended array
	Return _GUIListViewEx_ReturnArray($iLV_Index)

EndFunc   ;==>_GUIListViewEx_InsertColSpec

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_DeleteCol
; Description ...: Deletes selected column in active ListView
; Syntax.........: _GUIListViewEx_DeleteCol()
; Parameters ....: None
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of active ListView content with count in [0] element
;                  Failure: If no ListView active then returns "" and sets @error to 1
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_DeleteCol()

	; Set data for active ListView
	Local $iLV_Index = $aGLVEx_Data[0][1]
	; If no ListView active then return
	If $iLV_Index = 0 Then Return SetError(1, 0, "")

	; Delete active column
	Local $vRet = _GUIListViewEx_DeleteColSpec($iLV_Index, $aGLVEx_Data[0][2])

	Return SetError(@error, 0, $vRet)

EndFunc   ;==>_GUIListViewEx_DeleteCol

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_DeleteColSpec
; Description ...: Deletes specified column in specified ListView
; Syntax.........: _GUIListViewEx_DeleteCol($iLV_Index[, $iCol = -1])
; Parameters ....: $iLV_Index - Index of ListView as returned by _GUIListViewEx_Init
;                  $iCol      - (Optional) Column to delete - default -1 deletes rightmost column
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array of active ListView content with count in [0] element
;                  Failure: Empty string sets @error to
;                      1 = Invalid ListView index
;                      2 = invalid column
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_DeleteColSpec($iLV_Index, $iCol = -1)

	; Check valid index
	If $iLV_Index < 0 Or $iLV_Index > $aGLVEx_Data[0][0] Then Return SetError(1, 0, "")

	; Load active ListView details
	$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
	$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
	Local $fCheckBox = $aGLVEx_Data[$iLV_Index][6]

	; Copy array for manipulation
	$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
	$aGLVEx_SrcColArray = $aGLVEx_Data[$iLV_Index][18]

	; Check if valid column
	Local $iMax_Col = UBound($aGLVEx_SrcArray, 2) - 1
	If $iCol = -1 Then $iCol = $iMax_Col
	If $iCol < 0 Or $iCol > $iMax_Col Then Return SetError(2, 0, "")

	; Create Local array for checkboxes (if no checkboxes makes no difference)
	Local $aCheck_Array[UBound($aGLVEx_SrcArray)]
	For $i = 1 To UBound($aCheck_Array) - 1
		$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
	Next

	; Set no redraw flag - prevents problems while colour arrays are updated
	$aGLVEx_Data[0][12] = True

	For $i = 0 To UBound($aGLVEx_SrcArray) - 1
		For $j = $iCol To UBound($aGLVEx_SrcArray, 2) - 2
			$aGLVEx_SrcArray[$i][$j] = $aGLVEx_SrcArray[$i][$j + 1]
			$aGLVEx_SrcColArray[$i][$j] = $aGLVEx_SrcColArray[$i][$j + 1]
		Next
	Next
	ReDim $aGLVEx_SrcArray[UBound($aGLVEx_SrcArray)][UBound($aGLVEx_SrcArray, 2) - 1]
	ReDim $aGLVEx_SrcColArray[UBound($aGLVEx_SrcColArray)][UBound($aGLVEx_SrcColArray, 2) - 1]

	; Delete column from ListView
	_GUICtrlListView_DeleteColumn($hGLVEx_SrcHandle, $iCol)

	; If Loop No Redraw flag set
	If $aGLVEx_Data[0][15] Then
		; Rewrite ListView
		__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aCheck_Array, $iLV_Index, $fCheckBox)
	EndIf

	; Store amended array
	$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
	$aGLVEx_Data[$iLV_Index][18] = $aGLVEx_SrcColArray
	; Delete copied array
	$aGLVEx_SrcArray = 0
	$aGLVEx_SrcColArray = 0

	; Clear no redraw flag
	$aGLVEx_Data[0][12] = False

	; If colour used or single cell selection
	If $aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22] Then
		; Force reload of redraw colour array
		$aGLVEx_Data[0][14] = 0
		; If Loop No Redraw flag set
		If $aGLVEx_Data[0][15] Then
			; Redraw ListView by redrawing entire GUI
			_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
		EndIf
	EndIf

	; Return amended array
	Return _GUIListViewEx_ReturnArray($iLV_Index)

EndFunc   ;==>_GUIListViewEx_DeleteColSpec

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_EditOnClick
; Description ...: Open ListView items in user-defined columns for editing when doubleclicked
; Syntax.........: _GUIListViewEx_EditOnClick([$iEditMode = 0[, $iDelta_X = 0[, $iDelta_Y = 0]]])
; Parameters ....: $iEditMode - Only used if using Edit control:
;                                    Return after single edit - 0 (default)
;                                    {TAB} and arrow keys move to next item - 2-digit code (row mode/column mode)
;                                        1 = Reaching edge terminates edit process
;                                        2 = Reaching edge remains in place
;                                        3 = Reaching edge loops to opposite edge
;                               	     Positive value = ESC abandons current edit only, previous edits remain
;                                        Negative value = ESC resets all edits in current session
;                               Ignored if using Combo control - return after single edit
;                  $iDelta_X  - Permits fine adjustment of edit control in X axis if needed
;                  $iDelta_Y  - Permits fine adjustment of edit control in Y axis if needed
; Requirement(s).: v3.3.10 +
; Return values .: If no double-click: Empty string
; Return values .: Success: 2D array of items edited
;                              - Total number of edits in [0][0] element, with each edit following:
;                              - [zero-based row][zero-based column][original content][new content]
;                  After double-click just above ListView header:
;                      2D array  [column edited][original header text][new header text]
;                  Failure: Sets @error as follows:
;                      1 - ListView not editable
;                      2 - Empty ListView
;                      3 - Column not editable
; Author ........: Melba23
; Modified ......:
; Remarks .......: This function must be placed within the script idle loop.
;                  Edit control depends on _GUIListViewEx_Init $iAdded parameter:
;                      + 2  = Element editable - default edit control
;                      + 32 = Combo control used for editing
;                  Once item edit process started, all other script activity is suspended until following occurs:
;                      {ENTER}  = Current edit confirmed and editing process ended
;                      {ESCAPE} = Current or all edits cancelled and editing process ended
;                      If using Edit control:
;                          If $iEditMode non-zero then {TAB} and arrow keys = Current edit confirmed & continue editing
;                          Click outside edit = Editing process ends and
;                              If $iAdded + 4 : Current edit accepted
;                              Else :           Current edit cancelled
;                      If using Combo control:
;                          Combo actioned     = Combo selection accepted and editing process ended
;                          Click outside edit = Edit process ended and editing process ended
;                  For header edit only {ENTER}, {ESCAPE} and mouse click are actioned - single edit only
;                  The function only returns an array after an edit process launched by a double-click.  If no
;                  double-click has occurred, the function returns an empty string.  The user should check that a
;                  valid array is present before attempting to access it.
;                  If header edited [0][1] element of returned array exists - if items edited this element is empty
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_EditOnClick($iEditMode = 0, $iDelta_X = 0, $iDelta_Y = 0)

	Local $aEdited, $iError

	; If an item was double clicked
	If $fGLVEx_EditClickFlag Then

		; Clear flag
		$fGLVEx_EditClickFlag = False

		; Check Type parameter
		Switch Abs($iEditMode)
			Case 0, 11, 12, 13, 21, 22, 23, 31, 32, 33 ; Single edit or both axes set to valid parameter
				; Allow
			Case Else
				Return SetError(1, 0, "")
		EndSwitch

		; Set data for active ListView
		Local $iLV_Index = $aGLVEx_Data[0][1]
		; If no ListView active then return
		If $iLV_Index = 0 Then
			Return SetError(2, 0, "")
		EndIf

		; Get clicked item info
		Local $aLocation = _GUICtrlListView_SubItemHitTest($hGLVEx_SrcHandle)
		; Check valid row
		If $aLocation[0] = -1 Then
			Return SetError(3, 0, "")
		EndIf

		; Get valid column string
		Local $sCols = $aGLVEx_Data[$iLV_Index][7]
		; And validate selected column
		If Not StringInStr($sCols, "*") Then
			If Not StringInStr(";" & $sCols & ";", ";" & $aLocation[1] & ";") Then
				Return SetError(1, 0, "")
			EndIf
		EndIf

		; Start edit
		$aEdited = __GUIListViewEx_EditProcess($iLV_Index, $aLocation, $sCols, $iDelta_X, $iDelta_Y, $iEditMode)
		$iError = @error
		; Return result array
		Return SetError($iError, 0, $aEdited)

	EndIf

	; If a header was double clicked
	If $fGLVEx_HeaderEdit Then

		; Clear the flag
		$fGLVEx_HeaderEdit = False

		; Wait until mouse button released as click occurs outside the control
		While _WinAPI_GetAsyncKeyState(0x01)
			Sleep(10)
		WEnd

		; Edit header using the default values set by the handler
		$aEdited = _GUIListViewEx_EditHeader()
		$iError = @error
		; Return result
		Return SetError($iError, 0, $aEdited)

	EndIf

	; If nothing was clicked
	Return ""

EndFunc   ;==>_GUIListViewEx_EditOnClick

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_EditItem
; Description ...: Open ListView items for editing programatically
; Syntax.........: _GUIListViewEx_EditItem($iLV_Index, $iRow, $iCol[, $iEditMode = 0[, $iDelta_X = 0[, $iDelta_Y = 0]]])
; Parameters ....: $iLV_Index - Index number of ListView as returned by _GUIListViewEx_Init
;                  $iRow      - Zero-based row of item to edit
;                  $iCol      - Zero-based column of item to edit
;                  $iEditMode - Only used if using Edit control:
;                                    Return after single edit - 0 (default)
;                                    {TAB} and arrow keys move to next item - 2-digit code (row mode/column mode)
;                                        1 = Reaching edge terminates edit process
;                                        2 = Reaching edge remains in place
;                                        3 = Reaching edge loops to opposite edge
;                               	     Positive value = ESC abandons current edit only, previous edits remain
;                                        Negative value = ESC resets all edits in current session
;                               Ignored if using Combo control - return after single edit
;                  $iDelta_X  - Permits fine adjustment of edit control in X axis if needed
;                  $iDelta_Y  - Permits fine adjustment of edit control in Y axis if needed
; Requirement(s).: v3.3.10 +
; Return values .: Success: 2D array of items edited
;                              - Total number of edits in [0][0] element, with each edit following:
;                              - [zero-based row][zero-based column][original content][new content]
;                           @extended set depending on key used to end edit:
;							   - True = {ENTER} pressed
;							   - False = {ESC} pressed
;                  Failure: Sets @error as follows:
;                           1 - Invalid ListView Index
;                           2 - ListView not editable
;                           3 - Invalid row
;                           4 - Invalid column
;                           5 - Invalid edit mode
; Author ........: Melba23
; Modified ......:
; Remarks .......: - Once edit started, all other script activity is suspended until following occurs:
;                      {ENTER}  = Current edit confirmed and editing ended
;                      {ESCAPE} = Current edit cancelled and editing ended
;                      If $iEditMode non-zero then {TAB} and arrow keys = Current edit confirmed continue editing
;                      Click outside edit = Editing process ends and
;                          If $iAdded + 4 : Current edit accepted
;                          Else :           Current edit cancelled
;                  - Returned array allows for verification of new value - _GUIListViewEx_ChangeItem can reset original
;                  - @extended value can be used to determine if to continue in a loop post-edit
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_EditItem($iLV_Index, $iRow, $iCol, $iEditMode = 0, $iDelta_X = 0, $iDelta_Y = 0)

	; Activate the ListView
	_GUIListViewEx_SetActive($iLV_Index)
	If @error Then
		Return SetError(1, 0, "")
	EndIf
	; Check ListView is editable
	If $aGLVEx_Data[$iLV_Index][7] = "" Then
		Return SetError(2, 0, "")
	EndIf
	; Check row and col values
	Local $iMax = _GUICtrlListView_GetItemCount($hGLVEx_SrcHandle)
	If $iRow < 0 Or $iRow > $iMax - 1 Then
		Return SetError(3, 0, "")
	EndIf
	$iMax = _GUICtrlListView_GetColumnCount($hGLVEx_SrcHandle)
	If $iCol < 0 Or $iCol > $iMax - 1 Then
		Return SetError(4, 0, "")
	EndIf
	; Check edit mode parameter
	Switch Abs($iEditMode)
		Case 0, 11, 12, 13, 21, 22, 23, 31, 32, 33 ; Single edit or both axes set to valid parameter
			; Allow
		Case Else
			Return SetError(5, 0, "")
	EndSwitch

	; Declare location array
	Local $aLocation[2] = [$iRow, $iCol]
	; Load valid column string
	Local $sValidCols = $aGLVEx_Data[$iLV_Index][7]
	; Start edit
	Local $aEdited = __GUIListViewEx_EditProcess($iLV_Index, $aLocation, $sValidCols, $iDelta_X, $iDelta_Y, $iEditMode)
	; Determine key used to exit
	Local $iKeyCode = @extended
	; Wait until return key no longer pressed
	While _WinAPI_GetAsyncKeyState($iKeyCode)
		Sleep(10)
	WEnd

	; Unselect row
	_GUICtrlListView_SetItemSelected($aGLVEx_Data[$iLV_Index][0], -1, False)
	; Set extended value
	SetExtended(($iKeyCode = 0x0D) ? (True) : (False))
	; Return result array
	Return $aEdited

EndFunc   ;==>_GUIListViewEx_EditItem

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_ChangeItem
; Description ...: Change ListView item content programatically
; Syntax.........: _GUIListViewEx_ChangeItem($iLV_Index, $iRow, $iCol, $vValue)
; Parameters ....: $iLV_Index - Index number of ListView as returned by _GUIListViewEx_Init
;                  $iRow      - Zero-based row of item to change
;                  $iCol      - Zero-based column of item to change
;                  $vValue    - Content to place in ListView item
; Requirement(s).: v3.3.10 +
; Return values .: Success: Success: Array of current ListView content as returned by _GUIListViewEx_ReturnArray
;                  Failure: Sets @error as follows:
;                           1 - Invalid ListView Index
;                           2 - ListView not editable
;                           3 - Invalid row
;                           4 - Invalid column
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_ChangeItem($iLV_Index, $iRow, $iCol, $vValue)

	; Activate the ListView
	_GUIListViewEx_SetActive($iLV_Index)
	If @error Then
		Return SetError(1, 0, "")
	EndIf
	; Check ListView is editable
	If $aGLVEx_Data[$iLV_Index][7] = "" Then
		Return SetError(2, 0, "")
	EndIf
	; Check row and col values
	Local $iMax = _GUICtrlListView_GetItemCount($hGLVEx_SrcHandle)
	If $iRow < 0 Or $iRow > $iMax - 1 Then
		Return SetError(3, 0, "")
	EndIf
	$iMax = _GUICtrlListView_GetColumnCount($hGLVEx_SrcHandle)
	If $iCol < 0 Or $iCol > $iMax - 1 Then
		Return SetError(4, 0, "")
	EndIf
	; Load array
	Local $aData_Array = $aGLVEx_Data[$iLV_Index][2]
	Local $fCheckBox = $aGLVEx_Data[$iLV_Index][6]
	; Create Local array for checkboxes (if no checkboxes makes no difference)
	Local $aCheck_Array[UBound($aData_Array)]
	For $i = 1 To UBound($aCheck_Array) - 1
		$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
	Next
	If Not BitAND($aGLVEx_Data[$iLV_Index][3], 1) Then
		_ArrayInsert($aCheck_Array, 0, $aData_Array[0][0])
	EndIf
	; Change item in array
	$aData_Array[$iRow + 1][$iCol] = $vValue
	; Store modified array
	$aGLVEx_Data[$iLV_Index][2] = $aData_Array
	; If Loop No Redraw flag set
	If $aGLVEx_Data[0][15] Then
		; Rewrite ListView
		__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aData_Array, $aCheck_Array, $iLV_Index, $fCheckBox)
	EndIf
	; Return changed array
	Return _GUIListViewEx_ReturnArray($iLV_Index)

EndFunc   ;==>_GUIListViewEx_ChangeItem

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_EditHeader
; Description ...: Edit ListView headers programatically
; Syntax.........: _GUIListViewEx_EditHeader([$iLV_Index = Default[, $iCol = Default[, $iDelta_X = 0[, $iDelta_Y = 0]]]])
; Parameters ....: $iLV_Index - Index number of ListView as returned by _GUIListViewEx_Init - default active ListView
;                  $iCol      - Zero-based column of header to edit
;                  $iDelta_X  - Permits fine adjustment of edit control in X axis if needed
;                  $iDelta_Y  - Permits fine adjustment of edit control in Y axis if needed
; Requirement(s).: v3.3.10 +
; Return values .: Success: Array: 2D array [column][original header text][new header text]
;                  Failure: Empty string and sets @error as follows:
;                           1 - Invalid ListView Index
;                           2 - ListView headers not editable
;                           3 - Invalid column
; Author ........: Melba23
; Modified ......:
; Remarks .......: Once edit started, all other script activity is suspended until following occurs:
;                      {ENTER}  = Current edit confirmed and editing ended
;                      {ESCAPE} or click on other control = Current edit cancelled and editing ended
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_EditHeader($iLV_Index = Default, $iCol = Default, $iDelta_X = 0, $iDelta_Y = 0)

	Local $aRet = ""

	If $iLV_Index = Default Then
		$iLV_Index = $aGLVEx_Data[0][1]
	EndIf

	; Activate the ListView
	_GUIListViewEx_SetActive($iLV_Index)
	If @error Then
		Return SetError(1, 0, $aRet)
	EndIf

	Local $hLV_Handle = $aGLVEx_Data[$iLV_Index][0]
	Local $cLV_CID = $aGLVEx_Data[$iLV_Index][1]

	; Check ListView headers are editable
	If $aGLVEx_Data[$iLV_Index][8] = "" Then
		Return SetError(2, 0, $aRet)
	EndIf
	; Check col value
	If $iCol = Default Then
		$iCol = $aGLVEx_Data[0][2]
	EndIf
	Local $iMax = _GUICtrlListView_GetColumnCount($hLV_Handle)
	If $iCol < 0 Or $iCol > $iMax - 1 Then
		Return SetError(3, 0, $aRet)
	EndIf

	Local $tLVPos = DllStructCreate("struct;long X;long Y;endstruct")
	; Get position of ListView within GUI client area
	__GUIListViewEx_GetLVCoords($hLV_Handle, $tLVPos)
	; Get ListView client area to allow for scrollbars
	Local $aLVClient = WinGetClientSize($hLV_Handle)
	; Get ListView font details
	Local $aLV_FontDetails = __GUIListViewEx_GetLVFont($hLV_Handle)
	; Disable ListView
	WinSetState($hLV_Handle, "", @SW_DISABLE)
	; Read current text of header
	Local $aHeader_Data = _GUICtrlListView_GetColumn($hLV_Handle, $iCol)
	Local $sHeaderOrgText = $aHeader_Data[5]
	; Get required edit coords for 0 item
	Local $aLocation[2] = [0, $iCol]
	Local $aEdit_Coords = __GUIListViewEx_EditCoords($hLV_Handle, $cLV_CID, $aLocation, $tLVPos, $aLVClient[0] - 5, $iDelta_X, $iDelta_Y)
	; Now get header size and adjust coords for header
	Local $hHeader = _GUICtrlListView_GetHeader($hLV_Handle)
	Local $aHeader_Pos = WinGetPos($hHeader)
	$aEdit_Coords[0] -= 2
	$aEdit_Coords[1] -= $aHeader_Pos[3]
	$aEdit_Coords[3] = $aHeader_Pos[3]
	; Create temporary edit - get handle, set font size, give keyboard focus and select all text
	$cGLVEx_EditID = GUICtrlCreateEdit($sHeaderOrgText, $aEdit_Coords[0], $aEdit_Coords[1], $aEdit_Coords[2], $aEdit_Coords[3], 0)
	Local $hTemp_Edit = GUICtrlGetHandle($cGLVEx_EditID)
	GUICtrlSetFont($cGLVEx_EditID, $aLV_FontDetails[0], Default, Default, $aLV_FontDetails[1])
	GUICtrlSetState($cGLVEx_EditID, 256) ; $GUI_FOCUS
	GUICtrlSendMsg($cGLVEx_EditID, 0xB1, 0, -1) ; $EM_SETSEL
	; Valid keys to action (ENTER, ESC)
	Local $aKeys[2] = [0x0D, 0x1B]
	; Clear key code flag
	Local $iKey_Code = 0
	; Wait for a key press
	While 1
		; Check for valid key or mouse button pressed
		For $i = 0 To 1
			If _WinAPI_GetAsyncKeyState($aKeys[$i]) Then
				; Set key pressed flag
				$iKey_Code = $aKeys[$i]
				ExitLoop 2
			EndIf
		Next
		; Temp input loses focus
		If _WinAPI_GetFocus() <> $hTemp_Edit Then
			ExitLoop
		EndIf
		; If edit moveable by click then check for mouse pressed outside edit
		If _WinAPI_GetAsyncKeyState(0x01) Then
			Local $aCInfo = GUIGetCursorInfo()
			If Not (IsArray($aCInfo)) Or $aCInfo[4] <> $cGLVEx_EditID Then
				$iKey_Code = 0x01
				ExitLoop
			EndIf
		EndIf
		; Save CPU
		Sleep(10)
	WEnd
	; Action keypress
	Switch $iKey_Code
		Case 0x0D
			; Change column header text
			Local $sHeaderNewText = GUICtrlRead($cGLVEx_EditID)
			If $sHeaderNewText <> $sHeaderOrgText Then
				_GUICtrlListView_SetColumn($hLV_Handle, $iCol, $sHeaderNewText)
				Local $aRet[1][3] = [[$iCol, $sHeaderOrgText, $sHeaderNewText]]
			EndIf
	EndSwitch
	; Delete Edit
	GUICtrlDelete($cGLVEx_EditID)
	; Reenable ListView
	WinSetState($hLV_Handle, "", @SW_ENABLE)

	Return $aRet

EndFunc   ;==>_GUIListViewEx_EditHeader

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_EditWidth
; Description ...: Set required widths for column edit/combo when editing
; Syntax.........: _GUIListViewEx_EditWidth($iLV_Index, $aWidth)
; Parameters ....: $iLV_Index - Index number of ListView as returned by _GUIListViewEx_Init
;                  $aWidth    - Zero-based 1D array of required edit/combo widths where array index = column
;                               0/Default/empty = use actual column width
; Requirement(s).: v3.3.10 +
; Return values .: Success: 1
;                  Failure: 0 and sets @error as follows:
;                           1 - Invalid ListView Index
;                           2 - Invalid $aWidth array
; Author ........: Melba23
; Modified ......:
; Remarks .......: $aWidth will be ReDimmed to match columns - all values converted to Number datatype.
;                  Negative value resizes read-only combo edit control, otherwise only dropdown resized.
;                  Actual column width used if wider than set value
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_EditWidth($iLV_Index, $aWidth)

	; Check valid index
	If $iLV_Index < 1 Or $iLV_Index > $aGLVEx_Data[0][0] Then
		Return SetError(1, 0, 0)
	EndIf
	; Check valid array
	If (Not IsArray($aWidth)) Or (UBound($aWidth, 0) <> 1) Then Return SetError(2, 0, 0)
	; Resize array
	ReDim $aWidth[_GUICtrlListView_GetColumnCount($aGLVEx_Data[$iLV_Index][0])]
	; Store array
	$aGLVEx_Data[$iLV_Index][14] = $aWidth

EndFunc   ;==>_GUIListViewEx_EditWidth

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_BlockReDraw
; Description ...: Prevents ListView redrawing during looped Insert/Delete/Change calls
; Syntax.........: _GUIListViewEx_BlockReDraw($iLV_Index, $fMode)
; Parameters ....: $iLV_Index - Index number of ListView as returned by _GUIListViewEx_Init
;                  $fMode     - True  = Prevent redrawing during Insert/Delete/Change calls
;                             - False = Allow future redrawing and force a redraw
; Requirement(s).: v3.3.10 +
; Return values .: Success: 1
;                  Failure: 0 and sets @error as follows:
;                           1 - Invalid ListView Index
;                           2 - Invalid $fMode
; Author ........: Melba23
; Modified ......:
; Remarks .......: Allows multiple items to be inserted/deleted/changed programatically without redrawing the ListView
;                  after each call. When block removed, ListView is redrawn to update with new content
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_BlockReDraw($iLV_Index, $bMode)

	; Check valid index
	If $iLV_Index < 1 Or $iLV_Index > $aGLVEx_Data[0][0] Then
		Return SetError(1, 0, 0)
	EndIf
	Switch $bMode
		Case True
			; Clear redraw flag
			$aGLVEx_Data[0][15] = False

		Case False
			; Set redraw flag
			$aGLVEx_Data[0][15] = True
			; Force ListView redraw to current content
			Local $aData_Array = $aGLVEx_Data[$iLV_Index][2]
			Local $aCheck_Array[UBound($aData_Array)]
			For $i = 1 To UBound($aCheck_Array) - 1
				$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
			Next
			__GUIListViewEx_ReWriteLV($aGLVEx_Data[$iLV_Index][0], $aData_Array, $aCheck_Array, $iLV_Index, $aGLVEx_Data[$iLV_Index][6])

		Case Else
			Return SetError(2, 0, 0)
	EndSwitch
	Return 1

EndFunc   ;==>_GUIListViewEx_BlockReDraw

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_ComboData
; Description ...: Set data for edit combo in a specified column
; Syntax.........: _GUIListViewEx_ComboData($iLV_Index, $iCol, $vData[, $fRead_Only = False])
; Parameters ....: $iLV_Index    - Index number of ListView as returned by _GUIListViewEx_Init - default active ListView
;                  $iCol         - Column of ListView to show this data.  Use -1 for all columns
;                  $vData        - Content of combo - either delimited string or 0-based array
;                  $fRead_Only   - Whether combo is readonly (default = editable)
; Requirement(s).: v3.3.10 +
; Return values .: Success: 1
;                  Failure: 0 and sets @error as follows:
;                           1 - Invalid ListView Index
;                           2 - Deprecated
;                           3 - Invalid column parameter
; Author ........: Melba23
; Modified ......:
; Remarks .......: - Setting data for a column forces a combo display for editing
;                  - Once edit started, all other script activity is suspended until following occurs:
;                      Combo selection made or {ENTER} = Current edit confirmed and editing ended
;                      {ESCAPE} or click on other control = Current edit cancelled and editing ended
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_ComboData($iIndex, $iCol, $vData, $fRead_Only = False)

	; Check valid index
	If $iIndex < 1 Or $iIndex > $aGLVEx_Data[0][0] Then
		Return SetError(1, 0, 0)
	EndIf
	; Check if combo data array already exists
	If Not IsArray($aGLVEx_Data[$iIndex][11]) Then
		; Create and store if not
		Local $aCombo_Array[_GUICtrlListView_GetColumnCount($aGLVEx_Data[$iIndex][0])]
		$aGLVEx_Data[$iIndex][11] = $aCombo_Array
	EndIf
	; Check if valid col
	If $iCol < -1 Or $iCol > _GUICtrlListView_GetColumnCount($aGLVEx_Data[$iIndex][0]) - 1 Then
		Return SetError(3, 0, 0)
	EndIf
	; Extract combo data array
	Local $aComboData_Array = $aGLVEx_Data[$iIndex][11]
	; Clear current combo data
	If $iCol = -1 Then
		For $i = 0 To UBound($aComboData_Array) - 1
			$aComboData_Array[$i] = ""
		Next
	Else
		$aComboData_Array[$iCol] = ""
	EndIf
	Local $sCombo_Data = ""
	; If array passed
	If IsArray($vData) Then
		; Loop through at create delimited string
		For $i = 0 To UBound($vData) - 1
			$sCombo_Data &= $sGLVEx_SepChar & $vData[$i]
		Next
	Else
		; Check for leading |
		If StringLeft($vData, 1) <> $sGLVEx_SepChar Then
			$sCombo_Data = $sGLVEx_SepChar & $vData
		EndIf
	EndIf
	; Set readonly flag if required
	If $fRead_Only Then
		$sCombo_Data = "#" & $sCombo_Data
	EndIf
	; Set new value into array
	If $iCol = -1 Then
		For $i = 0 To UBound($aComboData_Array) - 1
			$aComboData_Array[$i] = $sCombo_Data
		Next
	Else
		$aComboData_Array[$iCol] = $sCombo_Data
	EndIf
	; Store array
	$aGLVEx_Data[$iIndex][11] = $aComboData_Array

	; Show success
	Return 1

EndFunc   ;==>_GUIListViewEx_ComboData

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_DragEvent
; Description ...: Returns index of ListView(s) involved in a drag-drop event
; Syntax.........: _GUIListViewEx_DragEvent()
; Parameters ....: None
; Requirement(s).: v3.3.10 +
; Return values .: If a drag-drop event has taken place - colon-delimited string giving "Drag" and "Drop" indices
;                  If no event - an empty string
; Author ........: Melba23
; Modified ......:
; Remarks .......: This function must be placed within the script idle loop.
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_DragEvent()

	; Return and clear DragEvent details
	Local $sRet = $sGLVEx_DragEvent
	$sGLVEx_DragEvent = ""
	Return $sRet

EndFunc   ;==>_GUIListViewEx_DragEvent

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_SetColour
; Description ...: Sets text and/or back colour for a user colour enabled ListView item
; Syntax.........: _GUIListViewEx_SetColour($iLV_Index, $sColSet, $iRow, $iCol)
; Parameters ....: $iLV_Index - Index of ListView
;                  $sColSet   - Colour string in RGB hex (0xRRGGBB)
;                                   "text;back"        = both user colours set
;                                   "text;" or ";back" = one user colour set, no change to other
;                                   ";" or ""          = reset both to default colours
;                  $iRow      - Row index (0-based)
;                  $iCol      - Column index (0-based)
; Requirement(s).: v3.3.10 +
; Return values .: Success: Returns 1
;                  Failure: Returns 0 and sets @error as follows:
;                      1 = Invalid index
;                      2 = Not user colour enabled
;                      3 = Invalid colour
;                      4 - Invalid row/col
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_SetColour($iLV_Index, $sColSet, $iRow, $iCol)

	; Activate the ListView
	_GUIListViewEx_SetActive($iLV_Index)
	If @error Then
		Return SetError(1, 0, 0)
	EndIf
	; Check ListView is user colour enabled
	If Not $aGLVEx_Data[$iLV_Index][19] Then
		Return SetError(2, 0, 0)
	EndIf
	; Check colour
	If $sColSet = "" Then
		$sColSet = ";"
	EndIf
	; Check for default colour setting and set flag
	Local $fDefCol = (($sColSet = ";") ? (True) : (False))
	; Check for valid colour strings
	If Not StringRegExp($sColSet, "^(\Q0x\E[0-9A-Fa-f]{6})?;(\Q0x\E[0-9A-Fa-f]{6})?$") Then
		Return SetError(3, 0, 0)
	EndIf
	; Load current array
	Local $aColArray = $aGLVEx_Data[$iLV_Index][18]
	; Check position exists in ListView
	If $iRow < 0 Or $iCol < 0 Or $iRow > UBound($aColArray) - 2 Or $iCol > UBound($aColArray, 2) - 1 Then
		Return SetError(4, 0, 0)
	EndIf
	; Current colour
	Local $aCurrSplit = StringSplit($aColArray[$iRow + 1][$iCol], ";")
	; New colour
	Local $aNewSplit = StringSplit($sColSet, ";")
	; Replace if required
	For $i = 1 To 2
		If $aNewSplit[$i] Then
			; Convert to BGR
			$aCurrSplit[$i] = '0x' & StringMid($aNewSplit[$i], 7, 2) & StringMid($aNewSplit[$i], 5, 2) & StringMid($aNewSplit[$i], 3, 2)
		EndIf
		If $fDefCol Then
			; Reset default
			$aCurrSplit[$i] = ""
		EndIf
	Next
	; Store new colour
	$aColArray[$iRow + 1][$iCol] = $aCurrSplit[1] & ";" & $aCurrSplit[2]
	; Store amended array
	$aGLVEx_Data[$iLV_Index][18] = $aColArray

	; Force reload of redraw colour array
	$aGLVEx_Data[0][14] = 0
	; Redraw listView item to show colour
	_GUICtrlListView_RedrawItems($aGLVEx_Data[$iLV_Index][0], $iRow, $iRow)

	Return 1

EndFunc   ;==>_GUIListViewEx_SetColour

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_LoadColour
; Description ...: Uses array to set text and back colour for a user colour enabled ListView
; Syntax.........: _GUIListViewEx_LoadColour($iLV_Index, $aColArray)
; Parameters ....: $iLV_Index - Index of ListView
;                  $aColArray - 0-based 2D array containing colour strings in RGB hex
;                                    "text;back"        = both user colours set
;                                    "text;" or ";back" = one user colour set
;                                    ";" or ""          = default colours
; Requirement(s).: v3.3.10 +
; Return values .: Success: Returns 1
;                  Failure: Returns 0 and sets @error as follows:
;                      1 = Invalid index
;                      2 = ListView not user colour enabled
;                      3 = Array not 2D (@extended = 0) or not correct size for LV (@extended = 1)
;                      4 = Invalid colour string in array
; Author ........: Melba23
; Modified ......:
; Remarks .......:
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_LoadColour($iLV_Index, $aColArray)

	Local $sColSet

	; Check valid index
	If $iLV_Index < 0 Or $iLV_Index > $aGLVEx_Data[0][0] Then Return SetError(1, 0, 0)
	; Check ListView is user colour enabled
	If Not $aGLVEx_Data[$iLV_Index][19] Then
		Return SetError(2, 0, 0)
	EndIf
	If UBound($aColArray, 0) <> 2 Then
		Return SetError(3, 0, 0)
	EndIf

	; Add a 0-line to match the stored data array
	_ArrayInsert($aColArray, 0)
	; Compare sizes
	If (UBound($aColArray) <> UBound($aGLVEx_Data[$iLV_Index][2])) Or (UBound($aColArray, 2) <> UBound($aGLVEx_Data[$iLV_Index][2], 2)) Then
		Return SetError(3, 1, 0)
	EndIf
	; Convert all colours to BGR
	For $i = 1 To UBound($aColArray, 1) - 1
		For $j = 0 To UBound($aColArray, 2) - 1
			$sColSet = $aColArray[$i][$j]
			If $sColSet = "" Then
				$sColSet = ";"
				$aColArray[$i][$j] = ";"
			EndIf
			If Not StringRegExp($sColSet, "^(\Q0x\E[0-9A-Fa-f]{6})?;(\Q0x\E[0-9A-Fa-f]{6})?$") Then
				Return SetError(4, 0, 0)
			EndIf
			$aColArray[$i][$j] = StringRegExpReplace($sColSet, "0x(.{2})(.{2})(.{2})", "0x$3$2$1")
		Next
	Next
	$aGLVEx_Data[$iLV_Index][18] = $aColArray

	Return 1

EndFunc   ;==>_GUIListViewEx_LoadColour

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_SetDefColours
; Description ...: Sets default colours for user colour/single cell select enabled ListViews
; Syntax.........: _GUIListViewEx_SetDefColours($aDefCols)
; Parameters ....: $aDefCols - 1D 4-element array of hex RGB default colour strings
;                                (Normal text, Normal field, Selected text, Selected field)
; Requirement(s).: v3.3.10 +
; Return values .: Success: Returns 1
;                  Failure: Returns 0 and sets @error as follows:
;                      1 = Invalid index
;                      2 = Not user colour or single cell selection enabled
;                      3 = Invalid array
;                      4 - Invalid colour
; Author ........: Melba23
; Modified ......:
; Remarks .......: Setting an element to Default resets the original default colour
;                  Setting an element to "" maintains current default colour
;                  Normal colours are used for all non-user coloured ListView items
;                  Selected colours used for single cell selection if enabled
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_SetDefColours($iLV_Index, $aDefCols)

	; Check valid index
	If $iLV_Index < 0 Or $iLV_Index > $aGLVEx_Data[0][0] Then Return SetError(1, 0, 0)
	; Check colour or single cell enabled
	If Not ($aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22]) Then Return SetError(2, 0, 0)
	; Check valid array
	If Not IsArray($aDefCols) Or UBound($aDefCols) <> 4 Or UBound($aDefCols, 0) <> 1 Then Return SetError(3, 0, 0)

	; Load current colours
	Local $aCurCols = $aGLVEx_Data[$iLV_Index][23]
	; Loop through array
	Local $sCol
	For $i = 0 To 3
		If $aDefCols[$i] = Default Then
			; Reset default colour
			$aDefCols[$i] = $aGLVEx_DefColours[$i]
		ElseIf $aDefCols[$i] = "" Then
			; Maintain current colour
			$aDefCols[$i] = $aCurCols[$i]
		Else
			Switch Number($aDefCols[$i])
				; Check valid colour
				Case 0 To 0xFFFFFF
					; Convert to BGR
					$sCol = '0x' & StringMid($aDefCols[$i], 7, 2) & StringMid($aDefCols[$i], 5, 2) & StringMid($aDefCols[$i], 3, 2)
					; Save in array
					$aDefCols[$i] = $sCol
				Case Else
					Return SetError(4, 0, 0)
			EndSwitch
		EndIf
	Next
	; Store array
	$aGLVEx_Data[$iLV_Index][23] = $aDefCols

	; Force reload of redraw colour array
	$aGLVEx_Data[0][14] = 0
	; If Loop No Redraw flag set
	If $aGLVEx_Data[0][15] Then
		; Redraw ListView
		_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
	EndIf

	Return 1

EndFunc

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_ContextPos
; Description ...: Returns index and row/col of last right click
; Syntax.........: _GUIListViewEx_ContextPos()
; Parameters ....: None
; Requirement(s).: v3.3.10 +
; Return values .: Success: Returns 3 element array: [ListView_index, Row, Column]
; Author ........: Melba23
; Modified ......:
; Remarks .......: Allows user colours to be set via a context menu
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_ContextPos()

	Local $aPos[3] = [$aGLVEx_Data[0][1], $aGLVEx_Data[0][10], $aGLVEx_Data[0][11]]
	Return $aPos

EndFunc   ;==>_GUIListViewEx_ContextPos

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_ToolTipInit
; Description ...: Defines column(s) which will display a tooltip when clicked
; Syntax.........: _GUIListViewEx_ToolTipInit($iLV_Index, $vRange [, $iTime = 1000 ], $iMode = 1]])
; Parameters ....: $iLV_Index - Index of ListView holding columns
;                  $vRange    - Range of columns - see remarks
;                  $iTime     - Time for tooltip to display (default = 1000)
;                  $iMode     - Display: 1 (default) = cell content, 2 = 0 column
; Requirement(s).: v3.3.10 +
; Return values .: Success: Returns 1
;                  Failure: Returns 0 and sets @error as follows:
;                      1 = Invalid index
;                      2 = Invalid range
;                      3 = Invalid time
; Author ........: Melba23
; Modified ......:
; Remarks .......: Function is designed to show:
;                      Mode 1: ListView content if column is too narrow for data within
;                      Mode 2: 0 column data to allow for row identification when right scrolled
;                  $vRange is a string containing the rows which show tooltips.
;                  It can be a single number or a range separated by a hyphen (-).
;                  Multiple items are separated by a semi-colon (;).
;                  "*" = all columns
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_ToolTipInit($iLV_Index, $vRange, $iTime = 1000, $iMode = 1)

	; Check valid parameters
	If $iLV_Index < 0 Or $iLV_Index > $aGLVEx_Data[0][0] Then Return SetError(1, 0, 0)
	If Not IsString($vRange) Then Return SetError(2, 0, 0)
	If Not IsInt($iTime) Then Return SetError(3, 0, 0)

	; Expand range
	Local $iNumber, $aSplit_1, $aSplit_2
	If $vRange <> "*" Then
		$vRange = StringStripWS($vRange, 8)
		$aSplit_1 = StringSplit($vRange, ";")
		$vRange = ""
		For $i = 1 To $aSplit_1[0]
			; Check for correct range syntax
			If Not StringRegExp($aSplit_1[$i], "^\d+(-\d+)?$") Then Return SetError(2, 0, 0)
			$aSplit_2 = StringSplit($aSplit_1[$i], "-")
			Switch $aSplit_2[0]
				Case 1
					$vRange &= $aSplit_2[1] & ";"
				Case 2
					If Number($aSplit_2[2]) >= Number($aSplit_2[1]) Then
						$iNumber = $aSplit_2[1] - 1
						Do
							$iNumber += 1
							$vRange &= $iNumber & ";"
						Until $iNumber = $aSplit_2[2]
					EndIf
			EndSwitch
		Next
		$vRange = StringSplit(StringTrimRight($vRange, 1), ";")
		If $vRange[1] < 0 Or $vRange[$vRange[0]] > _GUICtrlListView_GetColumnCount($aGLVEx_Data[$iLV_Index][0]) Then Return SetError(2, 0, 0)
	EndIf
	; Store column range and time
	$aGLVEx_Data[$iLV_Index][15] = $vRange
	$aGLVEx_Data[$iLV_Index][16] = $iTime
	$aGLVEx_Data[$iLV_Index][17] = $iMode

	Return 1

EndFunc   ;==>_GUIListViewEx_ToolTipInit

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_ToolTipShow
; Description ...: Show tooltips when defined columns clicked
; Syntax.........: _GUIListViewEx_ToolTipShow()
; Parameters ....: None
; Requirement(s).: v3.3.10 +
; Return values .: None
; Author ........: Melba23
; Modified ......:
; Remarks .......: This function must be placed within the script idle loop.
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_ToolTipShow()

	; Get Index
	Local $iLV_Index = $aGLVEx_Data[0][1]
	; Get mode
	Local $iMode = $aGLVEx_Data[$iLV_Index][17]
	; If tooltips initiated
	If $iMode Then
		Local $fToolTipCol = False
		; Get active cell if single cell selection
		If $aGLVEx_Data[$iLV_Index][21] Then
			$aGLVEx_Data[0][4] = $aGLVEx_Data[0][17]
			$aGLVEx_Data[0][5] = $aGLVEx_Data[0][18]
		EndIf
		; If new item clicked
		If $aGLVEx_Data[0][4] <> $aGLVEx_Data[0][6] Or $aGLVEx_Data[0][5] <> $aGLVEx_Data[0][7] Then
			; Check range
			If $aGLVEx_Data[$iLV_Index][15] = "*" Then
				$fToolTipCol = True
			Else
				If IsArray($aGLVEx_Data[$iLV_Index][15]) Then
					Local $vRange = $aGLVEx_Data[$iLV_Index][15]
					For $i = 1 To $vRange[0]
						; If initiated column
						If $aGLVEx_Data[0][2] = $vRange[$i] Then
							$fToolTipCol = True
							ExitLoop
						EndIf
					Next
				EndIf
			EndIf
		EndIf
		If $fToolTipCol Then
			; Read all row text
			Local $aItemText = _GUICtrlListView_GetItemTextArray($aGLVEx_Data[$iLV_Index][0], $aGLVEx_Data[0][4])
			Local $sText
			Switch $iMode
				Case 1
					$sText = $aItemText[$aGLVEx_Data[0][5] + 1]
				Case 2
					$sText = $aItemText[1]
			EndSwitch
			; Create ToolTip
			ToolTip($sText)
			; Set up clearance
			AdlibRegister("__GUIListViewEx_ToolTipHide", $aGLVEx_Data[$iLV_Index][16])
		EndIf
		; Store location
		$aGLVEx_Data[0][6] = $aGLVEx_Data[0][4]
		$aGLVEx_Data[0][7] = $aGLVEx_Data[0][5]

	EndIf

EndFunc   ;==>_GUIListViewEx_ToolTipShow

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_MsgRegister
; Description ...: Registers Windows messages required for the UDF
; Syntax.........: _GUIListViewEx_MsgRegister([$fNOTIFY = True, [$fMOUSEMOVE = True, [$fLBUTTONUP = True]]])
; Parameters ....: $fNOTIFY     - True = Register WM_NOTIFY message
;                  $fMOUSEMOVE  - True = Register WM_MOUSEMOVE message
;                  $fLBUTTONUP  - True = Register WM_LBUTTONUP message
;                  $fSYSCOMMAND - True = Register WM_SYSCOMAMND message
; Requirement(s).: v3.3.10 +
; Return values .: None
; Author ........: Melba23
; Modified ......:
; Remarks .......: If message handlers already registered, then call the relevant handler function from within that handler
;                  WM_NOTIFY handler required for all UDF functions
;                  WM_MOUSEMOVE and WM_LBUTTONUP handlers required for drag
;                  WM_SYSCOMMAND required for single click [X] GUI closure while editing
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_MsgRegister($fNOTIFY = True, $fMOUSEMOVE = True, $fLBUTTONUP = True, $fSYSCOMMAND = True)

	; Register required messages
	If $fNOTIFY Then GUIRegisterMsg(0x004E, "_GUIListViewEx_WM_NOTIFY_Handler") ; $WM_NOTIFY
	If $fMOUSEMOVE Then GUIRegisterMsg(0x0200, "_GUIListViewEx_WM_MOUSEMOVE_Handler") ; $WM_MOUSEMOVE
	If $fLBUTTONUP Then GUIRegisterMsg(0x0202, "_GUIListViewEx_WM_LBUTTONUP_Handler") ; $WM_LBUTTONUP
	If $fSYSCOMMAND Then GUIRegisterMsg(0x0112, "_GUIListViewEx_WM_SYSCOMMAND_Handler") ; $WM_SYSCOMMAND

EndFunc   ;==>_GUIListViewEx_MsgRegister

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_WM_NOTIFY_Handler
; Description ...: Windows message handler for WM_NOTIFY
; Syntax.........: _GUIListViewEx_WM_NOTIFY_Handler()
; Requirement(s).: v3.3.10 +
; Return values .: None
; Author ........: Melba23
; Modified ......:
; Remarks .......: If a WM_NOTIFY handler already registered, then call this function from within that handler
;                  If user colours are enabled, the handler return value must be returned on handler exit
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_WM_NOTIFY_Handler($hWnd, $iMsg, $wParam, $lParam)

	#forceref $hWnd, $iMsg, $wParam

	; Struct = $tagNMHDR and "int Item;int SubItem" from $tagNMLISTVIEW
	Local $tStruct = DllStructCreate("hwnd;uint_ptr;int_ptr;int;int", $lParam)
	If @error Then Return

	Local $hLV = DllStructGetData($tStruct, 1)
	Local $iItem = DllStructGetData($tStruct, 4)

	; Check if enabled ListView or header
	For $iLV_Index = 1 To $aGLVEx_Data[0][0]
		If $aGLVEx_Data[$iLV_Index][0] = DllStructGetData($tStruct, 1) Then
			ExitLoop
		EndIf
	Next
	If $iLV_Index > $aGLVEx_Data[0][0] Then Return ; Not enabled

	$aGLVEx_Data[0][17] = $aGLVEx_Data[$iLV_Index][20]
	$aGLVEx_Data[0][18] = $aGLVEx_Data[$iLV_Index][21]

	Local $iCode = BitAND(DllStructGetData($tStruct, 3), 0xFFFFFFFF)
	Switch $iCode

		Case $LVN_BEGINSCROLL
			; if editing then abandon
			If $cGLVEx_EditID <> 9999 Then
				; Delete temp edit control and set placeholder
				GUICtrlDelete($cGLVEx_EditID)
				$cGLVEx_EditID = 9999
				; Reactivate ListView
				WinSetState($hGLVEx_Editing, "", @SW_ENABLE)
			EndIf

		Case $LVN_COLUMNCLICK, -2 ; $NM_CLICK
			; Set values for active ListView
			$aGLVEx_Data[0][1] = $iLV_Index
			$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
			$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
			; Get and store row index
			$aGLVEx_Data[0][4] = DllStructGetData($tStruct, 4)
			; Get column index
			Local $iCol = DllStructGetData($tStruct, 5)
			; Store it - for normal and tooltip use
			$aGLVEx_Data[0][2] = $iCol
			$aGLVEx_Data[0][5] = $iCol

			; If a column was clicked
			If $iCode = $LVN_COLUMNCLICK Then
				; Scroll column into view
				; Get X coord of first item in column
				Local $aRect = _GUICtrlListView_GetSubItemRect($hGLVEx_SrcHandle, 0, $iCol)
				; Get col width
				Local $aLV_Pos = WinGetPos($hGLVEx_SrcHandle)
				; Scroll to left edge if all column not in view
				If $aRect[0] < 0 Or $aRect[2] > $aLV_Pos[2] - $aGLVEx_Data[0][8] Then ; Reduce by scrollbar width
					_GUICtrlListView_Scroll($hGLVEx_SrcHandle, $aRect[0], 0)
				EndIf

				; Look for Ctrl key pressed
				_WinAPI_GetAsyncKeyState(0x11) ; Needed to avoid double setting
				If _WinAPI_GetAsyncKeyState(0x11) Then
					; Load valid column string
					Local $sValidCols = $aGLVEx_Data[$iLV_Index][7]
					; Check column is editable
					If StringInStr($sValidCols, "*") Or StringInStr(";" & $sValidCols, ";" & $iCol) Then
						; Set header edit flag
						$fGLVEx_HeaderEdit = True
					EndIf
				Else
					; If ListView sortable
					If IsArray($aGLVEx_Data[$iLV_Index][4]) Then
						; Load array
						$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
						; Load current ListView sort state array
						Local $aLVSortState = $aGLVEx_Data[$iLV_Index][4]
						; Sort column - get column from from struct
						_GUICtrlListView_SimpleSort($hGLVEx_SrcHandle, $aLVSortState, $iCol)
						; Store new ListView sort state array
						$aGLVEx_Data[$iLV_Index][4] = $aLVSortState
						; Reread listview items into array
						Local $iDim2 = UBound($aGLVEx_SrcArray, 2) - 1
						For $j = 1 To $aGLVEx_SrcArray[0][0]
							For $k = 0 To $iDim2
								$aGLVEx_SrcArray[$j][$k] = _GUICtrlListView_GetItemText($hGLVEx_SrcHandle, $j - 1, $k)
							Next
						Next
						; Store amended array
						$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
						; Delete array
						$aGLVEx_SrcArray = 0
					EndIf
				EndIf
			EndIf

		Case $LVN_BEGINDRAG
			; Set values for this ListView
			$aGLVEx_Data[0][1] = $iLV_Index

			; Store source & target ListView data for eventual inter-LV drag
			$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
			$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]
			$iGLVEx_SrcIndex = $iLV_Index
			$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
			$hGLVEx_TgtHandle = $hGLVEx_SrcHandle
			$cGLVEx_TgtID = $cGLVEx_SrcID
			$iGLVEx_TgtIndex = $iGLVEx_SrcIndex
			$aGLVEx_TgtArray = $aGLVEx_SrcArray

			; Copy array for manipulation
			$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]

			; Set drag image flag
			Local $fImage = $aGLVEx_Data[$iLV_Index][5]

			; Check if Native or UDF and set focus
			If $cGLVEx_SrcID Then
				GUICtrlSetState($cGLVEx_SrcID, 256) ; $GUI_FOCUS
			Else
				_WinAPI_SetFocus($hGLVEx_SrcHandle)
			EndIf

			; Get dragged item index
			$iGLVEx_DraggedIndex = DllStructGetData($tStruct, 4) ; Item
			; Set dragged item count
			$iGLVEx_Dragging = 1

			; Check for selected items
			Local $iIndex
			; Check if single cell selection enabled
			If $aGLVEx_Data[$iLV_Index][22] Then
				; Use stored value
				$iIndex = $aGLVEx_Data[$iLV_Index][20]
			Else
				; Check actual values
				$iIndex = _GUICtrlListView_GetSelectedIndices($hGLVEx_SrcHandle)
			EndIf
			; Check if item is part of a multiple selection
			If StringInStr($iIndex, $iGLVEx_DraggedIndex) And StringInStr($iIndex, "|") Then
				; Extract all selected items
				Local $aIndex = StringSplit($iIndex, "|")
				For $i = 1 To $aIndex[0]
					If $aIndex[$i] = $iGLVEx_DraggedIndex Then ExitLoop
				Next
				; Now check for consecutive items
				If $i <> 1 Then ; Up
					For $j = $i - 1 To 1 Step -1
						; Consecutive?
						If $aIndex[$j] <> $aIndex[$j + 1] - 1 Then ExitLoop
						; Adjust dragged index to this item
						$iGLVEx_DraggedIndex -= 1
						; Increase number to drag
						$iGLVEx_Dragging += 1
					Next
				EndIf
				If $i <> $aIndex[0] Then ; Down
					For $j = $i + 1 To $aIndex[0]
						; Consecutive
						If $aIndex[$j] <> $aIndex[$j - 1] + 1 Then ExitLoop
						; Increase number to drag
						$iGLVEx_Dragging += 1
					Next
				EndIf
			Else ; Either no selection or only a single
				; Set flag
				$iGLVEx_Dragging = 1
			EndIf

			; Remove all highlighting
			_GUICtrlListView_SetItemSelected($hGLVEx_SrcHandle, -1, False)

			; Create drag image
			If $fImage Then
				Local $aImageData = _GUICtrlListView_CreateDragImage($hGLVEx_SrcHandle, $iGLVEx_DraggedIndex)
				$hGLVEx_DraggedImage = $aImageData[0]
				_GUIImageList_BeginDrag($hGLVEx_DraggedImage, 0, 0, 0)
			EndIf

		Case -3  ; $NM_DBLCLK
			; Only if editable
			If $aGLVEx_Data[$iLV_Index][7] <> "" Then
				; Set values for active ListView
				$aGLVEx_Data[0][1] = $iLV_Index
				$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
				; Copy array for manipulation
				$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
				; Set editing flag
				$fGLVEx_EditClickFlag = True
			EndIf

		Case -5  ; $NM_RCLICK
			; Set active ListView
			$aGLVEx_Data[0][1] = $iLV_Index
			; Get position of right click within Listview
			$aGLVEx_Data[0][10] = DllStructGetData($tStruct, 4)
			$aGLVEx_Data[0][11] = DllStructGetData($tStruct, 5)
			; Redraw last selected row
			_GUICtrlListView_RedrawItems($hLV, $aGLVEx_Data[0][17], $aGLVEx_Data[0][17])
			; Set new active cell
			$aGLVEx_Data[0][17] = DllStructGetData($tStruct, 4)
			$aGLVEx_Data[0][18] = DllStructGetData($tStruct, 5)
			$aGLVEx_Data[$iLV_Index][20] = $aGLVEx_Data[0][17]
			$aGLVEx_Data[$iLV_Index][21] = $aGLVEx_Data[0][18]
			; Redraw newly selected row
			_GUICtrlListView_RedrawItems($hLV, $aGLVEx_Data[0][17], $aGLVEx_Data[0][17])

		Case $LVN_KEYDOWN
			; Determine which key pressed
			Local $tKey = DllStructCreate($tagNMHDR & ";WORD KeyCode", $lParam)
			; Store key value
			$aGLVEx_Data[0][16] = DllStructGetData($tKey, "KeyCode")
			; Remove selected state if single cell selection
			If $aGLVEx_Data[$iLV_Index][22] Then _GUICtrlListView_SetItemSelected($hLV, $aGLVEx_Data[0][17], False)
			; Act on left/right keys
			Switch $aGLVEx_Data[0][16]
				Case 37 ; Left
					; Adjust column and prevent overrun
					If $aGLVEx_Data[0][18] > 0 Then $aGLVEx_Data[0][18] -= 1
					; Store new column
					$aGLVEx_Data[$iLV_Index][21] = $aGLVEx_Data[0][18]
					; Redraw row
					_GUICtrlListView_RedrawItems($hLV, $aGLVEx_Data[0][17], $aGLVEx_Data[0][17])
				Case 39 ; Right
					If $aGLVEx_Data[0][18] < _GUICtrlListView_GetColumnCount($hLV) - 1 Then $aGLVEx_Data[0][18] += 1
					$aGLVEx_Data[$iLV_Index][21] = $aGLVEx_Data[0][18]
					_GUICtrlListView_RedrawItems($hLV, $aGLVEx_Data[0][17], $aGLVEx_Data[0][17])
			EndSwitch

		Case $LVN_ITEMCHANGED
			; Remove selection state if single cell selection
			If $aGLVEx_Data[$iLV_Index][22] Then _GUICtrlListView_SetItemSelected($hLV, $iItem, False)
			; If a key was used to change selection need to reset active row
			If $aGLVEx_Data[0][16] <> 0 Then
				; Check key used
				Switch $aGLVEx_Data[0][16]
					Case 38 ; Up
						If $aGLVEx_Data[0][17] > 0 Then $aGLVEx_Data[0][17] -= 1
						$aGLVEx_Data[$iLV_Index][20] = $aGLVEx_Data[0][17]
					Case 40 ; Down
						If $aGLVEx_Data[0][17] < _GUICtrlListView_GetItemCount($hLV) - 1 Then $aGLVEx_Data[0][17] += 1
						$aGLVEx_Data[$iLV_Index][20] = $aGLVEx_Data[0][17]
				EndSwitch
				; Clear key flag
				$aGLVEx_Data[0][16] = 0
			Else
				; If mouse button pressed
				If _WinAPI_GetAsyncKeyState(0x01) Then
					; Determine position of mouse within ListView
					Local $aMPos = MouseGetPos()
					Local $tPoint = DllStructCreate("int X;int Y")
					DllStructSetData($tPoint, "X", $aMPos[0])
					DllStructSetData($tPoint, "Y", $aMPos[1])
					_WinAPI_ScreenToClient($hLV, $tPoint)
					Local $aCurPos[2] = [DllStructGetData($tPoint, "X"), DllStructGetData($tPoint, "Y")]
					; Check for cell under mouse
					Local $aHitTest = _GUICtrlListView_SubItemHitTest($hLV, $aCurPos[0], $aCurPos[1])
					; If click on valid cell
					If $aHitTest[0] > -1 And $aHitTest[1] > -1 And $aHitTest[0] = $iItem Then
						; Redraw previously selected row
						If $aGLVEx_Data[0][17] <> $iItem Then _GUICtrlListView_RedrawItems($hLV, $aGLVEx_Data[0][17], $aGLVEx_Data[0][17])
						; Set new row and column
						$aGLVEx_Data[0][17] = $aHitTest[0]
						$aGLVEx_Data[0][18] = $aHitTest[1]
						$aGLVEx_Data[$iLV_Index][20] = $aGLVEx_Data[0][17]
						$aGLVEx_Data[$iLV_Index][21] = $aGLVEx_Data[0][18]
						; Redraw newly selected row
						_GUICtrlListView_RedrawItems($hLV, $iItem, $iItem)
					EndIf
				EndIf
			EndIf

		Case -12 ; $NM_CUSTOMDRAW

			Local Static $aDefCols = $aGLVEx_DefColours

			; Prevent redraw if still changing ListView arrays
			If $aGLVEx_Data[0][12] Then Return
			; Check if ListView to be redrawn has changed
			If $aGLVEx_Data[0][14] <> DllStructGetData($tStruct, 1) Then
				; Store new handle
				$aGLVEx_Data[0][14] = DllStructGetData($tStruct, 1)
				If $aGLVEx_Data[$iLV_Index][19] Then
					; Copy new colour array
					$aGLVEx_Data[0][13] = $aGLVEx_Data[$iLV_Index][18]
					; Set new default colours
					$aDefCols = $aGLVEx_Data[$iLV_Index][23]
				EndIf
			EndIf
			; If colour or single cell selection
			If $aGLVEx_Data[$iLV_Index][19] Or $aGLVEx_Data[$iLV_Index][22] Then
				Local $tNMLVCUSTOMDRAW = DllStructCreate($tagNMLVCUSTOMDRAW, $lParam)
				Local $dwDrawStage = DllStructGetData($tNMLVCUSTOMDRAW, "dwDrawStage")
				Switch $dwDrawStage ; Holds a value that specifies the drawing stage
					Case 1 ; $CDDS_PREPAINT
						; Before the paint cycle begins
						Return 32 ; $CDRF_NOTIFYITEMDRAW - Notify the parent window of any item-related drawing operations

					Case 65537 ; $CDDS_ITEMPREPAINT
						; Before painting an item
						Return 32 ; $CDRF_NOTIFYSUBITEMDRAW - Notify the parent window of any subitem-related drawing operations

					Case 196609 ; BitOR($CDDS_ITEMPREPAINT, $CDDS_SUBITEM)
						; Before painting a subitem
						$iItem = DllStructGetData($tNMLVCUSTOMDRAW, "dwItemSpec")        ; Row index
						Local $iSubItem = DllStructGetData($tNMLVCUSTOMDRAW, "iSubItem") ; Column index
						; Set default colours
						Local $iTextColour = $aDefCols[0]
						Local $iBackColour = $aDefCols[1]
						; If colour enabled
						If $aGLVEx_Data[$iLV_Index][19] Then
							; Check for user colours
							If StringInStr(($aGLVEx_Data[0][13])[$iItem + 1][$iSubItem], ";") Then
								; Get required user colours
								Local $aSplitColour = StringSplit(($aGLVEx_Data[0][13])[$iItem + 1][$iSubItem], ";")
								If $aSplitColour[1] Then $iTextColour = $aSplitColour[1]
								If $aSplitColour[2] Then $iBackColour = $aSplitColour[2]
							EndIf
						EndIf
						If $aGLVEx_Data[$iLV_Index][22] Then
							; For selected item
							If $iItem = $aGLVEx_Data[0][17] And $iSubItem = $aGLVEx_Data[0][18] Then
								; Set selected item colours
								$iTextColour = $aDefCols[2]
								$iBackColour = $aDefCols[3]
							EndIf
						EndIf
						; Set required colours
						DllStructSetData($tNMLVCUSTOMDRAW, "ClrText", $iTextColour)
						DllStructSetData($tNMLVCUSTOMDRAW, "ClrTextBk", $iBackColour)
						Return 2 ; $CDRF_NEWFONT must be returned after changing font or colors
				EndSwitch
			EndIf

	EndSwitch

EndFunc   ;==>_GUIListViewEx_WM_NOTIFY_Handler

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_WM_MOUSEMOVE_Handler
; Description ...: Windows message handler for WM_NOTIFY
; Syntax.........: _GUIListViewEx_WM_MOUSEMOVE_Handler()
; Requirement(s).: v3.3.10 +
; Return values .: None
; Author ........: Melba23
; Modified ......:
; Remarks .......: If a WM_MOUSEMOVE handler already registered, then call this function from within that handler
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_WM_MOUSEMOVE_Handler($hWnd, $iMsg, $wParam, $lParam)

	#forceref $hWnd, $iMsg, $wParam

	Local $iVertScroll

	If $iGLVEx_Dragging = 0 Then
		Return "GUI_RUNDEFMSG"
	EndIf

	; Get item depth to make sure scroll is enough to get next item into view
	If $aGLVEx_Data[$aGLVEx_Data[0][1]][10] Then
		$iVertScroll = $aGLVEx_Data[$aGLVEx_Data[0][1]][10]
	Else
		Local $aRect = _GUICtrlListView_GetItemRect($hGLVEx_SrcHandle, 0)
		$iVertScroll = $aRect[3] - $aRect[1]
	EndIf

	; Get window under mouse cursor
	Local $hCurrent_Wnd = __GUIListViewEx_GetCursorWnd()

	; If not over the current tgt ListView
	If $hCurrent_Wnd <> $hGLVEx_TgtHandle Then

		; Check if external drag permitted
		If BitAND($aGLVEx_Data[$iGLVEx_TgtIndex][12], 1) Then
			Return "GUI_RUNDEFMSG"
		EndIf

		; Is it another initiated ListView
		For $i = 1 To $aGLVEx_Data[0][0]
			If $aGLVEx_Data[$i][0] = $hCurrent_Wnd Then

				; Check if external drop permitted
				If BitAND($aGLVEx_Data[$i][12], 2) Then
					Return "GUI_RUNDEFMSG"
				EndIf

				; Check compatibility between Src and Tgt ListViews
				; Check neither has checkboxes
				If $aGLVEx_Data[$iGLVEx_SrcIndex][6] + $aGLVEx_Data[$i][6] = 0 Then
					; Check same column count
					If _GUICtrlListView_GetColumnCount($hGLVEx_SrcHandle) = _GUICtrlListView_GetColumnCount($hCurrent_Wnd) Then
						; Compatible so switch to new target
						; Clear insert mark in current tgt ListView
						_GUICtrlListView_SetInsertMark($hGLVEx_TgtHandle, -1, True)
						; Set data for new tgt ListView
						$hGLVEx_TgtHandle = $hCurrent_Wnd
						$cGLVEx_TgtID = $aGLVEx_Data[$i][1]
						$iGLVEx_TgtIndex = $i
						$aGLVEx_TgtArray = $aGLVEx_Data[$i][2]
						$aGLVEx_Data[0][3] = $aGLVEx_Data[$i][10] ; Set item depth
						; No point in looping further
						ExitLoop
					EndIf
				EndIf
			EndIf
		Next
	EndIf

	; Get current mouse Y coord
	Local $iCurr_Y = BitShift($lParam, 16)

	; Set insert mark to correct side of items depending on sense of movement when cursor within range
	If $iGLVEx_InsertIndex <> -1 Then
		If $iGLVEx_LastY = $iCurr_Y Then
			Return "GUI_RUNDEFMSG"
		ElseIf $iGLVEx_LastY > $iCurr_Y Then
			$fGLVEx_BarUnder = False
			_GUICtrlListView_SetInsertMark($hGLVEx_TgtHandle, $iGLVEx_InsertIndex, False)
		Else
			$fGLVEx_BarUnder = True
			_GUICtrlListView_SetInsertMark($hGLVEx_TgtHandle, $iGLVEx_InsertIndex, True)
		EndIf
	EndIf

	; Store current Y coord
	$iGLVEx_LastY = $iCurr_Y

	; Get ListView item under mouse
	Local $aLVHit = _GUICtrlListView_HitTest($hGLVEx_TgtHandle)
	Local $iCurr_Index = $aLVHit[0]

	; If mouse is above or below ListView then scroll ListView
	If $iCurr_Index = -1 Then
		If $fGLVEx_BarUnder Then
			_GUICtrlListView_Scroll($hGLVEx_TgtHandle, 0, $iVertScroll)
		Else
			_GUICtrlListView_Scroll($hGLVEx_TgtHandle, 0, -$iVertScroll)
		EndIf
		Sleep(10)
	EndIf

	; Check if over same item
	If $iGLVEx_InsertIndex <> $iCurr_Index Then
		; Show insert mark on current item
		_GUICtrlListView_SetInsertMark($hGLVEx_TgtHandle, $iCurr_Index, $fGLVEx_BarUnder)
		; Store current item
		$iGLVEx_InsertIndex = $iCurr_Index
	EndIf

	Return "GUI_RUNDEFMSG"

EndFunc   ;==>_GUIListViewEx_WM_MOUSEMOVE_Handler

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_WM_LBUTTONUP_Handler
; Description ...: Windows message handler for WM_NOTIFY
; Syntax.........: _GUIListViewEx_WM_LBUTTONUP_Handler()
; Requirement(s).: v3.3.10 +
; Return values .: None
; Author ........: Melba23
; Modified ......:
; Remarks .......: If a WM_LBUTTONUP handler already registered, then call this function from within that handler
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_WM_LBUTTONUP_Handler($hWnd, $iMsg, $wParam, $lParam)

	#forceref $hWnd, $iMsg, $wParam, $lParam

	If Not $iGLVEx_Dragging Then
		Return "GUI_RUNDEFMSG"
	EndIf

	; Get item count
	Local $iMultipleItems = $iGLVEx_Dragging - 1

	; Reset flag
	$iGLVEx_Dragging = 0

	; Check for valid insert index (not set if dropping into empty space)
	If $iGLVEx_InsertIndex = -1 Then
		; Set to bottom
		$iGLVEx_InsertIndex = _GUICtrlListView_GetItemCount($hGLVEx_TgtHandle) + 1
	EndIf

	; Get window under mouse cursor
	Local $hCurrent_Wnd = __GUIListViewEx_GetCursorWnd()

	; Abandon if mouse not within tgt ListView
	If $hCurrent_Wnd <> $hGLVEx_TgtHandle Then
		; Clear insert mark
		_GUICtrlListView_SetInsertMark($hGLVEx_TgtHandle, -1, True)
		; Reset highlight to original items in Src ListView
		For $i = 0 To $iMultipleItems
			__GUIListViewEx_HighLight($hGLVEx_TgtHandle, $cGLVEx_TgtID, $iGLVEx_DraggedIndex + $i)
		Next
		; Delete copied arrays
		$aGLVEx_SrcArray = 0
		$aGLVEx_TgtArray = 0
		Return
	EndIf

	; Clear insert mark
	_GUICtrlListView_SetInsertMark($hGLVEx_TgtHandle, -1, True)

	; Clear drag image
	If $hGLVEx_DraggedImage Then
		_GUIImageList_DragLeave($hGLVEx_SrcHandle)
		_GUIImageList_EndDrag()
		_GUIImageList_Destroy($hGLVEx_DraggedImage)
		$hGLVEx_DraggedImage = 0
	EndIf

	; Dropping within same ListView
	If $hGLVEx_SrcHandle = $hGLVEx_TgtHandle Then
		; Determine position to insert
		If $fGLVEx_BarUnder Then
			If $iGLVEx_DraggedIndex > $iGLVEx_InsertIndex Then $iGLVEx_InsertIndex += 1
		Else
			If $iGLVEx_DraggedIndex < $iGLVEx_InsertIndex Then $iGLVEx_InsertIndex -= 1
		EndIf

		; Check not dropping on dragged item(s)
		Switch $iGLVEx_InsertIndex
			Case $iGLVEx_DraggedIndex To $iGLVEx_DraggedIndex + $iMultipleItems
				; Reset highlight to original items
				For $i = 0 To $iMultipleItems
					__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, $iGLVEx_DraggedIndex + $i)
				Next
				; Delete copied arrays
				$aGLVEx_SrcArray = 0
				$aGLVEx_TgtArray = 0
				Return
		EndSwitch

		; Create Local array for checkboxes (if no checkboxes makes no difference)
		Local $aCheck_Array[UBound($aGLVEx_SrcArray)]
		For $i = 1 To UBound($aCheck_Array) - 1
			$aCheck_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $i - 1)
		Next

		; Create Local array for dragged items checkbox state
		Local $aCheckDrag_Array[$iMultipleItems + 1]

		; Create Local colour array
		$aGLVEx_SrcColArray = $aGLVEx_Data[$iGLVEx_SrcIndex][18]
		Local $bUserCol = ((IsArray($aGLVEx_SrcColArray)) ? (True) : (False))

		; Amend arrays
		; Get data from dragged element(s)
		If $iMultipleItems Then
			; Multiple dragged elements
			Local $aInsertData[$iMultipleItems + 1]
			Local $aColData[$iMultipleItems + 1]
			Local $aItemData[UBound($aGLVEx_SrcArray, 2)]
			For $i = 0 To $iMultipleItems
				; Data
				For $j = 0 To UBound($aGLVEx_SrcArray, 2) - 1
					$aItemData[$j] = $aGLVEx_SrcArray[$iGLVEx_DraggedIndex + 1 + $i][$j]
				Next
				$aInsertData[$i] = $aItemData
				; Colours if required
				If $bUserCol Then
					For $j = 0 To UBound($aGLVEx_SrcColArray, 2) - 1
						$aItemData[$j] = $aGLVEx_SrcColArray[$iGLVEx_DraggedIndex + 1 + $i][$j]
					Next
					$aColData[$i] = $aItemData
				EndIf
				; Checkboxes
				$aCheckDrag_Array[$i] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $iGLVEx_DraggedIndex + $i)
			Next
		Else
			; Single dragged element
			Local $aInsertData[1]
			Local $aColData[1]
			Local $aItemData[UBound($aGLVEx_SrcArray, 2)]
			For $i = 0 To UBound($aGLVEx_SrcArray, 2) - 1
				$aItemData[$i] = $aGLVEx_SrcArray[$iGLVEx_DraggedIndex + 1][$i]
			Next
			$aInsertData[0] = $aItemData
			If $bUserCol Then
				For $i = 0 To UBound($aGLVEx_SrcColArray, 2) - 1
					$aItemData[$i] = $aGLVEx_SrcColArray[$iGLVEx_DraggedIndex + 1][$i]
				Next
				$aColData[0] = $aItemData
			EndIf
			$aCheckDrag_Array[0] = _GUICtrlListView_GetItemChecked($hGLVEx_SrcHandle, $iGLVEx_DraggedIndex)
		EndIf

		; Set no redraw flag - prevents problems while colour arrays are updated
		$aGLVEx_Data[0][12] = True

		; Delete dragged element(s) from arrays
		For $i = 0 To $iMultipleItems
			__GUIListViewEx_Array_Delete($aGLVEx_SrcArray, $iGLVEx_DraggedIndex + 1)
			__GUIListViewEx_Array_Delete($aCheck_Array, $iGLVEx_DraggedIndex + 1)
			If $bUserCol Then __GUIListViewEx_Array_Delete($aGLVEx_SrcColArray, $iGLVEx_DraggedIndex + 1)
		Next

		; Amend insert positon for multiple items deleted above
		If $iGLVEx_DraggedIndex < $iGLVEx_InsertIndex Then
			$iGLVEx_InsertIndex -= $iMultipleItems
		EndIf

		; Re-insert dragged element(s) into array
		For $i = $iMultipleItems To 0 Step -1
			__GUIListViewEx_Array_Insert($aGLVEx_SrcArray, $iGLVEx_InsertIndex + 1, $aInsertData[$i])
			__GUIListViewEx_Array_Insert($aCheck_Array, $iGLVEx_InsertIndex + 1, $aCheckDrag_Array[$i])
			If $bUserCol Then __GUIListViewEx_Array_Insert($aGLVEx_SrcColArray, $iGLVEx_InsertIndex + 1, $aColData[$i], False, False)
		Next

		; Rewrite ListView to match array
		__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aCheck_Array, $iGLVEx_SrcIndex)

		; Set highlight to inserted item(s)
		For $i = 0 To $iMultipleItems
			__GUIListViewEx_HighLight($hGLVEx_SrcHandle, $cGLVEx_SrcID, $iGLVEx_InsertIndex + $i)
		Next

		; Store amended array
		$aGLVEx_Data[$aGLVEx_Data[0][1]][2] = $aGLVEx_SrcArray
		$aGLVEx_Data[$iGLVEx_SrcIndex][18] = $aGLVEx_SrcColArray

	Else ; Dropping in another ListView

		; Determine position to insert
		If $fGLVEx_BarUnder Then
			$iGLVEx_InsertIndex += 1
		EndIf

		; Colour arrays for manipulation
		$aGLVEx_SrcColArray = $aGLVEx_Data[$iGLVEx_SrcIndex][18]
		Local $bUserColSrc = ((IsArray($aGLVEx_SrcColArray)) ? (True) : (False))
		$aGLVEx_TgtColArray = $aGLVEx_Data[$iGLVEx_TgtIndex][18]
		Local $bUserColTgt = ((IsArray($aGLVEx_TgtColArray)) ? (True) : (False))

		; Amend arrays
		; Get data from dragged element(s)
		If $iMultipleItems Then
			; Multiple dragged elements
			Local $aInsertData[$iMultipleItems + 1]
			Local $aColData[$iMultipleItems + 1]
			Local $aItemData[UBound($aGLVEx_SrcArray, 2)]
			For $i = 0 To $iMultipleItems
				; Data
				For $j = 0 To UBound($aGLVEx_SrcArray, 2) - 1
					$aItemData[$j] = $aGLVEx_SrcArray[$iGLVEx_DraggedIndex + 1 + $i][$j]
				Next
				$aInsertData[$i] = $aItemData
				; Colours if required
				If $bUserColTgt Then
					For $j = 0 To UBound($aGLVEx_SrcArray, 2) - 1
						If $bUserColSrc Then
							$aItemData[$j] = $aGLVEx_SrcColArray[$iGLVEx_DraggedIndex + 1 + $i][$j]
						Else
							$aItemData[$j] = ";"
						EndIf
					Next
					$aColData[$i] = $aItemData
				EndIf
			Next
		Else
			; Single dragged element
			Local $aInsertData[1]
			Local $aColData[1]
			Local $aItemData[UBound($aGLVEx_SrcArray, 2)]
			For $i = 0 To UBound($aGLVEx_SrcArray, 2) - 1
				$aItemData[$i] = $aGLVEx_SrcArray[$iGLVEx_DraggedIndex + 1][$i]
			Next
			$aInsertData[0] = $aItemData
			If $bUserColTgt Then
				For $i = 0 To UBound($aGLVEx_SrcArray, 2) - 1
					If $bUserColSrc Then
						$aItemData[$i] = $aGLVEx_SrcColArray[$iGLVEx_DraggedIndex + 1][$i]
					Else
						$aItemData[$i] = ";"
					EndIf
				Next
				$aColData[0] = $aItemData
			EndIf
		EndIf

		; Set no redraw flag - prevents problems while colour arrays are updated
		$aGLVEx_Data[0][12] = True

		; Delete dragged element(s) from source array
		If Not BitAND($aGLVEx_Data[$iGLVEx_SrcIndex][12], 4) Then
			For $i = 0 To $iMultipleItems
				__GUIListViewEx_Array_Delete($aGLVEx_SrcArray, $iGLVEx_DraggedIndex + 1)
				If $bUserColSrc Then __GUIListViewEx_Array_Delete($aGLVEx_SrcColArray, $iGLVEx_DraggedIndex + 1)
			Next
		EndIf
		; Check if insert index is valid
		If $iGLVEx_InsertIndex < 0 Then
			$iGLVEx_InsertIndex = _GUICtrlListView_GetItemCount($hGLVEx_TgtHandle)
		EndIf

		; Insert dragged element(s) into target array
		For $i = $iMultipleItems To 0 Step -1
			__GUIListViewEx_Array_Insert($aGLVEx_TgtArray, $iGLVEx_InsertIndex + 1, $aInsertData[$i])
			If $bUserColTgt Then __GUIListViewEx_Array_Insert($aGLVEx_TgtColArray, $iGLVEx_InsertIndex + 1, $aColData[$i], False, False)
		Next

		; Rewrite ListViews to match arrays
		__GUIListViewEx_ReWriteLV($hGLVEx_SrcHandle, $aGLVEx_SrcArray, $aGLVEx_SrcArray, $iGLVEx_SrcIndex, False)
		__GUIListViewEx_ReWriteLV($hGLVEx_TgtHandle, $aGLVEx_TgtArray, $aGLVEx_TgtArray, $iGLVEx_TgtIndex, False)
		; Note no checkbox array needed ListViews with them are not interdraggable, so repass normal array and set final parameter

		; Set highlight to inserted item(s)
		_GUIListViewEx_SetActive($iGLVEx_TgtIndex)
		For $i = 0 To $iMultipleItems
			__GUIListViewEx_HighLight($hGLVEx_TgtHandle, $cGLVEx_TgtID, $iGLVEx_InsertIndex + $i)
		Next

		; Store amended arrays
		$aGLVEx_Data[$iGLVEx_SrcIndex][2] = $aGLVEx_SrcArray
		$aGLVEx_Data[$iGLVEx_SrcIndex][18] = $aGLVEx_SrcColArray
		$aGLVEx_Data[$iGLVEx_TgtIndex][2] = $aGLVEx_TgtArray
		$aGLVEx_Data[$iGLVEx_TgtIndex][18] = $aGLVEx_TgtColArray

	EndIf

	; Delete copied arrays
	$aGLVEx_SrcArray = 0
	$aGLVEx_TgtArray = 0
	$aGLVEx_SrcColArray = 0
	$aGLVEx_TgtColArray = 0

	; Set DragEvent details
	$sGLVEx_DragEvent = $iGLVEx_SrcIndex & ":" & $iGLVEx_TgtIndex

	; Clear no redraw flag
	$aGLVEx_Data[0][12] = False

	; If colour used or single cell selection
	If $aGLVEx_Data[$iGLVEx_SrcIndex][19] Then
		; Force reload of redraw colour array
		$aGLVEx_Data[0][14] = 0
		; Redraw ListViews
		_WinAPI_RedrawWindow($hGLVEx_SrcHandle)
		If $hGLVEx_TgtHandle <> $hGLVEx_SrcHandle And $aGLVEx_Data[$iGLVEx_TgtIndex][19] Then
			_WinAPI_RedrawWindow($hGLVEx_TgtHandle)
		EndIf
	EndIf

EndFunc   ;==>_GUIListViewEx_WM_LBUTTONUP_Handler

; #FUNCTION# =========================================================================================================
; Name...........: _GUIListViewEx_WM_SYSCOMMAND_Handler
; Description ...: Windows message handler for WM_SYSCOMMAND
; Syntax.........: _GUIListViewEx_WM_SYSCOMMAND_Handler()
; Requirement(s).: v3.3.10 +
; Return values .: None
; Author ........: Melba23
; Modified ......:
; Remarks .......: If a WM_SYSCOMMAND handler already registered, then call this function from within that handler
; Example........: Yes
;=====================================================================================================================
Func _GUIListViewEx_WM_SYSCOMMAND_Handler($hWnd, $iMsg, $wParam, $lParam)

	#forceref $hWnd, $iMsg, $lParam, $lParam

	If $wParam = 0xF060 Then ; $SC_CLOSE
		$aGLVEx_Data[0][9] = True
	EndIf

EndFunc   ;==>_GUIListViewEx_WM_SYSCOMMAND_Handler

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_ExpandCols
; Description ...: Expands column ranges to list each column separately
; Author ........: Melba23
; Modified ......:
; ===============================================================================================================================
Func __GUIListViewEx_ExpandCols($sCols)

	Local $iNumber

	; Strip any whitespace
	$sCols = StringStripWS($sCols, 8)
	; Check if "all cols"
	If $sCols <> "*" Then
		; Check if ranges to be expanded
		If StringInStr($sCols, "-") Then
			; Parse string
			Local $aSplit_1, $aSplit_2
			; Split on ";"
			$aSplit_1 = StringSplit($sCols, ";")
			$sCols = ""
			; Check each element
			For $i = 1 To $aSplit_1[0]
				; Try and split on "-"
				$aSplit_2 = StringSplit($aSplit_1[$i], "-")
				; Add first value in all cases
				$sCols &= $aSplit_2[1] & ";"
				; If a valid range and limit values are in ascending order
				If ($aSplit_2[0]) > 1 And (Number($aSplit_2[2]) > Number($aSplit_2[1])) Then
					; Add the full range
					$iNumber = $aSplit_2[1]
					Do
						$iNumber += 1
						$sCols &= $iNumber & ";"
					Until $iNumber = $aSplit_2[2]
				EndIf
			Next
		EndIf
	EndIf
	; Return expanded string
	Return $sCols

EndFunc   ;==>__GUIListViewEx_ExpandCols

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_HighLight
; Description ...: Highlights first item and ensures visible, second item has highlight removed
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_HighLight($hLVHandle, $cLV_CID, $iIndexA, $iIndexB = -1)

	; Check if Native or UDF and set focus
	If $cLV_CID Then
		GUICtrlSetState($cLV_CID, 256) ; $GUI_FOCUS
	Else
		_WinAPI_SetFocus($hLVHandle)
	EndIf
	; Cancel highlight on other item - needed for multisel listviews
	If $iIndexB <> -1 Then _GUICtrlListView_SetItemSelected($hLVHandle, $iIndexB, False)
	; Set highlight to inserted item and ensure in view
	_GUICtrlListView_SetItemState($hLVHandle, $iIndexA, $LVIS_SELECTED, $LVIS_SELECTED)
	_GUICtrlListView_EnsureVisible($hLVHandle, $iIndexA)

EndFunc   ;==>__GUIListViewEx_HighLight

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_GetLVFont
; Description ...: Gets font details for ListView to be edited
; Author ........: Based on _GUICtrlGetFont by KaFu & Prog@ndy
; Modified ......: Melba23
; ===============================================================================================================================
Func __GUIListViewEx_GetLVFont($hLVHandle)

	Local $iError = 0, $aFontDetails[2] = [Default, Default]

	; Check handle
	If Not IsHWnd($hLVHandle) Then
		$hLVHandle = GUICtrlGetHandle($hLVHandle)
	EndIf
	If Not IsHWnd($hLVHandle) Then
		$iError = 1
	Else
		Local $hFONT = _SendMessage($hLVHandle, 0x0031) ; WM_GETFONT
		If Not $hFONT Then
			$iError = 2
		Else
			Local $hDC = _WinAPI_GetDC($hLVHandle)
			Local $hObjOrg = _WinAPI_SelectObject($hDC, $hFONT)
			Local $tFONT = DllStructCreate($tagLOGFONT)
			Local $aRet = DllCall('gdi32.dll', 'int', 'GetObjectW', 'ptr', $hFONT, 'int', DllStructGetSize($tFONT), 'ptr', DllStructGetPtr($tFONT))
			If @error Or $aRet[0] = 0 Then
				$iError = 3
			Else
				; Get font size
				$aFontDetails[0] = Round((-1 * DllStructGetData($tFONT, 'Height')) * 72 / _WinAPI_GetDeviceCaps($hDC, 90), 1) ; $LOGPIXELSY = 90 => DPI aware
				; Now look for font name
				$aRet = DllCall("gdi32.dll", "int", "GetTextFaceW", "handle", $hDC, "int", 0, "ptr", 0)
				Local $iCount = $aRet[0]
				Local $tBuffer = DllStructCreate("wchar[" & $iCount & "]")
				Local $pBuffer = DllStructGetPtr($tBuffer)
				$aRet = DllCall("Gdi32.dll", "int", "GetTextFaceW", "handle", $hDC, "int", $iCount, "ptr", $pBuffer)
				If @error Then
					$iError = 4
				Else
					$aFontDetails[1] = DllStructGetData($tBuffer, 1) ; FontFacename
				EndIf
			EndIf
			_WinAPI_SelectObject($hDC, $hObjOrg)
			_WinAPI_ReleaseDC($hLVHandle, $hDC)
		EndIf
	EndIf

	Return SetError($iError, 0, $aFontDetails)

EndFunc   ;==>__GUIListViewEx_GetLVFont

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_EditProcess
; Description ...: Runs ListView editing process
; Author ........: Melba23
; Modified ......:
; ===============================================================================================================================
Func __GUIListViewEx_EditProcess($iLV_Index, $aLocation, $sCols, $iDelta_X, $iDelta_Y, $iEditMode)

	Local $hTemp_Combo = 9999, $hTemp_Edit = 9999, $hTemp_List = 9999, $iKey_Code, $iCombo_State, $aSplit, $sInsert, $fClick_Move = False, $fCursor_Move = True

	; Unselect item
	_GUICtrlListView_SetItemSelected($hGLVEx_SrcHandle, $aLocation[0], False)

	; Declare return array - note second dimension [3] but only [2] returned if successful
	Local $aEdited[1][4] = [[0]] ; [[Number of edited items, blank, blank, blank]]

	; Load active ListView details
	$hGLVEx_SrcHandle = $aGLVEx_Data[$iLV_Index][0]
	$cGLVEx_SrcID = $aGLVEx_Data[$iLV_Index][1]

	; Store handle of ListView concerned
	$hGLVEx_Editing = $hGLVEx_SrcHandle
	Local $cEditingID = $cGLVEx_SrcID

	; Valid keys to action
	; ENTER, ESC
	Local $aKeys_Combo[2] = [0x0D, 0x1B]
	; TAB, ENTER, ESC, up/down arrows
	Local $aKeys_Edit[5] = [0x09, 0x0D, 0x1B, 0x26, 0x28]
	; Left/right arrows
	Local $aKeys_LR[2] = [0x25, 0x27]

	; Set Reset-on-ESC mode
	Local $fReset_Edits = False
	If $iEditMode < 0 Then
		$fReset_Edits = True
		$iEditMode = Abs($iEditMode)
	EndIf

	; Set row/col edit mode - default single edit
	Local $iEditRow = 0, $iEditCol = 0
	If $iEditMode Then
		; Separate axis settings
		$aSplit = StringSplit($iEditMode, "")
		$iEditRow = $aSplit[1]
		$iEditCol = $aSplit[2]
	EndIf

	; Check if edit to move on click
	If StringInStr($aGLVEx_Data[$iLV_Index][7], ";#") Then
		$fClick_Move = True
	EndIf

	; Check if cursor to move in edit
	If $aGLVEx_Data[$iLV_Index][9] Then
		$fCursor_Move = False
	EndIf

	; Check if combo required
	Local $fCombo = False
	Local $fRead_Only = False
	If IsArray($aGLVEx_Data[$iLV_Index][11]) Then
		; Extract combo data for ListView
		Local $aComboData_Array = $aGLVEx_Data[$iLV_Index][11]
		; If combo data set
		If IsArray($aComboData_Array) Then
			; Extract data for this column
			Local $sCombo_Data = $aComboData_Array[$aLocation[1]]
			; If data available then set combo flag - use default edit if not
			If $sCombo_Data Then
				$fCombo = True
				If StringLeft($sCombo_Data, 1) = "#" Then
					$fRead_Only = True
					$sCombo_Data = StringTrimLeft($sCombo_Data, 1)
				EndIf
			EndIf
		EndIf
	EndIf

	Local $tLVPos = DllStructCreate("struct;long X;long Y;endstruct")
	; Get position of ListView within GUI client area
	__GUIListViewEx_GetLVCoords($hGLVEx_Editing, $tLVPos)
	; Get ListView client area to allow for scrollbars
	Local $aLVClient = WinGetClientSize($hGLVEx_Editing)
	; Get ListView font details
	Local $aLV_FontDetails = __GUIListViewEx_GetLVFont($hGLVEx_Editing)
	; Disable ListView
	WinSetState($hGLVEx_Editing, "", @SW_DISABLE)

	; Load edit width data array
	Local $aWidth = ($aGLVEx_Data[$iLV_Index][14])
	; Create dummy array if required
	If Not IsArray($aWidth) Then Local $aWidth[_GUICtrlListView_GetColumnCount($aGLVEx_Data[$iLV_Index][0])]

	; Define variables
	Local $iWidth, $fExitLoop, $tMouseClick = DllStructCreate($tagPOINT)
	; Set default mousecoordmode
	Local $iOldMouseOpt = Opt("MouseCoordMode", 1)

	; Start the edit loop
	While 1
		; Read current text of clicked item
		Local $sItemOrgText = _GUICtrlListView_GetItemText($hGLVEx_Editing, $aLocation[0], $aLocation[1])
		; Ensure item is visible and get required edit coords
		Local $aEdit_Pos = __GUIListViewEx_EditCoords($hGLVEx_Editing, $cEditingID, $aLocation, $tLVPos, $aLVClient[0] - 5, $iDelta_X, $iDelta_Y)
		; Get required edit width - force to number so non-digits are set to 0
		$iWidth = Number($aWidth[$aLocation[1]])
		; Alter edit/combo width if required value less than current width
		If $iWidth > $aEdit_Pos[2] Then
			If $fRead_Only Then ; Only adjust read-only combo edit width if value is negative
				If $iWidth < 0 Then
					$aEdit_Pos[2] = Abs($iWidth)
				EndIf
			Else ; Always adjust for if manual input accepted
				$aEdit_Pos[2] = Abs($iWidth)
			EndIf
		EndIf

		If $fCombo Then
			; Create temporary combo - get handle, set font size, give keyboard focus
			If $fRead_Only Then
				$cGLVEx_EditID = GUICtrlCreateCombo("", $aEdit_Pos[0], $aEdit_Pos[1], $aEdit_Pos[2], $aEdit_Pos[3], 0x00200043) ; $CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL, $WS_VSCROLL
			Else
				$cGLVEx_EditID = GUICtrlCreateCombo("", $aEdit_Pos[0], $aEdit_Pos[1], $aEdit_Pos[2], $aEdit_Pos[3], 0x00200042) ; $CBS_DROPDOWN, $CBS_AUTOHSCROLL, $WS_VSCROLL
			EndIf
			GUICtrlSetFont($cGLVEx_EditID, $aLV_FontDetails[0], Default, Default, $aLV_FontDetails[1])
			GUICtrlSetData($cGLVEx_EditID, $sCombo_Data, $sItemOrgText)
			Local $tInfo = DllStructCreate("dword Size;struct;long EditLeft;long EditTop;long EditRight;long EditBottom;endstruct;" & _
					"struct;long BtnLeft;long BtnTop;long BtnRight;long BtnBottom;endstruct;dword BtnState;hwnd hCombo;hwnd hEdit;hwnd hList")
			Local $iInfo = DllStructGetSize($tInfo)
			DllStructSetData($tInfo, "Size", $iInfo)
			Local $hCombo = GUICtrlGetHandle($cGLVEx_EditID)
			; Set readonly combo dropped width if required
			If $fRead_Only And Abs($iWidth) > $aEdit_Pos[2] Then
				_SendMessage($hCombo, 0x160, Abs($iWidth)) ; $CB_SETDROPPEDWIDTH
			EndIf
			; Get combo data
			_SendMessage($hCombo, 0x164, 0, $tInfo, 0, "wparam", "struct*") ; $CB_GETCOMBOBOXINFO
			$hTemp_Edit = DllStructGetData($tInfo, "hEdit")
			$hTemp_List = DllStructGetData($tInfo, "hList")
			$hTemp_Combo = DllStructGetData($tInfo, "hCombo")
			Local $aMPos = MouseGetPos()
			MouseMove($aMPos[0], $aMPos[1] + 20, 0)
			Sleep(10)
			MouseMove($aMPos[0], $aMPos[1], 0)
			_WinAPI_SetFocus($hTemp_Edit)

		Else
			; Create temporary edit - get handle, set font size, give keyboard focus and select all text
			$cGLVEx_EditID = GUICtrlCreateEdit($sItemOrgText, $aEdit_Pos[0], $aEdit_Pos[1], $aEdit_Pos[2], $aEdit_Pos[3], 128) ; $ES_AUTOHSCROLL
			$hTemp_Edit = GUICtrlGetHandle($cGLVEx_EditID)
			GUICtrlSetFont($cGLVEx_EditID, $aLV_FontDetails[0], Default, Default, $aLV_FontDetails[1])
			GUICtrlSetState($cGLVEx_EditID, 256) ; $GUI_FOCUS
			GUICtrlSendMsg($cGLVEx_EditID, 0xB1, 0, -1) ; $EM_SETSEL
		EndIf

		; Copy array for manipulation
		$aGLVEx_SrcArray = $aGLVEx_Data[$iLV_Index][2]
		; Clear key code flag
		$iKey_Code = 0
		; Clear combo down/up flag
		$iCombo_State = False
		; Wait for a key press or combo down/up
		While 1
			; Clear flag
			$fExitLoop = False

			; Check for SYSCOMMAND Close Event
			If $aGLVEx_Data[0][9] Then
				$fExitLoop = True
				$aGLVEx_Data[0][9] = False
			EndIf

			; Mouse pressed
			If _WinAPI_GetAsyncKeyState(0x01) Then
				; Look for clicks outside edit/combo control
				DllStructSetData($tMouseClick, "x", MouseGetPos(0))
				DllStructSetData($tMouseClick, "y", MouseGetPos(1))
				Switch _WinAPI_WindowFromPoint($tMouseClick)
					Case $hTemp_Combo, $hTemp_Edit, $hTemp_List
						; Over edit/combo
					Case Else
						$fExitLoop = True
				EndSwitch
				; Wait for mouse button release
				While _WinAPI_GetAsyncKeyState(0x01)
					Sleep(10)
				WEnd
			EndIf
			; Exit loop
			If $fExitLoop Then
				If Not $fCombo Then
					; If quitting edit then set appropriate behaviour
					If $fClick_Move Then
						$iKey_Code = 0x02 ; Confirm edit and end process
					Else
						$iKey_Code = 0x01 ; Abandon editing
					EndIf
				EndIf
				ExitLoop
			EndIf

			If $fCombo Then
				; Check for dropdown open and close
				Switch _SendMessage($hCombo, 0x157) ; $CB_GETDROPPEDSTATE
					Case 0
						; If opened and closed act as if Enter pressed
						If $iCombo_State = True Then
							$iKey_Code = 0x0D
							ExitLoop
						EndIf
					Case 1
						; Set flag if opened
						If Not $iCombo_State Then
							$iCombo_State = True
						EndIf
				EndSwitch
				; Check for valid key pressed
				For $i = 0 To 1
					If _WinAPI_GetAsyncKeyState($aKeys_Combo[$i]) Then
						; Set key pressed flag
						$iKey_Code = $aKeys_Combo[$i]
						ExitLoop 2
					EndIf
				Next
			Else
				; Check for valid key pressed
				For $i = 0 To 4
					If _WinAPI_GetAsyncKeyState($aKeys_Edit[$i]) Then
						; Set key pressed flag
						$iKey_Code = $aKeys_Edit[$i]
						ExitLoop 2
					EndIf
				Next
				; Check for left/right keys
				For $i = 0 To 1
					If _WinAPI_GetAsyncKeyState($aKeys_LR[$i]) Then
						; Check if left/right move edit
						If $fCursor_Move Then
							; Set key pressed flag
							$iKey_Code = $aKeys_LR[$i]
							ExitLoop 2
						Else
							; See if Ctrl pressed
							If _WinAPI_GetAsyncKeyState(0x11) Then
								; Set key pressed flag
								$iKey_Code = $aKeys_LR[$i]
								ExitLoop 2
							EndIf
						EndIf
					EndIf
				Next
			EndIf

			; Temp input lost focus
			If _WinAPI_GetFocus() <> $hTemp_Edit Then
				ExitLoop
			EndIf

			; Save CPU
			Sleep(10)
		WEnd
		; Check if edit to be confirmed
		Switch $iKey_Code
			Case 0x02, 0x09, 0x0D, 0x25, 0x26, 0x27, 0x28 ; Mouse (with Click=Move), TAB, ENTER, arrow keys
				; Read edit content
				Local $sItemNewText = GUICtrlRead($cGLVEx_EditID)

				; Check replacement required
				If $sItemNewText <> $sItemOrgText Then
					; Amend item text
					_GUICtrlListView_SetItemText($hGLVEx_Editing, $aLocation[0], $sItemNewText, $aLocation[1])
					; Amend array element
					$aGLVEx_SrcArray[$aLocation[0] + 1][$aLocation[1]] = $sItemNewText
					; Store amended array
					$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
					; Add item data to return array
					$aEdited[0][0] += 1
					ReDim $aEdited[$aEdited[0][0] + 1][4]
					; Save location & original content
					$aEdited[$aEdited[0][0]][0] = $aLocation[0]
					$aEdited[$aEdited[0][0]][1] = $aLocation[1]
					$aEdited[$aEdited[0][0]][2] = $sItemOrgText
					$aEdited[$aEdited[0][0]][3] = $sItemNewText
				EndIf
		EndSwitch
		; Delete temporary edit and set place holder
		GUICtrlDelete($cGLVEx_EditID)
		$cGLVEx_EditID = 9999
		; Reset user mousecoord mode
		Opt("MouseCoordMode", $iOldMouseOpt)
		; Check edit mode
		If $iEditMode = 0 Then ; Single edit
			; Exit edit process
			ExitLoop
		Else
			Switch $iKey_Code
				Case 0x00, 0x01, 0x02, 0x0D ; Edit lost focus, mouse button outside edit, ENTER pressed
					; Wait until key/button no longer pressed
					While _WinAPI_GetAsyncKeyState($iKey_Code)
						Sleep(10)
					WEnd
					; Exit Edit process
					ExitLoop

				Case 0x1B ; ESC pressed
					; Check Reset-on-ESC mode
					If $fReset_Edits Then
						; Reset previous confirmed edits starting with most recent
						For $i = $aEdited[0][0] To 1 Step -1
							_GUICtrlListView_SetItemText($hGLVEx_Editing, $aEdited[$i][0], $aEdited[$i][2], $aEdited[$i][1])
							Switch UBound($aGLVEx_SrcArray, 0)
								Case 1
									$aSplit = StringSplit($aGLVEx_SrcArray[$aEdited[$i][0] + 1], $sGLVEx_SepChar)
									$aSplit[$aEdited[$i][1] + 1] = $aEdited[$i][2]
									$sInsert = ""
									For $j = 1 To $aSplit[0]
										$sInsert &= $aSplit[$j] & $sGLVEx_SepChar
									Next
									$aGLVEx_SrcArray[$aEdited[$i][0] + 1] = StringTrimRight($sInsert, 1)

								Case 2
									$aGLVEx_SrcArray[$aEdited[$i][0] + 1][$aEdited[$i][1]] = $aEdited[$i][2]
							EndSwitch
						Next
						; Store amended array
						$aGLVEx_Data[$iLV_Index][2] = $aGLVEx_SrcArray
						; Empty return array as no edits made
						ReDim $aEdited[1][4]
						$aEdited[0][0] = 0
					EndIf
					; Wait until key no longer pressed
					While _WinAPI_GetAsyncKeyState(0x1B)
						Sleep(10)
					WEnd
					; Exit Edit process
					ExitLoop
				Case 0x09, 0x27 ; TAB or right arrow
					While 1
						; Set next column
						$aLocation[1] += 1
						; Check column exists
						If $aLocation[1] = _GUICtrlListView_GetColumnCount($hGLVEx_Editing) Then
							; Does not exist so check required action
							Switch $iEditCol
								Case 1
									; Exit edit process
									ExitLoop 2
								Case 2
									; Stay on same location
									$aLocation[1] -= 1
									ExitLoop
								Case 3
									; Loop
									$aLocation[1] = 0
							EndSwitch
						EndIf
						; Check this column is editable
						If Not StringInStr($sCols, "*") Then
							If StringInStr(";" & $sCols, ";" & $aLocation[1]) Then
								; Editable column
								ExitLoop
							EndIf
						Else
							; Editable column
							ExitLoop
						EndIf
					WEnd

				Case 0x25 ; Left arrow
					While 1
						$aLocation[1] -= 1
						If $aLocation[1] < 0 Then
							Switch $iEditCol
								Case 1
									ExitLoop 2
								Case 2
									$aLocation[1] += 1
									ExitLoop
								Case 3
									$aLocation[1] = _GUICtrlListView_GetColumnCount($hGLVEx_Editing) - 1
							EndSwitch
						EndIf
						If Not StringInStr($sCols, "*") Then
							If StringInStr(";" & $sCols, ";" & $aLocation[1]) Then
								ExitLoop
							EndIf
						Else
							ExitLoop
						EndIf
					WEnd

				Case 0x28 ; Down key
					While 1
						; Set next row
						$aLocation[0] += 1
						; Check column exists
						If $aLocation[0] = _GUICtrlListView_GetItemCount($hGLVEx_Editing) Then
							; Does not exist so check required action
							Switch $iEditRow
								Case 1
									; Exit edit process
									ExitLoop 2
								Case 2
									; Stay on same location
									$aLocation[0] -= 1
									ExitLoop
								Case 3
									; Loop
									$aLocation[0] = -1
							EndSwitch
						Else
							; All rows editable
							ExitLoop
						EndIf
					WEnd

				Case 0x26 ; Up key
					While 1
						$aLocation[0] -= 1
						If $aLocation[0] < 0 Then
							Switch $iEditRow
								Case 1
									ExitLoop 2
								Case 2
									$aLocation[0] += 1
									ExitLoop
								Case 3
									$aLocation[0] = _GUICtrlListView_GetItemCount($hGLVEx_Editing)
							EndSwitch
						Else
							ExitLoop
						EndIf
					WEnd
			EndSwitch
			; Wait until key no longer pressed
			While _WinAPI_GetAsyncKeyState($iKey_Code)
				Sleep(10)
			WEnd
			; Continue edit loop on next item
		EndIf
	WEnd
	; Delete copied array
	$aGLVEx_SrcArray = 0
	; Reenable ListView
	WinSetState($hGLVEx_Editing, "", @SW_ENABLE)
	; Reselect item
	_GUICtrlListView_SetItemState($hGLVEx_SrcHandle, $aLocation[0], $LVIS_SELECTED, $LVIS_SELECTED)

	; Set extended to key value
	SetExtended($iKey_Code)
	; Return array
	Return $aEdited

EndFunc   ;==>__GUIListViewEx_EditProcess

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_EditCoords
; Description ...: Ensures item in view then locates and sizes edit control
; Author ........: Melba23
; Modified ......:
; ===============================================================================================================================
Func __GUIListViewEx_EditCoords($hLV_Handle, $cLV_CID, $aLocation, $tLVPos, $iLVWidth, $iDelta_X, $iDelta_Y)

	; Declare array to hold return data
	Local $aEdit_Data[4]
	; Ensure row visible
	_GUICtrlListView_EnsureVisible($hLV_Handle, $aLocation[0])
	; Get size of item
	Local $aRect = _GUICtrlListView_GetSubItemRect($hLV_Handle, $aLocation[0], $aLocation[1])
	; Set required edit height
	$aEdit_Data[3] = $aRect[3] - $aRect[1] + 1
	; Set required edit width
	$aEdit_Data[2] = _GUICtrlListView_GetColumnWidth($hLV_Handle, $aLocation[1])
	; Ensure column visible - scroll to left edge if all column not in view
	If $aRect[0] < 0 Or $aRect[2] > $iLVWidth Then
		_GUICtrlListView_Scroll($hLV_Handle, $aRect[0], 0)
		; Redetermine item coords
		$aRect = _GUICtrlListView_GetSubItemRect($hLV_Handle, $aLocation[0], $aLocation[1])
		; Check available column width and limit if required
		If $aRect[0] + $aEdit_Data[2] > $iLVWidth Then
			$aEdit_Data[2] = $iLVWidth - $aRect[0]
		EndIf
	EndIf
	; Adjust Y coord if Native ListView
	If $cLV_CID Then
		$iDelta_Y += 1
	EndIf
	; Determine screen coords for edit control
	$aEdit_Data[0] = DllStructGetData($tLVPos, "X") + $aRect[0] + $iDelta_X + 2
	$aEdit_Data[1] = DllStructGetData($tLVPos, "Y") + $aRect[1] + $iDelta_Y

	; Return edit data
	Return $aEdit_Data

EndFunc   ;==>__GUIListViewEx_EditCoords

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_ReWriteLV
; Description ...: Deletes all ListView content and refills to match array
; Author ........: Melba23
; Modified ......:
; ===============================================================================================================================
Func __GUIListViewEx_ReWriteLV($hLVHandle, ByRef $aLV_Array, ByRef $aCheck_Array, $iLV_Index, $fCheckBox = True)

	Local $iVertScroll

	; Get item depth
	If $aGLVEx_Data[$iLV_Index][10] Then
		$iVertScroll = $aGLVEx_Data[$iLV_Index][10]
	Else
		; If not already set then ListView was empty so determine
		Local $aRect = _GUICtrlListView_GetItemRect($hLVHandle, 0)
		$aGLVEx_Data[$iLV_Index][10] = $aRect[3] - $aRect[1]
		; If still empty set a placeholder for this instance
		If $iVertScroll = 0 Then
			; And make sure scroll is likely to be enough to get next item into view
			$iVertScroll = 20
		EndIf
	EndIf

	; Get top item
	Local $iTopIndex_Org = _GUICtrlListView_GetTopIndex($hLVHandle)

	_GUICtrlListView_BeginUpdate($hLVHandle)

	; Empty ListView
	_GUICtrlListView_DeleteAllItems($hLVHandle)

	; Check array to fill ListView
	If UBound($aLV_Array, 2) Then

		; Remove count line from stored array
		Local $aArray = $aLV_Array
		_ArrayDelete($aArray, 0)

		; Load ListView content
		Local $cLV_CID = $aGLVEx_Data[$iLV_Index][1]
		If $cLV_CID Then
			; Native ListView
			Local $sLine, $iLastCol = UBound($aArray, 2) - 1
			For $i = 0 To UBound($aArray) - 1
				$sLine = ""
				For $j = 0 To $iLastCol
					$sLine &= $aArray[$i][$j] & "|"
				Next
				GUICtrlCreateListViewItem(StringTrimRight($sLine, 1), $cLV_CID)
			Next
		Else
			; UDF ListView
			_GUICtrlListView_AddArray($hLVHandle, $aArray)
		EndIf

		; Reset checkbox if required
		For $i = 1 To $aLV_Array[0][0]
			If $fCheckBox And $aCheck_Array[$i] Then
				_GUICtrlListView_SetItemChecked($hLVHandle, $i - 1)
			EndIf
		Next

		; Now scroll to same place or max possible
		Local $iTopIndex_Curr = _GUICtrlListView_GetTopIndex($hLVHandle)
		While $iTopIndex_Curr < $iTopIndex_Org
			_GUICtrlListView_Scroll($hLVHandle, 0, $iVertScroll)
			; If scroll had no effect then max scroll up
			If _GUICtrlListView_GetTopIndex($hLVHandle) = $iTopIndex_Curr Then
				ExitLoop
			Else
				; Reset current top index
				$iTopIndex_Curr = _GUICtrlListView_GetTopIndex($hLVHandle)
			EndIf
		WEnd
	EndIf

	_GUICtrlListView_EndUpdate($hLVHandle)

EndFunc   ;==>__GUIListViewEx_ReWriteLV

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_GetLVCoords
; Description ...: Gets screen coords for ListView
; Author ........: Melba23
; Modified ......:
; ===============================================================================================================================
Func __GUIListViewEx_GetLVCoords($hLV_Handle, ByRef $tLVPos)

	; Get handle of ListView parent
	Local $aWnd = DllCall("user32.dll", "hwnd", "GetParent", "hwnd", $hLV_Handle)
	Local $hWnd = $aWnd[0]
	; Get position of ListView within GUI client area
	Local $aLVPos = WinGetPos($hLV_Handle)
	DllStructSetData($tLVPos, "X", $aLVPos[0])
	DllStructSetData($tLVPos, "Y", $aLVPos[1])
	_WinAPI_ScreenToClient($hWnd, $tLVPos)

EndFunc   ;==>__GUIListViewEx_GetLVCoords

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_GetCursorWnd
; Description ...: Gets handle of control under the mouse cursor
; Author ........: Melba23
; Modified ......:
; ===============================================================================================================================
Func __GUIListViewEx_GetCursorWnd()

	Local $iOldMouseOpt = Opt("MouseCoordMode", 1)
	Local $tMPos = DllStructCreate("struct;long X;long Y;endstruct")
	DllStructSetData($tMPos, "X", MouseGetPos(0))
	DllStructSetData($tMPos, "Y", MouseGetPos(1))
	Opt("MouseCoordMode", $iOldMouseOpt)
	Return _WinAPI_WindowFromPoint($tMPos)

EndFunc   ;==>__GUIListViewEx_GetCursorWnd

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_Array_Add
; Description ...: Adds a specified value at the end of an existing 1D or 2D array.
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_Array_Add(ByRef $avArray, $vAdd, $fMultiRow = False, $bCount = True)

	; Get size of the Array to modify
	Local $iIndex_Max = UBound($avArray)
	Local $iAdd_Dim

	; Get type of array
	Switch UBound($avArray, 0)
		Case 1 ; Checkbox array
			If UBound($vAdd, 0) = 2 Or $fMultiRow Then ; 2D or 1D as rows
				$iAdd_Dim = UBound($vAdd, 1)
				ReDim $avArray[$iIndex_Max + $iAdd_Dim]
			Else ; 1D as columns
				ReDim $avArray[$iIndex_Max + 1]
			EndIf

		Case 2 ; Data array
			; Get column count of data array
			Local $iDim2 = UBound($avArray, 2)
			If UBound($vAdd, 0) = 2 Then ; 2D add
				; Redim the Array
				$iAdd_Dim = UBound($vAdd, 1)
				ReDim $avArray[$iIndex_Max + $iAdd_Dim][$iDim2]
				$avArray[0][0] += $iAdd_Dim
				; Add new elements
				Local $iAdd_Max = UBound($vAdd, 2)
				For $i = 0 To $iAdd_Dim - 1
					For $j = 0 To $iDim2 - 1
						; If Insert array is too small to fill Array then continue with blanks
						If $j > $iAdd_Max - 1 Then
							$avArray[$iIndex_Max + $i][$j] = ""
						Else
							$avArray[$iIndex_Max + $i][$j] = $vAdd[$i][$j]
						EndIf
					Next
				Next

			ElseIf $fMultiRow Then ; 1D add as rows
				; Redim the Array
				$iAdd_Dim = UBound($vAdd, 1)
				ReDim $avArray[$iIndex_Max + $iAdd_Dim][$iDim2]
				$avArray[0][0] += $iAdd_Dim
				; Add new elements
				For $i = 0 To $iAdd_Dim - 1
					$avArray[$iIndex_Max + $i][0] = $vAdd[$i]
				Next

			Else ; 1D add as columns
				; Redim the Array
				ReDim $avArray[$iIndex_Max + 1][$iDim2]
				If $bCount Then
					$avArray[0][0] += 1
				EndIf
				; Add new elements
				If IsArray($vAdd) Then
					; Get size of Insert array
					Local $vAdd_Max = UBound($vAdd)
					For $j = 0 To $iDim2 - 1
						; If Insert array is too small to fill Array then continue with blanks
						If $j > $vAdd_Max - 1 Then
							$avArray[$iIndex_Max][$j] = ""
						Else
							$avArray[$iIndex_Max][$j] = $vAdd[$j]
						EndIf
					Next
				Else
					; Fill Array with variable
					For $j = 0 To $iDim2 - 1
						$avArray[$iIndex_Max][$j] = $vAdd
					Next
				EndIf
			EndIf

	EndSwitch

EndFunc   ;==>__GUIListViewEx_Array_Add

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_Array_Insert
; Description ...: Adds a value at the specified index of a 1D or 2D array.
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_Array_Insert(ByRef $avArray, $iIndex, $vInsert, $fMultiRow = False, $bCount = True)

	; Get size of the Array to modify
	Local $iIndex_Max = UBound($avArray)
	Local $iInsert_Dim

	; Get type of array
	Switch UBound($avArray, 0)
		Case 1 ; Checkbox array
			If UBound($vInsert, 0) = 2 Or $fMultiRow Then ; 2D or 1D as rows
				; Resize array
				$iInsert_Dim = UBound($vInsert, 1)
				ReDim $avArray[$iIndex_Max + $iInsert_Dim]

				; Move down all elements below the new index
				For $i = $iIndex_Max + $iInsert_Dim - 1 To $iIndex + 1 Step -1
					$avArray[$i] = $avArray[$i - 1]
				Next
			Else ; 1D as columns
				; Resize array
				ReDim $avArray[$iIndex_Max + 1]

				; Move down all elements below the new index
				For $i = $iIndex_Max To $iIndex + 1 Step -1
					$avArray[$i] = $avArray[$i - 1]
				Next
			EndIf

		Case 2 ; Data array
			; If at end of array
			If $iIndex > $iIndex_Max - 1 Then
				__GUIListViewEx_Array_Add($avArray, $vInsert, $fMultiRow, $bCount)
				Return
			EndIf
			; Get column count of data array
			Local $iDim2 = UBound($avArray, 2)
			If UBound($vInsert, 0) = 2 Then ; 2D insert
				; Redim the Array
				$iInsert_Dim = UBound($vInsert, 1)
				ReDim $avArray[$iIndex_Max + $iInsert_Dim][$iDim2]
				If $bCount Then
					$avArray[0][0] += $iInsert_Dim
				EndIf
				; Move down all elements below the new index
				For $i = $iIndex_Max + $iInsert_Dim - 1 To $iIndex + $iInsert_Dim Step -1
					For $j = 0 To $iDim2 - 1
						$avArray[$i][$j] = $avArray[$i - $iInsert_Dim][$j]
					Next
				Next
				; Add new elements
				Local $iInsert_Max = UBound($vInsert, 2)
				For $i = 0 To $iInsert_Dim - 1
					For $j = 0 To $iDim2 - 1
						; If Insert array is too small to fill Array then continue with blanks
						If $j > $iInsert_Max - 1 Then
							$avArray[$iIndex + $i][$j] = ""
						Else
							$avArray[$iIndex + $i][$j] = $vInsert[$i][$j]
						EndIf
					Next
				Next

			ElseIf $fMultiRow Then ; 1D insert as rows
				; Redim the Array
				$iInsert_Dim = UBound($vInsert, 1)
				ReDim $avArray[$iIndex_Max + $iInsert_Dim][$iDim2]
				$avArray[0][0] += $iInsert_Dim
				; Move down all elements below the new index
				For $i = $iIndex_Max + $iInsert_Dim - 1 To $iIndex + $iInsert_Dim Step -1
					For $j = 0 To $iDim2 - 1
						$avArray[$i][$j] = $avArray[$i - $iInsert_Dim][$j]
					Next
				Next
				; Add new items
				For $i = 0 To $iInsert_Dim - 1
					$avArray[$iIndex + $i][0] = $vInsert[$i]
				Next

			Else ; 1D insert as columns
				; Redim the Array
				ReDim $avArray[$iIndex_Max + 1][$iDim2]
				$avArray[0][0] += 1
				; Move down all elements below the new index
				For $i = $iIndex_Max To $iIndex + 1 Step -1
					For $j = 0 To $iDim2 - 1
						$avArray[$i][$j] = $avArray[$i - 1][$j]
					Next
				Next
				; Insert new elements
				If IsArray($vInsert) Then
					; Get size of Insert array
					Local $vInsert_Max = UBound($vInsert)
					For $j = 0 To $iDim2 - 1
						; If Insert array is too small to fill Array then continue with blanks
						If $j > $vInsert_Max - 1 Then
							$avArray[$iIndex][$j] = ""
						Else
							$avArray[$iIndex][$j] = $vInsert[$j]
						EndIf
					Next
				Else
					; Fill Array with variable
					For $j = 0 To $iDim2 - 1
						$avArray[$iIndex][$j] = $vInsert
					Next
				EndIf
			EndIf

	EndSwitch

EndFunc   ;==>__GUIListViewEx_Array_Insert

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_Array_Delete
; Description ...: Deletes a specified index from an existing 1D or 2D array.
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_Array_Delete(ByRef $avArray, $iIndex, $bDelCount = False)

	; Get size of the Array to modify
	Local $iIndex_Max = UBound($avArray)
	If $iIndex_Max = 0 Then Return

	; Get type of array
	Switch UBound($avArray, 0)
		Case 1 ; Checkbox array
			; Move up all elements below the new index
			For $i = $iIndex To $iIndex_Max - 2
				$avArray[$i] = $avArray[$i + 1]
			Next
			; Redim the Array
			ReDim $avArray[$iIndex_Max - 1]

		Case 2 ; Data array
			; Get size of second dimension
			Local $iDim2 = UBound($avArray, 2)
			; Move up all elements below the new index
			For $i = $iIndex To $iIndex_Max - 2
				For $j = 0 To $iDim2 - 1
					$avArray[$i][$j] = $avArray[$i + 1][$j]
				Next
			Next
			; Redim the Array
			ReDim $avArray[$iIndex_Max - 1][$iDim2]
			; If count element not being deleted
			If Not $bDelCount Then
				$avArray[0][0] -= 1
			EndIf

	EndSwitch

EndFunc   ;==>__GUIListViewEx_Array_Delete

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_Array_Swap
; Description ...: Swaps specified elements within a 1D or 2D array
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_Array_Swap(ByRef $avArray, $iIndex1, $iIndex2)

	Local $vTemp

	; Get type of array
	Switch UBound($avArray, 0)
		Case 1
			; Swap the elements via a temp variable
			$vTemp = $avArray[$iIndex1]
			$avArray[$iIndex1] = $avArray[$iIndex2]
			$avArray[$iIndex2] = $vTemp

		Case 2
			; Get size of second dimension
			Local $iDim2 = UBound($avArray, 2)
			; Swap the elements via a temp variable
			For $i = 0 To $iDim2 - 1
				$vTemp = $avArray[$iIndex1][$i]
				$avArray[$iIndex1][$i] = $avArray[$iIndex2][$i]
				$avArray[$iIndex2][$i] = $vTemp
			Next
	EndSwitch

	Return 0

EndFunc   ;==>__GUIListViewEx_Array_Swap

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_ToolTipHide
; Description ...: Called by Adlib to hide a tooltip displayed by _GUIListViewEx_ToolTipShow
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_ToolTipHide()
	; Cancel Adlib
	AdlibUnRegister("__GUIListViewEx_ToolTipHide")
	; Clear tooltip
	ToolTip("")
	; Reset tooltip row/col values
	$aGLVEx_Data[0][4] = -1
	$aGLVEx_Data[0][5] = -1
EndFunc   ;==>__GUIListViewEx_ToolTipHide

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_MakeString
; Description ...: Convert data/check/colour arrays to strings for saving
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_MakeString($aArray)

	If Not IsArray($aArray) Then Return SetError(1, 0, "")

	Local $sRet = ""
	Local $sDelim_Col = @CR
	Local $sDelim_Row = @LF

	Switch UBound($aArray, $UBOUND_DIMENSIONS)
		Case 1
			For $i = 0 To UBound($aArray, $UBOUND_ROWS) - 1
				$sRet &= $aArray[$i] & $sDelim_Row
			Next
			Return StringTrimRight($sRet, StringLen($sDelim_Col))

		Case 2
			For $i = 0 To UBound($aArray, $UBOUND_ROWS) - 1
				For $j = 0 To UBound($aArray, $UBOUND_COLUMNS) - 1
					$sRet &= $aArray[$i][$j] & $sDelim_Col
				Next
				$sRet = StringTrimRight($sRet, StringLen($sDelim_Col)) & $sDelim_Row
			Next
			Return StringTrimRight($sRet, StringLen($sDelim_Row))

		Case Else
			Return SetError(2, 0, "")
	EndSwitch

EndFunc   ;==>__GUIListViewEx_MakeString

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name...........: __GUIListViewEx_MakeArray
; Description ...: Convert data/check/colour strings to arrays for loading
; Author ........: Melba23
; Remarks .......:
; ===============================================================================================================================
Func __GUIListViewEx_MakeArray($sString)

	If $sString = "" Then Return SetError(1, 0, "")

	Local $aRetArray, $aRows, $aItems
	Local $sRowDelimiter = @LF
	Local $sColDelimiter = @CR

	If StringInStr($sString, $sColDelimiter) Then
		; 2D array
		$aRows = StringSplit($sString, $sRowDelimiter)
		; Get column count
		StringReplace($aRows[1], $sColDelimiter, "")
		; Create array
		Local $aRetArray[$aRows[0]][@extended + 1]
		; Fill array
		For $i = 1 To $aRows[0]
			$aItems = StringSplit($aRows[$i], $sColDelimiter)
			For $j = 1 To $aItems[0]
				$aRetArray[$i - 1][$j - 1] = $aItems[$j]
			Next
		Next
	Else
		; 1D array
		$aRetArray = StringSplit($sString, $sRowDelimiter, $STR_NOCOUNT)
	EndIf

	Return $aRetArray

EndFunc   ;==>__GUIListViewEx_MakeArray

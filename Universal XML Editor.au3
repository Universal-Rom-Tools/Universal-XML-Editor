#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Ressources\Universal_Xml_Editor.ico
#AutoIt3Wrapper_Outfile=..\BIN\Universal_XML_Editor.exe
#AutoIt3Wrapper_Outfile_x64=..\BIN\Universal_XML_Editor64.exe
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Description=Editeur XML Universel
#AutoIt3Wrapper_Res_Fileversion=1.0.0.1
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=p
#AutoIt3Wrapper_Res_LegalCopyright=LEGRAS David
#AutoIt3Wrapper_Res_Language=1036
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=y
#AutoIt3Wrapper_Run_Tidy=y
#Tidy_Parameters=/reel
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

;*************************************************************************
;**																		**
;**						Universal XML Editor							**
;**						LEGRAS David									**
;**																		**
;*************************************************************************

;Definition des librairies
;-------------------------
#include <Date.au3>
#include <array.au3>
#include <File.au3>
#include <String.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GUIListBox.au3>
#include <GuiStatusBar.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <Color.au3>
#include <Crypt.au3>
#include <GuiListView.au3>
#include <GDIPlus.au3>

#include "./Include/_MultiLang.au3"
#include "./Include/_ExtMsgBox.au3"
#include "./Include/_Trim.au3"
#include "./Include/_XMLDomWrapper.au3"
#include "./Include/_Hash.au3"
#include "./Include/_GUIListViewEx.au3"

;FileInstall
;-----------
Global $SOURCE_DIRECTORY = @ScriptDir
If Not _FileCreate($SOURCE_DIRECTORY & "\test") Then
	$SOURCE_DIRECTORY = @AppDataDir & "\Universal_XML_Scraper"
	DirCreate($SOURCE_DIRECTORY & "\UXMLS")
Else
	FileDelete($SOURCE_DIRECTORY & "\test")
EndIf

DirCreate($SOURCE_DIRECTORY & "\LanguageFiles")
DirCreate($SOURCE_DIRECTORY & "\Ressources")
FileInstall(".\UXE-config.ini", $SOURCE_DIRECTORY & "\UXE-config.ini")
FileInstall(".\LanguageFiles\UXE-ENGLISH.XML", $SOURCE_DIRECTORY & "\LanguageFiles\UXE-ENGLISH.XML")
FileInstall(".\LanguageFiles\UXE-FRENCH.XML", $SOURCE_DIRECTORY & "\LanguageFiles\UXE-FRENCH.XML")
FileInstall(".\Ressources\RecalboxV3.jpg", $SOURCE_DIRECTORY & "\Ressources\RecalboxV3.jpg")
FileInstall(".\Ressources\RecalboxV4.jpg", $SOURCE_DIRECTORY & "\Ressources\RecalboxV4.jpg")
FileInstall(".\Ressources\Recalbox.jpg", $SOURCE_DIRECTORY & "\Ressources\Recalbox.jpg")
FileInstall(".\Ressources\Hyperspin.jpg", $SOURCE_DIRECTORY & "\Ressources\Hyperspin.jpg")
FileInstall(".\Ressources\Emulationstation.jpg", $SOURCE_DIRECTORY & "\Ressources\Emulationstation.jpg")
FileInstall(".\Ressources\plink.exe", $SOURCE_DIRECTORY & "\Ressources\plink.exe")
FileInstall(".\Ressources\empty.jpg", $SOURCE_DIRECTORY & "\Ressources\empty.jpg")

;Definition des Variables
;-------------------------
Global $LANG_DIR = $SOURCE_DIRECTORY & "\LanguageFiles"; Where we are storing the language files.
Global $INI_P_CIBLE = $SOURCE_DIRECTORY & "\Ressources\empty.jpg"
Global $Empty_Image = $SOURCE_DIRECTORY & "\Ressources\empty.jpg"
Global $PathTmp = $SOURCE_DIRECTORY & "\API_temp.tmp"
Global $PathConfigINI = $SOURCE_DIRECTORY & "\UXE-config.ini"
Global $PathPlink = $SOURCE_DIRECTORY & "\Ressources\plink.exe"
Local $path_LOG = IniRead($PathConfigINI, "GENERAL", "Path_LOG", $SOURCE_DIRECTORY & "\log.txt")
Local $Verbose = IniRead($PathConfigINI, "GENERAL", "Verbose", 1)
Local $Menu_SSH = IniRead($PathConfigINI, "CONNEXION", "Menu_SSH", 0)
Local $Plink_root = IniRead($PathConfigINI, "CONNEXION", "Plink_root", "root")
Local $Plink_mdp = IniRead($PathConfigINI, "CONNEXION", "Plink_mdp", "recalboxroot")
Local $Plink_IP = IniRead($PathConfigINI, "CONNEXION", "Plink_IP", "RECALBOX")
Global $PathNew = IniRead($PathConfigINI, "LAST_USE", "$PathNew", "")
Global $PathRom = IniRead($PathConfigINI, "LAST_USE", "$PathRom", "")
Global $PathRomSub = IniRead($PathConfigINI, "LAST_USE", "$PathRomSub", "")
Global $PathImage = IniRead($PathConfigINI, "LAST_USE", "$PathImage", "")
Global $PathImageSub = IniRead($PathConfigINI, "LAST_USE", "$PathImageSub", "")
Global $No_Profil = IniRead($PathConfigINI, "LAST_USE", "$No_Profil", 1)
Global $user_lang = IniRead($PathConfigINI, "LAST_USE", "$user_lang", "-1")
Global $No_system = IniRead($PathConfigINI, "LAST_USE", "$No_system", "-1")
Global $HauteurImage = IniRead($PathConfigINI, "LAST_USE", "$HauteurImage", "")
Global $LargeurImage = IniRead($PathConfigINI, "LAST_USE", "$LargeurImage", "")
Global $TMP_LastChild = ''
Global $DevId = BinaryToString(_Crypt_DecryptData("0x1552EDED2FA9B5", "1gdf1g1gf", $CALG_RC4))
Global $DevPassword = BinaryToString(_Crypt_DecryptData("0x1552EDED2FA9B547FBD0D9A623D954AE7BEDC681", "1gdf1g1gf", $CALG_RC4))
Global $Rev, $RomSelected = "", $RomLoaded = 0
If @Compiled Then
	$Rev = "BETA " & FileGetVersion(@ScriptFullPath)
Else
	$Rev = 'In Progress'
EndIf

Global $A_ROMList, $A_XMLFormat, $V_XMLPath

;---------;
;Principal;
;---------;

_CREATION_LOG()
_LANG_LOAD($LANG_DIR, $user_lang)
_CREATION_LOGMESS("Langue Selectionnee : " & $user_lang)

#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#Region ### START Koda GUI section ### Form=
$F_UniversalEditor = GUICreate(_MultiLang_GetText("main_gui"), 798, 601, 192, 124)
GUISetBkColor(0x34495c, $F_UniversalEditor)
Local $MF = GUICtrlCreateMenu(_MultiLang_GetText("mnu_file"))
Local $MF_Profil = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_file_profil"), $MF)
Local $MF_XML = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_file_xml"), $MF)
Local $MF_Separation = GUICtrlCreateMenuItem("", $MF)
Local $MF_Exit = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_file_exit"), $MF)
Local $ME = GUICtrlCreateMenu(_MultiLang_GetText("mnu_edit"))
Local $ME_Replace = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_edit_replace"), $ME)
Local $ME_Separation = GUICtrlCreateMenuItem("", $ME)
Local $ME_Langue = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_edit_langue"), $ME)
Local $ME_Config = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_edit_config"), $ME)
Local $MP = GUICtrlCreateMenu("SSH")
Local $MP_KILLALL = GUICtrlCreateMenuItem("KillAll Emulationstation", $MP)
Local $MP_REBOOT = GUICtrlCreateMenuItem("Reboot", $MP)
Local $MP_POWEROFF = GUICtrlCreateMenuItem("Power off", $MP)
GUICtrlSetState($MP, $GUI_DISABLE)
Local $MH = GUICtrlCreateMenu(_MultiLang_GetText("mnu_help"))
Local $MH_Help = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_help_about"), $MH)
Local $H_LV_ROMLIST = GUICtrlCreateListView(_MultiLang_GetText("lv_roms"), 3, 122, 226, 430, $LVS_SHOWSELALWAYS)
;~ Local $H_LV_ROMLIST = _GUICtrlListView_Create($F_UniversalEditor, "Roms", 3, 122, 226, 430, BitOR($WS_HSCROLL, $WS_VSCROLL, $WS_BORDER, $LVS_REPORT, $LVS_NOCOLUMNHEADER), 0)
_GUICtrlListView_SetExtendedListViewStyle($H_LV_ROMLIST, $LVS_EX_FULLROWSELECT)
_GUICtrlListView_SetColumnWidth($H_LV_ROMLIST, 0, 206)
Local $H_LV_ATTRIBUT = GUICtrlCreateListView(_MultiLang_GetText("lv_attributs"), 232, 4, 562, 548, $LVS_SHOWSELALWAYS)
;~ Local $H_LV_ATTRIBUT = _GUICtrlListView_Create($F_UniversalEditor, "Attributs|Valeurs", 232, 4, 562, 548, BitOR($WS_HSCROLL, $WS_VSCROLL, $WS_BORDER, $LVS_REPORT, $LVS_NOCOLUMNHEADER), 0)
_GUICtrlListView_SetExtendedListViewStyle($H_LV_ATTRIBUT, $LVS_EX_FULLROWSELECT)
_GUICtrlListView_SetColumnWidth($H_LV_ATTRIBUT, 0, 313)
;~ Local $P_CIBLE = GUICtrlCreatePic($INI_P_CIBLE, 18, 8, 196, 100)
Local $SB_EDITOR = _GUICtrlStatusBar_Create($F_UniversalEditor)
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

; Initialisation interface
Local $A_Profil = _INI_CREATEARRAY_EDITOR()
Local $INI_P_CIBLE = $SOURCE_DIRECTORY & "\Ressources\" & IniRead($PathConfigINI, $A_Profil[$No_Profil], "$IMAGE_CIBLE", "empty.jpg")
_GUI_REFRESH($INI_P_CIBLE)

While 1
	$nMsg = GUIGetMsg()
	Switch $nMsg
		Case $GUI_EVENT_CLOSE, $MF_Exit
			Exit
		Case $MF_Profil
			$No_Profil = _PROFIL_SelectGUI($A_Profil)
			$INI_P_CIBLE = $SOURCE_DIRECTORY & "\Ressources\" & IniRead($PathConfigINI, $A_Profil[$No_Profil], "$IMAGE_CIBLE", "empty.jpg")
			_CREATION_LOGMESS("Profil : " & $A_Profil[$No_Profil])
			$RomLoaded = 0
			_GUIListViewEx_Close(0)
			_GUICtrlListView_DeleteAllItems($H_LV_ROMLIST)
			_GUICtrlListView_DeleteAllItems($H_LV_ATTRIBUT)
			_GUI_REFRESH($INI_P_CIBLE)
		Case $MP_KILLALL
			If MsgBox($MB_OKCANCEL, "KillAll Emulationstation", "Etes vous sur de vouloir arreter EmulationStation ?") = $IDOK Then
				Run($PathPlink & $Plink_IP & " -l " & $Plink_root & " -pw " & $Plink_mdp & " killall emulationstation")
				_CREATION_LOGMESS("SSH : KillAll Emulationstation")
			EndIf
		Case $MP_REBOOT
			If MsgBox($MB_OKCANCEL, "Reboot", "Etes vous sur de vouloir Rebooter la machine distante ?") = $IDOK Then
				Run($PathPlink & $Plink_IP & " -l " & $Plink_root & " -pw " & $Plink_mdp & " /sbin/reboot")
				_CREATION_LOGMESS("SSH : Reboot")
			EndIf
		Case $MP_POWEROFF
			If MsgBox($MB_OKCANCEL, "Power Off", "Etes vous sur de vouloir ArrÃªter la machine distante ?") = $IDOK Then
				Run($PathPlink & $Plink_IP & " -l " & $Plink_root & " -pw " & $Plink_mdp & " /sbin/poweroff")
				_CREATION_LOGMESS("SSH : Power Off")
			EndIf
		Case $ME_Replace
			If $RomLoaded = 1 Then
				_EDIT_REPLACE($A_ROMList, $A_XMLFormat, $V_XMLPath)
				$RomSelected = 1
			EndIf
		Case $ME_Langue
			_LANG_LOAD($LANG_DIR, -1)
			_CREATION_LOGMESS("Langue Selectionnee : " & $user_lang)
			_GUI_REFRESH($INI_P_CIBLE)
		Case $ME_Config
			_GUI_Config()
			_GUI_REFRESH($INI_P_CIBLE)
		Case $MH_Help
			$sMsg = "UNIVERSAL XML EDITOR - " & $Rev & @CRLF
			$sMsg &= _MultiLang_GetText("win_About_By") & @CRLF & @CRLF
			$sMsg &= _MultiLang_GetText("win_About_Thanks") & @CRLF
			$sMsg &= "http://www.screenzone.fr/" & @CRLF
			$sMsg &= "http://www.screenscraper.fr/" & @CRLF
			$sMsg &= "http://www.recalbox.com/" & @CRLF
			$sMsg &= "http://www.emulationstation.org/" & @CRLF
			_ExtMsgBoxSet(1, 2, 0x34495c, 0xFFFF00, 10, "Arial")
			_ExtMsgBox($EMB_ICONINFO, "OK", _MultiLang_GetText("win_About_Title"), $sMsg, 15)
		Case $MF_XML ;Menu Fichier/Charger le fichier XML
			$RomLoaded = 1
			_GUIListViewEx_Close(0)
			_GUICtrlListView_DeleteAllItems($H_LV_ROMLIST)
			_GUICtrlListView_DeleteAllItems($H_LV_ATTRIBUT)
			Local $V_XMLPath = FileOpenDialog(_MultiLang_GetText("win_sel_xml_Title"), "c:\", 'XML (*.xml)', $FD_FILEMUSTEXIST, "gamelist.xml")
			$A_XMLFormat = _XML_CREATEFORMAT($A_Profil[$No_Profil], $PathConfigINI)
			Global $A_ROMList = _ROM_CREATEARRAY($V_XMLPath, $A_XMLFormat)
			For $B_ROMList = 0 To UBound($A_ROMList) - 1
				_GUICtrlListView_AddItem($H_LV_ROMLIST, $A_ROMList[$B_ROMList][2])
;~ 				_GUICtrlListView_AddSubItem($H_LV_ROMLIST, $B_ROMList, $A_ROMList[$B_ROMList][3], 1)
			Next
			$I_LV_ROMLIST = _GUIListViewEx_Init($H_LV_ROMLIST, $A_ROMList, 0, 0, False, 720)
			_GUIListViewEx_MsgRegister(True, False, False, True) ;Register sans drag&drop
			_GUIListViewEx_SetActive(1) ;Activation de la LV de gauche
			_GUI_REFRESH($INI_P_CIBLE)
	EndSwitch
	If $RomLoaded = 1 Then
		If $aGLVEx_Data[1][20] <> $RomSelected And $aGLVEx_Data[1][20] >= 0 Then
			$RomSelected = $aGLVEx_Data[1][20]
			$NoRomSelected = $A_ROMList[$RomSelected][3]
			ConsoleWrite("Rom choisi n°" & $A_ROMList[$RomSelected][3] & @CRLF) ; Debug
			_GUICtrlListView_DeleteAllItems($H_LV_ATTRIBUT)
			$A_XMLList = _XML_CREATEARRAY($V_XMLPath, $A_XMLFormat, $NoRomSelected)
			For $B_XMLList = 0 To UBound($A_XMLList) - 1
				_GUICtrlListView_AddItem($H_LV_ATTRIBUT, $A_XMLList[$B_XMLList][0])
				_GUICtrlListView_AddSubItem($H_LV_ATTRIBUT, $B_XMLList, $A_XMLList[$B_XMLList][1], 1)
			Next
			_GUICtrlListView_SetColumnWidth($H_LV_ATTRIBUT, 0, $LVSCW_AUTOSIZE)
			_GUICtrlListView_SetColumnWidth($H_LV_ATTRIBUT, 1, 535 - _GUICtrlListView_GetColumnWidth($H_LV_ATTRIBUT, 0))
			$I_LV_ATTRIBUT = _GUIListViewEx_Init($H_LV_ATTRIBUT, $A_XMLList, 0, 0, False, 2, "1")
		EndIf
	EndIf
	$aRet = _GUIListViewEx_EditOnClick() ; Use combos to change EditMode
	; Array only returned AFTER EditOnClick process - so check array exists
	If IsArray($aRet) Then
		; Uncomment to see returned array
		$I_AttribSelected = $aGLVEx_Data[2][20]
		$V_AttribSelected = _GUICtrlListView_GetItem($H_LV_ATTRIBUT, $I_AttribSelected)
		$V_AttribSelected_Value = _GUICtrlListView_GetItem($H_LV_ATTRIBUT, $I_AttribSelected, 1)
		ConsoleWrite($V_AttribSelected[3] & ' - ' & $V_AttribSelected_Value[3] & @CRLF)
		_XML_UPDATEINFO($V_XMLPath, $A_XMLFormat, $NoRomSelected, $V_AttribSelected[3], $V_AttribSelected_Value[3])
;~ 		_ArrayDisplay($aRet, @error)
	EndIf
WEnd

;---------;
;Fonctions;
;---------;

Func _CREATION_LOG()
	If Not _FileCreate($path_LOG) Then MsgBox(4096, "Error", " Erreur creation du Fichier LOG      error:" & @error)
	$tCur = _Date_Time_GetLocalTime()
	$dtCur = _Date_Time_SystemTimeToArray($tCur)
	FileWrite($path_LOG, "Universal XML Scraper [" & $Rev & "]" & @CRLF)
	FileWrite($path_LOG, "Demarrage le " & StringRight("0" & $dtCur[1], 2) & "/" & StringRight("0" & $dtCur[0], 2) & "/" & StringRight("0" & $dtCur[2], 2) & " - " & StringRight("0" & $dtCur[3], 2) & ":" & StringRight("0" & $dtCur[4], 2) & ":" & StringRight("0" & $dtCur[5], 2) & @CRLF & @CRLF)
EndFunc   ;==>_CREATION_LOG

Func _CREATION_LOGMESS($Mess)
	$tCur = _Date_Time_GetLocalTime()
	$dtCur = _Date_Time_SystemTimeToArray($tCur)
	FileWrite($path_LOG, "[" & StringRight("0" & $dtCur[3], 2) & ":" & StringRight("0" & $dtCur[4], 2) & ":" & StringRight("0" & $dtCur[5], 2) & "] - " & $Mess & @CRLF)
EndFunc   ;==>_CREATION_LOGMESS

Func _GUI_REFRESH($INI_P_CIBLE, $ScrapIP = 0)
;~ 	MsgBox(0, "$INI_P_CIBLE", $INI_P_CIBLE)
	GUICtrlSetState($MP, $GUI_ENABLE)
	GUICtrlSetData($MF, _MultiLang_GetText("mnu_file"))
	GUICtrlSetState($MF, $GUI_ENABLE)
	GUICtrlSetData($MF_Profil, _MultiLang_GetText("mnu_file_profil"))
	GUICtrlSetData($MF_XML, _MultiLang_GetText("mnu_file_xml"))
	GUICtrlSetData($MF_Exit, _MultiLang_GetText("mnu_file_exit"))
	GUICtrlSetData($ME, _MultiLang_GetText("mnu_edit"))
	GUICtrlSetState($ME, $GUI_ENABLE)
	GUICtrlSetData($ME_Langue, _MultiLang_GetText("mnu_edit_langue"))
	GUICtrlSetData($ME_Config, _MultiLang_GetText("mnu_edit_config"))
	GUICtrlSetData($MH, _MultiLang_GetText("mnu_help"))
	GUICtrlSetState($MH, $GUI_ENABLE)
	GUICtrlSetData($MH_Help, _MultiLang_GetText("mnu_help_about"))

	_GDIPlus_Startup()

	$hGraphic = _GDIPlus_GraphicsCreateFromHWND($F_UniversalEditor)
	$hImage = _GDIPlus_ImageLoadFromFile($Empty_Image)
	$hImage = _GDIPlus_ImageResize($hImage, 233, 121)
	_WinAPI_RedrawWindow($F_UniversalEditor, 0, 0, $RDW_UPDATENOW)
	_GDIPlus_GraphicsDrawImage($hGraphic, $hImage, 1, 1)
	_WinAPI_RedrawWindow($F_UniversalEditor, 0, 0, $RDW_VALIDATE)
;~ 	_GDIPlus_GraphicsDispose($hGraphic)
	_GDIPlus_ImageDispose($hImage)

;~ 	$hGraphic = _GDIPlus_GraphicsCreateFromHWND($F_UniversalEditor)
	$hImage = _GDIPlus_ImageLoadFromFile($INI_P_CIBLE)
	$ImageWidth = _GDIPlus_ImageGetWidth($hImage)
	$ImageHeight = _GDIPlus_ImageGetHeight($hImage)
	$NewImageWidth = 200
	$NewImageHeight = Round(($ImageHeight * 200) / $ImageWidth)
	If $NewImageHeight > 100 Then
		$NewImageHeight = 100
		$NewImageWidth = Round(($ImageWidth * 100) / $ImageHeight)
	EndIf

	Local $Left = (233 / 2) - ($NewImageWidth / 2) + 1
	Local $Top = (121 / 2) - ($NewImageHeight / 2) + 1

	$hImage = _GDIPlus_ImageResize($hImage, $NewImageWidth, $NewImageHeight)
	_WinAPI_RedrawWindow($F_UniversalEditor, 0, 0, $RDW_UPDATENOW)
	_GDIPlus_GraphicsDrawImage($hGraphic, $hImage, $Left, $Top)
	_WinAPI_RedrawWindow($F_UniversalEditor, 0, 0, $RDW_VALIDATE)
	_GDIPlus_GraphicsDispose($hGraphic)
	_GDIPlus_ImageDispose($hImage)
	_GDIPlus_Shutdown()

	GUICtrlSetData($H_LV_ROMLIST, _MultiLang_GetText("lv_roms"))
	GUICtrlSetData($H_LV_ATTRIBUT, _MultiLang_GetText("lv_attributs"))
	_GUICtrlStatusBar_SetText($SB_EDITOR, "")
	Return
EndFunc   ;==>_GUI_REFRESH

Func _GUI_Config()
	#Region ### START Koda GUI section ### Form=
	Local $F_CONFIG = GUICreate(_MultiLang_GetText("win_config_Title"), 242, 346, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))
	Local $B_CONFENREG = GUICtrlCreateButton(_MultiLang_GetText("win_config_Enreg"), 8, 312, 107, 25)
	Local $B_CONFANNUL = GUICtrlCreateButton(_MultiLang_GetText("win_config_Cancel"), 120, 312, 115, 25)
	Local $G_Scrape = GUICtrlCreateGroup(_MultiLang_GetText("win_config_GroupScrap"), 8, 0, 225, 153)
	Local $L_PathRom = GUICtrlCreateLabel(_MultiLang_GetText("win_config_GroupScrap_PathRom"), 16, 16, 208, 17)
	Local $I_PathRom = GUICtrlCreateInput(IniRead($PathConfigINI, "LAST_USE", "$PathRom", $PathRom), 16, 34, 177, 21)
	Local $B_PathRom = GUICtrlCreateButton("...", 198, 34, 27, 21)
	Local $L_PathXML = GUICtrlCreateLabel(_MultiLang_GetText("win_config_GroupScrap_PathXML"), 16, 56, 110, 15)
	Local $I_PathXML = GUICtrlCreateInput(IniRead($PathConfigINI, "LAST_USE", "$PathNew", $PathNew), 16, 74, 177, 21)
	Local $B_PathXML = GUICtrlCreateButton("...", 198, 74, 27, 21)
	Local $L_PathRomSub = GUICtrlCreateLabel(_MultiLang_GetText("win_config_GroupScrap_PathRomSub"), 16, 104, 208, 17)
	Local $I_PathRomSub = GUICtrlCreateInput(IniRead($PathConfigINI, "LAST_USE", "$PathRomSub", $PathRomSub), 16, 122, 177, 21)
	Local $B_PathRomSub = GUICtrlCreateButton("...", 198, 122, 27, 21)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	Local $G_Image = GUICtrlCreateGroup(_MultiLang_GetText("win_config_GroupImage"), 8, 160, 225, 145)
	Local $L_PathImage = GUICtrlCreateLabel(_MultiLang_GetText("win_config_GroupImage_PathImage"), 16, 176, 177, 21)
	Local $I_PathImage = GUICtrlCreateInput(IniRead($PathConfigINI, "LAST_USE", "$PathImage", $PathImage), 16, 194, 177, 21)
	Local $B_PathImage = GUICtrlCreateButton("...", 198, 194, 27, 21)
	Local $L_ImageHauteur = GUICtrlCreateLabel(_MultiLang_GetText("win_config_GroupImage_hautImage"), 24, 226, 40, 17)
	Local $I_ImageHauteur = GUICtrlCreateInput("", 72, 224, 41, 21)
	Local $L_LargeurImage = GUICtrlCreateLabel(_MultiLang_GetText("win_config_GroupImage_LongImage"), 120, 226, 49, 17)
	Local $I_LargeurImage = GUICtrlCreateInput("", 168, 224, 41, 21)
	Local $L_PathImageSub = GUICtrlCreateLabel(_MultiLang_GetText("win_config_GroupImage_PathImageSub"), 16, 256, 208, 17)
	Local $I_PathImageSub = GUICtrlCreateInput(IniRead($PathConfigINI, "LAST_USE", "$PathImageSub", $PathImageSub), 16, 274, 177, 21)
	Local $B_PathImageSub = GUICtrlCreateButton("...", 198, 274, 27, 21)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	GUISetState(@SW_SHOW)
	GUISetState(@SW_DISABLE, $F_UniversalEditor)
	#EndRegion ### END Koda GUI section ###

	While 1
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case $GUI_EVENT_CLOSE, $B_CONFANNUL
				GUIDelete($F_CONFIG)
				GUISetState(@SW_ENABLE, $F_UniversalEditor)
				WinActivate($F_UniversalEditor)
				Return
			Case $B_PathRom
				$PathRom = FileSelectFolder(_MultiLang_GetText("win_config_GroupScrap_PathRom"), GUICtrlRead($I_PathRom), $FSF_CREATEBUTTON, GUICtrlRead($I_PathRom), $F_CONFIG)
				If StringRight($PathRom, 1) <> '\' Then $PathRom = $PathRom & '\'
				GUICtrlSetData($I_PathRom, $PathRom)
			Case $B_PathXML
				$PathNew = FileSaveDialog(_MultiLang_GetText("win_config_GroupScrap_PathXML"), GUICtrlRead($I_PathXML), "xml (*.xml)", 18, "", $F_CONFIG)
				GUICtrlSetData($I_PathXML, $PathNew)
			Case $B_PathRomSub
				GUICtrlSetData($I_PathRomSub, FileSelectFolder(_MultiLang_GetText("win_config_GroupScrap_PathRomSub"), GUICtrlRead($I_PathRomSub), $FSF_CREATEBUTTON, GUICtrlRead($I_PathRomSub), $F_CONFIG))
			Case $B_PathImage
				$PathImage = FileSelectFolder(_MultiLang_GetText("win_config_GroupImage_PathImage"), GUICtrlRead($I_PathImage), $FSF_CREATEBUTTON, GUICtrlRead($I_PathImage), $F_CONFIG)
				If StringRight($PathImage, 1) <> '\' Then $PathImage = $PathImage & '\'
				GUICtrlSetData($I_PathImage, $PathImage)
			Case $B_PathImageSub
				GUICtrlSetData($I_PathImageSub, FileSelectFolder(_MultiLang_GetText("win_config_GroupImage_PathImageSub"), GUICtrlRead($I_PathImageSub), $FSF_CREATEBUTTON, GUICtrlRead($I_PathImageSub), $F_CONFIG))
			Case $B_CONFENREG
				$PathRom = GUICtrlRead($I_PathRom)
				IniWrite($PathConfigINI, "LAST_USE", "$PathRom", $PathRom)
				$PathRomSub = GUICtrlRead($I_PathRomSub)
				IniWrite($PathConfigINI, "LAST_USE", "$PathRomSub", $PathRomSub)
				$PathNew = GUICtrlRead($I_PathXML)
				IniWrite($PathConfigINI, "LAST_USE", "$PathNew", $PathNew)
				$PathImage = GUICtrlRead($I_PathImage)
				IniWrite($PathConfigINI, "LAST_USE", "$PathImage", $PathImage)
				$PathImageSub = GUICtrlRead($I_PathImageSub)
				IniWrite($PathConfigINI, "LAST_USE", "$PathImageSub", $PathImageSub)
				$HauteurImage = GUICtrlRead($I_ImageHauteur)
				If $HauteurImage < 1 Then $HauteurImage = ""
				IniWrite($PathConfigINI, "LAST_USE", "$HauteurImage", $HauteurImage)
				$LargeurImage = GUICtrlRead($I_LargeurImage)
				If $LargeurImage < 1 Then $LargeurImage = ""
				IniWrite($PathConfigINI, "LAST_USE", "$LargeurImage", $LargeurImage)
				If Not FileExists($PathNew) And $PathNew <> "" Then
					If Not _FileCreate($PathNew) Then MsgBox($MB_SYSTEMMODAL, "Error", "Error Creating: " & $PathNew & @CRLF & "     error:" & @error)
				EndIf
				_CREATION_LOGMESS("Modification de la config :" & @CRLF)
				_CREATION_LOGMESS(" PathRom : " & $PathRom)
				_CREATION_LOGMESS(" PathRomSub : " & $PathRomSub)
				_CREATION_LOGMESS(" PathNew : " & $PathNew)
				_CREATION_LOGMESS(" PathImage : " & $PathImage)
				_CREATION_LOGMESS(" PathImageSub : " & $PathImageSub)
				_CREATION_LOGMESS(" HauteurImage : " & $HauteurImage)
				_CREATION_LOGMESS(" LargeurImage : " & $LargeurImage & @CRLF)
				GUIDelete($F_CONFIG)
				GUISetState(@SW_ENABLE, $F_UniversalEditor)
				WinActivate($F_UniversalEditor)
				Return
		EndSwitch
	WEnd
EndFunc   ;==>_GUI_Config

Func _INI_CREATEARRAY_EDITOR()
	Local $A_Profil[1]
	Local $B_Profils = 1
	While IniRead($PathConfigINI, "PROFILS_EDITOR", "$PROFILS_EDITOR_" & $B_Profils, "Ending") <> "Ending"
		_ArrayAdd($A_Profil, IniRead($PathConfigINI, "PROFILS_EDITOR", "$PROFILS_EDITOR_" & $B_Profils, "default"))
		$B_Profils = $B_Profils + 1
	WEnd
	_CREATION_LOGMESS("Recuperation des Profil")
;~ 	_ArrayDisplay($A_Profil, '$A_Profil') ; Debug
	Return $A_Profil
EndFunc   ;==>_INI_CREATEARRAY_EDITOR

Func _LANG_LOAD($LANG_DIR, $user_lang)
	;Create an array of available language files
	; ** n=0 is the default language file
	; [n][0] = Display Name in Local Language (Used for Select Function)
	; [n][1] = Language File (Full path.  In this case we used a $LANG_DIR
	; [n][2] = [Space delimited] Character codes as used by @OS_LANG (used to select correct lang file)
	Local $LANGFILES[2][3]

	$LANGFILES[0][0] = "English (US)" ;
	$LANGFILES[0][1] = $LANG_DIR & "\UXE-ENGLISH.XML"
	$LANGFILES[0][2] = "0409 " & _ ;English_United_States
			"0809 " & _ ;English_United_Kingdom
			"0c09 " & _ ;English_Australia
			"1009 " & _ ;English_Canadian
			"1409 " & _ ;English_New_Zealand
			"1809 " & _ ;English_Irish
			"1c09 " & _ ;English_South_Africa
			"2009 " & _ ;English_Jamaica
			"2409 " & _ ;English_Caribbean
			"2809 " & _ ;English_Belize
			"2c09 " & _ ;English_Trinidad
			"3009 " & _ ;English_Zimbabwe
			"3409" ;English_Philippines

	$LANGFILES[1][0] = "Francais" ; French
	$LANGFILES[1][1] = $LANG_DIR & "\UXE-FRENCH.XML"
	$LANGFILES[1][2] = "040c " & _ ;French_Standard
			"080c " & _ ;French_Belgian
			"0c0c " & _ ;French_Canadian
			"100c " & _ ;French_Swiss
			"140c " & _ ;French_Luxembourg
			"180c" ;French_Monaco

	;Set the available language files, names, and codes.
	_MultiLang_SetFileInfo($LANGFILES)
	If @error Then
		MsgBox(48, "Error", "Could not set file info.  Error Code " & @error)
		Exit
	EndIf

	;Check if the loaded settings file exists.  If not ask user to select language.
	If $user_lang = -1 Then
		;Create Selection GUI
		$user_lang = _LANGUE_SelectGUI($LANGFILES)
		If @error Then
			MsgBox(48, "Error", "Could not create selection GUI.  Error Code " & @error)
			Exit
		EndIf
		IniWrite($PathConfigINI, "LAST_USE", "$user_lang", $user_lang)
	EndIf

	Local $ret = _MultiLang_LoadLangFile($user_lang)
	If @error Then
		MsgBox(48, "Error", "Could not load lang file.  Error Code " & @error)
		Exit
	EndIf

	;If you supplied an invalid $user_lang, we will load the default language file
	If $ret = 2 Then
		MsgBox(64, "Information", "Just letting you know that we loaded the default language file")
	EndIf

	Return $LANGFILES
EndFunc   ;==>_LANG_LOAD

Func _LANGUE_SelectGUI($_gh_aLangFileArray, $default = @OSLang)
	GUISetState(@SW_DISABLE, $F_UniversalEditor)
	If $_gh_aLangFileArray = -1 Then Return SetError(1, 0, 0)
	If IsArray($_gh_aLangFileArray) = 0 Then Return SetError(1, 0, 0)
	Local $_multilang_gui_GUI = GUICreate(_MultiLang_GetText("win_sel_langue_Title"), 230, 100)
	Local $_multilang_gui_Combo = GUICtrlCreateCombo("(" & _MultiLang_GetText("win_sel_langue_Title") & ")", 8, 48, 209, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $_multilang_gui_Button = GUICtrlCreateButton(_MultiLang_GetText("win_sel_langue_button"), 144, 72, 75, 25)
	Local $_multilang_gui_Label = GUICtrlCreateLabel(_MultiLang_GetText("win_sel_langue_text"), 8, 8, 212, 33)

	;Create List of available languages
	For $i = 0 To UBound($_gh_aLangFileArray) - 1
		GUICtrlSetData($_multilang_gui_Combo, $_gh_aLangFileArray[$i][0], "(" & _MultiLang_GetText("win_sel_langue_Title") & ")")
	Next

	GUISetState(@SW_SHOW)
	While 1
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case -3, $_multilang_gui_Button
				ExitLoop
		EndSwitch
	WEnd
	Local $_selected = GUICtrlRead($_multilang_gui_Combo)
	GUIDelete($_multilang_gui_GUI)
	For $i = 0 To UBound($_gh_aLangFileArray) - 1
		If StringInStr($_gh_aLangFileArray[$i][0], $_selected) Then
			GUISetState(@SW_ENABLE, $F_UniversalEditor)
			WinActivate($F_UniversalEditor)
			Return StringLeft($_gh_aLangFileArray[$i][2], 4)
		EndIf
	Next
	GUISetState(@SW_ENABLE, $F_UniversalEditor)
	WinActivate($F_UniversalEditor)
	Return $default
EndFunc   ;==>_LANGUE_SelectGUI

Func _PROFIL_SelectGUI($A_Profil)
	GUISetState(@SW_DISABLE, $F_UniversalEditor)
	If $A_Profil = -1 Then Return SetError(1, 0, 0)
	If IsArray($A_Profil) = 0 Then Return SetError(1, 0, 0)
	Local $_profil_gui_GUI = GUICreate(_MultiLang_GetText("win_sel_profil_Title"), 230, 100)
	Local $_profil_gui_Combo = GUICtrlCreateCombo("(" & _MultiLang_GetText("win_sel_profil_Title") & ")", 8, 48, 209, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $_profil_gui_Button = GUICtrlCreateButton(_MultiLang_GetText("win_sel_profil_button"), 144, 72, 75, 25)
	Local $_profil_gui_Label = GUICtrlCreateLabel(_MultiLang_GetText("win_sel_profil_text"), 8, 8, 212, 33)

	;Create List of available profile
	For $i = 1 To UBound($A_Profil) - 1
		GUICtrlSetData($_profil_gui_Combo, $A_Profil[$i], "(" & _MultiLang_GetText("win_sel_profil_Title") & ")")
	Next

	GUISetState(@SW_SHOW)
	While 1
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case -3, $_profil_gui_Button
				ExitLoop
		EndSwitch
	WEnd
	Local $_selected = GUICtrlRead($_profil_gui_Combo)
	GUIDelete($_profil_gui_GUI)
	For $i = 1 To UBound($A_Profil) - 1
		If StringInStr($A_Profil[$i], $_selected) Then
			IniWrite($PathConfigINI, "LAST_USE", "$No_Profil", $i)
			GUISetState(@SW_ENABLE, $F_UniversalEditor)
			WinActivate($F_UniversalEditor)
			Return $i
		EndIf
	Next
	GUISetState(@SW_ENABLE, $F_UniversalEditor)
	WinActivate($F_UniversalEditor)
	Return 1
EndFunc   ;==>_PROFIL_SelectGUI

Func _XML_CREATEFORMAT($Profil, $PathConfigINI)
	Local $A_XMLFormat[1][3]
	Local $B_Elements = 1
	_CREATION_LOGMESS("Recuperation des champs du profil")
	While IniRead($PathConfigINI, $Profil, "$ELEMENT_" & $B_Elements, "Ending") <> "Ending"
		_ArrayAdd($A_XMLFormat, IniRead($PathConfigINI, $Profil, "$ELEMENT_" & $B_Elements, ""))
		$B_Elements = $B_Elements + 1
	WEnd
;~ 	_ArrayDisplay($A_XMLFormat, '$A_XMLFormat') ; Debug
	Return $A_XMLFormat
EndFunc   ;==>_XML_CREATEFORMAT

Func _ROM_CREATEARRAY($V_XMLPath, $A_XMLFormat)
	Local $Nb_XMLElements = UBound($A_XMLFormat) - 1
	Local $xpath_root, $xpath_child, $xpath_Unique

	For $B_XMLElements = 0 To $Nb_XMLElements - 1
		If $A_XMLFormat[$B_XMLElements][1] = "root" Then Local $xpath_root = "//" & $A_XMLFormat[$B_XMLElements][0]
		If $A_XMLFormat[$B_XMLElements][1] = "child" Then Local $xpath_child = "/" & $A_XMLFormat[$B_XMLElements][0]
		If $A_XMLFormat[$B_XMLElements][2] = "unique" Then Local $xpath_Unique = "/" & $A_XMLFormat[$B_XMLElements][0]

	Next

	ConsoleWrite("$xpath_root : " & $xpath_root & @CRLF) ; Debug
	ConsoleWrite("$xpath_child : " & $xpath_root & $xpath_child & @CRLF) ; Debug
	ConsoleWrite("$xpath_Unique : " & $xpath_root & $xpath_child & $xpath_Unique & @CRLF) ; Debug

	_XMLFileOpen($V_XMLPath)
	If @error Then
		ConsoleWrite("!_XMLFileOpen : " & $V_XMLPath & " : " & _XMLError("") & @CRLF) ; Debug
		Return -1
	EndIf

	Local $A_Nodes = _XMLGetChildNodes($xpath_root)
	If @error Then
		ConsoleWrite("!__XMLGetChildNodes : " & $V_XMLPath & " : " & _XMLError("") & @CRLF) ; Debug
		Return -1
	EndIf

	Dim $A_ROMList[UBound($A_Nodes)][4]

	For $B_Nodes = 1 To UBound($A_Nodes) - 1
		Local $sNode_Values = _XMLGetValue($xpath_root & "/*[" & $B_Nodes & "]" & $xpath_Unique)
		If IsArray($sNode_Values) Then
			$A_ROMList[$B_Nodes][0] = $sNode_Values[1]
			$sNode_Values_Temp = StringSplit($sNode_Values[1], '\')
			If $sNode_Values_Temp[0] <= 1 Then
				$sNode_Values_Temp = StringSplit($sNode_Values[1], '/')
				For $B_sNode_Values_Temp = 1 To $sNode_Values_Temp[0] - 1
					$A_ROMList[$B_Nodes][1] = $A_ROMList[$B_Nodes][1] & $sNode_Values_Temp[$B_sNode_Values_Temp] & '/'
				Next
			Else
				For $B_sNode_Values_Temp = 1 To $sNode_Values_Temp[0] - 1
					$A_ROMList[$B_Nodes][1] = $A_ROMList[$B_Nodes][1] & $sNode_Values_Temp[$B_sNode_Values_Temp] & '\'
				Next
			EndIf
;~ 			_ArrayDisplay($sNode_Values_Temp, '$sNode_Values_Temp') ; Debug
			$A_ROMList[$B_Nodes][1] = StringTrimRight($A_ROMList[$B_Nodes][0], StringLen($sNode_Values_Temp[$sNode_Values_Temp[0]]))
			$A_ROMList[$B_Nodes][2] = $sNode_Values_Temp[$sNode_Values_Temp[0]]
			$A_ROMList[$B_Nodes][3] = $B_Nodes - 1
		EndIf
	Next
	_ArrayDelete($A_ROMList, "0")
	_ArraySort($A_ROMList)
;~ 	_ArrayDisplay($A_ROMList, '$A_ROMList') ; Debug
	Return $A_ROMList
EndFunc   ;==>_ROM_CREATEARRAY

Func _XML_CREATEARRAY($V_XMLPath, $A_XMLFormat, $RomSelected)
	Local $Nb_XMLElements = UBound($A_XMLFormat) - 1
	Local $xpath_root
	Local $A_XMLFormat_TEMP[0]
	Local $PathImageSub_Temp = $INI_P_CIBLE
	_ArrayAdd($A_XMLFormat_TEMP, "")

	For $B_XMLElements = 0 To $Nb_XMLElements
;~ 		If $A_XMLFormat[$B_XMLElements][1] = "root" Then Local $xpath_root = "//" & $A_XMLFormat[$B_XMLElements][0]
		Switch StringLeft($A_XMLFormat[$B_XMLElements][1], 5)
			Case "root"
				Local $xpath_root = "//" & $A_XMLFormat[$B_XMLElements][0]
			Case "value"
				_ArrayAdd($A_XMLFormat_TEMP, $A_XMLFormat[$B_XMLElements][0] & "    ")
			Case "path:"
				If $A_XMLFormat[$B_XMLElements][2] = 'view' Then
					_ArrayAdd($A_XMLFormat_TEMP, $A_XMLFormat[$B_XMLElements][0] & "view")
				Else
					_ArrayAdd($A_XMLFormat_TEMP, $A_XMLFormat[$B_XMLElements][0] & "    ")
				EndIf
		EndSwitch
	Next
;~ 	_ArrayDelete($A_XMLFormat_TEMP, 0)

	ConsoleWrite("$xpath_root : " & $xpath_root & @CRLF) ; Debug

	_XMLFileOpen($V_XMLPath)
	If @error Then
		ConsoleWrite("!_XMLFileOpen : " & $V_XMLPath & " : " & _XMLError("") & @CRLF) ; Debug
		Return -1
	EndIf

	Dim $A_XMLList[UBound($A_XMLFormat_TEMP)][2]

	For $B_Nodes = 1 To UBound($A_XMLFormat_TEMP) - 1
		$A_XMLList[$B_Nodes][0] = StringTrimRight($A_XMLFormat_TEMP[$B_Nodes], 4)
		Local $sNode_Values = _XMLGetValue($xpath_root & "/*[" & $RomSelected + 1 & "]/" & StringTrimRight($A_XMLFormat_TEMP[$B_Nodes], 4))
		If IsArray($sNode_Values) Then
			ConsoleWrite($A_XMLFormat_TEMP[$B_Nodes] & "=" & $sNode_Values[1] & @CRLF);Debug
			$A_XMLList[$B_Nodes][1] = $sNode_Values[1]
			If StringRight($A_XMLFormat_TEMP[$B_Nodes], 4) = 'view' Then

				$TMP_Path = StringSplit($sNode_Values[1], "/")
				If $TMP_Path[1] = "" Then $TMP_Path = StringSplit($sNode_Values[1], "\")
;~ 				_ArrayDisplay($TMP_Path, "$TMP_Path")
				$TMP_File = _ALLTRIM($TMP_Path[$TMP_Path[0]])
				ConsoleWrite("-$TMP_File :" & $TMP_File & @CRLF)
				Local $PathImageSub_Temp = $PathImage & $TMP_File
				ConsoleWrite("+IMAGE :" & $PathImageSub_Temp & @CRLF)
			EndIf
		Else
		EndIf
	Next
	_GUI_REFRESH($PathImageSub_Temp)
	_ArrayDelete($A_XMLList, "0")
;~ 	_ArrayDisplay($A_XMLList, '$A_XMLList') ; Debug
	Return $A_XMLList
EndFunc   ;==>_XML_CREATEARRAY

Func _XML_UPDATEINFO($V_XMLPath, $A_XMLFormat, $RomSelected, $V_AttribSelected_TEMP, $V_AttribSelected_Value_TEMP)
	Local $Nb_XMLElements = UBound($A_XMLFormat) - 1
	Local $xpath_root
	Local $A_XMLFormat_TEMP[0]

	For $B_XMLElements = 0 To $Nb_XMLElements
		If $A_XMLFormat[$B_XMLElements][1] = "root" Then Local $xpath_root = "//" & $A_XMLFormat[$B_XMLElements][0]
	Next

	ConsoleWrite("$xpath_root : " & $xpath_root & @CRLF) ; Debug

	_XMLFileOpen($V_XMLPath)
	If @error Then
		ConsoleWrite("!_XMLFileOpen : " & $V_XMLPath & " : " & _XMLError("") & @CRLF) ; Debug
		Return -1
	EndIf

	$Result = _XMLUpdateField($xpath_root & "/*[" & $RomSelected + 1 & "]/" & $V_AttribSelected_TEMP, $V_AttribSelected_Value_TEMP)
	If $Result = -1 Then _XMLCreateChildNode($xpath_root & "/*[" & $RomSelected + 1 & "]", $V_AttribSelected_TEMP, $V_AttribSelected_Value_TEMP)

	Return
EndFunc   ;==>_XML_UPDATEINFO

Func _EDIT_REPLACE($A_ROMList, $A_XMLFormat, $V_XMLPath)
	GUISetState(@SW_DISABLE, $F_UniversalEditor)
	Local $Nb_XMLElements = UBound($A_XMLFormat) - 1
	Local $xpath_root
	Local $A_XMLFormat_TEMP[0]
	_ArrayAdd($A_XMLFormat_TEMP, "")

;~ 	_ArrayDisplay($A_XMLFormat, '$A_XMLFormat') ; Debug

	Local $_edit_replace_attribut_gui_GUI = GUICreate(_MultiLang_GetText("win_replace_Title"), 230, 220)
	Local $_edit_replace_attribut_gui_ComboLabel = GUICtrlCreateLabel(_MultiLang_GetText("win_replace_text"), 8, 8, 212, 33)
	Local $_edit_replace_attribut_gui_Combo = GUICtrlCreateCombo("(" & _MultiLang_GetText("win_replace_Title") & ")", 8, 48, 209, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
	Local $_edit_replace_attribut_gui_SourceLabel = GUICtrlCreateLabel(_MultiLang_GetText("win_replace_source"), 8, 72, 212, 17)
	Local $_edit_replace_attribut_gui_SourceInput = GUICtrlCreateInput("", 8, 96, 209, 21)
	Local $_edit_replace_attribut_gui_CibleLabel = GUICtrlCreateLabel(_MultiLang_GetText("win_replace_cible"), 8, 120, 212, 17)
	Local $_edit_replace_attribut_gui_CibleInput = GUICtrlCreateInput("", 8, 144, 209, 21)
	Local $_edit_replace_attribut_gui_ReplaceButton = GUICtrlCreateButton(_MultiLang_GetText("win_replace_button"), 8, 184, 75, 25)
	Local $_edit_replace_attribut_gui_CancelButton = GUICtrlCreateButton(_MultiLang_GetText("win_replace_cancelbutton"), 144, 184, 75, 25)

	For $B_XMLElements = 0 To $Nb_XMLElements
		If StringLeft($A_XMLFormat[$B_XMLElements][1], 5) = "value" Or StringLeft($A_XMLFormat[$B_XMLElements][1], 5) = "path:" Then _ArrayAdd($A_XMLFormat_TEMP, $A_XMLFormat[$B_XMLElements][0])
	Next
	_ArrayDelete($A_XMLFormat_TEMP, 0)

	;Create List of available attribut
	For $i = 0 To UBound($A_XMLFormat_TEMP) - 1
		GUICtrlSetData($_edit_replace_attribut_gui_Combo, $A_XMLFormat_TEMP[$i], "(" & _MultiLang_GetText("win_replace_Title") & ")")
	Next

	GUISetState(@SW_SHOW)
	While 1
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case $GUI_EVENT_CLOSE, $_edit_replace_attribut_gui_CancelButton
				GUIDelete($_edit_replace_attribut_gui_GUI)
				GUISetState(@SW_ENABLE, $F_UniversalEditor)
				WinActivate($F_UniversalEditor)
				Return
			Case $_edit_replace_attribut_gui_ReplaceButton
				Local $_selected = GUICtrlRead($_edit_replace_attribut_gui_Combo)
				Local $_SourceInput = GUICtrlRead($_edit_replace_attribut_gui_SourceInput)
				Local $_CibleInput = GUICtrlRead($_edit_replace_attribut_gui_CibleInput)

				For $B_XMLElements = 0 To $Nb_XMLElements
					If $A_XMLFormat[$B_XMLElements][1] = "root" Then Local $xpath_root = "//" & $A_XMLFormat[$B_XMLElements][0]
				Next

				_XMLFileOpen($V_XMLPath)
				If @error Then
					ConsoleWrite("!_XMLFileOpen : " & $V_XMLPath & " : " & _XMLError("") & @CRLF) ; Debug
					Return -1
				EndIf

				For $B_XMLList = 0 To UBound($A_XMLList) - 1
					Local $sNode_Values = _XMLGetValue($xpath_root & "/*[" & $B_XMLList & "]/" & $_selected)
					If IsArray($sNode_Values) Then
						ConsoleWrite($_selected & "=" & $sNode_Values[1] & @CRLF);Debug
						$XMLValue = StringReplace($sNode_Values[1], $_SourceInput, $_CibleInput)
						_XMLUpdateField($xpath_root & "/*[" & $B_XMLList & "]/" & $_selected, StringReplace($XMLValue, $_SourceInput, $_CibleInput))
						ConsoleWrite('>' & $_selected & "=" & $XMLValue & @CRLF);Debug
					EndIf
				Next
				GUIDelete($_edit_replace_attribut_gui_GUI)
				GUISetState(@SW_ENABLE, $F_UniversalEditor)
				WinActivate($F_UniversalEditor)
				Return
		EndSwitch
	WEnd

EndFunc   ;==>_EDIT_REPLACE


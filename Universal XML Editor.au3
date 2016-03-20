#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Ressources\Universal_Xml_Editor.ico
#AutoIt3Wrapper_Outfile=..\BIN\Universal_XML_Editor.exe
#AutoIt3Wrapper_Outfile_x64=..\BIN\Universal_XML_Editor64.exe
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Description=Editeur XML Universel
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
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
FileInstall(".\Ressources\plink.exe", $SOURCE_DIRECTORY & "\Ressources\plink.exe")
FileInstall(".\Ressources\empty.jpg", $SOURCE_DIRECTORY & "\Ressources\empty.jpg")

;Definition des Variables
;-------------------------
Global $LANG_DIR = $SOURCE_DIRECTORY & "\LanguageFiles"; Where we are storing the language files.
Global $INI_P_CIBLE = $SOURCE_DIRECTORY & "\Ressources\empty.jpg"
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
Global $Rev
If @Compiled Then
	$Rev = "BETA " & FileGetVersion(@ScriptFullPath)
Else
	$Rev = 'In Progress'
EndIf

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
Local $ME_Langue = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_edit_langue"), $ME)
Local $ME_Config = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_edit_config"), $ME)
Local $MP = GUICtrlCreateMenu("SSH")
Local $MP_KILLALL = GUICtrlCreateMenuItem("KillAll Emulationstation", $MP)
Local $MP_REBOOT = GUICtrlCreateMenuItem("Reboot", $MP)
Local $MP_POWEROFF = GUICtrlCreateMenuItem("Power off", $MP)
GUICtrlSetState($MP, $GUI_DISABLE)
Local $MH = GUICtrlCreateMenu(_MultiLang_GetText("mnu_help"))
Local $MH_Help = GUICtrlCreateMenuItem(_MultiLang_GetText("mnu_help_about"), $MH)
Local $H_LV_ROMLIST = GUICtrlCreateListView("Roms", 3, 122, 226, 430, $LVS_SHOWSELALWAYS)
_GUICtrlListView_SetExtendedListViewStyle($H_LV_ROMLIST, $LVS_EX_FULLROWSELECT)
_GUICtrlListView_SetColumnWidth($H_LV_ROMLIST, 0, 206)
Local $H_LV_ATTRIBUT = GUICtrlCreateListView("Attributs|Valeurs", 232, 4, 562, 548, $LVS_SHOWSELALWAYS)
_GUICtrlListView_SetExtendedListViewStyle($H_LV_ATTRIBUT, $LVS_EX_FULLROWSELECT)
_GUICtrlListView_SetColumnWidth($H_LV_ATTRIBUT, 0, 313)
Local $P_CIBLE = GUICtrlCreatePic($INI_P_CIBLE, 18, 8, 196, 100)
Local $SB_EDITOR = _GUICtrlStatusBar_Create($F_UniversalEditor)
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

; Initialisation interface
Local $A_Profil = _INI_CREATEARRAY_EDITOR()
Local $INI_P_CIBLE = IniRead($PathConfigINI, $A_Profil[$No_Profil], "$IMAGE_CIBLE", "empty.jpg")
_GUI_REFRESH($INI_P_CIBLE)

While 1
	$nMsg = GUIGetMsg()
	Switch $nMsg
		Case $GUI_EVENT_CLOSE, $MF_Exit
			Exit
		Case $MF_Profil
			$No_Profil = _PROFIL_SelectGUI($A_Profil)
			$INI_P_CIBLE = IniRead($PathConfigINI, $A_Profil[$No_Profil], "$IMAGE_CIBLE", "empty.jpg")
			_CREATION_LOGMESS("Profil : " & $A_Profil[$No_Profil])
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
			_GUIListViewEx_Close(0)
			_GUICtrlListView_DeleteAllItems($H_LV_ROMLIST)
			_GUICtrlListView_DeleteAllItems($H_LV_ATTRIBUT)
			Local $V_XMLPath = FileOpenDialog(_MultiLang_GetText("win_sel_xml_Title"), "c:\", 'XML (*.xml)', $FD_FILEMUSTEXIST, "gamelist.xml")
			$A_XMLFormat = _XML_CREATEFORMAT($A_Profil[$No_Profil], $PathConfigINI)
			$A_ROMList = _ROM_CREATEARRAY($V_XMLPath, $A_XMLFormat)
			For $B_ROMList = 0 To UBound($A_ROMList) - 1
				_GUICtrlListView_AddItem($H_LV_ROMLIST, $A_ROMList[$B_ROMList][2])
			Next
			$I_LV_ATTRIBUTE = _GUIListViewEx_Init($H_LV_ROMLIST, $A_ROMList, 0, 0, True)
;~ 			_GUIListViewEx_MsgRegister() ;Register pour le drag&drop
;~ 			_GUIListViewEx_SetActive(1) ;Activation de la LV de gauche
		Case $H_LV_ROMLIST
			_GUIListViewEx_SetActive(1) ;Activation de la LV de gauche
			$A_Selected = _GUICtrlListView_GetSelectedIndices($H_LV_ROMLIST, True)
			ConsoleWrite("nb de selectionné : " & $A_Selected[0] & " - 1 er : " & $A_Selected[1] & " - Dernier : " & $A_Selected[$A_Selected[0]] & @CRLF)
	EndSwitch
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
	GUICtrlSetState($MP, $GUI_ENABLE)
	GUICtrlSetData($MF, _MultiLang_GetText("mnu_file"))
	GUICtrlSetState($MF, $GUI_ENABLE)
	GUICtrlSetData($MF_Profil, _MultiLang_GetText("mnu_file_profil"))
	GUICtrlSetData($MF_Exit, _MultiLang_GetText("mnu_file_exit"))
	GUICtrlSetData($ME, _MultiLang_GetText("mnu_edit"))
	GUICtrlSetState($ME, $GUI_ENABLE)
	GUICtrlSetData($ME_Langue, _MultiLang_GetText("mnu_edit_langue"))
	GUICtrlSetData($ME_Config, _MultiLang_GetText("mnu_edit_config"))
	GUICtrlSetData($MH, _MultiLang_GetText("mnu_help"))
	GUICtrlSetState($MH, $GUI_ENABLE)
	GUICtrlSetData($MH_Help, _MultiLang_GetText("mnu_help_about"))
	GUICtrlSetImage($P_CIBLE, $SOURCE_DIRECTORY & "\Ressources\" & $INI_P_CIBLE)
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
	$LANGFILES[0][1] = $LANG_DIR & "\UXS-ENGLISH.XML"
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

	$LANGFILES[1][0] = "Français" ; French
	$LANGFILES[1][1] = $LANG_DIR & "\UXS-FRENCH.XML"
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
	Local $A_XMLFormat[1][2]
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
		If $A_XMLFormat[$B_XMLElements][1] = "path:rom" Then Local $xpath_Unique = "/" & $A_XMLFormat[$B_XMLElements][0]

	Next

	ConsoleWrite("$xpath_root : " & $xpath_root & @CRLF) ; Debug
	ConsoleWrite("$xpath_child : " & $xpath_root & $xpath_child & @CRLF) ; Debug
	ConsoleWrite("$xpath_Unique : " & $xpath_root & $xpath_child & $xpath_Unique & @CRLF) ; Debug

	_XMLFileOpen($V_XMLPath)
	If @error Then
		ConsoleWrite("!_XMLFileOpen : " & $V_XMLPath & " : " & _XMLError("") & @CRLF) ; Debug
		FileDelete($PathTmp)
		Return -1
	EndIf

	Local $A_Nodes = _XMLGetChildNodes($xpath_root)
	If @error Then
		ConsoleWrite("!__XMLGetChildNodes : " & $V_XMLPath & " : " & _XMLError("") & @CRLF) ; Debug
		FileDelete($PathTmp)
		Return -1
	EndIf

	Dim $A_ROMList[UBound($A_Nodes)][3]

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
		EndIf
	Next
	_ArrayDelete($A_ROMList, "0")
;~ 	_ArrayDisplay($A_ROMList, '$A_ROMList') ; Debug
	Return $A_ROMList
EndFunc   ;==>_ROM_CREATEARRAY


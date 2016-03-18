; ===========================
; MyFunctions.au3 for AutoIt3
; ===========================
; Author:	Brett Sinclair
;			email: autoitdev@pgsd.co.nz
;			31 July 2005
;
; Purpose:	Implements new functions _RTRIM(), _LTRIM(), _ALLTRIM()
;
;			To implement functions equivalent to the old dBase functions that removed spaces
;			from the, respectively, right, left and both left and right of a character string.
;			The function _TRIM() is equivalent to _RTRIM() and is provided for consistency with
;			the old dBase standard.
;
;			These four functions remove contiguous characters from the left and/or right of a character string
;			but not those that are within the string. For example _RTRIM("Mary had a little lamb   ")
;			will become "Mary had a little lamb" - the spaces inside the string are not removed.
;
; Syntax:	ResultString = <FunctionName>( string1, string2 )
;
;			<FunctionName> as above: _RTRIM(), _LTRIM(), _ALLTRIM(), _TRIM()
;			string1 is the character string to examine.
;			string2 is a list of the characters to be examined for; if omitted it defaults to the standard space character, chr(32).
;			ResultString is the string returned by the function with all characters in string2 trimmed from the left and/or right
;			of string1.
;
;			If string2 = "%%whs%%" all white space characters will be trimmed from string1.
;			Whitespace includes Chr(9) thru Chr(13) which are HorizontalTab, LineFeed, VerticalTab, FormFeed, and CarriageReturn.
;			Whitespace also includes the standard space character.
;
;			ResultString will be shorter than string1 by an amount equal to the number of characters trimmed from string1.
;
;			These functions are not case sensitive, e.g. "m" in string2 will trim both "M" and "m" from string1.
;
;			On any error condition ResultString will be equal to string1.
;
; Examples:	_RTRIM("Mary had a little lamb    ")  -> "Mary had a little lamb"
;			_RTRIM("Mary had a little giraffe xyxyxyz", "xyz")	-> "Mary had a little giraffe " (note space at end has not been removed).
;			_RTRIM("Mary had a little giraffe xyxyxyz", " xyz") -> "Mary had a little giraffe" (now the same space has been removed because
;																		a space is now included in string2).
;			_RTRIM("Mary had a little giraffe xyxbyxyz", "xyz") -> "Mary had a little giraffe xyxb" (only the x, y and z following the "b"
;																		will be removed because the "b" is not in string2.
;
; To use:	1.  Copy this script to the "Include" folder under the AutoIt programs folder.
;				(for example: c:\program files\autoit3\include\myfunctions.au3 )
;			2.	In your Autoit3 script have following statement:
;				#include <myfunctions.au3>
;			3.  "myfunctions" can be renamed to anything you want.
;
; Disclaimer: Thoroughly tested and debugged, but use entirely at your own risk.
;			  Usage automatically acknowledges acceptance of this condition.
; ==============================================================================================
;
func _LTRIM($sString, $sTrimChars=' ')

	$sTrimChars = StringReplace( $sTrimChars, "%%whs%%", " " & chr(9) & chr(11) & chr(12) & @CRLF )
	local $nCount, $nFoundChar
	local $aStringArray = StringSplit($sString, "")
	local $aCharsArray = StringSplit($sTrimChars, "")

	for $nCount = 1 to $aStringArray[0]
		$nFoundChar = 0
		for $i = 1 to $aCharsArray[0]
			if $aCharsArray[$i] = $aStringArray[$nCount] then
				$nFoundChar = 1
			EndIf
		next
		if $nFoundChar = 0 then return StringTrimLeft( $sString, ($nCount-1) )
	next
endfunc
; ==============================================================================================
;
func _RTRIM($sString, $sTrimChars=' ')

	$sTrimChars = StringReplace( $sTrimChars, "%%whs%%", " " & chr(9) & chr(11) & chr(12) & @CRLF )
	local $nCount, $nFoundChar
	local $aStringArray = StringSplit($sString, "")
	local $aCharsArray = StringSplit($sTrimChars, "")

	for $nCount = $aStringArray[0] to 1 step -1
		$nFoundChar = 0
		for $i = 1 to $aCharsArray[0]
			if $aCharsArray[$i] = $aStringArray[$nCount] then
				$nFoundChar = 1
			EndIf
		next
		if $nFoundChar = 0 then return StringTrimRight( $sString, ($aStringArray[0] - $nCount) )
	next
endfunc
; ==============================================================================================
;
func _ALLTRIM($sString, $sTrimChars=' ')

	;  Trim from left first, then right

	$sTrimChars = StringReplace( $sTrimChars, "%%whs%%", " " & chr(9) & chr(11) & chr(12) & @CRLF )
	local $sStringWork = ""

	$sStringWork = _LTRIM($sString, $sTrimChars)
	if $sStringWork <> "" then
		$sStringWork = _RTRIM($sStringWork, $sTrimChars)
	endif
	return $sStringWork

endfunc
; ==============================================================================================
;
func _TRIM($sString, $sTrimChars=' ')		; Equivalent to _RTRIM() and provided for dBase equivalence.

	return _RTRIM( $sString, $sTrimChars )

endfunc
; ==============================================================================================
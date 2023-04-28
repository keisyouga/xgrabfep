## user config file

# show debug message
set ::_debugPuts 0

# hotkeys
set config(grabKey) Alt-J
set config(ungrabKey) Alt-K
set config(toggleGrabKey) Alt-Kanji
set config(quitKey) Alt-Shift-Q

# preset some map and dic combinations for convenience
proc setMode {name map dic} {
	global modeName mapFile mapDict dicFile dicDict
	set modeName $name
	set mapFile $map
	set mapDict [loadMapOrDic $mapFile]
	set dicFile $dic
	set dicDict [loadMapOrDic $dicFile]
}
proc nomapMode {} {
	global modeName mapFile mapDict
	set modeName nomapMode
	set mapFile {}
	set mapDict {}
}
proc nodicMode {} {
	global modeName dicFile dicDict
	set modeName nodicMode
	set dicFile {}
	set dicDict {}
}
proc hiraganaMode {} {
	setMode hiraganaMode "map/ja-hiragana.map" ""
}
proc katakanaMode {} {
	setMode katakanaMode "map/ja-katakana.map" ""
}
proc cangjieMode {} {
	setMode cangjieMode "" "dic/cangjie35-jis.dic"
}
proc skkdicMode {} {
	setMode skkdicMode "map/ja-hiragana.map" "dic/skk-jisyo.dic"
}
# used as change mode command when alt+numer is pressed
set modeNameList {nomapMode hiraganaMode katakanaMode cangjieMode skkdicMode nodicMode}
# set current mode name
set modeName [lindex $modeNameList 0]
# initial mode
hiraganaMode

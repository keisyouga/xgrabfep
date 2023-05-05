#!/bin/sh
# the next line restarts using wish \
    exec wish "$0" ${1+"$@"}

# add directory lib to auto_path
set scriptDir [file dirname [file normalize [info script]]]
lappend ::auto_path [file join $scriptDir lib]

# config file is located in parent directory of main.tcl
set configDir [file dirname $scriptDir]
# config file path
set configFile [file join $::configDir "config.tcl"]
# change working directory to configdir
cd $configDir

package require Tk
package require tkxwin

################################################################
#
# functions
#

set _debugPuts 0

proc debugPuts {msg} {
	global _debugPuts
	if {$_debugPuts} {
		puts stderr $msg
	}
}

# make no inputString state
proc reset {} {
	global inputString mappedString precommitString
	global candList candLabel

	debugPuts "reset"

	set precommitString {}
	set mappedString {}
	set inputString {}
	set candList {}
	set candLabel {}

	wm withdraw .candwin
}

# send $str to the target window
proc commit {str} {
	debugPuts "commit : <$str>"

	tkxwin::sendUnicode -delay 100000 $str

	reset
}

# make candidate string
proc makeCandLabel {candl pos npage} {
	set page [expr $pos / $npage]
	set pos0 [expr $page * $npage]

	# show "current_position/max_cands"
	set str "[expr $pos + 1]/[llength $candl]\n"
	for {set i $pos0} {($i < [expr $pos0 + $npage]) && ($i < [llength $candl])} {incr i} {
		append str "[expr ($i + 1) % $npage] "
		# mark selected item
		if {$i == $pos} {
			append str "*"
		}
		append str "[lindex $candl $i]\n"
	}
	return $str
}

# callback of grabbed window
# return true if you don't want to send original key event to the target window
proc myCallback {windowid state keycode keysym characters} {
	global inputString mappedString precommitString
	global mapDict dicDict
	global candPageMaxItems candSelectPos candLabel candList
	global modeNameList
	global config

	debugPuts [format "myCallback : windowid=0x%x state=%d keycode=0x%x keysym=%s characters=%s (%s)" \
	               $windowid $state $keycode $keysym $characters [scan $characters %c]]

	# whether we need update mappedString?
	set needMap 0
	################################################################
	#
	# begin keyboard handling
	#
	if {($state == "8") && [regexp {^[0-9]$} $characters]} {
		# change mode by alt+num
		debugPuts "change mode : $characters"
		set cmd [lindex $modeNameList $characters]
		if {$cmd ne ""} {
			$cmd
			set needMap 1
		} else {
			return False
		}
	} elseif {$characters eq "\033" || $characters eq "\007"} {
		# escape or ^g
		if {$inputString ne ""} {
			reset
		} else {
			return False
		}
	} elseif {$characters eq "\010"} {
		# backspace
		if {$inputString ne ""} {
			set inputString [string range $inputString 0 end-1]
			set needMap 1
		} else {
			return False
		}
	} elseif {$characters eq "\016" ||
	          $characters eq "\020" ||
	          $characters eq "\006"	||
	          $characters eq "\002"	||
	          $characters eq "\001"	||
	          $characters eq "\005"} {
		# candpos operation
		if {[llength $candList] > 0} {
			if {$characters eq "\016"} {
				# ^n
				set candSelectPos [expr $candSelectPos + 1]
			} elseif {$characters eq "\020"} {
				# ^p
				set candSelectPos [expr $candSelectPos - 1]
			} elseif {$characters eq "\006"} {
				# ^f
				set candSelectPos [expr $candSelectPos + $candPageMaxItems]
			} elseif {$characters eq "\002"} {
				# ^b
				set candSelectPos [expr $candSelectPos - $candPageMaxItems]
			} elseif {$characters eq "\001"} {
				# ^a
				set candSelectPos 0
			} elseif {$characters eq "\005"} {
				# ^e
				set candSelectPos -1
			}
			# set candSelectPos in valid range
			set candSelectPos [expr $candSelectPos % [llength $candList]]
		} else {
			# if candList is empty, do nothing
			return False
		}
	} elseif {$characters eq " "} {
		# commit
		if {$precommitString ne ""} {
			commit $precommitString
			return True
		} else {
			return False
		}
	} elseif {[string is print -strict $characters]} {
		# select candidate and commit it by [0-9] key
		if {[regexp {^[0-9]$} $characters]} {
			if {[llength $candList] > 0} {
				if {$characters == 0} {
					set n 10
				} else {
					set n $characters
				}
				set pos [expr $candSelectPos - $candSelectPos % $candPageMaxItems + $n - 1]
				set str [getCandValue $candList $pos]
				if {$str ne ""} {
					commit $str
					return True
				}
			}
		}
		# append characters to inputString
		append inputString $characters
		set needMap 1
	} else {
		# uninteresting key, do nothing
		return False
	}
	#
	# end keyboard handling
	#
	################################################################

	if {$needMap} {
		set mappedString [updateMappedString $inputString $mapDict]
		if {$dicDict eq ""} {
			if {$inputString ne $mappedString} {
				commit $mappedString
				return True
			}
		}
		set candList [makeCandList $dicDict $mappedString]
		set candSelectPos 0
	}

	if {$mappedString ne ""} {
		# show candwin if not mapped
		if {![winfo ismapped .candwin]} {
			wm withdraw .candwin
			wm deiconify .candwin
		}
	}

	if {[llength $candList] > 0} {
		set precommitString [getCandValue $candList $candSelectPos]
		set candLabel [makeCandLabel $candList $candSelectPos $candPageMaxItems]
	} else {
		set precommitString $mappedString
		set candLabel {}
	}

	return True
}

# return list of "key : value"
# duplicate value is flatten with same key
proc makeCandList {dictv pattern} {
	set dKeys [dict keys $dictv $pattern]
	set listv {}
	foreach k $dKeys {
		set v [dict get $dictv $k]
		if {[llength $v] == 1} {
			lappend listv "$k : $v"
		} else {
			foreach v2 $v {
				lappend listv "$k : $v2"
			}
		}
	}
	return $listv
}

# returns mapped string
# i : inputString
# m : mapDict
proc updateMappedString {i m} {
	set mapped [string map $m $i]
	# debugPuts "updateMappedString : $i $mapped"
	return $mapped
}

# candList is {{key1 : value1} {key2 : value2} ...}
# return value of specified position
proc getCandValue {cands pos} {
	return [lindex $cands $pos 2]
}

# grab window
# win : x window id
proc doGrab {win} {
	debugPuts "doGrab $win"
	global grabbedWinId
	if {$win eq ""} {
		return
	}
	# ungrab previously grabbed window
	doUngrab
	# grab
	tkxwin::grabKey $win myCallback
	set grabbedWinId $win
}

# ungrab grabbed window
proc doUngrab {} {
	debugPuts "doUngrab"
	global grabbedWinId
	if {$grabbedWinId eq ""} {
		return
	}
	# ungrab
	tkxwin::ungrabKey $grabbedWinId
	set grabbedWinId {}
}

# toggle grabbed state of active window
proc doToggleGrab {win} {
	debugPuts "doToggleGrab $win"
	global grabbedWinId
	if {$win eq ""} {
		return
	} elseif {$win == $grabbedWinId} {
		# ungrab
		doUngrab
		wm withdraw .candwin
	} else {
		# grab
		# ungrab previously grabbed window
		doUngrab
		# grab
		doGrab $win
	}
}

# read config.tcl
# get list of map file names (map/*.map)
# get list of dic file names (dic/*.dic)
proc myInit {} {
	global inputString mapFile dicFile mappedString candList candSelectPos
	global mapFileList dicFileList modeNameList modeName

	global configFile
	global config

	# read user configurations if exists
	if {[file readable $configFile]} {
		# puts "source $configFile"
		source $configFile
	}

	# load map/*.map and empty map {}
	append mapFileList "{} [glob -nocomplain map/*.map]"
	set mapFile [lindex $mapFileList 0]
	# load dic/*.dic and empty dic {}
	append dicFileList "{} [glob -nocomplain dic/*.dic]"
	set dicFile [lindex $dicFileList 0]

	registerHotkeys

	watchActiveWindow
}

# watch active window to see if have been grabbed
proc watchActiveWindow {} {
	global grabbedWinId
	set win [tkxwin::getActiveWindowId]
	if {$grabbedWinId == $win} {
		# active window is grabbed
		if {[winfo exist .palette.grab]} {
			.palette.grab configure -foreground pink -background green
		}
	} else {
		# active window is not grabbed
		if {[winfo exist .palette.grab]} {
			.palette.grab configure -foreground black -background grey
		}
		if {[winfo exist .candwin] && [winfo ismapped .candwin]} {
			# reset causes candwin to withdraw
			reset
		}
	}

	after 1000 {watchActiveWindow}
}

# create window that displays while you type
proc makeCandwin {} {
	set w .candwin

	toplevel $w
	wm withdraw $w

	wm overrideredirect $w 1
	# wm attribute $w -type dnd

	pack [label $w.input -textvariable inputString]
	pack [label $w.mapped -textvariable mappedString]
	pack [label $w.precommit -textvariable precommitString]
	pack [label $w.l -textvariable candLabel]
}

proc unregisterHotkeys {} {
	global config

	# grab key
	tkxwin::unregisterHotkey $config(grabKey)
	# ungrab key
	tkxwin::unregisterHotkey $config(ungrabKey)
	# toggle key
	tkxwin::unregisterHotkey $config(toggleGrabKey)
	# quit key
	tkxwin::unregisterHotkey $config(quitKey)
}

proc registerHotkeys {} {
	global config

	# grab key
	tkxwin::registerHotkey $config(grabKey) {
		doGrab [tkxwin::getActiveWindowId]
	}
	# ungrab key
	tkxwin::registerHotkey $config(ungrabKey) {
		doUngrab
		wm withdraw .candwin
	}
	# toggle key
	tkxwin::registerHotkey $config(toggleGrabKey) {
		doToggleGrab [tkxwin::getActiveWindowId]
	}
	# quit key
	tkxwin::registerHotkey $config(quitKey) {
		exit
	}
}

# re-register hotkeys
# called from option dialog
proc updateHotkeys {w} {
	global config

	unregisterHotkeys

	set config(grabKey) [$w.grabkey get]
	set config(ungrabKey) [$w.ungrabkey get]
	set config(toggleGrabKey) [$w.togglegrabkey get]
	set config(quitKey) [$w.quitkey get]
	
	registerHotkeys
}

# create option dialog box
proc makeOptionDialog {} {
	global mapFile dicFile modeName
	global mapFileList dicFileList modeNameList
	global config

	set w .options
	if {[winfo exist $w]} {
		wm withdraw $w
		wm deiconify $w
		return
	}
	toplevel $w
	labelframe $w.mode -text mode
	ttk::combobox $w.mode.cb -textvariable modeName -value $modeNameList
	pack $w.mode.cb
	bind $w.mode.cb <<ComboboxSelected>> {
		set cmd [%W get]
		if {$cmd ne ""} {
			$cmd
			set needMap 1
		}
	}
	pack $w.mode

	labelframe $w.map -text map
	ttk::combobox $w.map.cb -textvariable mapFile -value $mapFileList
	pack $w.map.cb
	bind $w.map.cb <<ComboboxSelected>> {
		set mapDict [loadMapOrDic [%W get]]
	}
	pack $w.map
	
	labelframe $w.dic -text dic
	ttk::combobox $w.dic.cb -textvariable dicFile -values $dicFileList
	pack $w.dic.cb
	bind $w.dic.cb <<ComboboxSelected>> {
		set dicDict [loadMapOrDic [%W get]]
	}
	pack $w.dic

	labelframe $w.hotkey -text hotkey
	label $w.hotkey.grabkeyl -text grabkey
	entry $w.hotkey.grabkey
	label $w.hotkey.ungrabkeyl -text ungrabkey
	entry $w.hotkey.ungrabkey
	label $w.hotkey.togglegrabkeyl -text togglegrabkey
	entry $w.hotkey.togglegrabkey
	label $w.hotkey.quitkeyl -text quitkey
	entry $w.hotkey.quitkey
	button $w.hotkey.apply -text apply -command [list updateHotkeys $w.hotkey]

	$w.hotkey.grabkey insert 0 $config(grabKey)
	$w.hotkey.ungrabkey insert 0 $config(ungrabKey)
	$w.hotkey.togglegrabkey insert 0 $config(toggleGrabKey)
	$w.hotkey.quitkey insert 0 $config(quitKey)

	grid $w.hotkey.grabkeyl $w.hotkey.grabkey
	grid $w.hotkey.ungrabkeyl $w.hotkey.ungrabkey
	grid $w.hotkey.togglegrabkeyl $w.hotkey.togglegrabkey
	grid $w.hotkey.quitkeyl $w.hotkey.quitkey
	grid $w.hotkey.apply

	pack $w.hotkey
}

# create always visible window
# works as an indicator
proc makePalette {} {
	set w .palette

	toplevel $w

	pack [label $w.grab -text "xgrabfep" -foreground black -background grey] -side left

	wm overrideredirect $w 1
	wm geometry $w -300-0

	# move/resize window function for wm overrideredirect (no window decoration)
	# move window by left button drag
	bind $w <ButtonPress-1> {
		set t [winfo toplevel %W]
		set x0 [winfo x $t]
		set y0 [winfo y $t]
		set x1 [winfo pointerx $t]
		set y1 [winfo pointery $t]
	}
	bind $w <B1-Motion> {
		set t [winfo toplevel %W]
		set x2 [winfo pointerx $t]
		set y2 [winfo pointery $t]
		wm geometry $t "+[expr $x0 - $x1 + $x2]+[expr $y0 - $y1 + $y2]"
	}

	# popup menu
	menu $w.m -tearoff 0
	$w.m add command -label options -command makeOptionDialog
	$w.m add command -label about -command {tk_messageBox -title about -message $::argv0}
	$w.m add command -label exit -command exit
	bind $w <ButtonRelease-3> [list tk_popup $w.m %X %Y]
}

# read map/dic file
# return dict
proc loadMapOrDic {mapfile} {
	debugPuts "loadMapOrDic : $mapfile"
	# open file
	if {[catch {set chan [open $mapfile "r"]} fid]} {
		# cannot open file
		debugPuts "loadMapOrDic : $fid"
		# return empty list
		return {}
	}
	fconfigure $chan -encoding utf-8

	set dictv {}
	while {[gets $chan line] >= 0} {
		# split line, first one is key, the rest is value
		set fields [split $line]
		# key
		set k [lindex $fields 0]
		# value
		set d [join [lrange $fields 1 end]]
		dict lappend dictv "$k" "$d"
	}

	# close file
	close $chan

	return $dictv
}

proc main {} {
	global mapFile dicFile
	global inputString mappedString precommitString
	global mapDict dicDict

	set inputString {}
	set mappedString {}
	set precommitString {}

	# problem occurs if tk window has focus
	wm overrideredirect . 1
	wm withdraw .
}

#
# global variables
#
set grabbedWinId {}
set candSelectPos 0
set candList {}
# string, displayed in .candwin
set candLabel {}
set mapFileList {}
set mapFile {}
set dicFileList {}
set dicFile {}
# used as change mode command when alt+numer is pressed
set modeNameList {}
# current mode name
set modeName {}
# user input string
set inputString {}
# string, converted from inputString
set mappedString {}
# string, selected candidate
set precommitString {}
set mapDict {}
set dicDict {}
set candPageMaxItems 10
array set config {
	grabKey Alt-W
	ungrabKey Alt-E
	toggleGrabKey Alt-R
	quitKey Alt-Q
}

#
# begin program
#
myInit

makeCandwin
makePalette

main

#
# end program
#

# Local Variables:
# mode: tcl
# End:

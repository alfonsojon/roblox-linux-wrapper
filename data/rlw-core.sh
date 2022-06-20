#!/usr/bin/env bash
# Common variables used by all rlw scripts
export WINEARCH=win32
export WINEPREFIX="$HOME/.local/share/wineprefixes/roblox-wine"
export PULSE_LATENCY_MSEC=60 # Workaround fix for crackling sound (variable used by wine)

wineinitialize () {
	# Evaluate the Wine path selection, and base the wineserver
	# paths off that.
	printf "%b\n" "> wineinitialize: sourcing $HOME/.rlw/wine_choice"
	[[ -e "$HOME"/.rlw/wine_choice ]] && source "$HOME/.rlw/wine_choice" &&	printf "%b\n" "> wineinitialize: source complete" || printf "%b\n" "> wineinitialize: source failed"
	for x in "$WINE" "$WINESERVER"; do
		if [[ -x "$x" ]]; then
			printf "%b\n" "> wineinitialize: $(basename "$x") path set to $x"
		else
			if [[ ! -z "$x" ]]; then
				spawndialog error "Could not find $(basename "$x") at $x. Are you sure a copy is installed there?"
			fi
			winechooser
			break
		fi
	done
	export WINE
	export WINESERVER
	printf "%b\n" "> wineinitialize: Wine version $("$WINE" --version) is installed"
}

winechooser () {
	sel=$(zenity \
			--title "Wine Release Selection" \
			--width=480 \
			--height=300 \
			--cancel-label='Exit' \
			--list \
			--text 'Select the version of Wine you want to use:' \
			--radiolist \
			--column '' \
			--column 'Options' \
			TRUE 'Std roblox wine' \
			FALSE 'Automatic detection' \
			FALSE 'Browse for Wine binaries...')
	case $sel in
		'Browse for Wine binaries...')
			BIN=$(zenity --title "Select folder containing wine binaries (usually named bin)" --file-selection --directory)
			WINE="$BIN"/wine
			WINESERVER="$BIN"/wineserver;;
		'Std roblox wine')
			curl --silent --connect-timeout 8 --output /dev/null 'https://docs.google.com/uc?export=download&confirm=no_antivirus&id=1q4l4FvUj6bfMZGBEUXnsOPUgBxwUMXTr' -I -w "%{http_code}\n"
			if [[ "$http_code" -ne "200" ]]; then
				spawndialog error "Download error (code $http_code)"
				exit 1
			fi
			wget --no-check-certificate 'https://docs.google.com/uc?export=download&confirm=no_antivirus&id=1q4l4FvUj6bfMZGBEUXnsOPUgBxwUMXTr' -O WINE.tar.xz 2>&1 | sed -u 's/.* \([0-9]\+%\)\ \+\([0-9.]\+.\) \(.*\)/\1\n# Downloading at \2\/s, ETA \3/' | zenity --progress --title="Downloading File..." --auto-close --auto-kill
			mkdir $HOME/.winexe/
			tar -xf WINE.tar.xz -C $HOME/.winexe/
			WINE=$HOME/.winexe/bin/wine
			WINESERVER=$HOME/.winexe/bin/wineserver;;
		'Automatic detection')
			# Here, we will literally save '$(which wine)' as the path
			# so it changes dynamically and isn't immediately evaluated.
			WINE="$(which wine)"
			WINESERVER="$(which wineserver)"
			for x in "$WINE" "$WINESERVER"; do
				if [[ ! -x "$x" ]]; then
					spawndialog error "Missing dependencies! Please install wine somewhere in \"$PATH\", or select a custom path instead.\nDetails: Could not find $(basename \"$x\") at \"$x\".\nAre you sure a copy is installed there?"
					exit 1
				fi
			done;;
		*)
	esac
}



spawndialog () {
	zenity \
		--no-wrap \
		--window-icon="$RBXICON" \
		--title="$rlwversionstring" \
		--"$1" \
		--text="$2" 2&> /dev/null
}

rwine () {
	printf '%b\n' "> rwine: calling wine with arguments \"$(printf "%s " "$@")\""
	if [[ "$1" = "--silent" ]]; then
		"$WINE" "${@:2}" && rwineserver --silent
	else
		"$WINE" "$@" && rwineserver --wait; [[ "$?" = "0" ]] || {
			spawndialog error "wine closed unsuccessfully.\nSee terminal for details. (exit code $?)"
	}
	fi
}

rwineserver () {
	printf '%b\n' "> rwineserver: calling wineserver with arguments \"$(printf "%s " "$@")\""
	if [[ "$1" = "--wait" ]]; then
		"$WINESERVER" "$@" | $(zenity\
					--title="$rlwversionstring" \
					--window-icon="$RBXICON" \
					--width=480 \
					--progress \
					--auto-kill \
					--auto-close \
					--pulsate \
					--text="Waiting for wine to close...")
		return "$?"
	else
		"$WINESERVER" "$@"
		return "$?"
	fi
}

wineinitialize

#!/usr/bin/env bash
#
#    Copyright 2015 Jonathan Alfonso <alfonsojon1997@gmail.com>
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

spawndialog () {
	zenity \
		--window-icon="$RBXICON" \
		--title='Roblox Linux Wrapper v'"$RLWVERSION"'-'"$RLWCHANNEL" \
		--"$1" \
		--text="$2"
}

# Define some variables and the spawndialog function
export RLWVERSION=20150316
export RLWCHANNEL=staging
export WINEARCH=win32

if [ -f "$HOME/.local/share/icons/hicolor/512x512/apps/roblox.png" ]
then
	export RBXICON=$HOME/.local/share/icons/hicolor/512x512/apps/roblox.png
fi
echo 'Roblox Linux Wrapper v'"$RLWVERSION"'-'"$RLWCHANNEL"

# Uncomment these lines to use stock Wine (default)
export WINE="$(which wine)"
export WINEBOOTBIN="$(which wineboot)"
export WINESERVERBIN="$(which wineserver)"
export WINEPREFIX="$HOME/.local/share/wineprefixes/roblox-wine"
export WINEPREFIX_OLD="$HOME/.local/share/wineprefixes/Roblox-wine"
export WINEPREFIX_PROGRAMS="$HOME/.local/share/wineprefixes/roblox-wine/drive_c"

# Uncomment these lines to use wine-staging (formerly wine-compholio)
#if [ -f /opt/wine-staging/bin/wine ]
#then
#	export WINE="/opt/wine-staging/bin/wine"
#	export WINEBOOTBIN="/opt/wine-staging/bin/wineboot"
#	export WINESERVERBIN="/opt/wine-staging/bin/wineserver"
#	export WINEPREFIX="$HOME/.local/share/wineprefixes/roblox-wine-staging"
#	export WINEPREFIX_OLD="$HOME/.local/share/wineprefixes/Roblox-wine-staging"
#	export WINEPREFIX_PROGRAMS="$HOME/.local/share/wineprefixes/roblox-wine-staging/drive_c"
#fi

# Check that everything is here
[[ -x "$(which zenity)" -x "$(which wget)" -x "$WINE" -x "$WINEBOOTBIN" -x "$WINESERVERBIN"  ]] || { spawndialog error "Missing dependencies! Make sure zenity, wget, wine, and wine-staging are installed."; exit 1; }

# Check for optional dependencies
# Note: git is used for automatic updating, and is recommended.
[[ -x "(which git)" ]] || { spawndialog warning "git not found. Automatic updates will be disabled."; }

# Some internal functions to make wine more useful to the wrapper.
# This allows the wrapper to know what went wrong and where, without excessive code.
# Note: the "r" prefix indicates a function that extends system functionality.

rwine () {
	if [[ "$1" = "--silent" ]]; then
		$WINE "${@:2}"
	else
		$WINE "$@"; [[ "$?" = "0" ]] || { spawndialog error "wine closed unsuccessfully.\nSee terminal for details. (exit code $?)"; exit $?; }
	fi
}
rwineboot () {
	$WINEBOOTBIN; [[ "$?" = "0" ]] || { spawndialog error "wineboot closed unsuccessfully.\nSee terminal for details. (exit code $?)"; exit $?; }
}
rwineserver () {
	$WINESERVERBIN "$@"; [[ "$?" = "0" ]] || { spawndialog error "wineserver closed unsuccessfully.\nSee terminal for details. (exit code $?)"; exit $?; }
}
rwget () {
	wget "$@" 2>&1 | sed -u 's/.* \([0-9]\+%\)\ \+\([0-9.]\+.\) \(.*\)/\1\n# Downloading at \2\/s, ETA \3/' | zenity \
		--progress \
		--window-icon="$RBXICON" \
		--title='Downloading' \
		--auto-close \
		--no-cancel \
		--width=450 \
		--height=120
	[[ "$?" = "0" ]] || { spawndialog error "wget download failed. \nSee terminal for details. (exit code $?)"; exit $?; }
}
rwinetricks () {
	$(which winetricks) "$@"
}

roblox-install () {
	[[ -d "$WINEPREFIX" ]] && rmdir "$WINEPREFIX"
	[[ -d "$WINEPREFIX_OLD" ]] && [[ ! -d "$WINEPREFIX" ]] && { mv "$WINEPREFIX_OLD" "$WINEPREFIX"; }
	if [[ ! -d "$WINEPREFIX/drive_c" ]]; then
		spawndialog question 'A working Roblox wineprefix was not found. Would you like to install one?'
		if [[ $? = "0" ]]; then
			rm -rf "$WINEPREFIX"
			# Make sure our directories really exist
			[[ -d "$HOME/.local/share/wineprefixes" ]] || mkdir -p "$HOME/.local/share/wineprefixes"
			rwineboot
			cd "$WINEPREFIX"
			rwineserver --wait
			# Can cause problems in mutter. Examine further, don't use if not necessary.
			# rwinetricks --gui ddr=gdi
			[[ "$?" = 0 ]]  || { spawndialog error "Wine prefix not generated successfully.\nSee terminal for more details. (exit code $?)"; exit $?; }
			rwget http://roblox.com/install/setup.ashx -O /tmp/RobloxPlayerLauncher.exe
			WINEDLLOVERRIDES="winebrowser.exe,winemenubuilder.exe=" rwine /tmp/RobloxPlayerLauncher.exe
			cd "$WINEPREFIX"
			ROBLOXPROXY="$(find . -iname 'RobloxProxy.dll' | sed "s/.\/drive_c/C:/" | tr '/' '\\')"
			rwineserver --wait
			if [[ ! -f "$WINEPREFIX/Program Files/Mozilla Firefox/firefox.exe" ]]
			then
				ans=$(zenity \
					--title='Roblox Linux Wrapper v'$RLWVERSION'-'$RLWCHANNEL' by alfonsojon' \
					--window-icon="$RBXICON" \
					--width=480 \
					--height=240 \
					--cancel-label='Quit' \
					--list \
					--text 'Which browser do you want?' \
					--radiolist \
					--column '' \
					--column 'Options' \
					TRUE 'Firefox')
				case $ans in
				'Firefox')
					rwget http://ftp.mozilla.org/pub/mozilla.org/firefox/releases/31.4.0esr/win32/en-US/Firefox%20Setup%2031.4.0esr.exe -O /tmp/Firefox-Setup-esr.exe
					WINEDLLOVERRIDES="winebrowser.exe,winemenubuilder.exe=" rwine /tmp/Firefox-Setup-esr.exe /SD | zenity \
						--window-icon="$RBXICON" \
						--title='Installing Mozilla Firefox' \
						--text='Installing Mozilla Firefox Browser ...' \
						--progress \
						--pulsate \
						--no-cancel \
						--auto-close
					rwineserver --wait
				esac
			fi
		else
			exit 1
		fi
	fi

}

wrapper-install () {
	if [[ ! -d "$HOME/.rlw" ]] || [ ! -f "$HOME/.local/share/applications/Roblox.desktop" ]; then
		spawndialog question 'Roblox Linux Wrapper is not installed. This is necessary to launch games properly.\nWould you like to install it?'
		if [ $? = 0 ]
		then
			[[ -f "$HOME/.local/share/icons/hicolor/512x512/apps/roblox.png" ]] || { mkdir -p "$HOME/.local/share/icons/hicolor/512x512/apps"; rwget http://img1.wikia.nocookie.net/__cb20130302012343/robloxhelp/images/f/fb/ROBLOX_Circle_Logo.png -O "$HOME/.local/share/icons/hicolor/512x512/apps/roblox.png"; }
			export RBXICON=$HOME/.local/share/icons/hicolor/512x512/apps/roblox.png
			cat <<-EOF > $HOME/.local/share/applications/Roblox.desktop
			[Desktop Entry]
			Comment=Play Roblox
			Name=Roblox Linux Wrapper
			Exec=$HOME/.rlw/rlw-stub.sh
			Actions=RFAGroup;ROLWiki;
			GenericName=Building Game
			Icon=roblox
			Categories=Game;
			Type=Application

			[Desktop Action Support]
			Name=GitHub Support Ticket
			Exec=xdg-open 'https://github.com/alfonsojon/roblox-linux-wrapper/issues/new'

			[Desktop Action ROLWiki]
			Name=Roblox on Linux Wiki
			Exec=xdg-open 'http://roblox.wikia.com/wiki/Roblox_On_Linux'

			[Desktop Action RFAGroup]
			Name=Roblox for All
			Exec=xdg-open 'http://www.roblox.com/Groups/group.aspx?gid=292611'
			EOF
			mkdir -p "$HOME/.rlw"
			rwget https://raw.githubusercontent.com/alfonsojon/roblox-linux-wrapper/master/rlw.sh -O "$HOME/.rlw/rlw.sh"
			rwget https://raw.githubusercontent.com/alfonsojon/roblox-linux-wrapper/master/rlw-stub.sh -O "$HOME/.rlw/rlw-stub.sh"
			rwget http://img1.wikia.nocookie.net/__cb20130302012343/robloxhelp/images/f/fb/ROBLOX_Circle_Logo.png -O "$HOME/.local/share/icons/roblox.png"
			chmod +x "$HOME/.rlw/rlw.sh"
			chmod +x "$HOME/.rlw/rlw-stub.sh"
			chmod +x "$HOME/.local/share/applications/Roblox.desktop"
			xdg-desktop-menu install --novendor "$HOME/.local/share/applications/Roblox.desktop"
			xdg-desktop-menu forceupdate
			[[ -x "$HOME/.rlw/rlw-stub.sh" -x "$HOME/.rlw/rlw.sh && -f $HOME/.local/share/icons/roblox.png && -f $HOME/.local/share/applications/Roblox.desktop" ]] || { spawndialog error 'Roblox Linux Wrapper did not install successfully.'; exit 1; }
		else
			exit 1
		fi
	fi
}

playerwrapper () {
	ROBLOXPROXY=$(find . -iname 'RobloxProxy.dll' | sed "s/.\/drive_c/C:/" | tr '/' '\\')
	rwine --silent regsvr32 /i "$ROBLOXPROXY"
	if [ "$1" = legacy ]
	then
		export GAMEURL=$(\
			zenity \
				--title='Roblox Linux Wrapper v'$RLWVERSION'-'$RLWCHANNEL \
				--window-icon="$RBXICON" \
				--entry \
				--text='Paste the URL for the game here.' \
				--ok-label='Play' \
				--width=450 \
				--height=122)
			GAMEID=$(echo "$GAMEURL" | cut -d "=" -f 2)
		if [[ -n "$GAMEID" ]]
		then
			rwine "$(find "$WINEPREFIX" -name RobloxPlayerBeta.exe)" --id "$GAMEID"
			rwineserver --wait
		else
			spawndialog warning "Invalid game URL or ID."
			return
		fi
	else
		rwine "$browser" http://www.roblox.com/Games.aspx
	fi
}

#code to check which browser you're running
browser-install () {
	if [ -e "$WINEPREFIX_PROGRAMS/Program Files/Mozilla Firefox/firefox.exe" ]
	then
		browser='C:\Program Files\Mozilla Firefox\firefox.exe'
	else
		spawndialog error 'No browser installed. Please reinstall.'
	fi
}

main () {
	rm -rf "$HOME/Desktop/ROBLOX*desktop $HOME/Desktop/ROBLOX*.lnk"
	rm -rf "$HOME/.local/share/applications/wine/Programs/Roblox"
	sel=$(zenity \
		--title='Roblox Linux Wrapper v'$RLWVERSION'-'$RLWCHANNEL' by alfonsojon' \
		--window-icon="$RBXICON" \
		--width=480 \
		--height=240 \
		--cancel-label='Quit' \
		--list \
		--text 'What option would you like?' \
		--radiolist \
		--column '' \
		--column 'Options' \
		TRUE 'Play Roblox' \
		FALSE 'Play Roblox (Legacy Mode)' \
		FALSE 'Roblox Studio' \
		FALSE 'Reinstall Roblox' \
		FALSE 'Uninstall Roblox')
	case $sel in
	'Play Roblox')
		playerwrapper; main;;
	'Play Roblox (Legacy Mode)')
		playerwrapper legacy; main;;
	'Roblox Studio')
		WINEDLLOVERRIDES="msvcp110.dll,msvcr110.dll=n,b" rwine "$WINEPREFIX/drive_c/users/$USER/Local Settings/Application Data/RobloxVersions/RobloxStudioLauncherBeta.exe" -ide
		rwineserver --wait
		main ;;
	'Reinstall Roblox')
		spawndialog question 'Are you sure you would like to reinstall?'
		if [ "$?" = "0" ]
		then
			rm -rf "$WINEPREFIX";
			roblox-install; main
		else
			main
		fi;;
	'Uninstall Roblox')
		spawndialog question 'Are you sure you would like to uninstall?'
		if [[ "$?" = "0" ]]; then
			xdg-desktop-menu uninstall "$HOME/.local/share/applications/Roblox.desktop"
			rm -rf "$HOME/.rlw"
			[[ ! -f "$HOME/.local/share/icons/roblox.png" ]] || rm -rf "$HOME/.local/share/icons/roblox.png"
			rm -rf "$HOME/.local/share/icons/hicolor/512x512/apps/roblox.png"
			xdg-desktop-menu forceupdate
			$WINESERVERBIN --kill
			rm -rf "$WINEPREFIX"
			if [[ -d "$HOME/.rlw" ]] || [[ -f "$HOME/.local/share/icons/hicolor/512x512/apps/roblox.png" ]] || [[ -d "$WINEPREFIX" ]]
			then
				spawndialog error 'Roblox is still installed. Please try uninstalling again.'
			else
				spawndialog info 'Roblox has been uninstalled successfully.'
			fi
			exit
		else
			main
		fi;;
	esac
}

# Run dependency check & launch main function
wrapper-install && roblox-install && browser-install && main

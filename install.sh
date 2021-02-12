#!/usr/bin/env bash

shopt -s expand_aliases
# Portable way to get real path .......
readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}

fail() { echo "$1"; exit 1;}
macos() { test $(uname -s) == Darwin;}

digitalocean() { test "$(facter --no-ruby manufacturer 2>/dev/null)" == "DigitalOcean";}

if macos ; then
	:
else
	alias cpan="sudo /usr/bin/cpanm"
	alias cpanm="sudo /usr/bin/cpanm"
fi

function apt_install {
	dpkg -s $1 >/dev/null 2>&1
	test $? -eq 0 && return 0
	echo "Installing $1"
	sleep 1
	test -f /tmp/.install.flag || sudo apt-get update
	touch /tmp/.install.flag
	sudo apt -y install $1
}
function brew_install {
	if [ ! -z "$2" ] ; then
		test -f $2 && return
	fi
	echo "Installing $1"
	sleep 1
	brew install $1
	
}

function linux_packages {
	rm -f /tmp/.install.flag >/dev/null 2>&1
	apt_install handbrake 
	apt_install handbrake-cli
	apt_install libdvd-pkg
	apt_install jq
	#export PATH=$PATH:/usr/local/bin:/usr/local/opt/coreutils/libexec/gnubin	
}
function mac_packages {
	test -f /usr/local/bin/brew ||\
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	#brew_install bash /usr/local/bin/bash
}

function perl_install {
	perldoc -l $1 >/dev/null 2>&1
	test $? -eq 0 && return
	echo "Installing perl module $1"
	cpanm $1
}
	
myscript="$(readlinkf $0)"
bindir=$(dirname $myscript)
envdir=${bindir%/bin}/env

# Check that ssh keys have been copied
test -f ~/.ssh/id_rsa || fail "Copy .ssh files first"

#---------------------------------------------------------------------

function add_repository {
	name=$1
	gpg_url=$2
	gpg_text="$3"
	source_text="$4"

	#--> Get the signing key
	apt-key list 2>/dev/null|grep -qi "$gpg_text" 
	if [ $? -ne 0 ] ; then
			wget -qO - $gpg_url | sudo apt-key add -
	fi

	if [ ! -f /etc/apt/sources.list.d/$1.list ] ; then
		echo "$source_text" | sudo tee /etc/apt/sources.list.d/${name}.list
	fi
}
if macos ; then
	mac_packages
else
	if ! digitalocean ; then
	:
	# Sublime text and merge
		#add_repository sublime-text https://download.sublimetext.com/sublimehq-pub.gpg "Sublime HQ" "deb https://download.sublimetext.com/ apt/stable/"
	fi
	linux_packages
fi

#-------------------------------------------------------------------------
#perl_install Perl::Critic


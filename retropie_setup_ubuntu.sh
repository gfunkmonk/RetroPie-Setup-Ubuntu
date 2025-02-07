#! /bin/bash

# Computed variables
USER="$SUDO_USER"
USER_HOME="/home/$USER"
SCRIPT_PATH="$(realpath $0)"
SCRIPT_DIR="$(dirname $SCRIPT_PATH)"
SCRIPT_FILE="$(basename $SCRIPT_PATH)"
LOG_FILE="$SCRIPT_DIR/$(basename $0 .sh)-$(date +"%Y%m%d_%H%M%S").log"
OPTIONAL_SCRIPT_DIR="$SCRIPT_DIR/optional_scripts"

# Global setting for APT recommended packages - leave blank for now.
# It's a little more bloated, but we can't get a clean boot without it.
#APT_RECOMMENDS="–no-install-recommends"
APT_RECOMMENDS=

# Minimal depedencies to install RetroPie on Ubuntu
RETROPIE_DEPENDS=(
    xorg openbox pulseaudio alsa-utils menu libglib2.0-bin python3-xdg
    at-spi2-core libglib2.0-bin dbus-x11 git dialog unzip xmlstarlet joystick
    triggerhappy
)

# Helpful packages to improve usability
#--------------------------------------------------------------------------------
# openssh-server      Remote administration, copy/paste
# xdg-utils           Eliminates 'xdg-screensaver not found' error
# unclutter           Hides mouse cursor when not being used
# inxi                Queries video driver information
#--------------------------------------------------------------------------------
EXTRA_TOOLS=(
    openssh-server xdg-utils unclutter inxi
)


# Output to both console and log file
function enable_logging() {
    echo "--------------------------------------------------------------------------------"
    echo "| Saving console output to '$LOG_FILE'"
    echo "--------------------------------------------------------------------------------"
    touch $LOG_FILE
    exec > >(tee $LOG_FILE) 2>&1
    sleep 2
}


# Install RetroPie dependencies
function install_retropie_dependencies() {
    echo "--------------------------------------------------------------------------------"
    echo "| Updating OS packages and installing RetroPie dependencies"
    echo "--------------------------------------------------------------------------------"
    apt-get update && apt-get -y upgrade
    apt-get install -y $APT_RECOMMENDS ${RETROPIE_DEPENDS[@]}
    echo -e "FINISHED install_retropie_dependencies \n\n"
    sleep 2
}


# Install RetroPie
function install_retropie() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing RetroPie"
    echo "--------------------------------------------------------------------------------"
    # Get Retropie Setup script and perform an install of same packages 
    # used in the RetroPie image (as applicable)
    # See https://github.com/RetroPie/RetroPie-Setup/blob/master/scriptmodules/admin/image.sh
    cd $USER_HOME
    git clone --depth=1 https://github.com/gfunkmonk/RetroPie-Setup.git
    git config --global --add safe.directory /home/pi/RetroPie-Setup
    git clone --depth=1 https://github.com/gfunkmonk/RetroPie-Extra.git
    git config --global --add safe.directory /home/pi/RetroPie-Extra

    UNKNOWN_PLATFORM=$($USER_HOME/RetroPie-Setup/retropie_packages.sh setup | grep "Unknown platform" | wc -l)
	if [[ $UNKNOWN_PLATFORM > 0 ]]; then
        echo "\nWARNING: This platform is NOT SUPPORTED by RetroPie.  Is this a Ubuntu ARM installation?"
        echo -e "To allow RetroPie to run, the __platform variable is being manually overwritten as 'generic-x11' in /etc/environment.\n"
        export __platform=generic-x11
        echo "__platform=$__platform" | sudo tee -a /etc/environment > /dev/null
    fi

    $USER_HOME/RetroPie-Setup/retropie_packages.sh setup basic_install
    $USER_HOME/RetroPie-Setup/retropie_packages.sh bluetooth depends
    $USER_HOME/RetroPie-Setup/retropie_packages.sh usbromservice
    $USER_HOME/RetroPie-Setup/retropie_packages.sh samba depends
    $USER_HOME/RetroPie-Setup/retropie_packages.sh samba install_shares
    $USER_HOME/RetroPie-Setup/retropie_packages.sh splashscreen default
    $USER_HOME/RetroPie-Setup/retropie_packages.sh splashscreen enable
    $USER_HOME/RetroPie-Setup/retropie_packages.sh xpad
    chown -R $USER:$USER $USER_HOME/RetroPie-Setup
    echo -e "FINISHED install_retropie \n\n"
    sleep 2
}


# Install RetroArch shaders from official repository
function install_retroarch_shaders() {
    echo "--------------------------------------------------------------------------------"
    echo "| Remove the RPi shaders installed by RetroPie-Setup and replace with"
    echo "| RetroArch (merge of common & GLSL, and new Slang) shaders from Libretro"
    echo "--------------------------------------------------------------------------------"
    # Cleanup pi shaders installed by RetroPie-Setup
    rm -rf /opt/retropie/configs/all/retroarch/shaders
    mkdir -p /opt/retropie/configs/all/retroarch/shaders
    # Install common shaders from Libretro repository
    git clone --depth=1 https://github.com/libretro/common-shaders.git /tmp/common-shaders
    cp -r /tmp/common-shaders/* /opt/retropie/configs/all/retroarch/shaders/
    rm -rf /tmp/common-shaders
    # Install GLSL shaders from Libretro repository
    git clone --depth=1 https://github.com/libretro/glsl-shaders.git /tmp/glsl-shaders
    cp -r /tmp/glsl-shaders/* /opt/retropie/configs/all/retroarch/shaders/
    rm -rf /tmp/glsl-shaders
    # Install Slang shaders from Libretro repository (for use with Vulkan, glcore, ..)                              
    # https://www.libretro.com/index.php/category/slang/                                                            
    git clone --depth=1 https://github.com/libretro/slang-shaders.git /tmp/slang-shaders
    cp -r /tmp/slang-shaders/* /opt/retropie/configs/all/retroarch/shaders/
    rm -rf /tmp/slang-shaders

    # Remove git repository from shader dir
    rm -rf /opt/retropie/configs/all/retroarch/shaders/.git
    chown -R $USER:$USER /opt/retropie/configs
    echo -e "FINISHED install_retroarch_shaders \n\n"
    sleep 2
}


# Create file in sudoers.d directory and disable password prompt
function disable_sudo_password() {
    echo "--------------------------------------------------------------------------------"
    echo "| Disabling the sudo password prompt"
    echo "--------------------------------------------------------------------------------"
    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER-no-password-prompt
    chmod 0440 /etc/sudoers.d/$USER-no-password-prompt
    echo -e "FINISHED disable_sudo_password \n\n"
    sleep 2
}


# Install latest Intel video drivers
function install_latest_intel_drivers() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing the latest Intel video drivers from 'ppa:ubuntu-x-swat/updates'"
    echo "| This may throw errors on a new release if this PPA does not supportit yet (OK)."
    echo "--------------------------------------------------------------------------------"
    add-apt-repository -y ppa:ubuntu-x-swat/updates
    add-apt-repository -y ppa:kisak/kisak-mesa
    apt-get update && apt-get -y upgrade
    echo -e "FINISHED install_latest_intel_drivers \n\n"
    sleep 2
}


# Install the latest Nvidia video drivers
function install_latest_nvidia_drivers() {
    echo "--------------------------------------------------------------------------------"
    echo "- Installing the latest Nvidia video drivers"
    echo "--------------------------------------------------------------------------------"
    apt-get install -y $APT_RECOMMENDS ubuntu-drivers-common
    add-apt-repository -y ppa:graphics-drivers/ppa
    add-apt-repository -y ppa:kelebek333/nvidia-legacy
    add-apt-repository -y ppa:oibaf/graphics-drivers
    ubuntu-drivers autoinstall
    echo -e "FINISHED install_latest_nvidia_drivers \n\n"
    sleep 2
}


# Install MESA Vulkan drivers
function install_vulkan() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing Vulkan video drivers"
    echo "--------------------------------------------------------------------------------"
    apt-get install -y $APT_RECOMMENDS mesa-vulkan-drivers
    echo -e "FINISHED install_vulkan \n\n"
    sleep 2
}


# Enable Plymouth Splash Screen
function enable_plymouth_theme() {
    if [[ -z "$1" ]]; then
        echo "--------------------------------------------------------------------------------"
        echo "| Skipping Plymouth boot splash because no theme name was provided"
        echo "--------------------------------------------------------------------------------"
        echo -e "Skipped\n\n"
        return 255
    fi
    PLYMOUTH_THEME=$1
    echo "--------------------------------------------------------------------------------"
    echo "| Installing Plymouth boot splash and enabling theme '$PLYMOUTH_THEME'"
    echo "--------------------------------------------------------------------------------"
    apt-get install -y $APT_RECOMMENDS plymouth plymouth-themes plymouth-x11
    rm -rf /tmp/plymouth-themes
    git clone --depth=1 https://github.com/HerbFargus/plymouth-themes.git /tmp/plymouth-themes
    mv /tmp/plymouth-themes/* /usr/share/plymouth/themes/
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/$PLYMOUTH_THEME/$PLYMOUTH_THEME.plymouth 10
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/$PLYMOUTH_THEME/$PLYMOUTH_THEME.plymouth
    update-initramfs -u
    echo -e "FINISHED enable_plymouth_theme \n\n"
    sleep 2
}


# Hide Boot Messages
function hide_boot_messages() {
    echo "--------------------------------------------------------------------------------"
    echo "| Hiding boot messages"
    echo "--------------------------------------------------------------------------------"
    # Hide kernel messages and blinking cursor via GRUB
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vt.global_cursor_default=0"/g' /etc/default/grub
    update-grub

    # Hide fsck messages after Plymouth splash
    echo 'FRAMEBUFFER=y' > /etc/initramfs-tools/conf.d/splash
    update-initramfs -u

    # Remove cloud-init to suppress its boot messages
    apt-get purge cloud-init -y
    rm -rf /etc/cloud/ /var/lib/cloud/

    # Disable motd
    touch $USER_HOME/.hushlogin
    chown $USER:$USER $USER_HOME/.hushlogin
    echo -e "FINISHED hide_boot_messages \n\n"
    sleep 2
}


# Change the default runlevel to multi-user
# This disables GDM from loading at boot (new for 20.04)
function enable_runlevel_multiuser () {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling the 'multi-user' runlevel"
    echo "--------------------------------------------------------------------------------"
    systemctl set-default multi-user
    echo -e "FINISHED enable_runlevel_multiuser \n\n"
    sleep 2
}


# Configure user to autologin at the terminal
function enable_autologin_tty() {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling autologin to terminal"
    echo "--------------------------------------------------------------------------------"
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat << EOF >> /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --skip-login --noissue --autologin $USER %I \$TERM
Type=idle
EOF
    echo -e "FINISHED enable_autologin_tty \n\n"
    sleep 2
}


# Start X as soon as autologin is complete
function enable_autostart_xwindows() {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling autostart of X Windows"
    echo "--------------------------------------------------------------------------------"
    # Create a .xsession file to launch OpenBox when startx is called
    echo 'exec openbox-session' >> $USER_HOME/.xsession
    chown $USER:$USER $USER_HOME/.xsession

    # Add startx to .bash_profile
    cat << EOF >> $USER_HOME/.bash_profile
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
    exec startx -- >/dev/null 2>&1
fi
EOF
    chown $USER:$USER $USER_HOME/.bash_profile
    echo -e "FINISHED enable_autostart_xwindows \n\n"
    sleep 2
}


# Hide Openbox Windows and reduce visibility of terminal
function hide_openbox_windows() {
    echo "--------------------------------------------------------------------------------"
    echo "| Hiding window decorations in OpenBox"
    echo "--------------------------------------------------------------------------------"
    # Reduce the visibility of the gnome terminal by prepending these settings in the bash profile
    GNOME_TERMINAL_SETTINGS='dbus-launch gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/'
    cat << EOF >> $USER_HOME/.bash_profile
$GNOME_TERMINAL_SETTINGS use-theme-colors false
$GNOME_TERMINAL_SETTINGS use-theme-transparency false
$GNOME_TERMINAL_SETTINGS foreground-color '#FFFFFF'
$GNOME_TERMINAL_SETTINGS background-color '#000000'
$GNOME_TERMINAL_SETTINGS cursor-blink-mode 'off'
$GNOME_TERMINAL_SETTINGS scrollbar-policy 'never'
$GNOME_TERMINAL_SETTINGS audible-bell 'false'
gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false
EOF
    chown $USER:$USER $USER_HOME/.bash_profile

    # Further reduce the visibility of windows (terminal) by modifying the OpenBox config
    mkdir -p $USER_HOME/.config/openbox
    cp /etc/xdg/openbox/rc.xml $USER_HOME/.config/openbox/rc.xml
    cat << EOF > /tmp/rc.xml.applications
        <application class="*">
            <fullscreen>yes</fullscreen>
            <iconic>no</iconic>
            <layer>below</layer>
            <decor>no</decor>
            <maximized>true</maximized>
        </application>
EOF
    sed -i '/<applications>/r /tmp/rc.xml.applications' $USER_HOME/.config/openbox/rc.xml
    rm /tmp/rc.xml.applications
    sed -e 's/<keepBorder>yes<\/keepBorder>/<keepBorder>no<\/keepBorder>/g' -i $USER_HOME/.config/openbox/rc.xml
    chown -R $USER:$USER $USER_HOME/.config
    echo -e "FINISHED hide_openbox_xwindows \n\n"
    sleep 2
}


# Autostart OpenBox Applications
function autostart_openbox_apps() {
    echo "--------------------------------------------------------------------------------"
    echo "| Enabling OpenBox autostart applications and RetroPie autostart.sh"
    echo "--------------------------------------------------------------------------------"
    # OpenBox autostarts unclutter, then passes off to the RetroPie autostart
    mkdir -p $USER_HOME/.config/openbox
    echo 'unclutter -idle 0.01 -root' >> $USER_HOME/.config/openbox/autostart
    echo '/opt/retropie/configs/all/autostart.sh' >> $USER_HOME/.config/openbox/autostart
    chown -R $USER:$USER $USER_HOME/.config
    # Create RetroPie autostart
    mkdir -p /opt/retropie/configs/all
    touch /opt/retropie/configs/all/autostart.sh
    chmod +x /opt/retropie/configs/all/autostart.sh
    chown -R $USER:$USER /opt/retropie/configs
    cat << EOF > /opt/retropie/configs/all/autostart.sh
#! /bin/bash

gnome-terminal --full-screen --hide-menubar -- emulationstation --no-splash         # RPSU_End autostart_openbox_apps
EOF
    echo -e "FINISHED autostart_openbox_apps \n\n"
    sleep 2
}


# Install and configure extra tools
function install_extra_tools() {
    echo "--------------------------------------------------------------------------------"
    echo "| Installing the following tools to improve usability:"
    echo "| ${EXTRA_TOOLS[@]}"
    echo "--------------------------------------------------------------------------------"
    apt-get update
    apt-get install -y $APT_RECOMMENDS ${EXTRA_TOOLS[@]}

    # Configure 'inxi' if it was installed
    if [[ -x "$(command -v inxi)" ]]; then
        echo "--------------------------------------------------------------------------------"
        echo "| Enabling updates on the 'inxi' package", which is 
        echo "| used for checking hardware and system information"
        echo "| Command 'inxi -G' is useful for querying video card driver versions"
        echo "--------------------------------------------------------------------------------"
        sed -i 's/B_ALLOW_UPDATE=false/B_ALLOW_UPDATE=true/g' /etc/inxi.conf
        inxi -U
    fi
    
    echo -e "FINISHED install_extra_tools \n\n"
    sleep 2
}


# Install and configure extra tools
function fix_quirks() {
    echo "--------------------------------------------------------------------------------"
    echo "| Fixing any known quirks"
    echo "--------------------------------------------------------------------------------"

    # XDG_RUNTIME_DIR
    echo "--------------------------------------------------------------------------------"
    echo "| Remove 'error: XDG_RUNTIME_DIR not set in the environment' CLI error"
    echo "| when exiting Retroarch from the RetroPie Setup screen within ES"
    echo "| by creating a file in sudoers.d directory to keep environment variable"
    echo "--------------------------------------------------------------------------------"
    echo 'Defaults	env_keep +="XDG_RUNTIME_DIR"' | sudo tee /etc/sudoers.d/keep-xdg-environment-variable
    chmod 0440 /etc/sudoers.d/keep-xdg-environment-variable
    echo -e "\n"
    
    # Screen blanking
    echo "--------------------------------------------------------------------------------"
    echo "| Disable screen blanking (only happens outside of EmulationStation)"
    echo "| This prevents the display from doing any ‘screen blanking’ due to inactivity"
    echo "--------------------------------------------------------------------------------"
    sed -i '1 i\xset s off && xset -dpms' $USER_HOME/.xsession
    echo -e "\n"

    echo -e "FINISHED fix_quirks \n\n"
    sleep 2    
}


# Add the ability to change screen resolution in autostart.sh 
function set_resolution_xwindows() {
    echo "--------------------------------------------------------------------------------"
    echo "| Adding the ability to override the default display resolution"
    echo "| from the '/opt/retropie/config/all/autostart.sh' script."
    echo "| Update the PREFERRED_RESOLUTION variable inside the script to change this value."
    echo "| If not valid, it will gracefully revert to the display's preferred resolution."
    echo "| This is typically helpful for improving performance by lowering resolution on 4K displays"
    echo "--------------------------------------------------------------------------------"
    cat << EOF >> /tmp/set_resolution_xwindows

# RPSU_START set_resolution_xwindows
# Update the next line to customize the display resolution
# If will fall back to the display's preferred resolution, if the custom value is invalid 
PREFERRED_RESOLUTION=1920x1080
if [[ ! -z \$PREFERRED_RESOLUTION ]]; then
    current_resolution=\$(xrandr --display :0 | awk 'FNR==1{split(\$0,a,", "); print a[2]}' | awk '{gsub("current ","");gsub(" x ", "x");print}')
    connected_display=\$(xrandr --display :0 | grep " connected " | awk '{ print \$1 }')
    if \$(xrandr --display :0 | grep -q \$PREFERRED_RESOLUTION); then
        xrandr --display :0 --output \$connected_display --mode \$PREFERRED_RESOLUTION &
    else
        echo "\$PREFERRED_RESOLUTION is not available on \$connected_display.  Remaining at default resolution of \$current_resolution."
    fi
fi
# RPSU_END set_resolution_xwindows

EOF
    # Insert into autostart.sh after the 1st line (after shebang)
    sed -i '1r /tmp/set_resolution_xwindows' "/opt/retropie/configs/all/autostart.sh"
    rm /tmp/set_resolution_xwindows
    echo -e "FINISHED set_resolution_xwindows \n\n"
    sleep 2
}


# Sets the GRUB graphics mode
# Takes a valid mode string as a argument, such as "1920x1080x32"
# If none is provided, a default of 'auto' will be used
function set_resolution_grub() {
    if [[ -z "$1" ]]; then
        MODES="auto"
    else
        MODES="$1,auto"
    fi
    echo "--------------------------------------------------------------------------------"
    echo "| Changing the GRUB graphics mode to '$MODE'"
    echo "| If this mode is incompatible with your system, GRUB will fall back to 'auto' mode"
    echo "| Run 'vbeinfo' (legacy, pre-18.04) or 'videoinfo' (UEFI) from the GRUB command line"
    echo "| to see the supported modes"
    echo "| This value, 'GRUB_GFXMODE', can be edited in /etc/default/grub"
    echo "--------------------------------------------------------------------------------"
    sed -i "s/#GRUB_GFXMODE=.*/GRUB_GFXMODE=$MODES/g" "/etc/default/grub"
    update-grub
    echo -e "Done\n\n"
    sleep 2
    echo -e "FINISHED set_resolution_grub \n\n"
}


# Run any optional scripts that the user has provided
function run_optional_scripts() {
    SCRIPT_PATH=$1
    # If a specific file is provided, just run that
    if [[ -f $SCRIPT_PATH ]]; then
        SCRIPT_FILE_PATH=$SCRIPT_PATH
        echo "--------------------------------------------------------------------------------"
        echo "| Running optional script at $SCRIPT_FILE_PATH"
        echo "--------------------------------------------------------------------------------"
        echo -e "\n"
        source "$SCRIPT_FILE_PATH"
        sleep 2
    # Otherwise, run all scripts in the provided directory
    else
        echo "--------------------------------------------------------------------------------"
        echo "| Running any optional scripts found in $SCRIPT_PATH"
        echo "--------------------------------------------------------------------------------"
        ls "$SCRIPT_PATH" | sort -n | while read SCRIPT_FILE; do
            SCRIPT_FILE_PATH="$SCRIPT_PATH/$SCRIPT_FILE"
            if [[ -f $SCRIPT_FILE_PATH ]] && [[ $SCRIPT_FILE_PATH != *README* ]]; then
                echo -e "\n"
                source "$SCRIPT_FILE_PATH"
                sleep 2
            fi
        done
    fi
    echo -e "\n\n"
    echo -e "FINISHED run_optional_scripts \n\n"
}


# Repair any permissions that might have been incorrectly set
function repair_permissions() {
    echo "--------------------------------------------------------------------------------"
    echo "| Repairing file & folder permissions underneath $USER_HOME"
    echo "| by changing owner to $USER on all files and directories under $USER_HOME"
    echo "--------------------------------------------------------------------------------"
    chown -R $USER:$USER $USER_HOME/
    echo -e "FINISHED repair_permissions \n\n"
    sleep 2
}


# Remove unneeded packages
function remove_unneeded_packages() {
    echo "--------------------------------------------------------------------------------"
    echo "| Autoremoving any unneeded packages"
    echo "--------------------------------------------------------------------------------"
    apt-get update && apt-get -y upgrade
    apt-get -y autoremove
    echo -e "FINISHED remove_unneeded_packages \n\n"
    sleep 2
}

# Prompt user for reboot
function prompt_for_reboot() {
    read -p "Reboot the system now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
}


# Final message to user
function complete_install() {
    RUNTIME=$SECONDS
    echo "--------------------------------------------------------------------------------"
    echo "| Installation complete"
    echo "| Runtime: $(($RUNTIME / 60)) minutes and $(($RUNTIME % 60)) seconds"
    echo "| Output has been logged to '$LOG_FILE'"
    echo "--------------------------------------------------------------------------------"
    prompt_for_reboot
}

# Make sure the user is running the script via sudo
if [ -z "$SUDO_USER" ]; then
    echo "This script requires sudo privileges. Please run with: sudo $0"
    exit 1
fi
# Don't allow the user to run this script from the root account. RetroPie doesn't like this.
if [[ "$SUDO_USER" == root ]]; then
    echo "This script cannot be run by the root user.  Please run as normal user using sudo."
    exit 1
fi

#--------------------------------------------------------------------------------
#| INSTALLATION SCRIPT 
#--------------------------------------------------------------------------------
# If no arguments are provided
if [[ -z "$1" ]]; then

    #-- Log this script's output
    enable_logging
    run_optional_scripts "$OPTIONAL_SCRIPT_DIR/pre_install"
    #-- Basic RetroPie install 
    install_retropie_dependencies
    install_retropie
    install_retroarch_shaders
    disable_sudo_password
    #-- Common video drivers
    install_latest_intel_drivers
    install_latest_nvidia_drivers
    install_vulkan
    #-- Hide text and boot directly into EmulationStation
    enable_plymouth_theme "retropie-pacman"       # See https://github.com/HerbFargus/plymouth-themes.git for other theme names
    hide_boot_messages
    enable_runlevel_multiuser
    enable_autologin_tty
    enable_autostart_xwindows
    hide_openbox_windows
    autostart_openbox_apps
    #-- Additional customizations
    install_extra_tools
    fix_quirks
    #-- OPTIONAL STEPS (comment/change as needed)
    #   These are helpful for improving 4k performance and user experience
    set_resolution_xwindows "1920x1080"          # Run 'xrandr --display :0' when a X Windows session is running to the supported resolutions
    set_resolution_grub "1920x1080x32"           # Run 'vbeinfo' (legacy, pre 18.04) or 'videoinfo' (UEFI) from the GRUB command line to see the supported modes
    run_optional_scripts "$OPTIONAL_SCRIPT_DIR/post_install"
    #-- Final cleanup
    repair_permissions
    remove_unneeded_packages
    complete_install

# If function names are provided as arguments, just run those functions
# (then restore perms and clean up)
else
    enable_logging
    for call_function in "$@"; do
        $call_function
    done
    repair_permissions
    complete_install
fi

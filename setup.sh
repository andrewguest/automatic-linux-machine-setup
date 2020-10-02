#!/bin/bash

# 9/29/2020 - Initial creation


# First function to run. This will check for OS updates and describe what the script will do.
function setup {
    printf "This script will install a list of pre-defined packages and applications and the automatically set them up\n"
    printf "You must be in the sudoers group for this script to work!\n"
    printf "You must run this script as the user that will be using this setup!\n"

    # Make sure this script is being run on a Debian-like OS
    os_family=$(grep ID_LIKE /etc/os-release | cut -d'=' -f2)
    if [[ $os_family != "debian" ]]; then
        printf "[!] This script is written for Debian-like OSs only"
        exit 1
    fi

    # Check for OS updates and install them
    printf "[+] Checking for OS updates and installing them\n"
    if sudo apt update; then
        clear
        sudo apt upgrade -y
        sudo apt install jq -y
        printf "[+] All of the updates are installed!\n"
    else
        printf "[!] Error while trying to check for and install OS updates\n"
        exit 1
    fi
}


# This function will install and setup the terminal to work with Github.com
function Github_setup {
    clear
    printf "[+] Installing the 'gh' Github cli client\n"
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
    sudo apt-add-repository https://cli.github.com/packages
    sudo apt update
    sudo apt install gh -y
    printf "[+] Successfully installed the Github ('gh') command line client\n"

    if [[ -f ~/.ssh/id_rsa && -f ~/.ssh/id_rsa.pub ]] ; then
        printf "[+] SSH keys exist\n"
    else
        printf "[-] SSH keys do NOT exist. Creating one\n"
        # Generate an SSH public and private key
        ssh-keygen -t rsa -b 4096 -q -N "" -f ~/.ssh/id_rsa
        if [ $? -eq 0 ]; then
            printf "[+] Successfully generated SSH keys\n"
        else
            printf "[!] Could not generate SSH keys\n"
            exit 1
        fi
    fi
    ssh-add ~/.ssh/id_rsa

    read -p "Enter Github username: " githubuser
    printf "Go to Github.com and delete the current personal access token named 'New Linux machine setup script'.\n"
    printf "https://github.com/settings/tokens\n"
    printf "Then generate a new personal access token, with the same name, and copy the token for use here!\n"
    read -p "Personal access token: " token
    public_key=`cat ~/.ssh/id_rsa.pub`
    
    # Send the new SSH key to Github
    post_result=$(curl -u $githubuser:$token -X POST -H "Accept: application/vnd.github.v3+json" \
        -d "{\"title\":\"`hostname`\",\"key\":\"$public_key\"}" \
        https://api.github.com/user/keys)
    
    message=`echo $post_result | jq .message`
    error_message=`echo $post_result | jq .errors[].message`

    printf "$message"

    # If there's an error message from Github then print it
    if [ ! -z "$error_message" ]; then
        printf "[-] $error_message\n"
    fi

    # Pull the .gitconfig file
    printf "[+] Pulling your custom .gitconfig file\n"
    wget https://raw.githubusercontent.com/andrewguest/automatic-linux-machine-setup/master/.gitconfig > .gitconfig
}


function Install_OS_packages {
    clear

    # add the Microsoft VS Code GPG key and repo
    sudo wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"

    packages=("python3" "python3-pip" "git" "pipenv" "zsh" "software-properties-common" \
        "apt-transport-https" "code" "curl" "gconf2" "vlc" "zsh" "nodejs" )
    install_command='sudo apt install'

    printf "[+] Installing:\n"
    for package in ${packages[@]}; do
        printf "\t$package\n"
        install_command="$install_command $package"
    done

    # install the OS packages
    $install_command -y

    clear
    # install snap packages
    snap_install_command="sudo snap install"
    
    snap_packages=("postman" "gitkraken" "bitwarden")
    
    for package in ${snap_packages[@]}; do
        snap_install_command="$snap_install_command $package"
    done
    $snap_install_command 


    clear
    # Install DBeaver
    printf "[+] Installing DBeaver\n"
    sudo wget https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb -P /tmp
    sudo dpkg -i /tmp/dbeaver-ce_latest_amd64.deb
}


function Install_NPM_packages {
    clear
    
    printf "[+] Install NPM packages\n"

    npm_packages=("typescript" "@vue/cli" "vue" "yarn")
    
    npm_install_command="sudo npm install -g"

    printf "[+] Installing these Python packages:\n"
    for package in ${npm_packages[@]}; do
        printf "\t$package\n"
        npm_install_command="$npm_install_command $package"
    done

    $npm_install_command
}


function Install_Python_packages {
    clear
    python_packages=("jupyter" "notebook" "aws-shell" "pytest" "memory_profiler" "fastapi")

    pip_install_command="sudo pip3 install"

    printf "[+] Installing these Python packages:\n"
    for package in ${python_packages[@]}; do
        printf "\t$package\n"
        pip_install_command="$pip_install_command $package"
    done

    $pip_install_command
}


function Setup_ZSH {
    clear

    # If the .zshrc file, included with this repo, doesn't exist then pull it from Github  
    if [[ ! -f .zshrc ]] ; then
        printf "[+] .zshrc file not found locally. Pulling from Github\n"
        wget https://raw.githubusercontent.com/andrewguest/automatic-linux-machine-setup/master/.zshrc > .zshrc
    fi

    printf "[+] Copying ZSH config file to home directory\n"
    cp .zshrc ~

    printf "[+] Setting ZSH as your default shell\n"
    sudo chsh -s $(which zsh)

    printf "[+] Install Oh My ZSH\n"
    sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    printf "[+] Please log out and back in to use ZSH\n"

}


# Run the functions
Install_Python_packages
Github_setup
Install_OS_packages
Install_NPM_packages
Install_Python_packages
Setup_ZSH

# Clean up
sudo apt autoremove

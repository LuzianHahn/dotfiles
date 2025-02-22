# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ANSI octal sequence escape codes for colors. Should work on most systems
if command -V tput &> /dev/null;then
    red_color="$(tput setaf 1)"
    green_color="$(tput setaf 2)"
    yellow_color="$(tput setaf 3)"
    blue_color="$(tput setaf 6)"
    reset_color="$(tput sgr0)"
else
    red_color="\033[31m"
    green_color="\033[32m"
    yellow_color="\033[33m"
    blue_color="\033[36m"
    reset_color="\033[0m"
fi

# source custom autocompletion on PS1 git utils on MacOS, since they are not included per default
# see also https://www.macinstruct.com/tutorials/how-to-enable-git-tab-autocomplete-on-your-mac/ and
#   https://stackoverflow.com/questions/12870928/mac-bash-git-ps1-command-not-found
# bash files were downloaded from:
# - https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
# - https://raw.github.com/git/git/master/contrib/completion/git-prompt.sh
if [ "$(uname -s)" == "Darwin" ];then
    for f in git-completion.bash git-prompt.sh;do
        if [ -f $HOME/.local/lib/git-tools/$f ];then
            . $HOME/.local/lib/git-tools/$f
        fi
    done
fi

# Function to retrieve branch of current git project.
# If __git_ps1 is not present (which comes ordinary with git's completion utils), this remains silent.
export GIT_PS1_SHOWDIRTYSTATE=true         # indicate with "*" if there are untracked changes 
                                           # and with "+" if there are staged changes
export GIT_PS1_SHOWUNTRACKEDFILES=true     # indicate with "%" if there are untracked files
export GIT_PS1_SHOWUPSTREAM=true           # indicate with ">" if you are before or with "<" behind the upstream branch
git_infos () {
    __git_ps1 "[%s] " 2> /dev/null
}

PS1="${debian_chroot:+($debian_chroot)}""\[${yellow_color}\]"'$(git_infos)'"\[${reset_color}\]"
PS1="${PS1}\[${green_color}\]\u@\h\[${reset_color}\]:\[${blue_color}\]\w\[${reset_color}\]\$ "
# It is important to surround the colors within $PS1 with "\[" and "\]". 
# Otherwise it will also apply the correct coloring but cause problems handling longer statements.
# See also https://askubuntu.com/questions/111840/ps1-problem-messing-up-cli


# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -lahs'
alias la='ls -A'
alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

alias cfg='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias cfgedit='GIT_DIR=$HOME/.cfg GIT_WORK_TREE=$HOME vim'


# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


# >>> Homebrew initialization >>>
if [ "$(uname -s)" == "Darwin" ];then
    if [ -f /opt/homebrew/bin/brew ];then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
# <<< homebrew initialization

export PATH="$HOME/.local/bin:$PATH"


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/.local/miniconda3/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/.local/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/.local/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/.local/miniconda3/bin:$PATH"
    fi
fi
conda deactivate
unset __conda_setup
# <<< conda initialize <<<

# >>> uv initialization >>>
# In case of MacOS, this needs to happen after the Homebrew initialzation,
#  as this one contains potential python environments.
if [ -z $DISABLE_UV_INIT ] && command -v uv &> /dev/null ;then
    eval "$(uv generate-shell-completion bash)"
    BASE_UV_VENV_PATH=$HOME/.local/lib/uv_base
    BASE_UV_PYTHON_VERSION=3.12
    export UV_PYTHON_PREFERENCE=only-managed
    # pin python version only in $HOME to prevent `.python-version`-files appearing everywhere.
    ( cd $HOME && uv python pin $BASE_UV_PYTHON_VERSION > /dev/null )
    if [ ! -f $BASE_UV_VENV_PATH/bin/activate ];then
        uv venv --no-project $HOME/.local/lib/uv_base
    fi
    activate_base_venv() {
        source $BASE_UV_VENV_PATH/bin/activate
    }
fi
# <<< uv initialization

# Prevent usage of Keyring within Poetry
export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring

# Enables automatic loading of screen-session specific bash utilities
CURRENT_SCREENSESSION=$(echo "$STY" | cut -d. -f2)
if [ -f $HOME/.local/screen_env/$CURRENT_SCREENSESSION ];then
    . $HOME/.local/screen_env/$CURRENT_SCREENSESSION
fi

# allow parallel maintaining of bash history (e.g. in different sceen sessions)
export PROMPT_COMMAND='history -a'


# >>> Cargo initialization
if [ -f $HOME/.cargo/env ];then 
    . "$HOME/.cargo/env"
fi
# <<< Cargo initialization


# >>> nvm initialization
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# <<< nvm initialization

# Activate uv_base venv at then end, since its activation stores the $PATH-Env Variable up till this point.
# So calling `deactivate` removes $PATH changes, that were applied after its activation.
if [ -n $BASE_UV_VENV_PATH ];then
    activate_base_venv
fi

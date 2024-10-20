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
red_color="$(tput setaf 1)"
green_color="$(tput setaf 2)"
yellow_color="$(tput setaf 3)"
blue_color="$(tput setaf 6)"
reset_color="$(tput sgr0)"
# comment out or remove if no colors should get added or ANSI colors are not properly interpreted.
color_prompt=yes


# Function to retrieve branch of current git project.
# If __git_ps1 is not present (which comes ordinary with git's completion utils), this remains silent.
export GIT_PS1_SHOWDIRTYSTATE=true         # indicate with "*" if there are untracked changes 
                                           # and with "+" if there are staged changes
export GIT_PS1_SHOWUNTRACKEDFILES=true     # indicate with "%" if there are untracked files
export GIT_PS1_SHOWUPSTREAM=true           # indicate with ">" if you are before or with "<" behind the upstream branch
git_infos () {
    git_infos="$(__git_ps1 "[%s] " 2> /dev/null)"
    printf '\001%s\002%s\001%s\002' "$yellow_color" "$git_infos" "$reset_color"
}

PS1="${debian_chroot:+($debian_chroot)}"'$(git_infos)'
PS1="${PS1}${green_color}\u@\h${reset_color}:${blue_color}\w${reset_color}\$ "
unset color_prompt


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
unset __conda_setup
# <<< conda initialize <<<

alias cfg='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias cfgedit='GIT_DIR=$HOME/.cfg GIT_WORK_TREE=$HOME vim'

export PATH="$HOME/.local/bin:$PATH"

# Prevent usage of Keyring within Poetry
export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring

# Enables automatic loading of screen-session specific bash utilities
CURRENT_SCREENSESSION=$(echo "$STY" | cut -d. -f2)
if [ -f $HOME/.local/screen_env/$CURRENT_SCREENSESSION ];then
    . $HOME/.local/screen_env/$CURRENT_SCREENSESSION
fi

# allow parallel maintaining of bash history (e.g. in different sceen sessions)
export PROMPT_COMMAND='history -a'

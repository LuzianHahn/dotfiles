(
  AUTHOR=${AUTHOR:-private}
  create_work_contact_data_for_git () {
    echo "This system is currently using the following Authorship Metadata:"
    echo "Name: `git config --get user.name`"
    echo "Email: `git config --get user.email`"
    if [ "$AUTHOR" == "work" ]; then
      echo "\"work\" Authorship triggered. Setting up work account..."
      ln -s $HOME/.local/installer/.gitconfig.work.inc $HOME/
    else
      echo "Keeping original Authorship Metadata. If you want to change it, use:"
      echo "\"git config --global user.name\""
      echo and
      echo "\"git config --global user.email\""
    fi
  }

  cd $HOME
  git clone --bare https://github.com/LuzianHahn/dotfiles.git $HOME/.cfg
  function config {
    /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
  }
  mkdir -p .config-backup
  config checkout
  if [ $? = 0 ]; then
    echo "Checked out config.";
  else
    echo "Backing up pre-existing dot files.";
    config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
    echo "Backup is located at \"$PWD/.config-backup\""
    config checkout
  fi;
  config config --local status.showUntrackedFiles no
  config config --local user.email "luzian@hahn-coburg.de"
  config submodule update --init --recursive

  create_work_contact_data_for_git
)

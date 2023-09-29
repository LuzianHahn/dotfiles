(
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
  config submodule update --init --recursive
)

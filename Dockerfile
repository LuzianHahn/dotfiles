FROM debian:latest
RUN apt update && apt install vim curl git build-essential -y
RUN curl https://raw.githubusercontent.com/LuzianHahn/dotfiles/debian/.local/installer/dotfile_installer.sh | bash 
RUN bash -i /root/.local/installer/extra_installer.sh

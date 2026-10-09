alias open-webui='ssh 100.100.90.107 "systemctl --user start open-webui; journalctl --user -u open-webui -f; systemctl --user stop open-webui"'
alias strata='ssh 100.100.90.107 "systemctl --user start strata; journalctl --user -u strata -f; systemctl --user stop strata"'
alias comfyui='ssh 100.100.90.107 "systemctl --user start comfyui; journalctl --user -u comfyui -f; systemctl --user stop comfyui"'
alias sillytavern="cd ~/m2a/ai-chat/sillytavern && git pull && ./start.sh"

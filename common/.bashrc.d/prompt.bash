# Universal chroot prompt detection
if [ -n "$CHROOT_NAME" ]; then
  chroot_prompt="($CHROOT_NAME)"
elif [ -r /etc/chroot_name ]; then
  chroot_prompt="($(cat /etc/chroot_name))"
else
  chroot_prompt=""
fi

# Color prompt detection
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

if [ "$color_prompt" = yes ]; then
  PS1='${chroot_prompt}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${chroot_prompt}\u@\h:\w\$ '
fi

# Window title for X terminals
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${chroot_prompt}\u@\h: \w\a\]$PS1"
  ;;
esac


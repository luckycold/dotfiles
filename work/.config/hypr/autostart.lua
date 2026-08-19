-- Extra autostart processes.
local home = os.getenv("HOME") or ""

o.launch_on_start(home .. "/Applications/proton-login-wrapper")
o.launch_on_start("/opt/teams-for-linux/teams-for-linux")
o.launch_on_start("brave")
o.launch_on_start(home .. "/AppImages/oneleet.appimage --password-store=gnome-libsecret")
o.launch_on_start("betterbird")

-- Extra autostart processes.
local home = os.getenv("HOME") or ""

o.launch_on_start("omarchy-launch-webapp https://teams.cloud.microsoft")
o.launch_on_start("brave-origin")
o.launch_on_start(home .. "/AppImages/oneleet.appimage --password-store=gnome-libsecret")
o.launch_on_start("betterbird")

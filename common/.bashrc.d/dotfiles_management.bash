#!/bin/bash
# Dotfiles Management and Update Checker (merged)

_dotfiles_dir() {
    printf '%s\n' "${DOTFILES_DIR:-$HOME/dotfiles}"
}

# Desktop notification helper (freedesktop.org spec)
_can_send_desktop_notification() {
    command -v notify-send &>/dev/null || return 1
    [ -n "${DBUS_SESSION_BUS_ADDRESS-}" ] || return 1

    # Probe for a running notification service if possible
    if command -v gdbus &>/dev/null; then
        gdbus call --session \
            --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.GetServerInformation \
            >/dev/null 2>&1 || return 1
    fi

    return 0
}

_notify_desktop() {
    _can_send_desktop_notification || return 1
    notify-send "$@" 2>/dev/null
}

_dotfiles_notifications_available() {
    # Prefer checking D-Bus ownership (most universal).
    if command -v gdbus &>/dev/null; then
        local has_owner
        has_owner=$(gdbus call --session \
            --dest org.freedesktop.DBus \
            --object-path /org/freedesktop/DBus \
            --method org.freedesktop.DBus.NameHasOwner \
            org.freedesktop.Notifications 2>/dev/null) || return 1

        case "$has_owner" in
            *true*) return 0 ;;
            *) return 1 ;;
        esac
    fi

    # Fallback for systems without gdbus.
    if command -v busctl &>/dev/null; then
        busctl --user --quiet status org.freedesktop.Notifications >/dev/null 2>&1
        return $?
    fi

    return 1
}

# Send notification about available updates
# Wrapper to ensure we use the new action-based notification system
send_update_notification() {
    # If the new function exists, use it
    if command -v send_dotfiles_notification &>/dev/null; then
        send_dotfiles_notification
        return $?
    fi

    # Fallback to sourcing the file if function not found (e.g. background subshell)
    local dotfiles_dir
    dotfiles_dir="$(_dotfiles_dir)"
    if [ -f "$dotfiles_dir/common/.bashrc.d/dotfiles_notify.bash" ]; then
        source "$dotfiles_dir/common/.bashrc.d/dotfiles_notify.bash"
        if command -v send_dotfiles_notification &>/dev/null; then
            send_dotfiles_notification
            return $?
        fi
    fi

    # Legacy fallback if something is really broken
    if command -v osascript &>/dev/null; then
        osascript -e 'display notification "Run update-dotfiles to update" with title "Dotfiles Update Available"' 2>/dev/null || return 1
    elif _notify_desktop "Dotfiles Update Available" "Run 'update-dotfiles' to update"; then
        return 0
    else
        return 1
    fi
}

# --- Portable agent skills (skills.sh) ---
#
# Luke's portable skills come only from luckycold/agent-skills, installed with
# the official skills.sh CLI (https://skills.sh/docs/cli, source and flag
# reference: https://github.com/vercel-labs/skills docs/commands.md):
#   skills add luckycold/agent-skills --skill '*' --global --yes --agent ...
# That writes real copies to ~/.agents/skills/<skill>, which Codex, Cursor and
# OpenCode read directly, links ~/.claude/skills/<skill> to
# ../../.agents/skills/<skill> for Claude Code, and records each skill in
# ~/.agents/.skill-lock.json ($XDG_STATE_HOME/skills/ when that is set).
# Entries from other sources (cua-driver, Claude's synced/ and .trash/) are not
# touched. Nothing is deleted: anything replaced moves to
# ${XDG_STATE_HOME:-~/.local/state}/agent-skills/replaced-<timestamp>/.

# Pinned skills.sh CLI. Renovate proposes bumps (renovate.json); set
# AGENT_SKILLS_CLI_VERSION to try another version on one host.
_AGENT_SKILLS_CLI_PIN=1.7.4 # renovate: datasource=npm depName=skills

_agent_skills_source() {
    printf '%s\n' "${AGENT_SKILLS_SOURCE:-luckycold/agent-skills}"
}

_agent_skills_state_dir() {
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/agent-skills"
}

_agent_skills_lock_file() {
    if [ -n "${XDG_STATE_HOME-}" ]; then
        printf '%s\n' "$XDG_STATE_HOME/skills/.skill-lock.json"
    else
        printf '%s\n' "$HOME/.agents/.skill-lock.json"
    fi
}

# The git clone that commit 5f71da0 used instead of skills.sh.
_agent_skills_old_clone_dir() {
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/agent-skills"
}

# Succeeds when PATH=$1 has node >= 22.20 (the CLI's engines floor) and npm.
_agent_skills_node_ok() {
    PATH="$1" node -e 'const [a, b] = process.versions.node.split(".").map(Number);
process.exit(a > 22 || (a === 22 && b >= 20) ? 0 : 1)' >/dev/null 2>&1 &&
        PATH="$1" npm --version >/dev/null 2>&1
}

# Print a PATH with a usable node and npm. Non-interactive SSH shells often
# lack the host-local agent-tools prefix, so look for mise there too.
_agent_skills_node_path() {
    local mise_bin="" candidate node_bin

    if _agent_skills_node_ok "$PATH"; then
        printf '%s\n' "$PATH"
        return 0
    fi
    for candidate in "$(command -v mise 2>/dev/null)" \
        "$HOME/.local/share/agent-tools/bin/mise" "$HOME/.local/bin/mise"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            mise_bin="$candidate"
            break
        fi
    done
    if [ -n "$mise_bin" ]; then
        # The node mise already resolves for $HOME (global, system or local config).
        node_bin=$(cd "$HOME" && "$mise_bin" which node 2>/dev/null)
        if [ -n "$node_bin" ] && _agent_skills_node_ok "${node_bin%/*}:$PATH"; then
            printf '%s\n' "${node_bin%/*}:$PATH"
            return 0
        fi
        # None configured: install a contained runtime, as documented in the README.
        echo "Installing node@latest with mise for the skills.sh CLI..." >&2
        if "$mise_bin" install --quiet node@latest >&2 &&
            node_bin="$("$mise_bin" where node@latest)/bin/node" &&
            _agent_skills_node_ok "${node_bin%/*}:$PATH"; then
            printf '%s\n' "${node_bin%/*}:$PATH"
            return 0
        fi
    fi
    {
        echo "update-agent-skills: the skills.sh CLI needs Node.js >= 22.20 and npm; none found."
        echo "  Hint: install mise to ~/.local/share/agent-tools/bin and run 'mise use -g node@lts',"
        echo "  or install Node.js 22.20+ from the system package manager, then re-run."
        echo "  Installed skills were left as they are."
    } >&2
    return 1
}

# Run the pinned skills.sh CLI through Node from $HOME, without prompts or
# telemetry. Calling cli.mjs through node also works where npm's cache is
# mounted noexec and the generated `skills` shim cannot run.
_run_agent_skills_cli() {
    local node_path="${_AGENT_SKILLS_NODE_PATH-}"
    [ -n "$node_path" ] || node_path=$(_agent_skills_node_path) || return 1
    # shellcheck disable=SC2016 # the inner sh expands $cli and $@
    (
        cd "$HOME" || exit 1
        PATH="$node_path" DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 NO_COLOR=1 \
            npm_config_update_notifier=false npm_config_fund=false npm_config_audit=false \
            npm exec --yes --package="skills@${AGENT_SKILLS_CLI_VERSION:-$_AGENT_SKILLS_CLI_PIN}" -- sh -c '
                cli=$(command -v skills) || exit 127
                exec node "$(dirname "$cli")/../skills/bin/cli.mjs" "$@"
            ' sh "$@" </dev/null
    )
}

_remove_legacy_agent_skills_link() {
    local link_path="$1"
    local expected_suffix="$2"
    local link_target

    [ -L "$link_path" ] || return 0
    link_target=$(readlink "$link_path") || return 1

    case "$link_target" in
        *"$expected_suffix")
            unlink "$link_path"
            ;;
        *)
            echo "Refusing to replace unexpected skill link: $link_path -> $link_target" >&2
            return 1
            ;;
    esac
}

# True for link targets that older installers managed: the 5f71da0 clone,
# other agent-skills checkouts, or the vendored dotfiles skills trees.
_agent_skills_managed_target() {
    case "$1" in
        "$(_agent_skills_old_clone_dir)"/skills/* | */agent-skills/skills/* | \
            */agent-skills-*/skills/* | */dotfiles/common/.agents/skills/* | \
            */dotfiles/common/.claude/skills/*)
            return 0 ;;
    esac
    return 1
}

# Print the per-skill links that still point into old managed locations.
_agent_skills_old_links() {
    local kind path
    for kind in agents claude; do
        for path in "$HOME/.$kind/skills"/* "$HOME/.$kind/skills"/.[!.]*; do
            [ -L "$path" ] || continue
            _agent_skills_managed_target "$(readlink "$path")" && printf '%s\n' "$path"
        done
    done
}

# Move per-skill links into old managed locations to $1/<dir>-links and print
# "moved-path<TAB>backup-path" for each. skills.sh needs real directories there.
_agent_skills_move_old_links() {
    local backup_dir="$1" kind path
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        kind="${path#"$HOME"/.}"
        kind="${kind%%/*}"
        mkdir -p "$backup_dir/$kind-links" || return 1
        mv -- "$path" "$backup_dir/$kind-links/" || return 1
        printf '%s\t%s\n' "$path" "$backup_dir/$kind-links/${path##*/}"
    done <<< "$(_agent_skills_old_links)"
}

# Undo _agent_skills_move_old_links ($2) after a failed or interrupted
# install. Anything skills.sh already wrote in a link's place is a partial copy
# of upstream content; it moves to $1/partial/ so the old link can go back.
_agent_skills_restore_links() {
    local backup_dir="$1" moved backup partial
    while IFS=$'\t' read -r moved backup; do
        [ -n "$moved" ] && { [ -e "$backup" ] || [ -L "$backup" ]; } || continue
        if [ -e "$moved" ] || [ -L "$moved" ]; then
            partial="$backup_dir/partial/${moved#"$HOME"/}"
            mkdir -p "${partial%/*}" && mv -- "$moved" "$partial" || {
                echo "Left $backup in place; could not move $moved aside." >&2
                continue
            }
        fi
        mv -- "$backup" "$moved"
    done <<< "$2"
    rmdir "$backup_dir"/*-links "$backup_dir" 2>/dev/null
    return 0
}

# Move the 5f71da0 clone aside once nothing links into it any more. A clone
# with another origin is reported and left alone; it never forces a reinstall.
_agent_skills_retire_old_clone() {
    local backup_dir="$1" clone_dir origin path
    clone_dir="$(_agent_skills_old_clone_dir)"
    [ -e "$clone_dir" ] || return 0
    origin=$(git -C "$clone_dir" remote get-url origin 2>/dev/null)
    case "$origin" in
        *github.com[:/]luckycold/agent-skills | *github.com[:/]luckycold/agent-skills.git | \
            *github.com[:/]luckycold/agent-skills/ | *github.com[:/]luckycold/agent-skills.git/) ;;
        *)
            echo "Leaving $clone_dir in place: it is not a luckycold/agent-skills clone (origin: ${origin:-none}). Remove it by hand if it is unused."
            return 0 ;;
    esac
    for path in "$HOME"/.agents/skills/* "$HOME"/.claude/skills/*; do
        [ -L "$path" ] || continue
        case "$(readlink -f -- "$path")" in
            "$(readlink -f -- "$clone_dir")"/*)
                echo "Keeping $clone_dir: $path still links into it." >&2
                return 0 ;;
        esac
    done
    mkdir -p "$backup_dir" || return 1
    mv -- "$clone_dir" "$backup_dir/agent-skills-clone" || return 1
    echo "Moved the old agent-skills git clone to $backup_dir/agent-skills-clone"
}

# Refuse layouts where skills.sh would write into a git checkout: a folded
# ~/.agents or ~/.claude (a link into the dotfiles tree, left by a plain
# `stow common` on a host without them), or a clone at ~/.agents (the box).
_agent_skills_check_home() {
    local dotfiles_real dir real top
    if [ -L "$HOME/.agents/skills" ]; then
        echo "update-agent-skills: ~/.agents/skills is a link ($(readlink "$HOME/.agents/skills")); move it aside first." >&2
        return 1
    fi
    dotfiles_real=$(cd "$(_dotfiles_dir)" 2>/dev/null && pwd -P)
    for dir in .agents .claude; do
        real=$(cd "$HOME/$dir" 2>/dev/null && pwd -P) || continue
        case "$real" in
            "$dotfiles_real" | "$dotfiles_real"/*)
                [ -n "$dotfiles_real" ] || continue
                echo "update-agent-skills: ~/$dir resolves into the dotfiles checkout ($real); skills.sh would write into it." >&2
                echo "  Unfold it: rm ~/$dir && mkdir ~/$dir && (cd \"$(_dotfiles_dir)\" && stow -R -t ~ common), then re-run." >&2
                return 1 ;;
        esac
    done
    top=$(git -C "$HOME/.agents" rev-parse --show-toplevel 2>/dev/null) || return 0
    [ "$top" = "$(cd "$HOME/.agents" && pwd -P)" ] || return 0
    echo "update-agent-skills: ~/.agents is a git checkout; skills.sh would write into it." >&2
    echo "  Migrate once: mv ~/.agents ~/.agents.pre-skills-sh && mkdir ~/.agents &&" >&2
    echo "    (cd \"$(_dotfiles_dir)\" && stow -R -t ~ common) && init-env-secrets --all && update-agent-skills" >&2
    echo "  (scoped agents: render only their authorized selector instead of --all)." >&2
    return 1
}

# Hold the updater lock until the calling subshell exits: flock where it
# exists, otherwise (macOS) an atomic mkdir lock that is reclaimed when the
# process that took it is gone.
_agent_skills_take_lock() {
    local lock="$1" waited=0 owner
    if command -v flock >/dev/null 2>&1; then
        exec 9>>"$lock" || return 1
        flock -w 300 9 && return 0
    else
        until mkdir "$lock.d" 2>/dev/null; do
            owner=$(cat "$lock.d/pid" 2>/dev/null)
            if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
                rm -rf "$lock.d"
                continue
            fi
            if [ "$waited" -ge 300 ]; then
                echo "update-agent-skills: another refresh is still running." >&2
                return 1
            fi
            sleep 1
            waited=$((waited + 1))
        done
        echo "${BASHPID:-$$}" >"$lock.d/pid"
        # shellcheck disable=SC2064 # expand the path now
        trap "rm -rf '$lock.d'" EXIT
        return 0
    fi
    echo "update-agent-skills: another refresh is still running." >&2
    return 1
}

# Upstream commit for the source, or nothing when it cannot be checked.
_agent_skills_remote_head() {
    local source repo_url
    source="$(_agent_skills_source)"
    case "$source" in
        */*) repo_url="https://github.com/$source.git" ;;
        *) return 0 ;;
    esac
    if command -v timeout >/dev/null 2>&1; then
        GIT_TERMINAL_PROMPT=0 timeout 30s git ls-remote "$repo_url" HEAD 2>/dev/null | cut -f1
    else
        GIT_TERMINAL_PROMPT=0 git ls-remote "$repo_url" HEAD 2>/dev/null | cut -f1
    fi
}

# Stamp of the last complete sync: source, upstream commit, CLI version, skills.
_agent_skills_stamp_file() {
    printf '%s\n' "$(_agent_skills_state_dir)/last-sync"
}

# Succeeds when the last complete sync is still in place: same source and CLI,
# the same upstream commit $1 (not compared when $1 is empty because GitHub
# could not be reached), every skill it installed still a real directory, and
# no links left from an older layout. Then no network install is needed.
_agent_skills_current() {
    local head="$1" stamp key value name
    local want_source want_cli
    stamp="$(_agent_skills_stamp_file)"
    want_source="$(_agent_skills_source)"
    want_cli="${AGENT_SKILLS_CLI_VERSION:-$_AGENT_SKILLS_CLI_PIN}"
    [ -f "$stamp" ] && [ -f "$(_agent_skills_lock_file)" ] || return 1
    [ -z "$(_agent_skills_old_links)" ] || return 1
    while read -r key value; do
        case "$key" in
            source) [ "$value" = "$want_source" ] || return 1 ;;
            head) [ -z "$head" ] || [ "$value" = "$head" ] || return 1 ;;
            cli) [ "$value" = "$want_cli" ] || return 1 ;;
            skill)
                name="$value"
                [ -f "$HOME/.agents/skills/$name/SKILL.md" ] && [ ! -L "$HOME/.agents/skills/$name" ] || return 1
                if [ -d "$HOME/.claude" ]; then
                    [ -f "$HOME/.claude/skills/$name/SKILL.md" ] || return 1
                fi
                ;;
        esac
    done < "$stamp"
    grep -q '^skill ' "$stamp"
}

# Read the CLI's --json result ($1) and lock file; print "installed <name>"
# and "retired <name>" (locked for this source, no longer upstream). Fails if
# any skill failed to install.
_agent_skills_classify() {
    # shellcheck disable=SC2016 # JavaScript template literals, not shell
    PATH="$_AGENT_SKILLS_NODE_PATH" node -e '
const fs = require("fs");
const [jsonPath, lockPath, source] = process.argv.slice(1);
const text = fs.readFileSync(jsonPath, "utf8");
const results = JSON.parse(text.slice(text.indexOf("[")));
let ok = results.length > 0;
const installed = new Set();
for (const r of results) {
  if (r.status === "installed" && r.source === source) installed.add(r.name);
  else { ok = false; console.error(`skills.sh: ${r.name || "?"}: ${r.status} ${r.error || ""}`); }
}
let locked = {};
try { locked = JSON.parse(fs.readFileSync(lockPath, "utf8")).skills || {}; } catch {}
for (const n of [...installed].sort()) console.log(`installed ${n}`);
for (const n of Object.keys(locked).sort())
  if (locked[n].source === source && !installed.has(n)) console.log(`retired ${n}`);
process.exit(ok ? 0 : 1);' "$1" "$(_agent_skills_lock_file)" "$(_agent_skills_source)"
}

# Exit status of update-agent-skills when Node.js is unavailable: a skipped
# refresh (installed skills kept), which callers report without failing.
_AGENT_SKILLS_NO_NODE=69

# Install or refresh Luke's portable skills through skills.sh. Idempotent: a
# run with nothing new upstream does one `git ls-remote` and prints one line.
update-agent-skills() (
    local source state_dir backup_dir head moved="" classes kind name status=0
    local -a retired=()
    source="$(_agent_skills_source)"
    state_dir="$(_agent_skills_state_dir)"
    backup_dir="$state_dir/replaced-$(date +%Y%m%d-%H%M%S)"

    mkdir -p "$state_dir" || exit 1
    # One updater at a time (startup job vs update-dotfiles), before any change.
    _agent_skills_take_lock "$state_dir/update.lock" || exit 1

    _remove_legacy_agent_skills_link \
        "$HOME/.agents/skills" "dotfiles/common/.agents/skills" || exit 1
    _remove_legacy_agent_skills_link \
        "$HOME/.claude/skills" "dotfiles/common/.claude/skills" || exit 1
    _agent_skills_check_home || exit 1

    head="$(_agent_skills_remote_head)"
    if _agent_skills_current "$head"; then
        if [ -n "$head" ]; then
            echo "Agent skills are current ($source@${head:0:7})."
        else
            echo "Could not reach $source; keeping the installed agent skills."
        fi
        exit 0
    fi

    _AGENT_SKILLS_NODE_PATH="$(_agent_skills_node_path)" || exit "$_AGENT_SKILLS_NO_NODE"

    # Put old links back if the install is interrupted; the startup job's
    # timeout sends TERM to the whole process group.
    trap '_agent_skills_restore_links "$backup_dir" "$moved"; exit 143' TERM INT HUP
    moved="$(_agent_skills_move_old_links "$backup_dir")" || {
        _agent_skills_restore_links "$backup_dir" "$moved"
        exit 1
    }
    [ -n "$moved" ] && echo "Moved $(wc -l <<< "$moved") old skill links to $backup_dir"

    # Install the commit just checked, so the stamp names what is on disk.
    echo "Installing agent skills from $source${head:+@${head:0:7}} with skills.sh..."
    if ! _run_agent_skills_cli add "$source${head:+#$head}" --skill '*' --global --yes --json \
        --agent codex --agent claude-code --agent cursor --agent opencode \
        >"$state_dir/last-add.json" 2>"$state_dir/last-add.log" ||
        ! classes="$(_agent_skills_classify "$state_dir/last-add.json")"; then
        echo "update-agent-skills: skills.sh install failed; see $state_dir/last-add.log" >&2
        tail -n 5 "$state_dir/last-add.log" >&2
        _agent_skills_restore_links "$backup_dir" "$moved"
        exit 1
    fi
    trap - TERM INT HUP

    _agent_skills_retire_old_clone "$backup_dir" || status=1

    # Skills deleted upstream: keep a copy, then let skills.sh drop them from
    # the lock file and the Claude links.
    while read -r kind name; do
        [ "$kind" = retired ] || continue
        retired+=("$name")
        if [ -d "$HOME/.agents/skills/$name" ] && [ ! -L "$HOME/.agents/skills/$name" ]; then
            mkdir -p "$backup_dir/retired" && mv -- "$HOME/.agents/skills/$name" "$backup_dir/retired/" || status=1
        fi
    done <<< "$classes"
    if [ "${#retired[@]}" -gt 0 ]; then
        if _run_agent_skills_cli remove --global --yes "${retired[@]}" >>"$state_dir/last-add.log" 2>&1; then
            echo "Retired skills no longer in $source: ${retired[*]} (copies in $backup_dir/retired)"
        else
            echo "update-agent-skills: could not retire ${retired[*]}; see $state_dir/last-add.log" >&2
            status=1
        fi
    fi

    # Stamp only a clean sync, so anything left undone is retried next run.
    if [ "$status" -eq 0 ]; then
        {
            printf 'source %s\nhead %s\ncli %s\n' "$source" "$head" "${AGENT_SKILLS_CLI_VERSION:-$_AGENT_SKILLS_CLI_PIN}"
            sed -n 's/^installed /skill /p' <<< "$classes"
        } >"$state_dir/last-sync.tmp" && mv -f "$state_dir/last-sync.tmp" "$(_agent_skills_stamp_file)"
    else
        rm -f "$(_agent_skills_stamp_file)"
    fi

    echo "Installed $(grep -c '^installed ' <<< "$classes") agent skills from $source${head:+@${head:0:7}}."
    exit "$status"
)

# Bound background refreshes so they cannot run indefinitely.
# Keep the manual update-agent-skills command unchanged.
_dotfiles_auto_update_agent_skills() {
    [ "${AGENT_SKILLS_AUTO_UPDATE:-1}" = 1 ] || return 0

    local timeout_cmd
    if command -v timeout >/dev/null 2>&1; then
        timeout_cmd=timeout
    elif command -v gtimeout >/dev/null 2>&1; then
        timeout_cmd=gtimeout
    else
        echo "Skipping automatic agent skill refresh: timeout or gtimeout is required." >&2
        return 0
    fi

    # Pass only the required functions and settings (including unexported
    # AGENT_SKILLS_* overrides); never source shell startup files here.
    # shellcheck disable=SC2046 # one function name per word
    "$timeout_cmd" --kill-after=5s 120s env -u BASH_ENV bash --noprofile --norc -c \
        "_AGENT_SKILLS_CLI_PIN=$_AGENT_SKILLS_CLI_PIN
_AGENT_SKILLS_NO_NODE=$_AGENT_SKILLS_NO_NODE
$(declare -p AGENT_SKILLS_CLI_VERSION AGENT_SKILLS_SOURCE DOTFILES_DIR 2>/dev/null)
$(declare -f _dotfiles_dir $(declare -F | awk '$3 ~ /^(_agent_skills_|_run_agent_skills_cli$|_remove_legacy_agent_skills_link$|update-agent-skills$)/ {print $3}'))
update-agent-skills"
}

# git refuses a checkout owned by another user ("dubious ownership"), and
# the background check would then fail silently. Explain the fix instead.
_dotfiles_git_check_owner() {
    local dir="$1" err
    err=$(git -C "$dir" rev-parse --git-dir 2>&1 >/dev/null) && return 0
    case "$err" in
        *"dubious ownership"*)
            echo "Error: git refuses $dir: it is owned by $(stat -c %U "$dir" 2>/dev/null || stat -f %Su "$dir" 2>/dev/null || echo another user), not $(id -un)." >&2
            echo "  Fix: chown -R $(id -un): $dir (or re-clone it as $(id -un)). Do not add safe.directory '*'." >&2
            ;;
        *) printf '%s\n' "$err" >&2 ;;
    esac
    return 1
}

# The background check and update-dotfiles both fetch. Run them under one
# lock so they cannot race ("cannot lock ref ..."). $1 is how long to wait in
# seconds; 0 skips when another fetch holds the lock. Without flock, run as is.
_dotfiles_git_locked() {
    local wait="$1" lock_file
    shift
    lock_file="$(_dotfiles_dir)/.git/dotfiles-fetch.flock"
    if ! command -v flock >/dev/null 2>&1; then
        git "$@"
    elif [ "$wait" = 0 ]; then
        flock -n "$lock_file" git "$@"
    else
        flock -w "$wait" "$lock_file" git "$@"
    fi
}

# Background check for updates: once per interactive shell. Non-interactive
# shells (agents over SSH sourcing this file for update-dotfiles) skip it, so
# sourcing never starts a fetch behind update-dotfiles' back.
background_dotfiles_check() {
    # Only check once per shell session
    [ -n "${_DOTFILES_CHECKED-}" ] && return 0
    case $- in
        *i*) ;;
        *) return 0 ;;
    esac
    export _DOTFILES_CHECKED=1

    local dotfiles_dir
    dotfiles_dir="$(_dotfiles_dir)"
    [ ! -d "$dotfiles_dir/.git" ] && return 0

    # Run the check in the background so it never delays the prompt.
    (
        cd "$dotfiles_dir" 2>/dev/null || exit 0
        _dotfiles_background_fetch_and_notify
    ) &
    disown
}

# Fetch with a 10 s limit (skipped while update-dotfiles holds the fetch lock)
# and notify when the checkout is behind its upstream.
_dotfiles_background_fetch_and_notify() {
    local local_head remote_head
    local -a lock_cmd=()
    if command -v flock &>/dev/null; then
        lock_cmd=(flock -n "$(_dotfiles_dir)/.git/dotfiles-fetch.flock")
    fi

    if command -v timeout &>/dev/null; then
        timeout 10s "${lock_cmd[@]}" git fetch --quiet 2>/dev/null
    elif command -v gtimeout &>/dev/null; then
        gtimeout 10s "${lock_cmd[@]}" git fetch --quiet 2>/dev/null
    else
        "${lock_cmd[@]}" git fetch --quiet 2>/dev/null
    fi || return 0

    local_head=$(git rev-parse HEAD 2>/dev/null)
    remote_head=$(git rev-parse '@{u}' 2>/dev/null)
    if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
        if ! git merge-base --is-ancestor "$remote_head" "$local_head" 2>/dev/null; then
            # Send action-based notification with terminal update support
            send_update_notification
        fi
    fi
}

_dotfiles_linked_persona() {
    local dotfiles_dir="$(_dotfiles_dir)"
    local profile profile_dir link target
    for profile in agent personal steamos; do
        [ -d "$dotfiles_dir/$profile" ] || continue
        profile_dir=$(realpath -m -- "$dotfiles_dir/$profile" 2>/dev/null) || continue
        while IFS= read -r -d '' link; do
            target=$(readlink -n "$link" 2>/dev/null) || continue
            # Relative symlink targets are relative to the link's parent, not CWD.
            case "$target" in
                /*) ;;
                *) target="${link%/*}/$target" ;;
            esac
            target=$(realpath -m -- "$target" 2>/dev/null) || continue
            case "$target" in
                "$profile_dir"|"$profile_dir"/*)
                    printf '%s\n' "$profile"
                    return 0
                    ;;
            esac
        done < <(find "$HOME/.config" "$HOME/.bashrc.d" "$HOME/.local" "$HOME/.agents" -maxdepth 3 -type l -print0 2>/dev/null)
    done
    return 1
}

# Live state directories that the repo adds a few files to (for example
# ~/.grok/AGENTS.md) while tools write their own state there (skills.sh into
# ~/.agents, Claude Code into ~/.claude). Create them first, so a folding
# `stow -R` links only the files and never turns the whole directory into a
# link into the checkout.
_dotfiles_live_state_dirs=(.agents .claude .grok)

_dotfiles_restow_active() {
    local dotfiles_dir="$(_dotfiles_dir)"
    local persona dir
    for dir in "${_dotfiles_live_state_dirs[@]}"; do
        [ -e "$HOME/$dir" ] || [ -L "$HOME/$dir" ] || mkdir -p "$HOME/$dir" || return 1
    done
    pushd "$dotfiles_dir" >/dev/null || return 1
    echo "Restowing 'common' profile..."
    stow -R -t ~ common || { popd >/dev/null; return 1; }
    if persona="$(_dotfiles_linked_persona)"; then
        echo "Restowing '$persona' profile..."
        stow -R -t ~ "$persona" || { popd >/dev/null; return 1; }
    fi
    popd >/dev/null
}

# Also detect a linked agent profile when a noninteractive shell loads only
# this file, without loading the agent's startup environment first.
_dotfiles_bulk_secrets_allowed() {
    [ "${DOTFILES_SCOPED_AGENT:-0}" != 1 ] &&
        [ "$(_dotfiles_linked_persona)" != agent ]
}

_dotfiles_refresh_secrets_noninteractive() {
    if ! _dotfiles_bulk_secrets_allowed; then
        echo "Skipping bulk secret refresh for scoped agent; render only an authorized selector manually."
        return 0
    fi
    if ! declare -F init-env-secrets >/dev/null; then
        local secrets_file
        secrets_file="$(_dotfiles_dir)/common/.bashrc.d/secrets.bash"
        # Suppress startup jobs only while sourcing; preserve the caller's guard state.
        # shellcheck disable=SC1090
        [ -f "$secrets_file" ] && _SECRET_AUTO_REFRESH_STARTED=1 source "$secrets_file"
    fi
    if declare -F init-env-secrets >/dev/null; then
        echo "Refreshing template-generated secrets..."
        init-env-secrets --all || echo "Warning: secret refresh failed; run init-env-secrets --all"
    fi
}

# update-dotfiles --yes also refreshes skills. A failure is reported but does
# not undo the dotfiles update; a host without Node.js only gets a warning.
_dotfiles_update_agent_skills_noninteractive() {
    local status=0
    echo "Refreshing agent skills..."
    update-agent-skills || status=$?
    case "$status" in
        0) ;;
        "$_AGENT_SKILLS_NO_NODE")
            echo "Warning: agent skills were not refreshed (no Node.js); the installed skills stay in use." >&2 ;;
        *)
            echo "Warning: agent skill refresh failed; run update-agent-skills for details." >&2
            return 1 ;;
    esac
}

# Steps after a fast-forward: restow, secrets, skills. A restow conflict is
# reported but does not skip the other steps.
_dotfiles_post_update_noninteractive() {
    local status=0
    if ! (cd "$(_dotfiles_dir)" && _dotfiles_restow_active); then
        echo "Warning: restow failed; resolve the conflicts above, then run update-dotfiles --yes again." >&2
        status=1
    fi
    (cd "$(_dotfiles_dir)" && _dotfiles_refresh_secrets_noninteractive)
    _dotfiles_update_agent_skills_noninteractive || status=1
    return "$status"
}

# Run the post-update steps from the file on disk, not from the definitions
# this shell loaded before the pull, so an updated updater takes effect at once.
_dotfiles_post_update_from_disk() {
    env -u BASH_ENV DOTFILES_DIR="$(_dotfiles_dir)" \
        DOTFILES_SCOPED_AGENT="${DOTFILES_SCOPED_AGENT:-0}" \
        bash --noprofile --norc -c "$(declare -p AGENT_SKILLS_CLI_VERSION AGENT_SKILLS_SOURCE AGENT_SKILLS_AUTO_UPDATE 2>/dev/null)
"'source "$1" && _dotfiles_post_update_noninteractive' \
        bash "$(_dotfiles_dir)/common/.bashrc.d/dotfiles_management.bash"
}

# Manual update command (includes profile management after update).
# Agents should use: source this file, then `update-dotfiles --yes`.
update-dotfiles() {
    local dotfiles_dir
    dotfiles_dir="$(_dotfiles_dir)"
    local original_dir="$(pwd)"
    local noninteractive=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y|--non-interactive)
                noninteractive=1
                ;;
            -h|--help)
                echo "Usage: update-dotfiles [--yes]"
                echo "  --yes  Fast-forward and restow the active profile, then run update-agent-skills; no prompts."
                echo "         Refresh secrets except for scoped agents; use an authorized selector manually."
                return 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Usage: update-dotfiles [--yes]" >&2
                return 1
                ;;
        esac
        shift
    done

    [ ! -d "$dotfiles_dir/.git" ] && echo "Error: Dotfiles not found at $dotfiles_dir" && return 1
    _dotfiles_git_check_owner "$dotfiles_dir" || return 1

    cd "$dotfiles_dir" || return 1

    # Check for updates
    echo "Checking for updates..."
    _dotfiles_git_locked 60 fetch --quiet || { echo "Failed to check for updates"; cd "$original_dir"; return 1; }

    local local_head=$(git rev-parse HEAD)
    local remote_head=$(git rev-parse @{u} 2>/dev/null)

    if [ "$local_head" = "$remote_head" ]; then
        echo "Already up to date!"
        if [ "$noninteractive" -eq 1 ]; then
            cd "$original_dir" || return 1
            _dotfiles_post_update_from_disk
            return $?
        fi
        cd "$original_dir"
        return 0
    fi

    if [ "$noninteractive" -eq 1 ]; then
        echo "Pulling updates (fast-forward only)..."
        if ! _dotfiles_git_locked 60 pull --ff-only; then
            echo "Fast-forward failed. Report the divergence; do not reset or force-push." >&2
            cd "$original_dir"
            return 1
        fi
        cd "$original_dir" || return 1
        _dotfiles_post_update_from_disk || return 1
        echo "Update complete. Re-read ~/.agents/AGENTS.md and any skills this task needs."
        return 0
    fi

    # Pull updates
    echo "Pulling updates..."
    _dotfiles_git_locked 60 pull || { echo "Failed to pull updates"; cd "$original_dir"; return 1; }

    # Ask for profile
    local profiles=()
    local i=1

    echo "Which profile would you like?"
    echo "  1) none (common only)"
    while IFS= read -r profile; do
      ((i++))
      profiles+=("$profile")
      echo "  $i) $profile"
    done < <(_list_dotfiles_profiles)
    echo ""
    echo -n "Enter choice [1-$i]: "
    read -r choice

    local target_profile="none"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 2 && choice <= i )); then
      target_profile="${profiles[$((choice - 2))]}"
    fi

    _switch_dotfiles_profile "$target_profile"

    # Skills refresh in the background shell-startup job; --yes runs them directly.

    _dotfiles_refresh_secrets_noninteractive

    # Ask to reload bashrc
    echo -n "Reload shell configuration? (y/n): "
    read -r reload

    if [[ "$reload" =~ ^[yY]$ ]]; then
        source ~/.bashrc
        echo "Configuration reloaded"
    fi

    # Send completion notification since we actually updated
    # Prefer notifications when available, fall back to terminal output.
    if command -v notify-send &>/dev/null; then
        if ! notify-send -u normal -i dialog-information "Update Complete" "Restart your terminals to apply changes" 2>/dev/null; then
            echo "Update complete. Restart your terminals to apply changes."
        fi
    else
        echo "Update complete. Restart your terminals to apply changes."
    fi

    cd "$original_dir"
}

# --- Dotfiles Profile Management Functions ---

# Internal function to switch stow profiles
_skip_dotfiles_profile() {
  local dir="$1"
  [[ "$dir" == .* || "$dir" == "common" || "$dir" == "bootstrap" || "$dir" == "root" || "$dir" == *-root ]]
}

_switch_dotfiles_profile() {
  local target_profile="$1"
  local dotfiles_dir
  local dir
  local -a stow_args=(--no-folding -t "$HOME")
  local -a inactive_profiles=()
  dotfiles_dir="$(_dotfiles_dir)"

  if [ ! -d "$dotfiles_dir" ]; then
    echo "Error: Dotfiles directory '$dotfiles_dir' not found." >&2
    return 1
  fi

  echo "Switching profile in $dotfiles_dir..."
  pushd "$dotfiles_dir" >/dev/null || return 1

  if [[ -n "$target_profile" && "$target_profile" != "none" && "$target_profile" != "common" ]] && _skip_dotfiles_profile "$target_profile"; then
    echo "Error: '$target_profile' is not a home profile. Root-target packages must be applied explicitly with sudo stow -t /." >&2
    popd >/dev/null
    return 1
  fi

  if [[ -n "$target_profile" && "$target_profile" != "none" && "$target_profile" != "common" && ! -d "$target_profile" ]]; then
    echo "Error: Profile directory '$target_profile' not found." >&2
    popd >/dev/null
    return 1
  fi

  # Plan the whole switch together so a conflict cannot remove active links.
  # Disable folding to keep shared directories stable while switching profiles.
  for dir in */; do
    dir="${dir%/}"
    _skip_dotfiles_profile "$dir" && continue
    [[ "$dir" == "$target_profile" ]] && continue
    inactive_profiles+=("$dir")
  done
  if (( ${#inactive_profiles[@]} )); then
    stow_args+=(-D "${inactive_profiles[@]}")
  fi

  # Restow (-R) rather than stow (-S): it also removes links left dangling by
  # files deleted from the repo, such as a retired template.
  if [ -d "common" ]; then
    stow_args+=(-R common)
  fi
  if [[ -n "$target_profile" && "$target_profile" != "none" && "$target_profile" != "common" ]]; then
    stow_args+=(-R "$target_profile")
  fi

  echo "Checking profile switch for conflicts..."
  if ! stow -n "${stow_args[@]}"; then
    echo "Profile switch aborted; existing links are unchanged." >&2
    popd >/dev/null
    return 1
  fi
  if ! stow "${stow_args[@]}"; then
    echo "Error applying profile switch." >&2
    popd >/dev/null
    return 1
  fi

  if [[ -z "$target_profile" || "$target_profile" == "none" || "$target_profile" == "common" ]]; then
    echo "Only 'common' profile is now active."
  else
    echo "Profile '$target_profile' stowed successfully."
  fi

  popd >/dev/null

  # Reload Hyprland configuration if applicable
  if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
    echo "Reloading Hyprland configuration..."
    if ! hyprctl reload; then
      echo "Profile applied, but Hyprland could not reload." >&2
      return 1
    fi
    local config_errors
    if ! config_errors=$(hyprctl configerrors 2>&1) || [[ -n "$config_errors" ]]; then
      printf 'Profile applied, but Hyprland reported errors:\n%s\n' "$config_errors" >&2
      return 1
    fi
  fi

  # Reload systemd user units if applicable
  if command -v systemctl &>/dev/null; then
    echo "Reloading systemd user units..."
    systemctl --user daemon-reload >/dev/null 2>&1
  fi

  # Offer to refresh generated secrets for the new active profile.
  if [[ "$target_profile" != agent ]] && _dotfiles_bulk_secrets_allowed &&
    declare -F init-env-secrets >/dev/null && [ -t 0 ] && [ -t 1 ]; then
    echo -n "Refresh all generated secrets now? (y/N): "
    read -r refresh_secrets

    if [[ "$refresh_secrets" =~ ^[yY]$ ]]; then
      init-env-secrets --all
    fi
  fi

  echo "Profile switch complete."
}

# List available profiles
_list_dotfiles_profiles() {
  local dotfiles_dir
  dotfiles_dir="$(_dotfiles_dir)"
  local profiles=()

  for dir in "$dotfiles_dir"/*/; do
    dir="${dir%/}"
    dir="${dir##*/}"
    _skip_dotfiles_profile "$dir" && continue
    profiles+=("$dir")
  done

  printf '%s\n' "${profiles[@]}"
}

# Function to manually switch profiles
# Usage: stow-profile [profile_name]
stow-profile() {
  local target_profile="$1"

  # If no argument provided, show numbered menu
  if [[ -z "$target_profile" ]]; then
    local profiles=()
    local i=1

    echo "Available profiles:"
    echo "  1) none (common only)"
    while IFS= read -r profile; do
      ((i++))
      profiles+=("$profile")
      echo "  $i) $profile"
    done < <(_list_dotfiles_profiles)
    echo ""
    echo -n "Enter choice [1-$i]: "
    read -r choice

    if [[ -z "$choice" ]]; then
      echo "No selection made. Aborting."
      return 1
    fi

    if [[ "$choice" == "1" ]]; then
      target_profile="none"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 2 && choice <= i )); then
      target_profile="${profiles[$((choice - 2))]}"
    else
      echo "Invalid choice. Aborting."
      return 1
    fi
  fi

  _switch_dotfiles_profile "$target_profile"
}

# Run check on shell startup
background_dotfiles_check

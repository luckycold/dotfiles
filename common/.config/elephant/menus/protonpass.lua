--
-- Proton Pass Menu for Elephant/Walker
--
Name = "protonpass"
NamePretty = "Proton Pass"
Icon = "proton-pass"

-- Configuration
local CONFIG = {
    cache_file = "/home/lucky/.cache/walker/protonpass_cache.json",
    bin_pass = "/home/lucky/.local/bin/pass-cli",
    log_file = "/tmp/walker_protonpass_error.log",
    icon_refresh = "view-refresh",
    icon_item = "password-manager"
}

--
-- Helper: Construct a shell command that runs quietly, logs errors, copies output, and notifies
--
local function make_copy_action(subcommand, notification_text, pipe_filter)
    local cmd = string.format("%s %s 2>>%s", CONFIG.bin_pass, subcommand, CONFIG.log_file)
    if pipe_filter then
        cmd = cmd .. " | " .. pipe_filter
    end
    -- Use tr -d '\n' to strip newlines from the final output before copying
    cmd = cmd .. " | tr -d '\\n' | wl-copy"
    cmd = cmd .. string.format(" && notify-send \"%s\" \"%s\"", NamePretty, notification_text)
    return cmd
end

--
-- Helper: Generate the Refresh Cache Bash Command
--
local function get_refresh_command()
    -- We use a table to build the multi-line bash command for readability
    local parts = {
        string.format("mkdir -p \"$(dirname \"%s\")\"", CONFIG.cache_file),
        -- Get Vaults
        string.format("%s vault list --output json 2>>%s", CONFIG.bin_pass, CONFIG.log_file),
        "jq -r \".vaults[].name\"",
        -- Parallel fetch items from vaults
        string.format("xargs -P 8 -I {} %s item list \"{}\" --output json 2>>%s", CONFIG.bin_pass, CONFIG.log_file),
        -- Parse and format into cache file: Title|ID|ShareID|Type|Extra
        "jq -r \".items[] | \\\"\\(.content.title)|\\(.id)|\\(.share_id)|\\(.content.content | keys[0])|\\\"+((.content.content.Login.username | select(length>0)) // .content.content.Login.email // .content.content.CreditCard.number // \\\"\\\")\" > " .. CONFIG.cache_file,
        string.format("notify-send \"%s\" \"Cache updated\"", NamePretty)
    }
    return "bash -c '" .. table.concat(parts, " | ") .. "'"
end

--
-- Helper: Define Actions based on Item Type
--
local function get_item_actions(itype, share_id, id)
    local actions = {}
    local base_args = string.format("item view --share-id '%s' --item-id '%s'", share_id, id)

    if itype == "Login" then
        actions["activate"] = make_copy_action(base_args .. " --field password --output human", "Password copied")
        
        -- Username fallback logic (Username -> Email -> Empty) handled by jq
        local user_filter = "jq -r '(.item.content.content.Login.username | select(length>0)) // .item.content.content.Login.email // empty'"
        actions["Copy Username"] = make_copy_action(base_args .. " --output json", "Username copied", user_filter)
        
        -- TOTP filter
        local totp_args = string.format("item totp --share-id '%s' --item-id '%s' --output human", share_id, id)
        actions["Copy TOTP"] = make_copy_action(totp_args, "TOTP copied", "awk '/^totp:/ { print $2 }'")

    elseif itype == "SshKey" then
        actions["activate"] = make_copy_action(base_args .. " --field private_key --output human", "Private key copied")
        actions["Copy Public Key"] = make_copy_action(base_args .. " --field public_key --output human", "Public key copied")

    elseif itype == "CreditCard" then
        actions["activate"] = make_copy_action(base_args .. " --field number --output human", "Card number copied")
        actions["Copy CVV"] = make_copy_action(base_args .. " --field verification_number --output human", "CVV copied")

    else
        -- Fallback for Notes or other types
        actions["activate"] = make_copy_action(base_args .. " --output human", "Secret copied")
    end

    return actions
end

--
-- Helper: Format Item Subtext (e.g. Masked Credit Cards)
--
local function get_item_subtext(itype, extra)
    if not extra or extra == "" then return itype end
    
    if itype == "CreditCard" and #extra > 4 then
        return itype .. " (**** " .. extra:sub(-4) .. ")"
    end
    return itype .. " (" .. extra .. ")"
end

--
-- Main Entry Point
--
function GetEntries()
    local entries = {}
    local refresh_entry = {
        Text = "Refresh Proton Pass Cache",
        Subtext = "Updates the local item list",
        Icon = CONFIG.icon_refresh,
        Keywords = { "pass", "proton", "refresh", "update" },
        Actions = { activate = get_refresh_command() }
    }

    local f = io.open(CONFIG.cache_file, "r")
    if not f then
        -- Cache missing, offer to create it
        refresh_entry.Text = "Proton Pass: No Cache Found"
        refresh_entry.Subtext = "Select to fetch items (~15s)"
        table.insert(entries, refresh_entry)
        return entries
    end

    for line in f:lines() do
        -- Optimized parsing: direct pattern match is significantly faster than gmatch
        local title, id, share_id, itype, extra = line:match("^(.-)|(.-)|(.-)|(.-)|(.*)$")

        if title and id then
            local keywords = { itype }
            if extra and extra ~= "" then table.insert(keywords, extra) end

            table.insert(entries, {
                Text = title,
                Subtext = get_item_subtext(itype, extra),
                Icon = CONFIG.icon_item,
                Keywords = keywords,
                Actions = get_item_actions(itype, share_id, id)
            })
        end
    end
    f:close()

    -- Always append Refresh action at the bottom
    table.insert(entries, refresh_entry)

    return entries
end

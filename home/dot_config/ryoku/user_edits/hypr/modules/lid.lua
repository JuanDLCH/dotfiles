-- dotfiles: user_edits fork of Ryoku's hypr/modules/lid.lua (managed by chezmoi).
-- Same as upstream, except every lid event goes through ~/.local/libexec/ryoku-lid,
-- which keeps the laptop running on AC without an external display (lock + screen
-- off) and hands every other case to ryoku-clamshell unchanged.
-- `ryoku doctor` warns when upstream changes the original; `ryoku reset
-- hypr/modules/lid.lua` hands it back (and `chezmoi apply` puts this one back).
local lid = (os.getenv("HOME") or "") .. "/.local/libexec/ryoku-lid"

local function sync_physical_lid()
    hl.exec_cmd(lid .. " sync")
end

hl.on("hyprland.start", sync_physical_lid)
hl.on("config.reloaded", sync_physical_lid)
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(lid .. " close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(lid .. " open"),  { locked = true })

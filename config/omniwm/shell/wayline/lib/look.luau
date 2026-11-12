-- The Crew look: Wayline's chips and panels, unchanged (see lib/wayline-base.luau).
local look = table.clone(require("./wayline-base"))
look.personality = "crew"
return require("./skin")(look)

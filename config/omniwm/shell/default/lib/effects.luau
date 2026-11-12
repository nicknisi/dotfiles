local motion = {
    fade = { animate = { duration = 0.22, curve = "easeOut" },
        appear = { opacity = 0 }, exit = { opacity = 0 } },
    slide = { animate = { response = 0.38, bounce = 0.08 },
        appear = { opacity = 0, dy = 24 }, exit = { opacity = 0, dy = -16 } },
    pop = { animate = { response = 0.32, bounce = 0.18 },
        appear = { opacity = 0, scale = 0.5 }, exit = { opacity = 0, scale = 0.8 } },
    spring = { animate = { response = 0.42, bounce = 0.28 },
        appear = { opacity = 0, scale = 0.84 }, exit = { opacity = 0, scale = 0.84 } },
    stretch = { animate = "spatial", enter = { dy = -48, stretch = 0.12, curve = "spatial" },
        appear = { opacity = 0, dy = -24 }, exit = { opacity = 0, dy = 16 } },
    indicator = { animate = { response = 0.36, bounce = 0.08 }, trail = true },
}

local shaders = {
    aurora = { source = "effects-aurora.metal", values = { 0.7, 1, 0, 0 }, fps = 30 },
    sheen = { source = "effects-sheen.metal", values = { 0.3, 1, 0, 0 }, fps = 0 },
    glow = { source = "effects-glow.metal", values = { 16, 18, 0.65, 2 }, fps = 0 },
    ring = { source = "effects-ring.metal", values = { 16, 2, 45, 1 }, fps = 0 },
    ["rotating-border"] = { source = "effects-rotating-border.metal", values = { 16, 3, 90, 1 }, fps = 30 },
    burn = { source = "effects-burn.metal", values = { 26, 0.015, 1, -1 }, fps = 0 },
    smoke = { source = "effects-smoke.metal", values = { 60, 0.14, 1, -1 }, fps = 0 },
    pixelate = { source = "effects-pixelate.metal", values = { 48, 0, 0, -1 }, fps = 0 },
    genie = { source = "effects-genie.metal", values = { 0.5, 0, 0, -1 }, fps = 0 },
}

local masks = {
    burn = { source = "effects-burn.metal", values = { 26, 0.015, 0, -1 }, fps = 0, mask = true },
    smoke = { source = "effects-smoke.metal", values = { 60, 0.14, 0, -1 }, fps = 0, mask = true },
    circle = { source = "effects-circle.metal", values = { 0.5, 0.5, 1, -1 }, fps = 0, mask = true },
    wipe = { source = "effects-wipe.metal", values = { 1, 0, 1, -1 }, fps = 0, mask = true },
    dissolve = { source = "effects-dissolve.metal", values = { 8, 1, 0, -1 }, fps = 0, mask = true },
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in value do result[key] = copy(item) end
    return result
end

local function preset(collection, name, props)
    local base = collection[name]
    assert(base, "unknown effect preset: " .. tostring(name))
    local result = copy(base)
    for key, value in props or {} do result[key] = value end
    return result
end

return table.freeze({
    motion = function(name, props) return preset(motion, name, props) end,
    shader = function(name, props) return ui.shader(preset(shaders, name, props)) end,
    mask = function(name, props) return ui.shader(preset(masks, name, props)) end,
})

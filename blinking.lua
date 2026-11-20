-- blinking.lua: Sub-second power-grid flicker controller for opt-in blinking
-- street lanterns and blinking facade windows.
--
-- Non-blinking lanterns (neoclassical_city:lantern_steady, lantern_off) and
-- non-blinking windows (neoclassical_city:window_lit, window_dark) are NOT in
-- the blinking groups and are never modified by this controller.

local GRID_SCAN_RADIUS = 50
local GRID_SCAN_Y_RADIUS = 32
local GRID_SCAN_INTERVAL = 1.6

local BLINK_LANTERN_SET = {
    ["neoclassical_city:lantern_blinking"] = true,
    ["neoclassical_city:lantern_blinking_dim"] = true,
    ["neoclassical_city:lantern_blinking_off"] = true,
}

local BLINK_WINDOW_SET = {
    ["neoclassical_city:window_blinking"] = true,
    ["neoclassical_city:window_blinking_dim"] = true,
    ["neoclassical_city:window_blinking_dark"] = true,
}

local cached_lanterns = {}
local cached_window_units = {} -- Each entry: { positions = { pos1, ... }, x = x, z = z, state = node_name }
local scan_accum = GRID_SCAN_INTERVAL
local last_scan_centers = {}

-- Flicker phase state machine:
--   "unstable" -> erratic sub-second flickering
--   "sputter"  -> rapid alternating voltage strobe
--   "brownout" -> rolling blackout wave
--   "recovery" -> stuttering power surge back on
local grid_phase = "unstable"
local phase_timer = 2.8
local phase_duration = 2.8
local tick_accum = 0
local next_tick = 0.14
local surge_polarity = false
local wave_dx = 1
local wave_dz = 0
local wave_min_proj = 0
local wave_max_proj = 1

local function rescan_grid_nodes(players)
    cached_lanterns = {}
    cached_window_units = {}

    local seen_lanterns = {}
    local unit_by_key = {}

    for _, player in ipairs(players) do
        local p = vector.round(player:get_pos())
        local minp = {
            x = p.x - GRID_SCAN_RADIUS,
            y = p.y - GRID_SCAN_Y_RADIUS,
            z = p.z - GRID_SCAN_RADIUS,
        }
        local maxp = {
            x = p.x + GRID_SCAN_RADIUS,
            y = p.y + GRID_SCAN_Y_RADIUS,
            z = p.z + GRID_SCAN_RADIUS,
        }

        local lanterns = minetest.find_nodes_in_area(minp, maxp, { "group:neoclassical_blinking_lantern" })
        for i = 1, #lanterns do
            local lp = lanterns[i]
            local key = lp.x .. "," .. lp.y .. "," .. lp.z
            if not seen_lanterns[key] then
                seen_lanterns[key] = true
                cached_lanterns[#cached_lanterns + 1] = {
                    pos = lp,
                    state = minetest.get_node(lp).name,
                }
            end
        end

        local windows = minetest.find_nodes_in_area(minp, maxp, { "group:neoclassical_blinking_window" })
        for i = 1, #windows do
            local wp = windows[i]
            -- Group 2-block-tall architectural windows on the same floor band
            local floor_band = math.floor(wp.y / 4)
            local ukey = wp.x .. "," .. floor_band .. "," .. wp.z
            local unit = unit_by_key[ukey]
            if not unit then
                unit = {
                    positions = { wp },
                    x = wp.x,
                    z = wp.z,
                    state = minetest.get_node(wp).name,
                }
                unit_by_key[ukey] = unit
                cached_window_units[#cached_window_units + 1] = unit
            else
                local dup = false
                for j = 1, #unit.positions do
                    if unit.positions[j].y == wp.y then
                        dup = true
                        break
                    end
                end
                if not dup then
                    unit.positions[#unit.positions + 1] = wp
                end
            end
        end
    end
end

local function set_lantern_state(entry, target)
    if entry.state ~= target then
        local cur = minetest.get_node(entry.pos).name
        if not BLINK_LANTERN_SET[cur] then
            return
        end
        entry.state = target
        minetest.swap_node(entry.pos, { name = target })
    end
end

local function set_window_unit_state(unit, target)
    if unit.state ~= target then
        unit.state = target
        local positions = unit.positions
        for i = 1, #positions do
            local cur = minetest.get_node(positions[i]).name
            if BLINK_WINDOW_SET[cur] then
                minetest.swap_node(positions[i], { name = target })
            end
        end
    end
end

local function pick_different_lantern(current)
    local roll = math.random(1, 100)
    local target
    if roll <= 45 then
        target = "neoclassical_city:lantern_blinking_off"
    elseif roll <= 77 then
        target = "neoclassical_city:lantern_blinking_dim"
    else
        target = "neoclassical_city:lantern_blinking"
    end
    if target == current then
        if current == "neoclassical_city:lantern_blinking" then
            target = (math.random(1, 100) <= 65)
                and "neoclassical_city:lantern_blinking_off"
                or "neoclassical_city:lantern_blinking_dim"
        elseif current == "neoclassical_city:lantern_blinking_off" then
            target = (math.random(1, 100) <= 65)
                and "neoclassical_city:lantern_blinking"
                or "neoclassical_city:lantern_blinking_dim"
        else
            target = (math.random(1, 100) <= 55)
                and "neoclassical_city:lantern_blinking_off"
                or "neoclassical_city:lantern_blinking"
        end
    end
    return target
end

local function pick_different_window(current)
    local roll = math.random(1, 100)
    local target
    if roll <= 48 then
        target = "neoclassical_city:window_blinking_dark"
    elseif roll <= 72 then
        target = "neoclassical_city:window_blinking_dim"
    else
        target = "neoclassical_city:window_blinking"
    end
    if target == current then
        if current == "neoclassical_city:window_blinking" then
            target = (math.random(1, 100) <= 70)
                and "neoclassical_city:window_blinking_dark"
                or "neoclassical_city:window_blinking_dim"
        elseif current == "neoclassical_city:window_blinking_dark" then
            target = (math.random(1, 100) <= 68)
                and "neoclassical_city:window_blinking"
                or "neoclassical_city:window_blinking_dim"
        else
            target = (math.random(1, 100) <= 55)
                and "neoclassical_city:window_blinking_dark"
                or "neoclassical_city:window_blinking"
        end
    end
    return target
end

local function compute_wave_bounds()
    local angle = math.random() * math.pi * 2
    wave_dx = math.cos(angle)
    wave_dz = math.sin(angle)
    local minp, maxp = math.huge, -math.huge
    for i = 1, #cached_lanterns do
        local lp = cached_lanterns[i].pos
        local proj = lp.x * wave_dx + lp.z * wave_dz
        if proj < minp then minp = proj end
        if proj > maxp then maxp = proj end
    end
    for i = 1, #cached_window_units do
        local u = cached_window_units[i]
        local proj = u.x * wave_dx + u.z * wave_dz
        if proj < minp then minp = proj end
        if proj > maxp then maxp = proj end
    end
    if minp >= maxp then
        wave_min_proj = -50
        wave_max_proj = 50
    else
        wave_min_proj = minp
        wave_max_proj = maxp
    end
end

local function advance_grid_phase()
    if grid_phase == "unstable" then
        if math.random(1, 100) <= 55 then
            grid_phase = "sputter"
            phase_duration = 1.0 + math.random() * 0.8
        else
            grid_phase = "brownout"
            phase_duration = 1.5 + math.random() * 1.1
            compute_wave_bounds()
        end
    elseif grid_phase == "sputter" then
        if math.random(1, 100) <= 68 then
            grid_phase = "brownout"
            phase_duration = 1.5 + math.random() * 1.2
            compute_wave_bounds()
        else
            grid_phase = "unstable"
            phase_duration = 2.0 + math.random() * 1.8
        end
    elseif grid_phase == "brownout" then
        grid_phase = "recovery"
        phase_duration = 0.8 + math.random() * 0.5
        compute_wave_bounds()
    else
        grid_phase = "unstable"
        phase_duration = 2.2 + math.random() * 1.8
    end
    phase_duration = math.max(0.7, phase_duration)
    phase_timer = phase_duration
    surge_polarity = false
end

local function run_grid_tick()
    local n_lanterns = #cached_lanterns
    local n_windows = #cached_window_units
    if n_lanterns == 0 and n_windows == 0 then
        return
    end

    if grid_phase == "unstable" then
        for i = 1, n_lanterns do
            if math.random(1, 100) <= 38 then
                local entry = cached_lanterns[i]
                set_lantern_state(entry, pick_different_lantern(entry.state))
            end
        end

        for i = 1, n_windows do
            if math.random(1, 100) <= 28 then
                local unit = cached_window_units[i]
                set_window_unit_state(unit, pick_different_window(unit.state))
            end
        end

        next_tick = 0.13 + math.random() * 0.10

    elseif grid_phase == "sputter" then
        surge_polarity = not surge_polarity

        for i = 1, n_lanterns do
            if math.random(1, 100) <= 78 then
                local entry = cached_lanterns[i]
                if surge_polarity then
                    local target = (math.random(1, 100) <= 78)
                        and "neoclassical_city:lantern_blinking"
                        or "neoclassical_city:lantern_blinking_dim"
                    set_lantern_state(entry, target)
                else
                    local target = (math.random(1, 100) <= 78)
                        and "neoclassical_city:lantern_blinking_off"
                        or "neoclassical_city:lantern_blinking_dim"
                    set_lantern_state(entry, target)
                end
            end
        end

        for i = 1, n_windows do
            if math.random(1, 100) <= 62 then
                local unit = cached_window_units[i]
                if surge_polarity then
                    local target = (math.random(1, 100) <= 74)
                        and "neoclassical_city:window_blinking"
                        or "neoclassical_city:window_blinking_dim"
                    set_window_unit_state(unit, target)
                else
                    local target = (math.random(1, 100) <= 82)
                        and "neoclassical_city:window_blinking_dark"
                        or "neoclassical_city:window_blinking_dim"
                    set_window_unit_state(unit, target)
                end
            end
        end

        next_tick = 0.09 + math.random() * 0.05

    elseif grid_phase == "brownout" then
        local frac = 1.0 - (phase_timer / math.max(0.1, phase_duration))
        local wave_front = wave_min_proj + (wave_max_proj - wave_min_proj) * math.min(1.0, frac * 1.9)

        for i = 1, n_lanterns do
            local entry = cached_lanterns[i]
            local proj = entry.pos.x * wave_dx + entry.pos.z * wave_dz
            if proj <= wave_front then
                local roll = math.random(1, 100)
                if roll <= 90 then
                    set_lantern_state(entry, "neoclassical_city:lantern_blinking_off")
                elseif roll <= 97 then
                    set_lantern_state(entry, "neoclassical_city:lantern_blinking_dim")
                else
                    set_lantern_state(entry, "neoclassical_city:lantern_blinking")
                end
            elseif proj <= wave_front + 14 then
                set_lantern_state(entry, "neoclassical_city:lantern_blinking_dim")
            end
        end

        for i = 1, n_windows do
            local unit = cached_window_units[i]
            local proj = unit.x * wave_dx + unit.z * wave_dz
            if proj <= wave_front then
                local roll = math.random(1, 100)
                if roll <= 88 then
                    set_window_unit_state(unit, "neoclassical_city:window_blinking_dark")
                elseif roll <= 96 then
                    set_window_unit_state(unit, "neoclassical_city:window_blinking_dim")
                else
                    set_window_unit_state(unit, "neoclassical_city:window_blinking")
                end
            elseif proj <= wave_front + 12 then
                set_window_unit_state(unit, "neoclassical_city:window_blinking_dim")
            end
        end

        next_tick = 0.11

    elseif grid_phase == "recovery" then
        local frac = 1.0 - (phase_timer / math.max(0.1, phase_duration))
        local wave_front = wave_min_proj + (wave_max_proj - wave_min_proj) * math.min(1.0, frac * 1.6)
        local false_dip = (frac > 0.35 and frac < 0.55)

        for i = 1, n_lanterns do
            local entry = cached_lanterns[i]
            local proj = entry.pos.x * wave_dx + entry.pos.z * wave_dz
            if false_dip and math.random(1, 100) <= 65 then
                set_lantern_state(entry, "neoclassical_city:lantern_blinking_dim")
            elseif proj <= wave_front then
                local target = (math.random(1, 100) <= 80)
                    and "neoclassical_city:lantern_blinking"
                    or "neoclassical_city:lantern_blinking_dim"
                set_lantern_state(entry, target)
            end
        end

        for i = 1, n_windows do
            local unit = cached_window_units[i]
            local proj = unit.x * wave_dx + unit.z * wave_dz
            if false_dip and math.random(1, 100) <= 55 then
                set_window_unit_state(unit, "neoclassical_city:window_blinking_dark")
            elseif proj <= wave_front then
                local roll = math.random(1, 100)
                if roll <= 52 then
                    set_window_unit_state(unit, "neoclassical_city:window_blinking")
                elseif roll <= 74 then
                    set_window_unit_state(unit, "neoclassical_city:window_blinking_dim")
                else
                    set_window_unit_state(unit, "neoclassical_city:window_blinking_dark")
                end
            end
        end

        next_tick = 0.10
    end
end

minetest.register_globalstep(function(dtime)
    local players = minetest.get_connected_players()
    if #players == 0 then
        return
    end

    scan_accum = scan_accum + dtime
    local moved_far = false
    for i = 1, #players do
        local p = players[i]
        local pname = p:get_player_name()
        local pos = p:get_pos()
        local prev = last_scan_centers[pname]
        if not prev or vector.distance(pos, prev) >= 10 then
            moved_far = true
        end
    end

    if scan_accum >= GRID_SCAN_INTERVAL or moved_far then
        scan_accum = 0
        last_scan_centers = {}
        for i = 1, #players do
            local p = players[i]
            last_scan_centers[p:get_player_name()] = p:get_pos()
        end
        rescan_grid_nodes(players)
    end

    if #cached_lanterns == 0 and #cached_window_units == 0 then
        return
    end

    phase_timer = phase_timer - dtime
    if phase_timer <= 0 then
        advance_grid_phase()
    end

    tick_accum = tick_accum + dtime
    if tick_accum >= next_tick then
        tick_accum = 0
        run_grid_tick()
    end
end)

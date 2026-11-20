-- citygen.lua: On-demand VoxelManip neoclassical city generator adapted from
-- Amenaza's procedural urban mapgen, invoked manually anywhere via chat command.

local abs = math.abs
local floor = math.floor

local DEFAULT_RADIUS = 120
local MIN_RADIUS = 16
local MAX_RADIUS = 500
local TILE_SIZE = 64
local MIN_CY = -4
local MAX_CY = 40

-- Deterministic fast 2D integer hash -> 0..9999
local function hash2d(x, z)
    local h = (x * 374761393 + z * 668265263) % 2147483647
    h = ((h * 1274126177) % 2147483647)
    return abs(h) % 10000
end

-- Positive modulo helper
local function pmod(a, m)
    local r = a % m
    if r < 0 then r = r + m end
    return r
end

-- Content IDs cached on first build
local C = nil
local function init_content_ids()
    if C then return end
    local gid = minetest.get_content_id
    C = {
        air = gid("air"),
        bedrock = gid("neoclassical_city:bedrock"),
        grass = gid("neoclassical_city:park_grass"),
        gravel = gid("neoclassical_city:park_gravel"),
        water = gid("neoclassical_city:water"),
        trunk = gid("neoclassical_city:tree_trunk"),
        leaves = gid("neoclassical_city:tree_leaves"),
        asphalt = gid("neoclassical_city:asphalt"),
        asphalt_x = gid("neoclassical_city:asphalt_line_x"),
        asphalt_z = gid("neoclassical_city:asphalt_line_z"),
        cobble = gid("neoclassical_city:cobblestone"),
        cobble_trim = gid("neoclassical_city:cobblestone_trim"),
        sidewalk = gid("neoclassical_city:sidewalk"),
        curb = gid("neoclassical_city:sidewalk_curb"),
        cable_x = gid("neoclassical_city:power_cable_x"),
        cable_z = gid("neoclassical_city:power_cable_z"),
        cable_j = gid("neoclassical_city:power_cable_junction"),
        wall_cream = gid("neoclassical_city:sandstone_cream"),
        wall_ochre = gid("neoclassical_city:sandstone_ochre"),
        wall_terra = gid("neoclassical_city:sandstone_terracotta"),
        wall_slate = gid("neoclassical_city:sandstone_slate"),
        rusticated = gid("neoclassical_city:rusticated_base"),
        cornice = gid("neoclassical_city:cornice"),
        pillar = gid("neoclassical_city:pillar"),
        win_lit = gid("neoclassical_city:window_lit"),
        win_dark = gid("neoclassical_city:window_dark"),
        roof_slate = gid("neoclassical_city:roof_slate"),
        roof_copper = gid("neoclassical_city:roof_copper"),
        lobby = gid("neoclassical_city:lobby_floor"),
        post = gid("neoclassical_city:lantern_post"),
        lantern_steady = gid("neoclassical_city:lantern_steady"),
        lantern_blinking = gid("neoclassical_city:lantern_blinking"),
        dc_wall = gid("neoclassical_city:datacenter_wall"),
        dc_vent = gid("neoclassical_city:datacenter_vent"),
        dc_floor = gid("neoclassical_city:datacenter_floor"),
        dc_beacon = gid("neoclassical_city:datacenter_beacon"),
        rack_on = gid("neoclassical_city:server_rack_active"),
        core_on = gid("neoclassical_city:mainframe_core"),
    }
    C.palettes = { C.wall_cream, C.wall_ochre, C.wall_terra, C.wall_slate }
end

-- Heavy power conduit route along open plaza, boulevards, and streets
local function get_cable_node(x, z)
    if (x == -28 and z == 0)
        or (x == -80 and z == 0)
        or (x == -80 and z == 240)
        or (x == -320 and z == 240)
        or (x == -320 and z == 369)
    then
        return C.cable_j
    end
    if z == 0 and x >= -80 and x <= -28 then
        return (x % 16 == 0) and C.cable_j or C.cable_x
    end
    if x == -80 and z >= 0 and z <= 240 then
        return (z % 16 == 0) and C.cable_j or C.cable_z
    end
    if z == 240 and x >= -320 and x <= -80 then
        return (x % 16 == 0) and C.cable_j or C.cable_x
    end
    if x == -320 and z >= 240 and z <= 418 then
        return (z % 16 == 0 and z < 370) and C.cable_j or C.cable_z
    end
    return nil
end

-- Boulevard/park tree sampler
local function sample_tree(x, z, y, tx, tz)
    local dx = x - tx
    local dz = z - tz
    if dx == 0 and dz == 0 and y >= 2 and y <= 6 then
        return C.trunk
    end
    if y >= 5 and y <= 8 then
        local r2 = dx * dx + dz * dz
        if (y == 5 or y == 6) and r2 <= 5 then
            return C.leaves
        elseif y == 7 and r2 <= 2 then
            return C.leaves
        elseif y == 8 and r2 <= 1 then
            return C.leaves
        end
    end
    return nil
end

-- Street lantern standing on sidewalk Y=1 (post Y=2..5, lamp Y=6)
local function sample_lantern(y, lantern_cid)
    if y >= 2 and y <= 5 then
        return C.post
    elseif y == 6 then
        return lantern_cid
    end
    return nil
end

-- ============================================================================
-- Landmark 1: Data Center Facility (X: -350..-290, Z: 370..430)
-- ============================================================================
local function generate_datacenter_column(data, area, wx, oy, wz, x, z, min_cy, max_cy)
    local lx = x - (-320) -- -30..30
    local lz = z - 370    -- 0..60

    local is_outer_wall = (abs(lx) == 30 or lz == 0 or lz == 60)
    local is_entrance = (lz == 0 and abs(lx) <= 2)
    local is_partition_1 = (lz == 14 and abs(lx) > 2)
    local is_partition_2 = (lz == 42 and abs(lx) > 2)

    local is_server_rack = false
    if lz >= 18 and lz <= 38 and (lz % 4 ~= 0) then
        if abs(lx) == 6 or abs(lx) == 12 or abs(lx) == 18 or abs(lx) == 24 then
            is_server_rack = true
        end
    end
    if lz >= 46 and lz <= 54 and (abs(lx) == 8 or abs(lx) == 14) and (lz % 3 ~= 0) then
        is_server_rack = true
    end

    local is_core_pedestal = (abs(lx) <= 1 and lz >= 49 and lz <= 51)
    local is_core_pos = (lx == 0 and lz == 50)
    local cable = get_cable_node(x, z)

    for y = min_cy, max_cy do
        local vi = area:index(wx, oy + y, wz)
        if y < 0 then
            data[vi] = C.bedrock
        elseif y == 0 then
            data[vi] = cable or C.dc_floor
        elseif y >= 1 and y <= 14 then
            if is_outer_wall then
                if is_entrance and y <= 5 then
                    data[vi] = C.air
                elseif is_entrance and y == 6 then
                    data[vi] = C.dc_beacon
                elseif (y == 3 or y == 8) and ((abs(lx) == 30 and lz % 6 == 0) or ((lz == 0 or lz == 60) and abs(lx) % 6 == 0)) then
                    data[vi] = C.dc_vent
                else
                    data[vi] = C.dc_wall
                end
            elseif y == 11 or y == 14 then
                data[vi] = C.dc_wall
            elseif y > 11 then
                if abs(lx) >= 28 or lz <= 2 or lz >= 58 then
                    data[vi] = C.dc_wall
                elseif (y == 12 or y == 13) and (abs(lx) % 10 == 0) and (lz % 10 == 0) then
                    data[vi] = C.dc_vent
                else
                    data[vi] = C.air
                end
            else
                if is_partition_1 or is_partition_2 then
                    data[vi] = C.dc_wall
                elseif is_core_pos and y == 2 then
                    data[vi] = C.core_on
                elseif is_core_pedestal and y == 1 then
                    data[vi] = C.dc_wall
                elseif is_server_rack and y >= 1 and y <= 5 then
                    data[vi] = C.rack_on
                else
                    data[vi] = C.air
                end
            end
        else
            data[vi] = C.air
        end
    end
end

-- ============================================================================
-- Landmark 2: Grand Central Plaza & Neoclassical Colonnade
-- Plaza: X: -52..52, Z: -52..33
-- Colonnade & Hall: X: -44..44, Z: 34..74
-- ============================================================================
local function generate_central_plaza_column(data, area, wx, oy, wz, x, z, min_cy, max_cy, lantern_cid)
    local cable = get_cable_node(x, z)

    -- Grand Neoclassical Hall & Colonnade (Z: 34..74, X: -44..44)
    if z >= 34 and z <= 74 and abs(x) <= 44 then
        local ax = abs(x)
        local is_steps = (z >= 34 and z <= 36 and ax <= 36)
        local is_portico = (z >= 37 and z <= 43 and ax <= 36)
        local is_hall = (z >= 44 and z <= 74 and ax <= 44)

        for y = min_cy, max_cy do
            local vi = area:index(wx, oy + y, wz)
            if y < 0 then
                data[vi] = C.bedrock
            elseif y == 0 then
                data[vi] = C.cobble
            elseif is_steps then
                if y == 1 and z >= 35 then
                    data[vi] = C.sidewalk
                elseif y == 2 and z == 36 then
                    data[vi] = C.sidewalk
                else
                    data[vi] = C.air
                end
            elseif is_portico then
                if y <= 2 then
                    data[vi] = C.lobby
                elseif y >= 3 and y <= 13 then
                    if z == 38 and ax <= 32 and (ax % 8 == 0) then
                        data[vi] = C.pillar
                    else
                        data[vi] = C.air
                    end
                elseif y == 14 or y == 15 then
                    data[vi] = C.cornice
                elseif y >= 16 and y <= 21 then
                    local ped_half = 36 - (y - 16) * 6
                    if ax <= ped_half then
                        data[vi] = (ax == ped_half or y == 16) and C.cornice or C.wall_cream
                    else
                        data[vi] = C.air
                    end
                else
                    data[vi] = C.air
                end
            elseif is_hall then
                if y <= 2 then
                    data[vi] = C.lobby
                elseif y >= 3 and y <= 15 then
                    local on_wall = (z == 44 or z == 74 or ax == 44)
                    local is_entry = (z == 44 and ax <= 3 and y <= 8)
                    if on_wall and not is_entry then
                        if y == 15 or y == 9 then
                            data[vi] = C.cornice
                        elseif (y == 5 or y == 6 or y == 11 or y == 12) and ((ax % 6 == 0 and ax < 42) or ((z - 44) % 6 == 0 and z < 72)) then
                            -- Non-blinking lit window
                            data[vi] = C.win_lit
                        else
                            data[vi] = C.wall_cream
                        end
                    else
                        data[vi] = C.air
                    end
                elseif y >= 16 and y <= 23 then
                    local inset = y - 16
                    if ax <= 44 - inset and z >= 44 + inset and z <= 74 - inset then
                        data[vi] = C.roof_copper
                    else
                        data[vi] = C.air
                    end
                else
                    data[vi] = C.air
                end
            else
                data[vi] = C.air
            end
        end
        return
    end

    -- Open Grand Cobblestone Plaza (X: -52..52, Z: -52..33)
    local dist_fountain = (x * x) + ((z + 6) * (z + 6))
    local is_plaza_lantern = (
        (abs(x) == 42 and (z == -42 or z == -20 or z == 2 or z == 24))
        or (abs(x) == 18 and (z == -42 or z == 28))
    )

    for y = min_cy, max_cy do
        local vi = area:index(wx, oy + y, wz)
        if y < 0 then
            data[vi] = C.bedrock
        elseif y == 0 then
            if cable then
                data[vi] = cable
            elseif dist_fountain <= 25 then
                data[vi] = C.water
            elseif dist_fountain <= 36 then
                data[vi] = C.cobble_trim
            elseif (abs(x) % 12 == 0 or abs(z) % 12 == 0) then
                data[vi] = C.cobble_trim
            else
                data[vi] = C.cobble
            end
        elseif y == 1 then
            if dist_fountain > 25 and dist_fountain <= 36 then
                data[vi] = C.cobble_trim
            elseif x == 0 and z == -6 then
                data[vi] = C.pillar
            elseif is_plaza_lantern then
                data[vi] = C.curb
            else
                data[vi] = C.air
            end
        else
            if x == 0 and z == -6 and y <= 4 then
                data[vi] = C.pillar
            elseif is_plaza_lantern then
                data[vi] = sample_lantern(y, lantern_cid) or C.air
            else
                data[vi] = C.air
            end
        end
    end
end

-- ============================================================================
-- Landmark 3: Grand Spa Park (X: 56..230, Z: -160..160)
-- ============================================================================
local function generate_park_column(data, area, wx, oy, wz, x, z, min_cy, max_cy, lantern_cid)
    local is_main_path = (abs(z) <= 4 or abs(x - 140) <= 4 or abs(z - 80) <= 2 or abs(z + 80) <= 2)
    local pond_d2 = ((x - 175) * (x - 175)) / 4 + (z * z) / 9
    local is_pond = (pond_d2 < 140) and not is_main_path

    local tx = floor((x + 9) / 18) * 18
    local tz = floor((z + 9) / 18) * 18
    local has_tree = (hash2d(tx, tz) % 3 ~= 0) and (abs(tz) > 9) and (abs(tx - 140) > 9)
        and (((tx - 175) * (tx - 175)) / 4 + (tz * tz) / 9 > 180)
        and (tx >= 64 and tx <= 222 and abs(tz) <= 150)

    local is_lantern = (abs(z) == 5 and (x % 24 == 0)) or (abs(x - 140) == 5 and (z % 24 == 0))

    for y = min_cy, max_cy do
        local vi = area:index(wx, oy + y, wz)
        if y < 0 then
            data[vi] = C.bedrock
        elseif y == 0 then
            if is_main_path then
                data[vi] = C.gravel
            elseif is_pond then
                data[vi] = C.water
            else
                data[vi] = C.grass
            end
        elseif y == 1 then
            if is_lantern then
                data[vi] = C.curb
            elseif has_tree and x == tx and z == tz then
                data[vi] = C.trunk
            else
                data[vi] = C.air
            end
        else
            if is_lantern then
                data[vi] = sample_lantern(y, lantern_cid) or C.air
            elseif has_tree then
                data[vi] = sample_tree(x, z, y, tx, tz) or C.air
            else
                data[vi] = C.air
            end
        end
    end
end

-- ============================================================================
-- Standard City Grid: Boulevards, Roundabouts, Side Streets, Alleys, Buildings
-- ============================================================================
local function generate_city_column(data, area, wx, oy, wz, x, z, min_cy, max_cy, lantern_cid)
    local cable = get_cable_node(x, z)

    -- Superblock coordinates (240x240) for primary boulevards & roundabouts
    local mx = pmod(x + 120, 240) - 120
    local mz = pmod(z + 120, 240) - 120
    local amx = abs(mx)
    local amz = abs(mz)

    -- Roundabout at major boulevard intersections (240x240)
    local r2 = mx * mx + mz * mz
    if r2 <= 484 then -- radius 22
        local is_center_island = (r2 <= 49)
        local is_ring_curb = (r2 > 49 and r2 <= 64)
        local is_outer_curb = (r2 > 361 and r2 <= 484)
        local is_lantern = ((amx == 19 and mz == 0) or (mx == 0 and amz == 19))

        for y = min_cy, max_cy do
            local vi = area:index(wx, oy + y, wz)
            if y < 0 then
                data[vi] = C.bedrock
            elseif y == 0 then
                if cable then
                    data[vi] = cable
                elseif is_center_island then
                    data[vi] = C.grass
                elseif is_ring_curb or is_outer_curb then
                    data[vi] = C.cobble_trim
                else
                    data[vi] = C.cobble
                end
            elseif y == 1 then
                if is_ring_curb then
                    data[vi] = C.curb
                elseif mx == 0 and mz == 0 then
                    data[vi] = C.pillar
                elseif is_lantern then
                    data[vi] = C.curb
                else
                    data[vi] = C.air
                end
            else
                if mx == 0 and mz == 0 and y <= 6 then
                    data[vi] = C.pillar
                elseif is_lantern then
                    data[vi] = sample_lantern(y, lantern_cid) or C.air
                else
                    data[vi] = C.air
                end
            end
        end
        return
    end

    -- Primary Boulevards (asphalt: -6..6, sidewalk: 7..9)
    local on_blvd_x_road = (amz <= 6)
    local on_blvd_z_road = (amx <= 6)
    local on_blvd_x_walk = (amz >= 7 and amz <= 9)
    local on_blvd_z_walk = (amx >= 7 and amx <= 9)

    if on_blvd_x_road or on_blvd_z_road or on_blvd_x_walk or on_blvd_z_walk then
        local is_road = on_blvd_x_road or on_blvd_z_road
        local is_curb = (not is_road) and (amz == 7 or amx == 7)
        local is_lantern = (not is_road) and (
            (amz == 7 and pmod(x, 20) == 0 and amx > 10)
            or (amx == 7 and pmod(z, 20) == 0 and amz > 10)
        )
        local tx = floor(x / 20) * 20 + 10
        local tz = floor(z / 20) * 20 + 10
        local tree_z = (mz >= 0) and (z - mz + 8) or (z - mz - 8)
        local tree_x = (mx >= 0) and (x - mx + 8) or (x - mx - 8)
        local near_blvd_tree_x = (not is_road) and on_blvd_x_walk and (amx > 14) and (abs(x - tx) <= 2) and (abs(z - tree_z) <= 2)
        local near_blvd_tree_z = (not is_road) and on_blvd_z_walk and (amz > 14) and (abs(z - tz) <= 2) and (abs(x - tree_x) <= 2)

        for y = min_cy, max_cy do
            local vi = area:index(wx, oy + y, wz)
            if y < 0 then
                data[vi] = C.bedrock
            elseif y == 0 then
                if cable then
                    data[vi] = cable
                elseif is_road then
                    if on_blvd_x_road and mz == 0 and (pmod(x, 6) < 3) and not on_blvd_z_road then
                        data[vi] = C.asphalt_x
                    elseif on_blvd_z_road and mx == 0 and (pmod(z, 6) < 3) and not on_blvd_x_road then
                        data[vi] = C.asphalt_z
                    else
                        data[vi] = C.asphalt
                    end
                else
                    data[vi] = C.sidewalk
                end
            elseif y == 1 then
                if is_road then
                    data[vi] = C.air
                else
                    data[vi] = is_curb and C.curb or C.sidewalk
                end
            else
                if is_lantern then
                    data[vi] = sample_lantern(y, lantern_cid) or C.air
                elseif near_blvd_tree_x then
                    data[vi] = sample_tree(x, z, y, tx, tree_z) or C.air
                elseif near_blvd_tree_z then
                    data[vi] = sample_tree(x, z, y, tree_x, tz) or C.air
                else
                    data[vi] = C.air
                end
            end
        end
        return
    end

    -- Secondary Streets every 80 blocks (asphalt: -3..3, sidewalk: 4..5)
    local sx = pmod(x + 40, 80) - 40
    local sz = pmod(z + 40, 80) - 40
    local asx = abs(sx)
    local asz = abs(sz)

    local on_sec_x_road = (asz <= 3)
    local on_sec_z_road = (asx <= 3)
    local on_sec_x_walk = (asz == 4 or asz == 5)
    local on_sec_z_walk = (asx == 4 or asx == 5)

    if on_sec_x_road or on_sec_z_road or on_sec_x_walk or on_sec_z_walk then
        local is_road = on_sec_x_road or on_sec_z_road
        local is_curb = (not is_road) and (asz == 4 or asx == 4)
        local is_lantern = (not is_road) and (
            (asz == 4 and pmod(x, 24) == 0 and asx > 6)
            or (asx == 4 and pmod(z, 24) == 0 and asz > 6)
        )

        for y = min_cy, max_cy do
            local vi = area:index(wx, oy + y, wz)
            if y < 0 then
                data[vi] = C.bedrock
            elseif y == 0 then
                if cable then
                    data[vi] = cable
                elseif is_road then
                    data[vi] = C.asphalt
                else
                    data[vi] = C.sidewalk
                end
            elseif y == 1 then
                if is_road then
                    data[vi] = C.air
                else
                    data[vi] = is_curb and C.curb or C.sidewalk
                end
            else
                if is_lantern then
                    data[vi] = sample_lantern(y, lantern_cid) or C.air
                else
                    data[vi] = C.air
                end
            end
        end
        return
    end

    -- Inside an 80x80 City Block (local coords bx, bz in 6..74)
    local block_id_x = floor((x + 40) / 80)
    local block_id_z = floor((z + 40) / 80)
    local bx = pmod(x + 40, 80)
    local bz = pmod(z + 40, 80)

    -- Narrow historic cobblestone alley (width 4)
    local block_h = hash2d(block_id_x, block_id_z)
    if (bx >= 38 and bx <= 41) or ((block_h % 2 == 0) and bz >= 38 and bz <= 41) then
        for y = min_cy, max_cy do
            local vi = area:index(wx, oy + y, wz)
            if y < 0 then
                data[vi] = C.bedrock
            elseif y == 0 then
                data[vi] = C.cobble
            else
                data[vi] = C.air
            end
        end
        return
    end

    -- Building parcel quadrant
    local px0, px1 = (bx < 38) and 7 or 42, (bx < 38) and 37 or 73
    local pz0, pz1 = (bz < 38) and 7 or 42, (bz < 38) and 37 or 73
    if (block_h % 2 ~= 0) then
        pz0, pz1 = 7, 73
    end

    -- Sidewalk/courtyard border outside parcel footprint
    if bx < px0 or bx > px1 or bz < pz0 or bz > pz1 then
        for y = min_cy, max_cy do
            local vi = area:index(wx, oy + y, wz)
            if y < 0 then
                data[vi] = C.bedrock
            elseif y <= 1 then
                data[vi] = C.sidewalk
            else
                data[vi] = C.air
            end
        end
        return
    end

    -- Deterministic architectural parameters for this parcel
    local ph = hash2d(block_id_x * 4 + (bx < 38 and 1 or 2), block_id_z * 4 + (bz < 38 and 1 or 2))
    local stories = 3 + (ph % 3) -- 3 to 5 stories
    local wall_h = stories * 4 + 2 -- 14, 18, or 22 nodes
    local wall_cid = C.palettes[(ph % 4) + 1]
    local roof_cid = ((ph % 5) == 0) and C.roof_copper or C.roof_slate

    local dx_edge = math.min(bx - px0, px1 - bx)
    local dz_edge = math.min(bz - pz0, pz1 - bz)
    local d_edge = math.min(dx_edge, dz_edge)

    -- Inner courtyard for large parcels
    if dx_edge >= 8 and dz_edge >= 8 then
        for y = min_cy, max_cy do
            local vi = area:index(wx, oy + y, wz)
            if y < 0 then
                data[vi] = C.bedrock
            elseif y == 0 then
                data[vi] = ((bx + bz) % 4 == 0) and C.grass or C.cobble
            else
                data[vi] = C.air
            end
        end
        return
    end

    local on_outer_wall = (d_edge == 0)
    local on_inner_wall = (dx_edge == 7 or dz_edge == 7)
    local mid_x = floor((px0 + px1) / 2)
    local mid_z = floor((pz0 + pz1) / 2)
    local is_doorway = (
        ((bz == pz0 or bz == pz1) and abs(bx - mid_x) <= 1)
        or ((bx == px0 or bx == px1) and abs(bz - mid_z) <= 1)
    )

    for y = min_cy, max_cy do
        local vi = area:index(wx, oy + y, wz)
        if y < 0 then
            data[vi] = C.bedrock
        elseif y == 0 then
            data[vi] = C.lobby
        elseif y == 1 then
            if (on_outer_wall or on_inner_wall) and not is_doorway then
                data[vi] = C.rusticated
            else
                data[vi] = C.lobby
            end
        elseif y >= 2 and y <= wall_h then
            if on_outer_wall then
                if is_doorway and y <= 4 then
                    data[vi] = C.air
                elseif y <= 4 then
                    data[vi] = C.rusticated
                elseif y == 5 or y == wall_h then
                    data[vi] = C.cornice
                elseif (y % 4 == 2 or y % 4 == 3) and ((bx % 4 == 0) ~= (bz % 4 == 0)) then
                    -- Non-blinking windows (lit or dark)
                    local lit_roll = hash2d(x + y * 7, z) % 3
                    data[vi] = (lit_roll == 0) and C.win_lit or C.win_dark
                else
                    data[vi] = wall_cid
                end
            elseif on_inner_wall then
                if is_doorway and y <= 4 then
                    data[vi] = C.air
                else
                    data[vi] = wall_cid
                end
            elseif y == 6 then
                data[vi] = C.sidewalk
            else
                data[vi] = C.air
            end
        elseif y > wall_h and y <= wall_h + 4 then
            local inset = y - wall_h
            if d_edge >= inset and d_edge <= 7 - inset then
                data[vi] = roof_cid
            else
                data[vi] = C.air
            end
        else
            data[vi] = C.air
        end
    end
end

-- ============================================================================
-- Asynchronous Chunked VoxelManip City Builder
-- ============================================================================

local active_job = nil
local data_buf = {}

local function generate_tile(job, tile)
    init_content_ids()

    local ox, oy, oz = job.origin.x, job.origin.y, job.origin.z
    local lantern_cid = job.blinking_lanterns and C.lantern_blinking or C.lantern_steady

    local minp = { x = tile.x0, y = oy + MIN_CY, z = tile.z0 }
    local maxp = { x = tile.x1, y = oy + MAX_CY, z = tile.z1 }

    local vm = minetest.get_voxel_manip(minp, maxp)
    local emin, emax = vm:read_from_map(minp, maxp)
    local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
    vm:get_data(data_buf)

    for wz = tile.z0, tile.z1 do
        local cz = wz - oz
        for wx = tile.x0, tile.x1 do
            local cx = wx - ox
            if cx >= -350 and cx <= -290 and cz >= 370 and cz <= 430 then
                generate_datacenter_column(data_buf, area, wx, oy, wz, cx, cz, MIN_CY, MAX_CY)
            elseif abs(cx) <= 52 and cz >= -52 and cz <= 74 then
                generate_central_plaza_column(data_buf, area, wx, oy, wz, cx, cz, MIN_CY, MAX_CY, lantern_cid)
            elseif cx >= 56 and cx <= 230 and abs(cz) <= 160 then
                generate_park_column(data_buf, area, wx, oy, wz, cx, cz, MIN_CY, MAX_CY, lantern_cid)
            else
                generate_city_column(data_buf, area, wx, oy, wz, cx, cz, MIN_CY, MAX_CY, lantern_cid)
            end
        end
    end

    vm:set_data(data_buf)
    vm:calc_lighting()
    vm:write_to_map(true)
end

local function process_next_tile()
    local job = active_job
    if not job or job.cancelled then
        active_job = nil
        return
    end

    job.index = job.index + 1
    local tile = job.tiles[job.index]
    if not tile then
        local elapsed = string.format("%.1f", (minetest.get_us_time() - job.start_us) / 1e6)
        if job.caller and minetest.get_player_by_name(job.caller) then
            minetest.chat_send_player(
                job.caller,
                string.format(
                    "[Neoclassical City] Done! Built %dx%d city at (%d, %d, %d) in %ss.",
                    job.radius * 2 + 1,
                    job.radius * 2 + 1,
                    job.origin.x,
                    job.origin.y,
                    job.origin.z,
                    elapsed
                )
            )
        end
        active_job = nil
        return
    end

    local minp = { x = tile.x0, y = job.origin.y + MIN_CY, z = tile.z0 }
    local maxp = { x = tile.x1, y = job.origin.y + MAX_CY, z = tile.z1 }

    minetest.emerge_area(minp, maxp, function(_, _, calls_remaining)
        if calls_remaining > 0 then
            return
        end
        if not active_job or active_job ~= job or job.cancelled then
            return
        end

        generate_tile(job, tile)

        local pct = floor((job.index / #job.tiles) * 100)
        if job.caller and pct >= job.next_report_pct and job.index < #job.tiles then
            while job.next_report_pct <= pct do
                job.next_report_pct = job.next_report_pct + 25
            end
            if minetest.get_player_by_name(job.caller) then
                minetest.chat_send_player(
                    job.caller,
                    string.format("[Neoclassical City] Building... %d%% (%d/%d tiles)", pct, job.index, #job.tiles)
                )
            end
        end

        minetest.after(0.05, process_next_tile)
    end)
end

function neoclassical_city.build_city(origin, opts)
    if active_job then
        return false, "A city build is already in progress. Use /build_city_cancel to abort it."
    end

    opts = opts or {}
    local radius = tonumber(opts.radius) or DEFAULT_RADIUS
    radius = floor(radius)
    if radius < MIN_RADIUS or radius > MAX_RADIUS then
        return false, string.format("Radius must be between %d and %d.", MIN_RADIUS, MAX_RADIUS)
    end

    local ox = floor(origin.x)
    local oy = floor(origin.y)
    local oz = floor(origin.z)

    local tiles = {}
    for z0 = oz - radius, oz + radius, TILE_SIZE do
        local z1 = math.min(z0 + TILE_SIZE - 1, oz + radius)
        for x0 = ox - radius, ox + radius, TILE_SIZE do
            local x1 = math.min(x0 + TILE_SIZE - 1, ox + radius)
            tiles[#tiles + 1] = { x0 = x0, z0 = z0, x1 = x1, z1 = z1 }
        end
    end

    active_job = {
        origin = { x = ox, y = oy, z = oz },
        radius = radius,
        blinking_lanterns = opts.blinking_lanterns == true,
        caller = opts.caller,
        tiles = tiles,
        index = 0,
        next_report_pct = 25,
        start_us = minetest.get_us_time(),
        cancelled = false,
    }

    minetest.after(0, process_next_tile)
    return true, string.format(
        "[Neoclassical City] Building %dx%d city centered at (%d, %d, %d) with %s lanterns (%d tiles)...",
        radius * 2 + 1,
        radius * 2 + 1,
        ox,
        oy,
        oz,
        active_job.blinking_lanterns and "blinking" or "steady",
        #tiles
    )
end

-- ============================================================================
-- Privilege & Chat Commands
-- ============================================================================

minetest.register_privilege("neoclassical_city", {
    description = "Can generate neoclassical cities using /build_city",
    give_to_singleplayer = true,
    give_to_admin = true,
})

local function handle_build_city(name, param)
    local player = minetest.get_player_by_name(name)
    if not player then
        return false, "You must be online to run this command."
    end

    local radius = DEFAULT_RADIUS
    local blinking_lanterns = false

    for token in (param or ""):gmatch("%S+") do
        local low = token:lower()
        local num = tonumber(token)
        if num then
            radius = floor(num)
        elseif low == "blinking" or low == "blink" then
            blinking_lanterns = true
        elseif low == "steady" or low == "static" or low == "normal" then
            blinking_lanterns = false
        else
            return false, string.format(
                "Unknown argument '%s'. Usage: /build_city [radius %d-%d] [steady|blinking]",
                token,
                MIN_RADIUS,
                MAX_RADIUS
            )
        end
    end

    local pos = player:get_pos()
    local origin = {
        x = floor(pos.x + 0.5),
        y = floor(pos.y) - 1,
        z = floor(pos.z + 0.5),
    }

    local ok, msg = neoclassical_city.build_city(origin, {
        radius = radius,
        blinking_lanterns = blinking_lanterns,
        caller = name,
    })

    if ok and pos.y < origin.y + 2 then
        player:set_pos({ x = pos.x, y = origin.y + 2.5, z = pos.z })
    end

    return ok, msg
end

minetest.register_chatcommand("build_city", {
    params = "[radius] [steady|blinking]",
    description = string.format(
        "Build the neoclassical city centered at your position (default radius: %d, max: %d; lanterns: steady or blinking; windows are non-blinking)",
        DEFAULT_RADIUS,
        MAX_RADIUS
    ),
    privs = { neoclassical_city = true },
    func = handle_build_city,
})

minetest.register_chatcommand("neoclassical_city", {
    params = "[radius] [steady|blinking]",
    description = "Alias for /build_city",
    privs = { neoclassical_city = true },
    func = handle_build_city,
})

minetest.register_chatcommand("build_city_cancel", {
    description = "Cancel an in-progress neoclassical city build",
    privs = { neoclassical_city = true },
    func = function()
        if not active_job then
            return false, "No city build is currently running."
        end
        active_job.cancelled = true
        active_job = nil
        return true, "[Neoclassical City] City build cancelled."
    end,
})

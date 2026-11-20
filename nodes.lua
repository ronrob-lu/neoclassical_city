-- nodes.lua: Neoclassical architectural blocks, streets, parks,
-- steady & blinking street lanterns, steady & blinking facade windows,
-- power conduits, and optional data center hardware.

local function register_city_node(name, def)
    def.is_ground_content = false
    def.groups = def.groups or { cracky = 3 }
    minetest.register_node("neoclassical_city:" .. name, def)
end

-- ============================================================================
-- Foundation, Perimeter & Park Elements
-- ============================================================================

register_city_node("bedrock", {
    description = "City Foundation",
    tiles = { "neoclassical_city_bedrock.png" },
    groups = { cracky = 1 },
})

register_city_node("perimeter_wall", {
    description = "City Perimeter Wall",
    tiles = { "neoclassical_city_perimeter_wall.png" },
    groups = { cracky = 2 },
})

register_city_node("park_grass", {
    description = "Park Lawn",
    tiles = { "neoclassical_city_park_grass.png" },
    groups = { crumbly = 3, soil = 1 },
})

register_city_node("park_gravel", {
    description = "Park Promenade Gravel",
    tiles = { "neoclassical_city_park_gravel.png" },
    groups = { crumbly = 2 },
})

register_city_node("water", {
    description = "Ornamental Basin Water",
    tiles = { "neoclassical_city_water.png" },
    walkable = true,
    paramtype = "light",
    groups = { oddly_breakable_by_hand = 3 },
})

register_city_node("tree_trunk", {
    description = "Boulevard Tree Trunk",
    tiles = { "neoclassical_city_tree_trunk.png" },
    groups = { tree = 1, choppy = 2, oddly_breakable_by_hand = 2 },
})

register_city_node("tree_leaves", {
    description = "Boulevard Tree Canopy",
    tiles = { "neoclassical_city_tree_leaves.png" },
    paramtype = "light",
    groups = { snappy = 3, leaves = 1 },
})

-- ============================================================================
-- Streets, Plazas & Sidewalks
-- ============================================================================

register_city_node("asphalt", {
    description = "Asphalt Road",
    tiles = { "neoclassical_city_asphalt.png" },
})

register_city_node("asphalt_line_x", {
    description = "Asphalt Road (East-West Lane)",
    tiles = { "neoclassical_city_asphalt_line_x.png", "neoclassical_city_asphalt.png" },
})

register_city_node("asphalt_line_z", {
    description = "Asphalt Road (North-South Lane)",
    tiles = { "neoclassical_city_asphalt_line_z.png", "neoclassical_city_asphalt.png" },
})

register_city_node("cobblestone", {
    description = "Historic Cobblestone",
    tiles = { "neoclassical_city_cobblestone.png" },
})

register_city_node("cobblestone_trim", {
    description = "Plaza Border Stone",
    tiles = { "neoclassical_city_cobblestone_trim.png" },
})

register_city_node("sidewalk", {
    description = "Stone Sidewalk",
    tiles = { "neoclassical_city_sidewalk.png" },
})

register_city_node("sidewalk_curb", {
    description = "Sidewalk Curbstone",
    tiles = {
        "neoclassical_city_sidewalk.png",
        "neoclassical_city_sidewalk.png",
        "neoclassical_city_sidewalk_curb.png",
    },
})

-- ============================================================================
-- Heavy Power Conduits
-- ============================================================================

register_city_node("power_cable_x", {
    description = "Heavy Power Conduit (E-W)",
    tiles = { "neoclassical_city_power_cable_x.png", "neoclassical_city_asphalt.png" },
    light_source = 3,
})

register_city_node("power_cable_z", {
    description = "Heavy Power Conduit (N-S)",
    tiles = { "neoclassical_city_power_cable_z.png", "neoclassical_city_asphalt.png" },
    light_source = 3,
})

register_city_node("power_cable_junction", {
    description = "Power Conduit Junction",
    tiles = { "neoclassical_city_power_cable_junction.png", "neoclassical_city_asphalt.png" },
    light_source = 6,
})

-- ============================================================================
-- Neoclassical & Historic European Architecture
-- ============================================================================

register_city_node("sandstone_cream", {
    description = "Cream Neoclassical Facade",
    tiles = { "neoclassical_city_sandstone_cream.png" },
})

register_city_node("sandstone_ochre", {
    description = "Ochre Historic Plaster",
    tiles = { "neoclassical_city_sandstone_ochre.png" },
})

register_city_node("sandstone_terracotta", {
    description = "Terracotta Historic Plaster",
    tiles = { "neoclassical_city_sandstone_terracotta.png" },
})

register_city_node("sandstone_slate", {
    description = "Slate Limestone Facade",
    tiles = { "neoclassical_city_sandstone_slate.png" },
})

register_city_node("rusticated_base", {
    description = "Rusticated Stone Base",
    tiles = { "neoclassical_city_rusticated_base.png" },
})

register_city_node("cornice", {
    description = "Sculpted Cornice",
    tiles = {
        "neoclassical_city_sandstone_cream.png",
        "neoclassical_city_sandstone_cream.png",
        "neoclassical_city_cornice.png",
    },
})

register_city_node("pillar", {
    description = "Fluted Neoclassical Column",
    tiles = {
        "neoclassical_city_sandstone_cream.png",
        "neoclassical_city_sandstone_cream.png",
        "neoclassical_city_pillar.png",
    },
})

register_city_node("roof_slate", {
    description = "Slate Roof Tiles",
    tiles = { "neoclassical_city_roof_slate.png" },
})

register_city_node("roof_copper", {
    description = "Verdigris Copper Roof",
    tiles = { "neoclassical_city_roof_copper.png" },
})

register_city_node("lobby_floor", {
    description = "Checkered Marble Lobby Floor",
    tiles = { "neoclassical_city_lobby_floor.png" },
})

-- ============================================================================
-- Facade Windows: Non-Blinking (Default) & Opt-In Blinking
-- ============================================================================

register_city_node("window_lit", {
    description = "Lit Facade Window (Non-Blinking)",
    tiles = { "neoclassical_city_window_lit.png" },
    light_source = 11,
    groups = { cracky = 3, oddly_breakable_by_hand = 3 },
})

register_city_node("window_dark", {
    description = "Dark Facade Window (Non-Blinking)",
    tiles = { "neoclassical_city_window_dark.png" },
    light_source = 0,
    groups = { cracky = 3, oddly_breakable_by_hand = 3 },
})

register_city_node("window_blinking", {
    description = "Blinking Facade Window",
    tiles = { "neoclassical_city_window_lit.png" },
    light_source = 11,
    groups = { cracky = 3, oddly_breakable_by_hand = 3, neoclassical_blinking_window = 1 },
})

register_city_node("window_blinking_dim", {
    description = "Blinking Facade Window (Dim)",
    tiles = { "neoclassical_city_window_lit.png^[multiply:#7a5830" },
    light_source = 3,
    drop = "neoclassical_city:window_blinking",
    groups = {
        cracky = 3,
        oddly_breakable_by_hand = 3,
        neoclassical_blinking_window = 1,
        not_in_creative_inventory = 1,
    },
})

register_city_node("window_blinking_dark", {
    description = "Blinking Facade Window (Dark)",
    tiles = { "neoclassical_city_window_dark.png" },
    light_source = 0,
    drop = "neoclassical_city:window_blinking",
    groups = {
        cracky = 3,
        oddly_breakable_by_hand = 3,
        neoclassical_blinking_window = 1,
        not_in_creative_inventory = 1,
    },
})

-- ============================================================================
-- Street Lanterns: Non-Blinking & Blinking Variants
-- ============================================================================

register_city_node("lantern_post", {
    description = "Wrought-Iron Lamppost",
    tiles = { "neoclassical_city_lantern_post.png" },
    drawtype = "nodebox",
    paramtype = "light",
    node_box = {
        type = "fixed",
        fixed = { -0.14, -0.5, -0.14, 0.14, 0.5, 0.14 },
    },
    collision_box = {
        type = "fixed",
        fixed = { -0.18, -0.5, -0.18, 0.18, 0.5, 0.18 },
    },
    groups = { cracky = 3, oddly_breakable_by_hand = 3 },
})

local lantern_box = {
    type = "fixed",
    fixed = {
        { -0.28, -0.5, -0.28, 0.28, 0.35, 0.28 },
        { -0.34, 0.35, -0.34, 0.34, 0.5, 0.34 },
    },
}

-- Non-blinking street lanterns
register_city_node("lantern_steady", {
    description = "Street Lantern (Non-Blinking)",
    tiles = {
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_steady.png",
    },
    drawtype = "nodebox",
    paramtype = "light",
    node_box = lantern_box,
    light_source = 14,
    groups = { cracky = 3, oddly_breakable_by_hand = 3 },
})

register_city_node("lantern_off", {
    description = "Street Lantern (Extinguished)",
    tiles = {
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_off.png",
    },
    drawtype = "nodebox",
    paramtype = "light",
    node_box = lantern_box,
    light_source = 0,
    groups = { cracky = 3, oddly_breakable_by_hand = 3 },
})

-- Blinking street lanterns
register_city_node("lantern_blinking", {
    description = "Street Lantern (Blinking)",
    tiles = {
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_on.png",
    },
    drawtype = "nodebox",
    paramtype = "light",
    node_box = lantern_box,
    light_source = 14,
    groups = { cracky = 3, oddly_breakable_by_hand = 3, neoclassical_blinking_lantern = 1 },
})

register_city_node("lantern_blinking_dim", {
    description = "Street Lantern (Blinking - Dim)",
    tiles = {
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_dim.png",
    },
    drawtype = "nodebox",
    paramtype = "light",
    node_box = lantern_box,
    light_source = 4,
    drop = "neoclassical_city:lantern_blinking",
    groups = {
        cracky = 3,
        oddly_breakable_by_hand = 3,
        neoclassical_blinking_lantern = 1,
        not_in_creative_inventory = 1,
    },
})

register_city_node("lantern_blinking_off", {
    description = "Street Lantern (Blinking - Off)",
    tiles = {
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_post.png",
        "neoclassical_city_lantern_off.png",
    },
    drawtype = "nodebox",
    paramtype = "light",
    node_box = lantern_box,
    light_source = 0,
    drop = "neoclassical_city:lantern_blinking",
    groups = {
        cracky = 3,
        oddly_breakable_by_hand = 3,
        neoclassical_blinking_lantern = 1,
        not_in_creative_inventory = 1,
    },
})

-- ============================================================================
-- Data Center Hardware (Decorative Landmark Blocks)
-- ============================================================================

register_city_node("datacenter_wall", {
    description = "Reinforced Data Center Wall",
    tiles = { "neoclassical_city_datacenter_wall.png" },
})

register_city_node("datacenter_vent", {
    description = "Industrial Cooling Vent",
    tiles = {
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_vent.png",
    },
})

register_city_node("datacenter_floor", {
    description = "Server Room Floor Grate",
    tiles = { "neoclassical_city_datacenter_floor.png" },
})

register_city_node("datacenter_beacon", {
    description = "Facility Warning Beacon",
    tiles = {
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_beacon.png",
    },
    light_source = 8,
})

register_city_node("datacenter_beacon_off", {
    description = "Facility Beacon (Safe)",
    tiles = {
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_beacon_off.png",
    },
    light_source = 5,
})

register_city_node("server_rack_active", {
    description = "Active Server Rack",
    tiles = {
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_wall.png",
        {
            name = "neoclassical_city_server_rack_active.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 32,
                aspect_h = 32,
                length = 1.6,
            },
        },
    },
    light_source = 6,
})

register_city_node("server_rack_shutdown", {
    description = "Deactivated Server Rack",
    tiles = {
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_server_rack_shutdown.png",
    },
    light_source = 0,
})

register_city_node("mainframe_core", {
    description = "Mainframe Core Terminal",
    tiles = {
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_wall.png",
        {
            name = "neoclassical_city_mainframe_core.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 32,
                aspect_h = 32,
                length = 1.2,
            },
        },
    },
    light_source = 9,
})

register_city_node("mainframe_core_off", {
    description = "Mainframe Core (Offline)",
    tiles = {
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_datacenter_wall.png",
        "neoclassical_city_mainframe_core_off.png",
    },
    light_source = 6,
})

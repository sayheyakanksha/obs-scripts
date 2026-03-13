obs = obslua

-- State
local counter_value = 0

-- Hotkey handles (global so they persist for saving)
local hk_increment = nil
local hk_decrement = nil
local hk_reset = nil

-- Settings
local text_source_name = ""
local prefix_text = ""
local suffix_text = ""
local start_value = 0

-----------------------------------------------------------
-- Update the text source in OBS
-----------------------------------------------------------
local function update_display()
    local source = obs.obs_get_source_by_name(text_source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", prefix_text .. tostring(counter_value) .. suffix_text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

-----------------------------------------------------------
-- Counter controls
-----------------------------------------------------------
function counter_increment(pressed)
    if not pressed then return end
    counter_value = counter_value + 1
    update_display()
    obs.script_log(obs.LOG_INFO, "Counter: " .. counter_value)
end

function counter_decrement(pressed)
    if not pressed then return end
    counter_value = counter_value - 1
    update_display()
    obs.script_log(obs.LOG_INFO, "Counter: " .. counter_value)
end

function counter_reset(pressed)
    if not pressed then return end
    counter_value = start_value
    update_display()
    obs.script_log(obs.LOG_INFO, "Counter reset to " .. counter_value)
end

-----------------------------------------------------------
-- Button callbacks
-----------------------------------------------------------
local function on_increment_clicked(props, p)
    counter_increment(true)
    return false
end

local function on_decrement_clicked(props, p)
    counter_decrement(true)
    return false
end

local function on_reset_clicked(props, p)
    counter_reset(true)
    return false
end

-----------------------------------------------------------
-- Populate text sources list
-----------------------------------------------------------
local function populate_text_sources(props, prop)
    obs.obs_property_list_clear(prop)
    obs.obs_property_list_add_string(prop, "-- Select a Text Source --", "")

    local sources = obs.obs_enum_sources()
    if sources then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_gdiplus_v2"
                or source_id == "text_ft2_source" or source_id == "text_ft2_source_v2"
                or source_id == "text_pango_source" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(prop, name, name)
            end
        end
        obs.source_list_release(sources)
    end
end

-----------------------------------------------------------
-- OBS Script Interface
-----------------------------------------------------------

function script_description()
    return [[
<h2>OBS Counter</h2>
<p>Version 1.0.0, @sayheyakanksha</p>
<p>A simple counter that increments or decrements by 1.</p>
<p>Add a text prefix and suffix around the number.</p>
<p>Assign hotkeys in OBS Settings → Hotkeys for hands-free control.</p>
]]
end

function script_properties()
    local props = obs.obs_properties_create()

    -- Source selection
    local source_list = obs.obs_properties_add_list(props, "text_source",
        "Text Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(props, source_list)

    -- Prefix / Suffix
    obs.obs_properties_add_text(props, "prefix_text", "Text Prefix", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "suffix_text", "Text Suffix", obs.OBS_TEXT_DEFAULT)

    -- Start value
    obs.obs_properties_add_int(props, "start_value", "Starting Value", -9999, 9999, 1)

    -- Control buttons
    obs.obs_properties_add_button(props, "increment_button", "+  Add 1", on_increment_clicked)
    obs.obs_properties_add_button(props, "decrement_button", "-  Subtract 1", on_decrement_clicked)
    obs.obs_properties_add_button(props, "reset_button", "⏹  Reset", on_reset_clicked)

    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "text_source", "")
    obs.obs_data_set_default_string(settings, "prefix_text", "")
    obs.obs_data_set_default_string(settings, "suffix_text", "")
    obs.obs_data_set_default_int(settings, "start_value", 0)
end

function script_update(settings)
    text_source_name = obs.obs_data_get_string(settings, "text_source")
    prefix_text = obs.obs_data_get_string(settings, "prefix_text")
    suffix_text = obs.obs_data_get_string(settings, "suffix_text")
    start_value = obs.obs_data_get_int(settings, "start_value")
end

function script_load(settings)
    counter_value = start_value

    -- Register hotkeys
    hk_increment = obs.obs_hotkey_register_frontend("counter_increment",
        "Counter: Add 1", counter_increment)
    hk_decrement = obs.obs_hotkey_register_frontend("counter_decrement",
        "Counter: Subtract 1", counter_decrement)
    hk_reset = obs.obs_hotkey_register_frontend("counter_reset",
        "Counter: Reset", counter_reset)

    -- Load saved hotkey bindings
    local key_inc = obs.obs_data_get_array(settings, "counter_increment")
    local key_dec = obs.obs_data_get_array(settings, "counter_decrement")
    local key_reset = obs.obs_data_get_array(settings, "counter_reset")

    obs.obs_hotkey_load(hk_increment, key_inc)
    obs.obs_hotkey_load(hk_decrement, key_dec)
    obs.obs_hotkey_load(hk_reset, key_reset)

    obs.obs_data_array_release(key_inc)
    obs.obs_data_array_release(key_dec)
    obs.obs_data_array_release(key_reset)
end

function script_save(settings)
    if hk_increment then
        obs.obs_data_set_array(settings, "counter_increment", obs.obs_hotkey_save(hk_increment))
    end
    if hk_decrement then
        obs.obs_data_set_array(settings, "counter_decrement", obs.obs_hotkey_save(hk_decrement))
    end
    if hk_reset then
        obs.obs_data_set_array(settings, "counter_reset", obs.obs_hotkey_save(hk_reset))
    end
end

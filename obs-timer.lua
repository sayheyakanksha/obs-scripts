obs = obslua

-- Script state
local timer_active = false
local timer_paused = false
local elapsed_ms = 0
local last_tick = 0
local countdown_target_ms = 0
local countdown_finished = false

-- Settings values
local text_source_name = ""
local timer_mode = "countup"       -- "countup" or "countdown"
local show_hours = true
local show_milliseconds = true
local prefix_text = ""
local suffix_text = ""
local countup_start_hours = 0
local countup_start_minutes = 0
local countup_start_seconds = 0
local countdown_hours = 0
local countdown_minutes = 5
local countdown_seconds = 0
local countdown_end_text = "00:00:00:00"
local auto_reset = false
local update_interval_ms = 10      -- how often to refresh display

-----------------------------------------------------------
-- Utility: format milliseconds into display string
-----------------------------------------------------------
local function format_time(ms)
    if ms < 0 then ms = 0 end

    local total_seconds = math.floor(ms / 1000)
    local millis = ms % 1000
    local seconds = total_seconds % 60
    local minutes = math.floor(total_seconds / 60) % 60
    local hours = math.floor(total_seconds / 3600)

    local result = ""

    if show_hours then
        result = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    else
        result = string.format("%02d:%02d", minutes, seconds)
    end

    if show_milliseconds then
        result = result .. string.format(":%02d", math.floor(millis / 10))
    end

    return result
end

-----------------------------------------------------------
-- Update the text source in OBS
-----------------------------------------------------------
local function set_text_source(text)
    local source = obs.obs_get_source_by_name(text_source_name)
    if source then
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", prefix_text .. text .. suffix_text)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    end
end

-----------------------------------------------------------
-- Get current time in milliseconds
-----------------------------------------------------------
local function get_time_ms()
    return math.floor(obs.os_gettime_ns() / 1000000)
end

-----------------------------------------------------------
-- Timer tick callback
-----------------------------------------------------------
local function timer_tick()
    if not timer_active or timer_paused then
        return
    end

    local now = get_time_ms()
    local delta = now - last_tick
    last_tick = now

    if timer_mode == "countup" then
        elapsed_ms = elapsed_ms + delta
        local start_offset = (countup_start_hours * 3600 + countup_start_minutes * 60 + countup_start_seconds) * 1000
        set_text_source(format_time(start_offset + elapsed_ms))
    else
        -- Countdown
        elapsed_ms = elapsed_ms + delta
        local remaining = countdown_target_ms - elapsed_ms

        if remaining <= 0 then
            remaining = 0
            set_text_source(countdown_end_text)
            countdown_finished = true

            if auto_reset then
                timer_reset(true)
            else
                timer_active = false
                timer_paused = false
            end
        else
            set_text_source(format_time(remaining))
        end
    end
end

-----------------------------------------------------------
-- Timer controls
-----------------------------------------------------------
function timer_start(pressed)
    if not pressed then return end

    if text_source_name == "" then
        obs.script_log(obs.LOG_WARNING, "No text source selected. Please choose a text source in script settings.")
        return
    end

    if timer_active and not timer_paused then
        return -- already running
    end

    if timer_mode == "countdown" then
        countdown_target_ms = (countdown_hours * 3600 + countdown_minutes * 60 + countdown_seconds) * 1000
        if countdown_target_ms <= 0 then
            obs.script_log(obs.LOG_WARNING, "Countdown target is zero. Set a countdown duration in script settings.")
            return
        end
    end

    countdown_finished = false
    last_tick = get_time_ms()

    if not timer_active then
        elapsed_ms = 0
        if timer_mode == "countdown" then
            set_text_source(format_time(countdown_target_ms))
        else
            local start_offset = (countup_start_hours * 3600 + countup_start_minutes * 60 + countup_start_seconds) * 1000
            set_text_source(format_time(start_offset))
        end
    end

    timer_active = true
    timer_paused = false

    obs.timer_add(timer_tick, update_interval_ms)
    obs.script_log(obs.LOG_INFO, "Timer started")
end

function timer_pause(pressed)
    if not pressed then return end

    if not timer_active then return end

    if timer_paused then
        -- Resume
        timer_paused = false
        last_tick = get_time_ms()
        obs.timer_add(timer_tick, update_interval_ms)
        obs.script_log(obs.LOG_INFO, "Timer resumed")
    else
        -- Pause
        timer_paused = true
        obs.timer_remove(timer_tick)
        obs.script_log(obs.LOG_INFO, "Timer paused")
    end
end

function timer_start_pause(pressed)
    if not pressed then return end

    if not timer_active then
        timer_start(true)
    else
        timer_pause(true)
    end
end

function timer_reset(pressed)
    if pressed == false then return end
    -- pressed can be true or a truthy value from auto_reset

    timer_active = false
    timer_paused = false
    elapsed_ms = 0
    countdown_finished = false
    obs.timer_remove(timer_tick)

    if timer_mode == "countdown" then
        countdown_target_ms = (countdown_hours * 3600 + countdown_minutes * 60 + countdown_seconds) * 1000
        set_text_source(format_time(countdown_target_ms))
    else
        local start_offset = (countup_start_hours * 3600 + countup_start_minutes * 60 + countup_start_seconds) * 1000
        set_text_source(format_time(start_offset))
    end

    obs.script_log(obs.LOG_INFO, "Timer reset")
end

-----------------------------------------------------------
-- Button callbacks for the properties UI
-----------------------------------------------------------
local function on_start_pause_clicked(props, p)
    timer_start_pause(true)
    return false
end

local function on_reset_clicked(props, p)
    timer_reset(true)
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
-- Callback when timer mode changes (show/hide countdown settings)
-----------------------------------------------------------
local function on_mode_changed(props, prop, settings)
    local mode = obs.obs_data_get_string(settings, "timer_mode")
    local is_countdown = (mode == "countdown")
    local is_countup = (mode == "countup")

    obs.obs_property_set_visible(obs.obs_properties_get(props, "countup_group"), is_countup)
    obs.obs_property_set_visible(obs.obs_properties_get(props, "countdown_group"), is_countdown)

    return true
end

-----------------------------------------------------------
-- OBS Script Interface
-----------------------------------------------------------

function script_description()
    return [[
<h2>OBS Advanced Timer</h2>
<p>A flexible count-up and countdown timer for OBS.</p>
<p>Version 1.0.0, @sayheyakanksha</p>
<ul>
<li><b>Count Up</b> – Counts from 00:00:00:000 upward</li>
<li><b>Countdown</b> – Counts down from a set duration to zero</li>
</ul>
<p>Assign hotkeys in OBS Settings → Hotkeys for hands-free control.</p>
<p><b>Controls:</b> Use the buttons below or assign hotkeys for Start/Pause/Reset.</p>
]]
end

function script_properties()
    local props = obs.obs_properties_create()

    -- Source selection
    local source_list = obs.obs_properties_add_list(props, "text_source",
        "Text Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(props, source_list)

    -- Timer mode
    local mode_list = obs.obs_properties_add_list(props, "timer_mode",
        "Timer Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(mode_list, "Count Up", "countup")
    obs.obs_property_list_add_string(mode_list, "Countdown", "countdown")
    obs.obs_property_set_modified_callback(mode_list, on_mode_changed)

    -- Count Up settings group
    local countup_group = obs.obs_properties_create()
    obs.obs_properties_add_int(countup_group, "countup_start_hours", "Start Hours", 0, 99, 1)
    obs.obs_properties_add_int(countup_group, "countup_start_minutes", "Start Minutes", 0, 59, 1)
    obs.obs_properties_add_int(countup_group, "countup_start_seconds", "Start Seconds", 0, 59, 1)
    obs.obs_properties_add_group(props, "countup_group", "Count Up Settings",
        obs.OBS_GROUP_NORMAL, countup_group)

    -- Countdown settings group
    local countdown_group = obs.obs_properties_create()
    obs.obs_properties_add_int(countdown_group, "countdown_hours", "Hours", 0, 99, 1)
    obs.obs_properties_add_int(countdown_group, "countdown_minutes", "Minutes", 0, 59, 1)
    obs.obs_properties_add_int(countdown_group, "countdown_seconds", "Seconds", 0, 59, 1)
    obs.obs_properties_add_text(countdown_group, "countdown_end_text", "End Text", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_bool(countdown_group, "auto_reset", "Auto-Reset When Done")
    obs.obs_properties_add_group(props, "countdown_group", "Countdown Settings",
        obs.OBS_GROUP_NORMAL, countdown_group)

    -- Display format
    obs.obs_properties_add_bool(props, "show_hours", "Show Hours")
    obs.obs_properties_add_bool(props, "show_milliseconds", "Show Milliseconds")

    -- Prefix / Suffix
    obs.obs_properties_add_text(props, "prefix_text", "Text Prefix", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "suffix_text", "Text Suffix", obs.OBS_TEXT_DEFAULT)

    -- Update interval
    local interval_list = obs.obs_properties_add_list(props, "update_interval",
        "Update Speed", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    obs.obs_property_list_add_int(interval_list, "Fast (10ms – smooth milliseconds)", 10)
    obs.obs_property_list_add_int(interval_list, "Normal (50ms)", 50)
    obs.obs_property_list_add_int(interval_list, "Slow (100ms – lower CPU)", 100)
    obs.obs_property_list_add_int(interval_list, "Seconds Only (1000ms)", 1000)

    -- Control buttons
    obs.obs_properties_add_button(props, "start_pause_button", "▶ ⏸  Start / Pause", on_start_pause_clicked)
    obs.obs_properties_add_button(props, "reset_button", "⏹  Reset", on_reset_clicked)

    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "text_source", "")
    obs.obs_data_set_default_string(settings, "timer_mode", "countup")
    obs.obs_data_set_default_int(settings, "countup_start_hours", 0)
    obs.obs_data_set_default_int(settings, "countup_start_minutes", 0)
    obs.obs_data_set_default_int(settings, "countup_start_seconds", 0)
    obs.obs_data_set_default_int(settings, "countdown_hours", 0)
    obs.obs_data_set_default_int(settings, "countdown_minutes", 5)
    obs.obs_data_set_default_int(settings, "countdown_seconds", 0)
    obs.obs_data_set_default_string(settings, "countdown_end_text", "00:00:00:00")
    obs.obs_data_set_default_bool(settings, "auto_reset", false)
    obs.obs_data_set_default_bool(settings, "show_hours", true)
    obs.obs_data_set_default_bool(settings, "show_milliseconds", true)
    obs.obs_data_set_default_string(settings, "prefix_text", "")
    obs.obs_data_set_default_string(settings, "suffix_text", "")
    obs.obs_data_set_default_int(settings, "update_interval", 10)
end

function script_update(settings)
    text_source_name = obs.obs_data_get_string(settings, "text_source")
    timer_mode = obs.obs_data_get_string(settings, "timer_mode")
    countup_start_hours = obs.obs_data_get_int(settings, "countup_start_hours")
    countup_start_minutes = obs.obs_data_get_int(settings, "countup_start_minutes")
    countup_start_seconds = obs.obs_data_get_int(settings, "countup_start_seconds")
    countdown_hours = obs.obs_data_get_int(settings, "countdown_hours")
    countdown_minutes = obs.obs_data_get_int(settings, "countdown_minutes")
    countdown_seconds = obs.obs_data_get_int(settings, "countdown_seconds")
    countdown_end_text = obs.obs_data_get_string(settings, "countdown_end_text")
    auto_reset = obs.obs_data_get_bool(settings, "auto_reset")
    show_hours = obs.obs_data_get_bool(settings, "show_hours")
    show_milliseconds = obs.obs_data_get_bool(settings, "show_milliseconds")
    prefix_text = obs.obs_data_get_string(settings, "prefix_text")
    suffix_text = obs.obs_data_get_string(settings, "suffix_text")
    update_interval_ms = obs.obs_data_get_int(settings, "update_interval")

    -- Recalculate countdown target if settings changed
    countdown_target_ms = (countdown_hours * 3600 + countdown_minutes * 60 + countdown_seconds) * 1000
end

function script_load(settings)
    -- Register hotkeys
    local hotkey_start_pause = obs.obs_hotkey_register_frontend("timer_start_pause",
        "Timer: Start / Pause", timer_start_pause)
    local hotkey_reset = obs.obs_hotkey_register_frontend("timer_reset",
        "Timer: Reset", timer_reset)
    local hotkey_start = obs.obs_hotkey_register_frontend("timer_start_only",
        "Timer: Start", timer_start)
    local hotkey_pause = obs.obs_hotkey_register_frontend("timer_pause_only",
        "Timer: Pause / Resume", timer_pause)

    -- Load saved hotkey bindings
    local key_start_pause = obs.obs_data_get_array(settings, "timer_start_pause")
    local key_reset = obs.obs_data_get_array(settings, "timer_reset")
    local key_start = obs.obs_data_get_array(settings, "timer_start_only")
    local key_pause = obs.obs_data_get_array(settings, "timer_pause_only")

    obs.obs_hotkey_load(hotkey_start_pause, key_start_pause)
    obs.obs_hotkey_load(hotkey_reset, key_reset)
    obs.obs_hotkey_load(hotkey_start, key_start)
    obs.obs_hotkey_load(hotkey_pause, key_pause)

    obs.obs_data_array_release(key_start_pause)
    obs.obs_data_array_release(key_reset)
    obs.obs_data_array_release(key_start)
    obs.obs_data_array_release(key_pause)
end

function script_save(settings)
    -- Hotkey save is handled automatically by OBS
end

function script_unload()
    obs.timer_remove(timer_tick)
end

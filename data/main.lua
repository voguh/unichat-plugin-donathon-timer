--[[
 * Copyright (c) 2025 Voguh
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
]]

---@type UniChatLogger
local logger = require("unichat:logger");
---@type UniChatStrings
local strings = require("unichat:strings");
---@type UniChatTime
local time = require("unichat:time");

local STATUS_KEY = "status";
local POINTS_KEY = "points";
local SECONDS_KEY = "seconds";
local STARTED_AT_KEY = "started_at";
local PAUSE_KEY = "pause_timestamp";
local RUNNING_STATUS = "RUNNING";
local PAUSED_STATUS = "PAUSED";
local STOPPED_STATUS = "STOPPED";

local SPONSORSHIP_POINTS_THRESHOLD_KEY = "sponsorship_points_threshold";
local SPONSORSHIP_POINTS_TO_ADD_KEY = "sponsorship_points_to_add";
local TWITCH_BITS_POINTS_THRESHOLD_KEY = "twitch_bits_points_threshold";
local TWITCH_BITS_POINTS_TO_ADD_KEY = "twitch_bits_points_to_add";
local DONATE_POINTS_THRESHOLD_KEY = "donate_points_threshold";
local DONATE_POINTS_TO_ADD_KEY = "donate_points_to_add";

local SPONSORSHIP_MINUTES_THRESHOLD_KEY = "sponsorship_minutes_threshold";
local SPONSORSHIP_MINUTES_TO_ADD_KEY = "sponsorship_minutes_to_add";
local TWITCH_BITS_MINUTES_THRESHOLD_KEY = "twitch_bits_minutes_threshold";
local TWITCH_BITS_MINUTES_TO_ADD_KEY = "twitch_bits_minutes_to_add";
local DONATE_MINUTES_THRESHOLD_KEY = "donate_minutes_threshold";
local DONATE_MINUTES_TO_ADD_KEY = "donate_minutes_to_add";

local IS_DOUBLE_MODE_KEY = "is_double_mode";

--[[ ====================================================================== ]]--

local sponsorship_points_threshold = 1;
local sponsorship_points_to_add = 1;
local twitch_bits_points_threshold = 100;
local twitch_bits_points_to_add = 1;
local donate_points_threshold = 7;
local donate_points_to_add = 1;

local sponsorship_minutes_threshold = 1;
local sponsorship_minutes_to_add = 5;
local twitch_bits_minutes_threshold = 100;
local twitch_bits_minutes_to_add = 7;
local donate_minutes_threshold = 1;
local donate_minutes_to_add = 1;

local is_double_mode = false;

--[[ ====================================================================== ]]--

local total_points = 0;
local points_queue = {};
local is_processing_points_queue = false;
local function flush_points_queue()
    if is_processing_points_queue then
        return;
    end

    is_processing_points_queue = true;

    while #points_queue > 0 do
        local points_to_add = table.remove(points_queue, 1);
        total_points = total_points + points_to_add;
        UniChatAPI:set_userstore_item(POINTS_KEY, tostring(total_points));
        logger:info("Added {} points to donathon timer. Total points: {}", points_to_add, total_points);
    end

    is_processing_points_queue = false;
end

--[[ ====================================================================== ]]--

local total_seconds = 0;
local seconds_queue = {};
local is_processing_seconds_queue = false;
local function flush_seconds_queue()
    if is_processing_seconds_queue then
        return;
    end

    is_processing_seconds_queue = true;

    while #seconds_queue > 0 do
        local seconds_to_add = table.remove(seconds_queue, 1);
        total_seconds = total_seconds + seconds_to_add;
        UniChatAPI:set_userstore_item(SECONDS_KEY, tostring(total_seconds));
        logger:info("Added {} seconds to donathon timer. Total seconds: {}", seconds_to_add, total_seconds);
    end

    is_processing_seconds_queue = false;
end

--[[ ====================================================================== ]]--

---@param event UniChatEvent
local function on_event(event)
    local seconds = 0;
    local points = 0;

    if event.type == "unichat:donate" then
        ---@type UniChatDonateEventPayload
        local data = event.data;

        if data.platform == "twitch" then
            points = math.floor(data.value / twitch_bits_points_threshold) * twitch_bits_points_to_add;
            seconds = math.floor(data.value / twitch_bits_minutes_threshold) * twitch_bits_minutes_to_add * 60;
        elseif data.platform == "youtube" then
            points = math.floor(data.value / donate_points_threshold) * donate_points_to_add;
            seconds = math.floor(data.value / donate_minutes_threshold) * donate_minutes_to_add * 60;
        end
    elseif event.type == "unichat:sponsor" then
        ---@type UniChatSponsorEventPayload
        local data = event.data;

        points = math.floor(1 / sponsorship_points_threshold) * sponsorship_points_to_add;
        seconds = math.floor(1 / sponsorship_minutes_threshold) * sponsorship_minutes_to_add * 60;
    elseif event.type == "unichat:sponsor_gift" then
        ---@type UniChatSponsorGiftEventPayload
        local data = event.data;

        points = math.floor(data.count / sponsorship_points_threshold) * sponsorship_points_to_add;
        seconds = math.floor(data.count / sponsorship_minutes_threshold) * sponsorship_minutes_to_add * 60;
    elseif event.type == "unichat:message" then
        ---@type UniChatMessageEventPayload
        local data = event.data;

        if data.authorType == "MODERATOR" or data.authorType == "BROADCASTER" then
            local args = strings:split(data.messageText, " ");

            if args[1] == "!donathon" then
                local cmd = args[2];

                if cmd == "begin" and data.authorType == "BROADCASTER" then
                    if UniChatAPI:get_userstore_item(STATUS_KEY) ~= STOPPED_STATUS then
                        UniChatAPI:notify("Donathon timer is already running. Please reset it before starting a new one.");
                        return;
                    end

                    points = 0;
                    seconds = 3 * 60 * 60;
                    UniChatAPI:set_userstore_item(POINTS_KEY, "0");
                    UniChatAPI:set_userstore_item(STARTED_AT_KEY, tostring(time:now()));
                    UniChatAPI:set_userstore_item(STATUS_KEY, RUNNING_STATUS);
                    UniChatAPI:notify("Donathon timer started with 3 hours!");
                elseif cmd == "reset" and data.authorType == "BROADCASTER" then
                    UniChatAPI:set_userstore_item(POINTS_KEY, nil);
                    UniChatAPI:set_userstore_item(SECONDS_KEY, nil);
                    UniChatAPI:set_userstore_item(STARTED_AT_KEY, nil);
                    UniChatAPI:set_userstore_item(PAUSE_KEY, nil);
                    UniChatAPI:set_userstore_item(STATUS_KEY, STOPPED_STATUS);
                    total_points = 0;
                    total_seconds = 0;
                    UniChatAPI:notify("Donathon timer reset.");
                    return;
                elseif cmd == "pause" then
                    UniChatAPI:set_userstore_item(PAUSE_KEY, tostring(time:now()));
                    UniChatAPI:set_userstore_item(STATUS_KEY, PAUSED_STATUS);
                    UniChatAPI:notify("Donathon timer paused.");
                    return;
                elseif cmd == "resume" then
                    local now_timestamp = time:now();
                    local pause_timestamp_str = UniChatAPI:get_userstore_item(PAUSE_KEY);
                    local pause_timestamp = math.tointeger(pause_timestamp_str);
                    if pause_timestamp_str == nil or pause_timestamp == nil then
                        UniChatAPI:notify("Donathon timer is not paused.");
                        return;
                    end

                    local ms_gap = now_timestamp - pause_timestamp;
                    local seconds_paused = math.floor(ms_gap / 1000);
                    seconds = seconds_paused;

                    UniChatAPI:set_userstore_item(STATUS_KEY, RUNNING_STATUS);
                    UniChatAPI:notify("Donathon timer resumed.");
                elseif cmd == "double" then
                    if is_double_mode then
                        is_double_mode = false;
                        sponsorship_minutes_to_add = sponsorship_minutes_to_add / 2;
                        twitch_bits_minutes_to_add = twitch_bits_minutes_to_add / 2;
                        donate_minutes_to_add = donate_minutes_to_add / 2;
                        UniChatAPI:notify("Donathon timer double mode disabled.");
                    else
                        is_double_mode = true;
                        sponsorship_minutes_to_add = sponsorship_minutes_to_add * 2;
                        twitch_bits_minutes_to_add = twitch_bits_minutes_to_add * 2;
                        donate_minutes_to_add = donate_minutes_to_add * 2;
                        UniChatAPI:notify("Donathon timer double mode enabled.");
                    end

                    UniChatAPI:set_userstore_item(SPONSORSHIP_MINUTES_TO_ADD_KEY, tostring(sponsorship_minutes_to_add));
                    UniChatAPI:set_userstore_item(TWITCH_BITS_MINUTES_TO_ADD_KEY, tostring(twitch_bits_minutes_to_add));
                    UniChatAPI:set_userstore_item(DONATE_MINUTES_TO_ADD_KEY, tostring(donate_minutes_to_add));
                    UniChatAPI:set_userstore_item(IS_DOUBLE_MODE_KEY, tostring(is_double_mode));

                    return;
                elseif cmd == "set" then
                    local sub_cmd = args[3];                    
                    if sub_cmd == nil or strings:is_empty(sub_cmd) then
                        UniChatAPI:notify("Invalid set command. Usage: !donathon set <element> <value>");
                        return;
                    end

                    local value = math.tointeger(args[4]);
                    if value == nil or value < 0 then
                        UniChatAPI:notify("Invalid value. Usage: !donathon set <element> <value>");
                        return;
                    end

                    if sub_cmd == "sponsorship_points_threshold" or sub_cmd == "spt" then
                        sponsorship_points_threshold = value;
                        UniChatAPI:set_userstore_item(SPONSORSHIP_POINTS_THRESHOLD_KEY, tostring(sponsorship_points_threshold));
                        UniChatAPI:notify("Sponsorship points threshold set to " .. tostring(sponsorship_points_threshold) .. ".");
                        return;
                    elseif sub_cmd == "sponsorship_points_to_add" or sub_cmd == "spta" then
                        sponsorship_points_to_add = value;
                        UniChatAPI:set_userstore_item(SPONSORSHIP_POINTS_TO_ADD_KEY, tostring(sponsorship_points_to_add));
                        UniChatAPI:notify("Sponsorship points to add set to " .. tostring(sponsorship_points_to_add) .. ".");
                        return;

                    elseif sub_cmd == "twitch_bits_points_threshold" or sub_cmd == "tbpt" then
                        twitch_bits_points_threshold = value;
                        UniChatAPI:set_userstore_item(TWITCH_BITS_POINTS_THRESHOLD_KEY, tostring(twitch_bits_points_threshold));
                        UniChatAPI:notify("Twitch bits points threshold set to " .. tostring(twitch_bits_points_threshold) .. ".");
                        return;
                    elseif sub_cmd == "twitch_bits_points_to_add" or sub_cmd == "tbpta" then
                        twitch_bits_points_to_add = value;
                        UniChatAPI:set_userstore_item(TWITCH_BITS_POINTS_TO_ADD_KEY, tostring(twitch_bits_points_to_add));
                        UniChatAPI:notify("Twitch bits points to add set to " .. tostring(twitch_bits_points_to_add) .. ".");
                        return;

                    elseif sub_cmd == "donate_points_threshold" or sub_cmd == "dpt" then
                        donate_points_threshold = value;
                        UniChatAPI:set_userstore_item(DONATE_POINTS_THRESHOLD_KEY, tostring(donate_points_threshold));
                        UniChatAPI:notify("Donate points threshold set to " .. tostring(donate_points_threshold) .. ".");
                        return;
                    elseif sub_cmd == "donate_points_to_add" or sub_cmd == "dpta" then
                        donate_points_to_add = value;
                        UniChatAPI:set_userstore_item(DONATE_POINTS_TO_ADD_KEY, tostring(donate_points_to_add));
                        UniChatAPI:notify("Donate points to add set to " .. tostring(donate_points_to_add) .. ".");
                        return;

                    elseif sub_cmd == "sponsorship_minutes_threshold" or sub_cmd == "smt" then
                        sponsorship_minutes_threshold = value;
                        UniChatAPI:set_userstore_item(SPONSORSHIP_MINUTES_THRESHOLD_KEY, tostring(sponsorship_minutes_threshold));
                        UniChatAPI:notify("Sponsorship minutes threshold set to " .. tostring(sponsorship_minutes_threshold) .. ".");
                        return;
                    elseif sub_cmd == "sponsorship_minutes_to_add" or sub_cmd == "smta" then
                        sponsorship_minutes_to_add = value;
                        UniChatAPI:set_userstore_item(SPONSORSHIP_MINUTES_TO_ADD_KEY, tostring(sponsorship_minutes_to_add));
                        UniChatAPI:notify("Sponsorship minutes to add set to " .. tostring(sponsorship_minutes_to_add) .. ".");
                        return;

                    elseif sub_cmd == "twitch_bits_minutes_threshold" or sub_cmd == "tbmt" then
                        twitch_bits_minutes_threshold = value;
                        UniChatAPI:set_userstore_item(TWITCH_BITS_MINUTES_THRESHOLD_KEY, tostring(twitch_bits_minutes_threshold));
                        UniChatAPI:notify("Twitch bits minutes threshold set to " .. tostring(twitch_bits_minutes_threshold) .. ".");
                        return;
                    elseif sub_cmd == "twitch_bits_minutes_to_add" or sub_cmd == "tbmta" then
                        twitch_bits_minutes_to_add = value;
                        UniChatAPI:set_userstore_item(TWITCH_BITS_MINUTES_TO_ADD_KEY, tostring(twitch_bits_minutes_to_add));
                        UniChatAPI:notify("Twitch bits minutes to add set to " .. tostring(twitch_bits_minutes_to_add) .. ".");
                        return;

                    elseif sub_cmd == "donate_minutes_threshold" or sub_cmd == "dmt" then
                        donate_minutes_threshold = value;
                        UniChatAPI:set_userstore_item(DONATE_MINUTES_THRESHOLD_KEY, tostring(donate_minutes_threshold));
                        UniChatAPI:notify("Donate minutes threshold set to " .. tostring(donate_minutes_threshold) .. ".");
                        return;
                    elseif sub_cmd == "donate_minutes_to_add" or sub_cmd == "dmta" then
                        donate_minutes_to_add = value;
                        UniChatAPI:set_userstore_item(DONATE_MINUTES_TO_ADD_KEY, tostring(donate_minutes_to_add));
                        UniChatAPI:notify("Donate minutes to add set to " .. tostring(donate_minutes_to_add) .. ".");
                        return;
                    end
                    
                    UniChatAPI:notify("Unknown set command. Usage: !donathon set <element> <value>");
                    return;
                elseif cmd == "addpoints" then
                    local additional_points = math.tointeger(args[3]);
                    if additional_points == nil or additional_points <= 0 then
                        UniChatAPI:notify("Invalid points amount. Usage: !donathon addpoints <points>");
                        return;
                    end

                    points = additional_points;
                elseif cmd == "addseconds" then
                    local additional_seconds = math.tointeger(args[3]);
                    if additional_seconds == nil or additional_seconds <= 0 then
                        UniChatAPI:notify("Invalid seconds amount. Usage: !donathon addseconds <seconds>");
                        return;
                    end

                    seconds = additional_seconds;
                elseif cmd == "addminutes" then
                    local additional_minutes = math.tointeger(args[3]);
                    if additional_minutes == nil or additional_minutes <= 0 then
                        UniChatAPI:notify("Invalid minutes amount. Usage: !donathon addminutes <minutes>");
                        return;
                    end

                    seconds = additional_minutes * 60;
                else
                    UniChatAPI:notify("Unknown donathon command.");
                    return;
                end
            end
        end
    end

    if points > 0 then
        table.insert(points_queue, points);
        flush_points_queue();
    end

    if seconds > 0 then
        table.insert(seconds_queue, seconds);
        flush_seconds_queue();
    end
end

--[[ ====================================================================== ]]--

local stored_sponsorship_points_threshold = UniChatAPI:get_userstore_item(SPONSORSHIP_POINTS_THRESHOLD_KEY);
if stored_sponsorship_points_threshold ~= nil then
    sponsorship_points_threshold = math.tointeger(stored_sponsorship_points_threshold) or sponsorship_points_threshold;
end

local stored_sponsorship_points_to_add = UniChatAPI:get_userstore_item(SPONSORSHIP_POINTS_TO_ADD_KEY);
if stored_sponsorship_points_to_add ~= nil then
    sponsorship_points_to_add = math.tointeger(stored_sponsorship_points_to_add) or sponsorship_points_to_add;
end

local stored_twitch_bits_points_threshold = UniChatAPI:get_userstore_item(TWITCH_BITS_POINTS_THRESHOLD_KEY);
if stored_twitch_bits_points_threshold ~= nil then
    twitch_bits_points_threshold = math.tointeger(stored_twitch_bits_points_threshold) or twitch_bits_points_threshold;
end

local stored_twitch_bits_points_to_add = UniChatAPI:get_userstore_item(TWITCH_BITS_POINTS_TO_ADD_KEY);
if stored_twitch_bits_points_to_add ~= nil then
    twitch_bits_points_to_add = math.tointeger(stored_twitch_bits_points_to_add) or twitch_bits_points_to_add;
end

local stored_donate_points_threshold = UniChatAPI:get_userstore_item(DONATE_POINTS_THRESHOLD_KEY);;
if stored_donate_points_threshold ~= nil then
    donate_points_threshold = math.tointeger(stored_donate_points_threshold) or donate_points_threshold;
end

local stored_donate_points_to_add = UniChatAPI:get_userstore_item(DONATE_POINTS_TO_ADD_KEY);
if stored_donate_points_to_add ~= nil then
    donate_points_to_add = math.tointeger(stored_donate_points_to_add) or donate_points_to_add;
end

--[[ ====================================================================== ]]--

local stored_sponsorship_minutes_threshold = UniChatAPI:get_userstore_item(SPONSORSHIP_MINUTES_THRESHOLD_KEY);
if stored_sponsorship_minutes_threshold ~= nil then
    sponsorship_minutes_threshold = math.tointeger(stored_sponsorship_minutes_threshold) or sponsorship_minutes_threshold;
end

local stored_sponsorship_minutes_to_add = UniChatAPI:get_userstore_item(SPONSORSHIP_MINUTES_TO_ADD_KEY);
if stored_sponsorship_minutes_to_add ~= nil then
    sponsorship_minutes_to_add = math.tointeger(stored_sponsorship_minutes_to_add) or sponsorship_minutes_to_add;
end

local stored_twitch_bits_minutes_threshold = UniChatAPI:get_userstore_item(TWITCH_BITS_MINUTES_THRESHOLD_KEY);
if stored_twitch_bits_minutes_threshold ~= nil then
    twitch_bits_minutes_threshold = math.tointeger(stored_twitch_bits_minutes_threshold) or twitch_bits_minutes_threshold;
end

local stored_twitch_bits_minutes_to_add = UniChatAPI:get_userstore_item(TWITCH_BITS_MINUTES_TO_ADD_KEY);
if stored_twitch_bits_minutes_to_add ~= nil then
    twitch_bits_minutes_to_add = math.tointeger(stored_twitch_bits_minutes_to_add) or twitch_bits_minutes_to_add;
end

local stored_donate_minutes_threshold = UniChatAPI:get_userstore_item(DONATE_MINUTES_THRESHOLD_KEY);
if stored_donate_minutes_threshold ~= nil then
    donate_minutes_threshold = math.tointeger(stored_donate_minutes_threshold) or donate_minutes_threshold;
end

local stored_donate_minutes_to_add = UniChatAPI:get_userstore_item(DONATE_MINUTES_TO_ADD_KEY);
if stored_donate_minutes_to_add ~= nil then
    donate_minutes_to_add = math.tointeger(stored_donate_minutes_to_add) or donate_minutes_to_add;
end

--[[ ====================================================================== ]]--

local stored_is_double_mode = UniChatAPI:get_userstore_item(IS_DOUBLE_MODE_KEY);
if stored_is_double_mode == nil then
    is_double_mode = stored_is_double_mode == "true";
end

local stored_points = UniChatAPI:get_userstore_item(POINTS_KEY);
if stored_points ~= nil then
    total_points = math.tointeger(stored_points) or 0;
end

local stored_seconds = UniChatAPI:get_userstore_item(SECONDS_KEY);
if stored_seconds ~= nil then
    total_seconds = math.tointeger(stored_seconds) or 0;
end

local stored_status = UniChatAPI:get_userstore_item(STATUS_KEY);
if stored_status ~= STOPPED_STATUS and stored_status ~= PAUSED_STATUS then
    UniChatAPI:set_userstore_item(STATUS_KEY, STOPPED_STATUS);
end
UniChatAPI:add_event_listener(on_event);

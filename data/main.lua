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
local MINUTES_KEY = "minutes";
local STARTED_AT_KEY = "started_at";
local PAUSE_KEY = "pause_timestamp";
local RUNNING_STATUS = "RUNNING";
local PAUSED_STATUS = "PAUSED";
local STOPPED_STATUS = "STOPPED";

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

local total_minutes = 0;
local minutes_queue = {};
local is_processing_minutes_queue = false;
local function flush_minutes_queue()
    if is_processing_minutes_queue then
        return;
    end

    is_processing_minutes_queue = true;

    while #minutes_queue > 0 do
        local minutes_to_add = table.remove(minutes_queue, 1);
        total_minutes = total_minutes + minutes_to_add;
        UniChatAPI:set_userstore_item(MINUTES_KEY, tostring(total_minutes));
        logger:info("Added {} minutes to donathon timer. Total minutes: {}", minutes_to_add, total_minutes);
    end

    is_processing_minutes_queue = false;
end

--[[ ====================================================================== ]]--

---@param event UniChatEvent
local function on_event(event)
    local minutes = 0;
    local points = 0;

    if event.type == "unichat:donate" then
        ---@type UniChatDonateEventPayload
        local data = event.data;

        if data.platform == "twitch" then
            -- 100 bits = 1 point
            points = math.floor(data.value / 100);
            minutes = math.floor(points * 7);
        elseif data.platform == "youtube" then
            points = math.floor(data.value);
            minutes = math.floor(points * 7);
        end
    elseif event.type == "unichat:sponsor" then
        ---@type UniChatSponsorEventPayload
        local data = event.data;

        points = 1;
        minutes = 7;
    elseif event.type == "unichat:sponsor_gift" then
        ---@type UniChatSponsorGiftEventPayload
        local data = event.data;

        points = data.count;
        minutes = data.count * 7;
    elseif event.type == "unichat:message" then
        ---@type UniChatMessageEventPayload
        local data = event.data;

        if data.authorType == "MODERATOR" or data.authorType == "BROADCASTER" then
            local args = strings:split(data.messageText, " ");

            if args[1] == "!donathon" then
                local cmd = args[2];

                if cmd == "begin" then
                    if UniChatAPI:get_userstore_item(STATUS_KEY) ~= STOPPED_STATUS then
                        UniChatAPI:notify("Donathon timer is already running. Please reset it before starting a new one.");
                        return;
                    end

                    points = 0;
                    minutes = 60 * 3;
                    UniChatAPI:set_userstore_item(POINTS_KEY, "0");
                    UniChatAPI:set_userstore_item(STARTED_AT_KEY, tostring(time:now()));
                    UniChatAPI:set_userstore_item(STATUS_KEY, RUNNING_STATUS);
                    UniChatAPI:notify("Donathon timer started with 3 hours!");
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
                    local minutes_paused = math.floor(ms_gap / 60000);
                    minutes = minutes_paused;

                    UniChatAPI:set_userstore_item(STATUS_KEY, RUNNING_STATUS);
                    UniChatAPI:notify("Donathon timer resumed.");
                elseif cmd == "reset" then
                    UniChatAPI:set_userstore_item(POINTS_KEY, nil);
                    UniChatAPI:set_userstore_item(MINUTES_KEY, nil);
                    UniChatAPI:set_userstore_item(STARTED_AT_KEY, nil);
                    UniChatAPI:set_userstore_item(PAUSE_KEY, nil);
                    UniChatAPI:set_userstore_item(STATUS_KEY, STOPPED_STATUS);
                    total_points = 0;
                    total_minutes = 0;
                    UniChatAPI:notify("Donathon timer reset.");
                    return;
                elseif cmd == "addpoints" then
                    local additional_points = math.tointeger(args[3]);
                    if additional_points == nil or additional_points <= 0 then
                        UniChatAPI:notify("Invalid points amount. Usage: !donathon addpoints <points>");
                        return;
                    end

                    points = additional_points;
                elseif cmd == "addminutes" then
                    local additional_minutes = math.tointeger(args[3]);
                    if additional_minutes == nil or additional_minutes <= 0 then
                        UniChatAPI:notify("Invalid minutes amount. Usage: !donathon addminutes <minutes>");
                        return;
                    end

                    minutes = additional_minutes;
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

    if minutes > 0 then
        table.insert(minutes_queue, minutes);
        flush_minutes_queue();
    end
end

local stored_points = UniChatAPI:get_userstore_item(POINTS_KEY);
if stored_points ~= nil then
    total_points = math.tointeger(stored_points) or 0;
end

local stored_minutes = UniChatAPI:get_userstore_item(MINUTES_KEY);
if stored_minutes ~= nil then
    total_minutes = math.tointeger(stored_minutes) or 0;
end

local stored_status = UniChatAPI:get_userstore_item(STATUS_KEY);
if stored_status ~= STOPPED_STATUS and stored_status ~= PAUSED_STATUS then
    UniChatAPI:set_userstore_item(STATUS_KEY, STOPPED_STATUS);
end
UniChatAPI:add_event_listener(on_event);

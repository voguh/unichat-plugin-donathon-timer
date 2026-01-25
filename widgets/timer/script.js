/*!******************************************************************************
 * Copyright (c) 2025 Voguh
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ******************************************************************************/

/* <<==== FIELDS TO JS VARIABLES ====>> */
const POINTS_LABEL = "{{pointsLabel}}";

const TWITCH_DONATE_MESSAGE = "{{twitchDonateMessage}}";
const GENERIC_DONATE_MESSAGE = "{{genericDonateMessage}}";

const TWITCH_SPONSORSHIP_MESSAGE = "{{twitchSponsorshipMessage}}";
const YOUTUBE_SPONSORSHIP_MESSAGE = "{{youtubeSponsorshipMessage}}";
const GENERIC_SPONSORSHIP_MESSAGE = "{{genericSponsorshipMessage}}";

const TWITCH_SPONSORGIFT_MESSAGE = "{{twitchSponsorGiftMessage}}";
const YOUTUBE_SPONSORGIFT_MESSAGE = "{{youtubeSponsorGiftMessage}}";
const GENERIC_SPONSORGIFT_MESSAGE = "{{genericSponsorGiftMessage}}";
/* <<== END FIELDS TO JS VARIABLES ==>> */

const STATUS_KEY = "plugin-donathon-timer:status";
const POINTS_KEY = "plugin-donathon-timer:points";
const SECONDS_KEY = "plugin-donathon-timer:seconds";
const STARTED_AT_KEY = "plugin-donathon-timer:started_at";
const PAUSE_KEY = "plugin-donathon-timer:pause_timestamp";
const RUNNING_STATUS = "RUNNING";
const PAUSED_STATUS = "PAUSED";
const STOPPED_STATUS = "STOPPED";

let totalPoints = 0;
let totalSeconds = 0;
let startedAt = null;
let pausedAt = null;
let timerInterval = null;
let timerStatus = STOPPED_STATUS;
/** @type {string} */
const NOTIFICATION_QUEUE = [];
let isProcessingQueue = false;

/* ========================================================================== */

const STATUS_ELEMENT = document.querySelector("#main-container > .counter > .status");
const TIMER_ELEMENT = document.querySelector("#main-container > .counter > .timer");
const POINTS_ELEMENT = document.querySelector("#main-container > .counter > .points");
const NOTIFICATION_ELEMENT = document.querySelector("#main-container > .notification");

/* ========================================================================== */

function parseTierName(platform, tier) {
    if (platform === "twitch" && tier.toLowerCase() !== "prime") {
        return parseInt(tier, 10) / 1000
    }

    return tier || "sponsorship";
}

function enrichMessage(text, data) {
    let enrichedText = text;

    for (const [rawKey, value] of Object.entries(data)) {
        const key = `{${rawKey}}`;
        const snakeKey = key.replace(/([A-Z])/g, "_$1").toLowerCase();

        if (rawKey === "tier") {
            enrichedText = enrichedText.replaceAll(key, parseTierName(data.platform, value));
            enrichedText = enrichedText.replaceAll(snakeKey, parseTierName(data.platform, value));
        } else {
            enrichedText = enrichedText.replaceAll(key, value);
            enrichedText = enrichedText.replaceAll(snakeKey, value);
        }
    }

    return enrichedText;
}

/* ========================================================================== */

async function processEventQueue() {
    if (isProcessingQueue) {
        return;
    }

    isProcessingQueue = true;
    while (NOTIFICATION_QUEUE.length > 0) {
        const message = NOTIFICATION_QUEUE.shift();

        NOTIFICATION_ELEMENT.innerHTML = message;
        NOTIFICATION_ELEMENT.classList.add("notify");
        await new Promise(resolve => setTimeout(resolve, 2251));

        NOTIFICATION_ELEMENT.classList.remove("notify");
        await new Promise(resolve => setTimeout(resolve, 250));
    }
    isProcessingQueue = false;
}

function processTimerTick() {
    const now = timerStatus == PAUSED_STATUS ? pausedAt : Date.now();
    const elapsed_ms = now - (startedAt || now);
    const remaining_ms = totalSeconds * 1000 - elapsed_ms;
    let status = timerStatus;
    if (status == RUNNING_STATUS && remaining_ms <= 0) {
        status = STOPPED_STATUS;
    }

    if ([RUNNING_STATUS, PAUSED_STATUS].includes(status)) {
        const display_hours = Math.floor(remaining_ms / 3600000).toString().padStart(2, '0');
        const display_minutes = Math.floor((remaining_ms % 3600000) / 60000).toString().padStart(2, '0');
        const display_seconds = Math.floor((remaining_ms % 60000) / 1000).toString().padStart(2, '0');
        
        STATUS_ELEMENT.innerHTML = status === RUNNING_STATUS ? '<i class="fas fa-play"></i>' : '<i class="fas fa-pause"></i>';
        TIMER_ELEMENT.textContent = `${display_hours}:${display_minutes}:${display_seconds}`;
        POINTS_ELEMENT.textContent = `${totalPoints} ${POINTS_LABEL}`;
    } else if (status === STOPPED_STATUS) {
        STATUS_ELEMENT.innerHTML = '<i class="fas fa-stop"></i>';
        TIMER_ELEMENT.textContent = "00:00:00";
        POINTS_ELEMENT.textContent = `${totalPoints} ${POINTS_LABEL}`;
    }
}

/* ========================================================================== */

window.addEventListener("unichat:connected", function ({ detail: { userstore } }) {
    globalThis.UNICHAT_USERSTORE = userstore;

    totalPoints = parseInt(userstore[POINTS_KEY]|| "0", 10);
    totalSeconds = parseInt(userstore[SECONDS_KEY]|| "0", 10);
    const started_timestamp = parseInt(userstore[STARTED_AT_KEY] || "0", 10);
    startedAt = started_timestamp > 0 ? started_timestamp : null;
    timerStatus = userstore[STATUS_KEY] || STOPPED_STATUS;
    const paused_timestamp = parseInt(userstore[PAUSE_KEY] || "0", 10);
    pausedAt = paused_timestamp > 0 ? paused_timestamp : null;

    if (timerInterval != null) {
        clearInterval(timerInterval);
    }
    timerInterval = setInterval(processTimerTick, 1000);
    processTimerTick();
});

window.addEventListener("unichat:event", function ({ detail: event }) {
    // Handle custom events sent from the server via websocket

    if (event.type === "unichat:donate") {
        /** @type {import("../unichat").UniChatEventDonate['data']} */
        const data = event.data;

        if (data.platform === "twitch") {
            NOTIFICATION_QUEUE.push(enrichMessage(TWITCH_DONATE_MESSAGE, data));
        } else {
            NOTIFICATION_QUEUE.push(enrichMessage(GENERIC_DONATE_MESSAGE, data));
        }
    } else if (event.type === "unichat:sponsor") {
        /** @type {import("../unichat").UniChatEventSponsor['data']} */
        const data = event.data;

        if (data.platform === "twitch") {
            NOTIFICATION_QUEUE.push(enrichMessage(TWITCH_SPONSORSHIP_MESSAGE, data));
        } else if (data.platform === "youtube") {
            NOTIFICATION_QUEUE.push(enrichMessage(YOUTUBE_SPONSORSHIP_MESSAGE, data));
        } else {
            NOTIFICATION_QUEUE.push(enrichMessage(GENERIC_SPONSORSHIP_MESSAGE, data));
        }
    } else if (event.type === "unichat:sponsor_gift") {
        /** @type {import("../unichat").UniChatEventSponsorGift['data']} */
        const data = event.data;

        if (data.platform === "twitch") {
            NOTIFICATION_QUEUE.push(enrichMessage(TWITCH_SPONSORGIFT_MESSAGE, data));
        } else if (data.platform === "youtube") {
            NOTIFICATION_QUEUE.push(enrichMessage(YOUTUBE_SPONSORGIFT_MESSAGE, data));
        } else {
            NOTIFICATION_QUEUE.push(enrichMessage(GENERIC_SPONSORGIFT_MESSAGE, data));
        }
    }

    requestAnimationFrame(processEventQueue);
});

window.addEventListener("unichat:userstore_update", function ({ detail: { key, value } }) {
    if (key === POINTS_KEY) {
        totalPoints = parseInt(value || "0", 10);
    } else if (key === SECONDS_KEY) {
        totalSeconds = parseInt(value || "0", 10);
    } else if (key === STARTED_AT_KEY) {
        const started_timestamp = parseInt(value || "0", 10);
        startedAt = started_timestamp > 0 ? started_timestamp : null;
    } else if (key === PAUSE_KEY) {
        const paused_timestamp = parseInt(value || "0", 10);
        pausedAt = paused_timestamp > 0 ? paused_timestamp : null;
    } else if (key === STATUS_KEY) {
        timerStatus = value || STOPPED_STATUS;

        if ([RUNNING_STATUS, PAUSED_STATUS].includes(value)) {
            if (timerInterval == null) {
                timerInterval = setInterval(processTimerTick, 1000);
                processTimerTick();
            }
        } else if (value === STOPPED_STATUS) {
            totalPoints = 0;
            totalSeconds = 0;
            startedAt = null;
            pausedAt = null;
            if (timerInterval != null) {
                clearInterval(timerInterval);
                timerInterval = null;
            }

            processTimerTick();
        }
    }
});

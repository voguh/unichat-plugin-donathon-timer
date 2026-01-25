/*!******************************************************************************
 * Copyright (c) 2025 Voguh
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ******************************************************************************/

const SPONSORSHIP_POINTS_THRESHOLD_KEY = "plugin-donathon-timer:sponsorship_points_threshold";
const SPONSORSHIP_POINTS_TO_ADD_KEY = "plugin-donathon-timer:sponsorship_points_to_add";
const TWITCH_BITS_POINTS_THRESHOLD_KEY = "plugin-donathon-timer:twitch_bits_points_threshold";
const TWITCH_BITS_POINTS_TO_ADD_KEY = "plugin-donathon-timer:twitch_bits_points_to_add";
const DONATE_POINTS_THRESHOLD_KEY = "plugin-donathon-timer:donate_points_threshold";
const DONATE_POINTS_TO_ADD_KEY = "plugin-donathon-timer:donate_points_to_add";

const SPONSORSHIP_MINUTES_THRESHOLD_KEY = "plugin-donathon-timer:sponsorship_minutes_threshold";
const SPONSORSHIP_MINUTES_TO_ADD_KEY = "plugin-donathon-timer:sponsorship_minutes_to_add";
const TWITCH_BITS_MINUTES_THRESHOLD_KEY = "plugin-donathon-timer:twitch_bits_minutes_threshold";
const TWITCH_BITS_MINUTES_TO_ADD_KEY = "plugin-donathon-timer:twitch_bits_minutes_to_add";
const DONATE_MINUTES_THRESHOLD_KEY = "plugin-donathon-timer:donate_minutes_threshold";
const DONATE_MINUTES_TO_ADD_KEY = "plugin-donathon-timer:donate_minutes_to_add";

const STATUS_KEY = "plugin-donathon-timer:status";
const POINTS_KEY = "plugin-donathon-timer:points";
const SECONDS_KEY = "plugin-donathon-timer:seconds";
const IS_DOUBLE_MODE_KEY = "plugin-donathon-timer:is_double_mode";

const RUNNING_STATUS = "RUNNING";
const PAUSED_STATUS = "PAUSED";
const STOPPED_STATUS = "STOPPED";
const STATUS_ICON_MAP = {
    [RUNNING_STATUS]: '<i class="fas fa-play"></i>',
    [PAUSED_STATUS]: '<i class="fas fa-pause"></i>',
    [STOPPED_STATUS]: '<i class="fas fa-stop"></i>'
}

/* ========================================================================== */

const MAIN_CONTAINER = document.querySelector("#main-container");

let sponsorshipPointsThreshold = 1;
let sponsorshipPointsToAdd = 1;
let twitchBitsPointsThreshold = 100;
let twitchBitsPointsToAdd = 1;
let donatePointsThreshold = 7;
let donatePointsToAdd = 1;

let sponsorshipMinutesThreshold = 1;
let sponsorshipMinutesToAdd = 5;
let twitchBitsMinutesThreshold = 100;
let twitchBitsMinutesToAdd = 7;
let donateMinutesThreshold = 1;
let donateMinutesToAdd = 1;

let timerStatus = STOPPED_STATUS;
let totalPoints = 0;
let totalSeconds = 0;
let isDoubleMode = false;

/* ========================================================================== */

function secondsToHMS(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    const hoursStr = hours.toString().padStart(2, '0');
    const minutesStr = minutes.toString().padStart(2, '0');
    const secondsStr = seconds.toString().padStart(2, '0');

    return `${hoursStr}:${minutesStr}:${secondsStr}`;
}

function buildLabelWithValue(labelText, valueText) {
    const container = document.createElement("div");

    const label = document.createElement("span");
    label.classList.add("label");
    label.textContent = labelText;
    container.appendChild(label);

    const value = document.createElement("span");
    value.classList.add("value");
    value.textContent = valueText;
    container.appendChild(value);

    return container;
}

function updateDisplay() {
    const displayContainer = document.createElement("div");
    displayContainer.classList.add("display");

    displayContainer.appendChild(buildLabelWithValue("Sponsorship Points Threshold", sponsorshipPointsThreshold));
    displayContainer.appendChild(buildLabelWithValue("Sponsorship Points To Add", sponsorshipPointsToAdd));
    displayContainer.appendChild(buildLabelWithValue("Twitch Bits Points Threshold", twitchBitsPointsThreshold));
    displayContainer.appendChild(buildLabelWithValue("Twitch Bits Points To Add", twitchBitsPointsToAdd));
    displayContainer.appendChild(buildLabelWithValue("Donate Points Threshold", donatePointsThreshold));
    displayContainer.appendChild(buildLabelWithValue("Donate Points To Add", donatePointsToAdd));
    displayContainer.appendChild(document.createElement("hr"));
    displayContainer.appendChild(buildLabelWithValue("Sponsorship Minutes Threshold", sponsorshipMinutesThreshold));
    displayContainer.appendChild(buildLabelWithValue("Sponsorship Minutes To Add", sponsorshipMinutesToAdd));
    displayContainer.appendChild(buildLabelWithValue("Twitch Bits Minutes Threshold", twitchBitsMinutesThreshold));
    displayContainer.appendChild(buildLabelWithValue("Twitch Bits Minutes To Add", twitchBitsMinutesToAdd));
    displayContainer.appendChild(buildLabelWithValue("Donate Minutes Threshold", donateMinutesThreshold));
    displayContainer.appendChild(buildLabelWithValue("Donate Minutes To Add", donateMinutesToAdd));
    displayContainer.appendChild(document.createElement("hr"));
    displayContainer.appendChild(buildLabelWithValue("Timer Status", timerStatus));
    displayContainer.appendChild(buildLabelWithValue("Total Points", totalPoints));
    displayContainer.appendChild(buildLabelWithValue("Total Time", secondsToHMS(totalSeconds)));
    displayContainer.appendChild(buildLabelWithValue("Double Mode", isDoubleMode ? "Enabled" : "Disabled"));

    MAIN_CONTAINER.replaceChildren(displayContainer);
}

function debouncedUpdateDisplay() {
    clearTimeout(debouncedUpdateDisplay.timeout);
    debouncedUpdateDisplay.timeout = setTimeout(updateDisplay, 100);
}

/* ========================================================================== */

window.addEventListener("unichat:connected", function ({ detail: { userstore } }) {
    globalThis.UNICHAT_USERSTORE = userstore;

    let storedSponsorshipPointsThreshold = parseInt(userstore[SPONSORSHIP_POINTS_THRESHOLD_KEY]);
    if (!Number.isNaN(storedSponsorshipPointsThreshold)) {
        sponsorshipPointsThreshold = storedSponsorshipPointsThreshold;
    }

    let storedSponsorshipPointsToAdd = parseInt(userstore[SPONSORSHIP_POINTS_TO_ADD_KEY]);
    if (!Number.isNaN(storedSponsorshipPointsToAdd)) {
        sponsorshipPointsToAdd = storedSponsorshipPointsToAdd;
    }
    
    let storedTwitchBitsPointsThreshold = parseInt(userstore[TWITCH_BITS_POINTS_THRESHOLD_KEY]);
    if (!Number.isNaN(storedTwitchBitsPointsThreshold)) {
        twitchBitsPointsThreshold = storedTwitchBitsPointsThreshold;
    }

    let storedTwitchBitsPointsToAdd = parseInt(userstore[TWITCH_BITS_POINTS_TO_ADD_KEY]);
    if (!Number.isNaN(storedTwitchBitsPointsToAdd)) {
        twitchBitsPointsToAdd = storedTwitchBitsPointsToAdd;
    }

    let storedDonatePointsThreshold = parseInt(userstore[DONATE_POINTS_THRESHOLD_KEY]);
    if (!Number.isNaN(storedDonatePointsThreshold)) {
        donatePointsThreshold = storedDonatePointsThreshold;
    }

    let storedDonatePointsToAdd = parseInt(userstore[DONATE_POINTS_TO_ADD_KEY]);
    if (!Number.isNaN(storedDonatePointsToAdd)) {
        donatePointsToAdd = storedDonatePointsToAdd;
    }

    /* ====================================================================== */

    let storedSponsorshipMinutesThreshold = parseInt(userstore[SPONSORSHIP_MINUTES_THRESHOLD_KEY]);
    if (!Number.isNaN(storedSponsorshipMinutesThreshold)) {
        sponsorshipMinutesThreshold = storedSponsorshipMinutesThreshold;
    }

    let storedSponsorshipMinutesToAdd = parseInt(userstore[SPONSORSHIP_MINUTES_TO_ADD_KEY]);
    if (!Number.isNaN(storedSponsorshipMinutesToAdd)) {
        sponsorshipMinutesToAdd = storedSponsorshipMinutesToAdd;
    }

    let storedTwitchBitsMinutesThreshold = parseInt(userstore[TWITCH_BITS_MINUTES_THRESHOLD_KEY]);
    if (!Number.isNaN(storedTwitchBitsMinutesThreshold)) {
        twitchBitsMinutesThreshold = storedTwitchBitsMinutesThreshold;
    }

    let storedTwitchBitsMinutesToAdd = parseInt(userstore[TWITCH_BITS_MINUTES_TO_ADD_KEY]);
    if (!Number.isNaN(storedTwitchBitsMinutesToAdd)) {
        twitchBitsMinutesToAdd = storedTwitchBitsMinutesToAdd;
    }

    let storedDonateMinutesThreshold = parseInt(userstore[DONATE_MINUTES_THRESHOLD_KEY]);
    if (!Number.isNaN(storedDonateMinutesThreshold)) {
        donateMinutesThreshold = storedDonateMinutesThreshold;
    }

    let storedDonateMinutesToAdd = parseInt(userstore[DONATE_MINUTES_TO_ADD_KEY]);
    if (!Number.isNaN(storedDonateMinutesToAdd)) {
        donateMinutesToAdd = storedDonateMinutesToAdd;
    }

    /* ====================================================================== */

    let storedTimerStatus = userstore[STATUS_KEY];
    if ([RUNNING_STATUS, PAUSED_STATUS, STOPPED_STATUS].includes(storedTimerStatus)) {
        timerStatus = storedTimerStatus;
    }

    let storedTotalPoints = parseInt(userstore[POINTS_KEY]);
    if (!Number.isNaN(storedTotalPoints)) {
        totalPoints = storedTotalPoints;
    }

    let storedTotalSeconds = parseInt(userstore[SECONDS_KEY]);
    if (!Number.isNaN(storedTotalSeconds)) {
        totalSeconds = storedTotalSeconds;
    }

    let storedIsDoubleMode = userstore[IS_DOUBLE_MODE_KEY];
    if (storedIsDoubleMode === "true" || storedIsDoubleMode === "false") {
        isDoubleMode = storedIsDoubleMode === "true";
    }

    requestAnimationFrame(debouncedUpdateDisplay);
});

window.addEventListener("unichat:event", function ({ detail: event }) {
    // Nothing...
});

window.addEventListener("unichat:userstore_update", function ({ detail: { key, value } }) {
    switch (key) {
        case SPONSORSHIP_POINTS_THRESHOLD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                sponsorshipPointsThreshold = parsedValue;
            }
            break;
        }
        case SPONSORSHIP_POINTS_TO_ADD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                sponsorshipPointsToAdd = parsedValue;
            }
            break;
        }

        /* ================================================================== */

        case TWITCH_BITS_POINTS_THRESHOLD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                twitchBitsPointsThreshold = parsedValue;
            }
            break;
        }
        case TWITCH_BITS_POINTS_TO_ADD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                twitchBitsPointsToAdd = parsedValue;
            }
            break;
        }

        /* ================================================================== */

        case DONATE_POINTS_THRESHOLD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                donatePointsThreshold = parsedValue;
            }
            break;
        }

        case DONATE_POINTS_TO_ADD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                donatePointsToAdd = parsedValue;
            }
            break;
        }

        /* ====================================================================================== */

        case SPONSORSHIP_MINUTES_THRESHOLD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                sponsorshipMinutesThreshold = parsedValue;
            }
            break;
        }
        case SPONSORSHIP_MINUTES_TO_ADD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                sponsorshipMinutesToAdd = parsedValue;
            }
            break;
        }

        /* ================================================================== */

        case TWITCH_BITS_MINUTES_THRESHOLD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                twitchBitsMinutesThreshold = parsedValue;
            }
            break;
        }
        case TWITCH_BITS_MINUTES_TO_ADD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                twitchBitsMinutesToAdd = parsedValue;
            }
            break;
        }

        /* ================================================================== */

        case DONATE_MINUTES_THRESHOLD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                donateMinutesThreshold = parsedValue;
            }
            break;
        }
        case DONATE_MINUTES_TO_ADD_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                donateMinutesToAdd = parsedValue;
            }
            break;
        }

        /* ====================================================================================== */

        case STATUS_KEY: {
            if ([RUNNING_STATUS, PAUSED_STATUS, STOPPED_STATUS].includes(value)) {
                timerStatus = value;
            }
            break;
        }

        case POINTS_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                totalPoints = parsedValue;
            }
            break;
        }

        case SECONDS_KEY: {
            let parsedValue = parseInt(value);
            if (!Number.isNaN(parsedValue)) {
                totalSeconds = parsedValue;
            }
            break;
        }

        case IS_DOUBLE_MODE_KEY: {
            if (value === "true" || value === "false") {
                isDoubleMode = value === "true";
            }
            break;
        }
    }

    requestAnimationFrame(debouncedUpdateDisplay);
});

-- ==========================================
-- CUBE PROTECTION SCRIPT
-- ArduCopter 4.5.1 / CubePilot
--
-- KBAA_CFG = 0 -> UNLOCK
-- KBAA_CFG = 1 -> LOCK WPNAV values
--
-- KBAA_SPD = locked WPNAV_SPEED
-- KBAA_ACL = locked WPNAV_ACCEL
-- KBAA_BAT = battery threshold
--
-- Battery <= KBAA_BAT + AUTO -> LOITER
-- GPS / RTK protection removed
-- ==========================================


-- ==========================================
-- KBAA PARAMETERS
-- ==========================================

local KBAA_TABLE_KEY = 120

assert(
    param:add_table(KBAA_TABLE_KEY, "KBAA_", 4),
    "KBAA: table failed"
)

assert(
    param:add_param(KBAA_TABLE_KEY, 1, "CFG", 0),
    "KBAA: CFG failed"
)

assert(
    param:add_param(KBAA_TABLE_KEY, 2, "SPD", 300),
    "KBAA: SPD failed"
)

assert(
    param:add_param(KBAA_TABLE_KEY, 3, "ACL", 180),
    "KBAA: ACL failed"
)

assert(
    param:add_param(KBAA_TABLE_KEY, 4, "BAT", 41.0),
    "KBAA: BAT failed"
)


local KBAA_CFG = Parameter()
local KBAA_SPD = Parameter()
local KBAA_ACL = Parameter()
local KBAA_BAT = Parameter()

assert(KBAA_CFG:init("KBAA_CFG"))
assert(KBAA_SPD:init("KBAA_SPD"))
assert(KBAA_ACL:init("KBAA_ACL"))
assert(KBAA_BAT:init("KBAA_BAT"))


-- ==========================================
-- WPNAV PARAMETERS
-- ==========================================

local WPNAV_SPEED = Parameter()
local WPNAV_ACCEL = Parameter()

assert(WPNAV_SPEED:init("WPNAV_SPEED"))
assert(WPNAV_ACCEL:init("WPNAV_ACCEL"))


-- ==========================================
-- BATTERY
-- ==========================================

local BATTERY_ID = 0

local AUTO = 3
local LOITER = 5


-- ==========================================
-- LOCK STATE
-- ==========================================

local previous_cfg = KBAA_CFG:get()


-- ==========================================
-- MAIN UPDATE
-- ==========================================

function update()


    -- ======================================
    -- BATTERY PROTECTION
    -- ======================================

    local voltage = battery:voltage(BATTERY_ID)

    if voltage ~= nil then

        local current_mode = vehicle:get_mode()
        local battery_limit = KBAA_BAT:get()

        -- Battery low + AUTO
        if voltage <= battery_limit
        and current_mode == AUTO then

            -- Force LOITER every time AUTO is selected

            if vehicle:set_mode(LOITER) then

                gcs:send_text(
                    4,
                    string.format(
                        "AUTO BLOCKED - Battery %.2fV",
                        voltage
                    )
                )

            end

        end

    end


    -- ======================================
    -- KBAA CONFIG
    -- ======================================

    local cfg = KBAA_CFG:get()


    -- ======================================
    -- UNLOCK -> LOCK
    -- CAPTURE CURRENT WPNAV VALUES
    -- ======================================

    if cfg == 1 and previous_cfg ~= 1 then

        local speed = WPNAV_SPEED:get()
        local accel = WPNAV_ACCEL:get()

        if speed ~= nil and accel ~= nil then

            KBAA_SPD:set_and_save(speed)
            KBAA_ACL:set_and_save(accel)

            gcs:send_text(
                6,
                string.format(
                    "KBAA LOCKED: SPD %.0f ACL %.0f",
                    speed,
                    accel
                )
            )

        end

    end


    -- ======================================
    -- LOCK ENFORCEMENT
    -- ======================================

    if cfg == 1 then

        local locked_speed = KBAA_SPD:get()
        local locked_accel = KBAA_ACL:get()


        -- WPNAV SPEED

        if locked_speed ~= nil then

            if WPNAV_SPEED:get() ~= locked_speed then

                WPNAV_SPEED:set_and_save(locked_speed)

            end

        end


        -- WPNAV ACCEL

        if locked_accel ~= nil then

            if WPNAV_ACCEL:get() ~= locked_accel then

                WPNAV_ACCEL:set_and_save(locked_accel)

            end

        end

    end


    -- ======================================
    -- UPDATE STATE
    -- ======================================

    previous_cfg = cfg


    -- ======================================
    -- LOOP
    -- ======================================

    return update, 200

end


-- ==========================================
-- START MESSAGE
-- ==========================================

gcs:send_text(
    6,
    "KBAA PROTECTION SCRIPT STARTED"
)

return update()

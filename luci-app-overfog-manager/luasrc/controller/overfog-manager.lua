module("luci.controller.overfog-manager", package.seeall)

function index()
    local fs = require "nixio.fs"
    if not fs.access("/usr/bin/overfogctl") then
        return
    end

    entry({"admin", "services", "overfog-manager"}, firstchild(),
        _("Overfog Manager"), 65).dependent = false
    entry({"admin", "services", "overfog-manager", "overview"},
        call("action_overview"), _("Overview"), 10).leaf = true
end

function action_overview()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local util = require "luci.util"
    local fs = require "nixio.fs"
    local jsonc = require "luci.jsonc"
    local dispatcher = require "luci.dispatcher"

    local action
    local action_output = ""
    local upload_path = os.tmpname()
    local upload_file
    local upload_received = false
    local session_token = dispatcher.context.authsession or ""
    local operation_name = "request"
    local operation_success = false

    local function run_operation(command)
        operation_success = sys.call(command .. " >/dev/null 2>&1") == 0
    end

    if http.getenv("REQUEST_METHOD") == "POST" then
        http.setfilehandler(function(meta, chunk, eof)
            if meta and meta.name == "happ_file" and meta.file and meta.file ~= "" then
                upload_received = true
                upload_file = upload_file or io.open(upload_path, "w")
                if chunk and upload_file then
                    upload_file:write(chunk)
                end
                if eof and upload_file then
                    upload_file:close()
                    upload_file = nil
                end
            end
        end)

        if session_token == "" or http.formvalue("token") ~= session_token then
            action_output = "Invalid or expired form token"
        else
            action = http.formvalue("action")
            local known_actions = {
                test = true, switch = true, ["profile-delete"] = true,
                rollback = true, ["watchdog-move"] = true,
                ["watchdog-remove"] = true, ["watchdog-add"] = true,
                ["watchdog-configure"] = true, import = true
            }
            if known_actions[action] then
                operation_name = action
            end

        if action == "test" then
            local profile = http.formvalue("profile") or ""
            if profile ~= "" then
                run_operation("/usr/bin/overfogctl test " .. util.shellquote(profile))
            end
        elseif action == "switch" then
            local profile = http.formvalue("profile") or ""
            if http.formvalue("confirm") == "1" and profile ~= "" then
                run_operation("/usr/bin/overfogctl switch " .. util.shellquote(profile))
            end
        elseif action == "profile-delete" then
            local profile = http.formvalue("profile") or ""
            if http.formvalue("confirm") == "1" and profile ~= "" then
                run_operation("/usr/bin/overfogctl profile-delete " ..
                    util.shellquote(profile) .. " --purge-backups")
            end
        elseif action == "rollback" then
            if http.formvalue("confirm") == "1" then
                run_operation("/usr/bin/overfogctl rollback")
            end
        elseif action == "watchdog-move" then
            local profile = http.formvalue("profile") or ""
            local direction = http.formvalue("direction") or ""
            if profile ~= "" and (direction == "up" or direction == "down") then
                run_operation("/usr/bin/overfogctl watchdog profile-move " ..
                    util.shellquote(profile) .. " " .. util.shellquote(direction))
            end
        elseif action == "watchdog-remove" then
            local profile = http.formvalue("profile") or ""
            if profile ~= "" then
                run_operation("/usr/bin/overfogctl watchdog profile-remove " ..
                    util.shellquote(profile))
            end
        elseif action == "watchdog-add" then
            local profile = http.formvalue("profile") or ""
            if profile ~= "" then
                run_operation("/usr/bin/overfogctl watchdog profile-add " ..
                    util.shellquote(profile))
            end
        elseif action == "watchdog-configure" then
            local enabled = http.formvalue("watchdog_enabled") or "0"
            local interval = http.formvalue("watchdog_interval") or ""
            local threshold = http.formvalue("watchdog_threshold") or ""
            local cooldown = http.formvalue("watchdog_cooldown") or ""
            run_operation("/usr/bin/overfogctl watchdog configure " ..
                util.shellquote(enabled) .. " " .. util.shellquote(interval) .. " " ..
                util.shellquote(threshold) .. " " .. util.shellquote(cooldown))
        elseif action == "import" then
            local country = http.formvalue("country") or ""
            local pasted_json = http.formvalue("happ_json") or ""
            if upload_file then
                upload_file:close()
                upload_file = nil
            end
            if not upload_received then
                fs.unlink(upload_path)
            end
            if not upload_received and pasted_json ~= "" then
                local pasted_file = io.open(upload_path, "w")
                if pasted_file then
                    pasted_file:write(pasted_json)
                    pasted_file:close()
                end
            end
            if fs.access(upload_path) then
                local country_arg = ""
                if country ~= "" then
                    country_arg = " --country " .. util.shellquote(country)
                end
                run_operation("/usr/bin/overfogctl import " .. util.shellquote(upload_path) .. country_arg)
                fs.unlink(upload_path)
            end
        end
        end

        if upload_file then
            upload_file:close()
        end
        fs.unlink(upload_path)
        http.redirect(dispatcher.build_url("admin", "services", "overfog-manager", "overview") ..
            "?operation=" .. operation_name .. "&result=" ..
            (operation_success and "ok" or "failed"))
        return
    end

    if http.formvalue("result") == "ok" then
        action_output = "Operation completed successfully. Refreshing this page will not repeat the request."
    elseif http.formvalue("result") == "failed" then
        action_output = "Operation did not complete. The current router state is shown below."
    end

    local doctor = sys.exec("/usr/bin/overfogctl doctor --json 2>/dev/null")
    local profiles = sys.exec("/usr/bin/overfogctl list --json 2>/dev/null")
    local watchdog_profiles_json = sys.exec("/usr/bin/overfogctl watchdog profiles --json 2>/dev/null")
    local watchdog_config_json = sys.exec("/usr/bin/overfogctl watchdog config 2>/dev/null")
    local all_profiles = jsonc.parse(profiles) or {}
    local ordered_profiles = jsonc.parse(watchdog_profiles_json) or {}
    local ordered = {}
    for _, item in ipairs(ordered_profiles) do
        ordered[item.name] = true
    end
    local available_profiles = {}
    for _, item in ipairs(all_profiles) do
        if item.name and not ordered[item.name] then
            table.insert(available_profiles, item)
        end
    end
    http.prepare_content("text/html")
    luci.template.render("overfog-manager/overview", {
        doctor_json = doctor,
        profiles_json = profiles,
        watchdog_profiles = ordered_profiles,
        available_watchdog_profiles = available_profiles,
        watchdog_config = jsonc.parse(watchdog_config_json) or {},
        doctor = jsonc.parse(doctor) or {},
        profile_list = all_profiles,
        form_token = session_token,
        action_output = action_output
    })
end

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

    local action
    local action_output = ""
    local upload_path = os.tmpname()
    local upload_file
    local upload_received = false

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

        action = http.formvalue("action")

        if action == "test" then
            local profile = http.formvalue("profile") or ""
            if profile ~= "" then
                action_output = sys.exec("/usr/bin/overfogctl test " .. util.shellquote(profile) .. " 2>&1")
            else
                action_output = "Profile is required"
            end
        elseif action == "switch" then
            local profile = http.formvalue("profile") or ""
            if http.formvalue("confirm") == "1" and profile ~= "" then
                action_output = sys.exec("/usr/bin/overfogctl switch " .. util.shellquote(profile) .. " 2>&1")
            else
                action_output = "Switch requires a profile and confirmation"
            end
        elseif action == "rollback" then
            if http.formvalue("confirm") == "1" then
                action_output = sys.exec("/usr/bin/overfogctl rollback 2>&1")
            else
                action_output = "Rollback requires confirmation"
            end
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
                local source_kind = upload_received and "upload" or "paste"
                action_output = "Source: " .. source_kind .. "\n" ..
                    sys.exec("/usr/bin/overfogctl import " .. util.shellquote(upload_path) .. country_arg .. " 2>&1")
                fs.unlink(upload_path)
            else
                action_output = "Upload a HAPP/Xray file or paste its JSON content"
            end
        end
    end

    local doctor = sys.exec("/usr/bin/overfogctl doctor --json 2>/dev/null")
    local profiles = sys.exec("/usr/bin/overfogctl list --json 2>/dev/null")
    http.prepare_content("text/html")
    luci.template.render("overfog-manager/overview", {
        doctor_json = doctor,
        profiles_json = profiles,
        action_output = action_output
    })
end

import json
import pathlib
import re
import shutil
import subprocess
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures"


class RepositoryFixturesTests(unittest.TestCase):
    def read_json(self, name):
        with (FIXTURES / name).open(encoding="utf-8") as handle:
            return json.load(handle)

    def test_base_config_has_one_overfog_outbound(self):
        config = self.read_json("config.base.sanitized.json")
        overfog = [item for item in config["outbounds"] if item.get("tag") == "overfog"]
        self.assertEqual(len(overfog), 1)
        self.assertEqual(overfog[0]["type"], "vless")

    def test_base_config_preserves_canonical_split_routing(self):
        config = self.read_json("config.base.sanitized.json")
        route = config["route"]
        rules = route["rules"]

        self.assertEqual(rules[0]["action"], "sniff")
        self.assertEqual(
            rules[1],
            {"port": 53, "network": ["tcp", "udp"], "outbound": "direct"},
        )
        self.assertEqual(rules[2]["domain_suffix"], [".ru", ".su", ".by"])
        self.assertEqual(rules[3]["rule_set"], ["geosite-category-ru"])
        self.assertEqual(rules[4]["rule_set"], ["geoip-ru"])
        self.assertFalse(any(rule.get("protocol") == "dns" for rule in rules))
        self.assertFalse(any("2ip.ru" in rule.get("domain_suffix", []) for rule in rules))
        self.assertEqual(route["final"], "overfog")
        self.assertTrue(route["auto_detect_interface"])

        direct = next(item for item in config["outbounds"] if item.get("tag") == "direct")
        self.assertNotIn("bind_interface", direct)
        tun = next(item for item in config["inbounds"] if item.get("type") == "tun")
        self.assertEqual(tun["stack"], "gvisor")
        self.assertEqual(config["log"]["level"], "info")

    def test_profile_shape_is_sanitized_and_complete(self):
        profile = self.read_json("profile.finland.sanitized.json")
        outbound = profile["outbound"]
        self.assertEqual(profile["name"], "finland")
        self.assertEqual(outbound["tag"], "overfog")
        self.assertTrue(outbound["tls"]["reality"]["public_key"].startswith("SANITIZED_"))

    def test_happ_fixture_contains_expected_source_fields(self):
        happ = self.read_json("happ.sanitized.json")
        outbound = happ["outbounds"][0]
        user = outbound["settings"]["vnext"][0]["users"][0]
        reality = outbound["streamSettings"]["realitySettings"]
        self.assertEqual(outbound["protocol"], "vless")
        self.assertEqual(user["flow"], "xtls-rprx-vision")
        self.assertEqual(reality["fingerprint"], "qq")

    def test_happ_remarks_provides_safe_profile_name_source(self):
        happ = self.read_json("happ.sanitized.json")
        normalized = re.sub(r"[^\w-]", "", re.sub(r"\s+", "_", happ["remarks"].strip()), flags=re.UNICODE)
        self.assertEqual(normalized, "Германия_Premium")
        self.assertNotIn("№", normalized)

    def test_no_real_secret_markers_in_fixtures(self):
        text = "\n".join(path.read_text(encoding="utf-8") for path in FIXTURES.glob("*.json"))
        self.assertNotIn("ai-apiroute.cc", text)
        self.assertNotIn("178.17.60.", text)

    def test_luci_uses_shared_cli_for_operations(self):
        controller = (ROOT / "luci-app-overfog-manager" / "luasrc" / "controller" / "overfog-manager.lua").read_text(encoding="utf-8")
        self.assertIn("doctor --json", controller)
        self.assertIn("list --json", controller)
        self.assertIn("overfogctl test", controller)
        self.assertIn("overfogctl import", controller)
        self.assertIn("overfogctl switch", controller)
        self.assertIn("overfogctl rollback", controller)
        self.assertIn("overfogctl profile-delete", controller)
        self.assertIn('meta.file ~= ""', controller)
        self.assertIn('formvalue("token")', controller)
        self.assertIn("http.redirect", controller)
        self.assertIn("operation_success", controller)
        self.assertIn("Operation did not complete", controller)

    def test_candidate_generation_is_shared_by_test_and_switch(self):
        cli = (ROOT / "overfogctl").read_text(encoding="utf-8")
        config = (ROOT / "lib" / "config.sh").read_text(encoding="utf-8")
        self.assertIn('generate_candidate "$CONFIG" "$PROFILE" "$TMP"', cli)
        self.assertIn("canonicalize_static_routing", config)

    def test_watchdog_configuration_is_disabled_by_default(self):
        config = (ROOT / "config" / "overfog-manager").read_text(encoding="utf-8")
        self.assertIn("option enabled '0'", config)
        self.assertIn("option interval '60'", config)
        self.assertIn("option failure_threshold '3'", config)
        self.assertIn("option cooldown '600'", config)
        self.assertIn("list profile_order", config)
        self.assertNotIn("Germaniya_2", config)
        self.assertNotIn("Estoniya_1", config)
        self.assertNotIn("finland", config)

    def test_watchdog_is_secret_safe_and_documented(self):
        watchdog = (ROOT / "lib" / "watchdog.sh").read_text(encoding="utf-8")
        self.assertIn("WATCHDOG_STATE_FILE", watchdog)
        self.assertIn("watchdog_state_valid", watchdog)
        self.assertNotIn("uuid", watchdog.lower())

    def test_process_check_targets_expected_singbox_command(self):
        checks = (ROOT / "lib" / "checks.sh").read_text(encoding="utf-8")
        self.assertIn("pgrep -f '/usr/bin/sing-box run'", checks)

    def test_watchdog_service_is_disabled_by_configuration_not_code(self):
        service = (ROOT / "etc" / "init.d" / "overfog-manager-watchdog").read_text(encoding="utf-8")
        self.assertIn("/usr/bin/overfogctl watchdog monitor", service)
        self.assertIn("USE_PROCD=1", service)
        cli = (ROOT / "overfogctl").read_text(encoding="utf-8")
        self.assertIn("cmd_watchdog_monitor_once", cli)
        self.assertIn("WATCHDOG_AUTOMATIC_BACKUP_DIR", cli)

    def test_watchdog_order_is_user_managed_and_profiles_are_auto_appended(self):
        watchdog = (ROOT / "lib" / "watchdog.sh").read_text(encoding="utf-8")
        cli = (ROOT / "overfogctl").read_text(encoding="utf-8")
        self.assertIn("watchdog_profile_order_add", watchdog)
        self.assertIn("watchdog_profile_order_move", watchdog)
        self.assertIn("watchdog_configure", watchdog)
        self.assertIn("watchdog profile-move", cli)
        self.assertIn("watchdog_profile_order_add \"$NAME\"", cli)

    def test_luci_exposes_watchdog_order_controls(self):
        controller = (ROOT / "luci-app-overfog-manager" / "luasrc" / "controller" / "overfog-manager.lua").read_text(encoding="utf-8")
        view = (ROOT / "luci-app-overfog-manager" / "luasrc" / "view" / "overfog-manager" / "overview.htm").read_text(encoding="utf-8")
        self.assertIn("watchdog profile-move", controller)
        self.assertIn("watchdog profile-remove", controller)
        self.assertIn("watchdog profile-add", controller)
        self.assertIn("watchdog configure", controller)
        self.assertIn("Automatic failover", view)
        self.assertIn('name="token"', view)
        self.assertIn('action" value="profile-delete"', view)
        self.assertIn("overfog-operation-overlay", view)
        self.assertIn("lockInterface", view)
        self.assertIn("event.preventDefault()", view)
        self.assertNotIn("disabled = true", view)

    def test_profile_deletion_protects_active_profile_and_rollback(self):
        cli = (ROOT / "overfogctl").read_text(encoding="utf-8")
        profiles = (ROOT / "lib" / "profiles.sh").read_text(encoding="utf-8")
        self.assertIn("cmd_profile_delete", cli)
        self.assertIn("Cannot delete the active profile", cli)
        self.assertIn("--purge-backups", cli)
        self.assertIn("profile_backup_references", profiles)

    def test_mutating_cli_commands_use_the_shared_operation_lock(self):
        cli = (ROOT / "overfogctl").read_text(encoding="utf-8")
        self.assertGreaterEqual(cli.count("acquire_operation_lock"), 7)
        self.assertIn("Another profile, switch, rollback, or watchdog operation", cli)

    def test_installer_is_grouped_and_does_not_install_singbox_config(self):
        installer = (ROOT / "installer" / "install.sh").read_text(encoding="utf-8")
        self.assertIn("cli luci watchdog configuration", installer)
        self.assertIn("backup-and-update", (ROOT / "ARCHITECTURE.md").read_text(encoding="utf-8"))
        self.assertNotIn("install_file \"$PAYLOAD_ROOT/etc/sing-box/config.json\"", installer)
        self.assertIn("Installation choices completed", installer)
        self.assertIn("--check", installer)
        self.assertIn("sed 's/\\r$//'", installer)
        self.assertIn("--prune-backups", installer)
        self.assertIn("prune_deployment_backups", installer)

    def test_installer_bundle_launcher_has_payload_marker(self):
        launcher = (ROOT / "installer" / "launcher.sh").read_text(encoding="utf-8")
        installer = (ROOT / "installer" / "install.sh").read_text(encoding="utf-8")
        self.assertIn("__OVERFOG_PAYLOAD_BELOW__", launcher)
        self.assertIn("tar -xzf", launcher)
        builder = (ROOT / "scripts" / "build-installer.sh").read_text(encoding="utf-8")
        self.assertIn("overfog-manager-installer.run", builder)
        self.assertIn("checksums.sha256", builder)
        self.assertIn("sha256sum -c checksums.sha256", installer)

    def test_shell_syntax(self):
        shell = shutil.which("sh")
        if shell is None:
            self.skipTest("POSIX sh is not available")
        result = subprocess.run([shell, "-n", str(ROOT / "overfogctl")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_shell_integration_uses_an_isolated_operation_lock(self):
        integration = (ROOT / "tests" / "shell" / "test_cli.sh").read_text(encoding="utf-8")
        self.assertIn("OVERFOG_OPERATION_LOCK_DIR=\"$TMP_ROOT/operation.lock\"", integration)


if __name__ == "__main__":
    unittest.main()

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
        self.assertNotIn("cdn-fl.ai-apiroute.cc", text)
        self.assertNotIn("178.17.60.19", text)

    def test_luci_uses_shared_cli_for_operations(self):
        controller = (ROOT / "luci-app-overfog-manager" / "luasrc" / "controller" / "overfog-manager.lua").read_text(encoding="utf-8")
        self.assertIn("doctor --json", controller)
        self.assertIn("list --json", controller)
        self.assertIn("overfogctl test", controller)
        self.assertIn("overfogctl import", controller)
        self.assertIn("overfogctl switch", controller)
        self.assertIn("overfogctl rollback", controller)
        self.assertIn('meta.file ~= ""', controller)

    def test_watchdog_configuration_is_disabled_by_default(self):
        config = (ROOT / "config" / "overfog-manager").read_text(encoding="utf-8")
        self.assertIn("option enabled '0'", config)
        self.assertIn("option interval '60'", config)
        self.assertIn("option failure_threshold '3'", config)
        self.assertIn("option cooldown '600'", config)
        self.assertIn("option profile_order 'Germaniya_2 Estoniya_1 finland'", config)

    def test_watchdog_is_secret_safe_and_documented(self):
        watchdog = (ROOT / "lib" / "watchdog.sh").read_text(encoding="utf-8")
        self.assertIn("WATCHDOG_STATE_FILE", watchdog)
        self.assertIn("watchdog_state_valid", watchdog)
        self.assertNotIn("uuid", watchdog.lower())

    def test_watchdog_service_is_disabled_by_configuration_not_code(self):
        service = (ROOT / "etc" / "init.d" / "overfog-manager-watchdog").read_text(encoding="utf-8")
        self.assertIn("/usr/bin/overfogctl watchdog monitor", service)
        self.assertIn("USE_PROCD=1", service)
        cli = (ROOT / "overfogctl").read_text(encoding="utf-8")
        self.assertIn("cmd_watchdog_monitor_once", cli)
        self.assertIn("WATCHDOG_AUTOMATIC_BACKUP_DIR", cli)

    def test_shell_syntax(self):
        shell = shutil.which("sh")
        if shell is None:
            self.skipTest("POSIX sh is not available")
        result = subprocess.run([shell, "-n", str(ROOT / "overfogctl")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()

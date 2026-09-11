#!/usr/bin/env python3
"""Real local bare-git lifecycle and adversarial-input checks, all under a temp HOME."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

HELPER = Path(__file__).resolve().parents[1] / "helpers/extensions.lua"
MID = "test.keystroke-probe"


class ExtensionsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="keystroke-git-test-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.home = self.work / "home"
        self.home.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        self.env.update(HOME=str(self.home), XDG_DATA_HOME=str(self.home / "data"),
                        XDG_CONFIG_HOME=str(self.home / "config"), XDG_CACHE_HOME=str(self.home / "cache"),
                        XDG_STATE_HOME=str(self.home / "state"), XDG_RUNTIME_DIR=str(self.work / "runtime"),
                        GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                        GIT_AUTHOR_NAME="Test", GIT_AUTHOR_EMAIL="test@example.invalid",
                        GIT_COMMITTER_NAME="Test", GIT_COMMITTER_EMAIL="test@example.invalid")
        self.managed = self.home / "data/keystroke/extensions"
        self.dest = self.managed / MID
        self.src = self.work / "source"
        self.src.mkdir()
        self.bare = self.work / "probe.git"
        self.url = self.bare.as_uri()
        self.m = {"schemaVersion": 1, "id": MID, "name": "Probe", "version": "1.0.0", "kinds": ["service"],
                  "entryPoints": {"service": "Service.qml"}, "x-keystroke": {"apiVersion": 1}}
        self.write_manifest()
        (self.src / "Service.qml").write_text('import QtQuick\nQtObject { readonly property var provider: ({ apiVersion: 1, name: "Probe", query: function(ctx) { return [] } }) }\n')
        (self.src / "install.sh").write_text("#!/bin/sh\ntouch " + str(self.work / "installer-ran") + "\n")
        (self.src / "install.sh").chmod(0o755)
        self.git("init", "-q", "-b", "main", cwd=self.src)
        self.git("add", ".", cwd=self.src)
        self.git("commit", "-qm", "initial", cwd=self.src)
        self.git("init", "-q", "--bare", "-b", "main", str(self.bare))
        self.git("push", "-q", str(self.bare), "main", cwd=self.src)

    def git(self, *args, cwd=None):
        return subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], cwd=cwd,
                              env=self.env, check=True, capture_output=True, text=True, timeout=10).stdout.strip()

    def call(self, *args, ok=True, cwd=None):
        result = subprocess.run(["luajit", str(HELPER), *args], cwd=cwd, env=self.env, capture_output=True, text=True, timeout=15)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def lua(self, code, *args, setup=""):
        # Import the production module, not a Python translation of its validators.
        script = "package.path = " + json.dumps(str(HELPER.parent / "?.lua") + ";") + " .. package.path\n"
        script += "local U = require('runtime')\n" + setup + "\nlocal E = require('extensions')\n" + code
        result = subprocess.run(["luajit", "-e", script, "--", "/dev/null", *args], cwd=self.work, env=self.env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        return result

    def write_manifest(self):
        (self.src / "manifest.json").write_text(json.dumps(self.m))

    def push(self):
        self.write_manifest()
        self.git("add", "-A", cwd=self.src)
        self.git("commit", "-qm", "next", cwd=self.src)
        self.git("push", "-q", str(self.bare), "main", cwd=self.src)

    def install(self):
        return self.call("install", "--id", MID, "--", self.url)

    def test_lifecycle_and_default_disabled_scan(self):
        self.install()
        self.assertFalse((self.work / "installer-ran").exists())
        found = json.loads(self.call("scan").stdout)
        m = found["manifests"][MID]
        self.assertFalse(m["__enabled"])
        self.assertNotIn("__sourceDir", m)
        self.assertFalse((self.home / "config").exists(), "helper must not write settings")
        enabled = json.loads(self.call("scan", "--enabled-json", json.dumps([MID])).stdout)["manifests"][MID]
        self.assertTrue(enabled["__enabled"])
        self.assertEqual(enabled["__sourceDir"], str(self.dest))
        self.assertFalse(json.loads(self.call("scan", "--enabled-json", "[]").stdout)["manifests"][MID]["__enabled"])
        before = self.git("rev-parse", "HEAD", cwd=self.dest)
        self.m["version"] = "2.0.0"
        self.push()
        fields = self.call("check", "--", MID).stdout.strip().split("\t")
        self.assertEqual(fields[1], before)
        self.assertNotEqual(fields[1], fields[2])
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.dest), before)
        self.assertFalse((self.dest / ".git/FETCH_HEAD").exists())
        result = self.call("update", "--", MID)
        self.assertIn("restart the launcher shell", result.stdout)
        self.assertEqual(json.loads((self.dest / "manifest.json").read_text())["version"], "2.0.0")
        self.call("remove", "--", MID)
        self.assertFalse(self.dest.exists())
        self.assertFalse(any(p.name.startswith((".stage-", ".remove-")) for p in self.managed.iterdir()))

    def test_identity_mismatch_never_installs(self):
        self.call("install", "--id", "other.extension", "--", self.url, ok=False)
        self.assertFalse(self.dest.exists())

    def test_malicious_manifests_and_symlinks_never_install(self):
        variants = [
            {"id": "../escape"}, {"id": "extensions"}, {"x-keystroke": {"apiVersion": 2}},
            {"x-keystroke": {"apiVersion": True}}, {"x-keystroke": None},
            {"entryPoints": {"service": "../outside.qml"}}, {"entryPoints": {"service": "/etc/passwd"}},
            {"entryPoints": {"service": "sub/../../Service.qml"}},
            {"entryPoints": {"service": "Service.qml", "view": "../../outside.qml"}},
            {"entryPoints": {"service": "missing.qml"}}, {"entryPoints": {"service": "Service.qml#x"}},
            {"entryPoints": {"service": "."}}, {"entryPoints": {"service": "Service.qml", "other": "bad\\path"}},
        ]
        original = dict(self.m)
        for fields in variants:
            with self.subTest(fields=fields):
                self.m = dict(original, **fields)
                self.push()
                self.call("install", "--", self.url, ok=False)
                self.assertFalse(self.dest.exists())
        self.m = original
        (self.src / "Service.qml").unlink()
        (self.src / "Service.qml").symlink_to(self.work / "outside.qml")
        (self.work / "outside.qml").write_text("do not load")
        self.push()
        self.call("install", "--", self.url, ok=False)
        self.assertFalse(self.dest.exists())

    def test_dirty_update_preserves_local_edits_and_head(self):
        self.install()
        before = self.git("rev-parse", "HEAD", cwd=self.dest)
        self.m["version"] = "2.0.0"
        self.push()
        service = self.dest / "Service.qml"
        service.write_text(service.read_text() + "// local edits\n")
        edited = service.read_bytes()
        result = self.call("update", MID, ok=False)
        self.assertIn("local edits", result.stderr)
        self.assertEqual(service.read_bytes(), edited)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.dest), before)
        self.git("update-index", "--assume-unchanged", "Service.qml", cwd=self.dest)
        self.assertIn("local edits", self.call("update", MID, ok=False).stderr)
        self.git("update-index", "--no-assume-unchanged", "Service.qml", cwd=self.dest)
        self.git("checkout", "--", "Service.qml", cwd=self.dest)
        (self.dest / "notes").write_text("untracked notes")
        self.assertIn("local edits", self.call("update", MID, ok=False).stderr)
        self.assertEqual((self.dest / "notes").read_text(), "untracked notes")

    def test_hidden_mode_changes_are_preserved(self):
        self.install()
        self.git("config", "core.filemode", "false", cwd=self.dest)
        (self.dest / "Service.qml").chmod(0o755)
        self.assertIn("local edits", self.call("update", MID, ok=False).stderr)
        self.assertTrue((self.dest / "Service.qml").stat().st_mode & 0o100)

    def test_ignored_files_and_local_commits_are_preserved(self):
        (self.src / ".gitignore").write_text("notes\n")
        self.push()
        self.install()
        (self.dest / "notes").write_text("ignored notes")
        self.assertIn("ignored files", self.call("update", MID, ok=False).stderr)
        (self.dest / "notes").unlink()
        (self.dest / "Service.qml").write_text("// committed local work\n")
        self.git("commit", "-qam", "local", cwd=self.dest)
        self.m["version"] = "2.0.0"
        self.push()
        self.assertIn("not a fast-forward", self.call("update", MID, ok=False).stderr)
        self.assertEqual((self.dest / "Service.qml").read_text(), "// committed local work\n")

    def test_bad_update_preserves_previous_install(self):
        self.install()
        before = self.git("rev-parse", "HEAD", cwd=self.dest)
        self.m["id"] = "other.extension"
        self.push()
        self.call("update", MID, ok=False)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.dest), before)
        self.m["id"] = MID
        self.m["entryPoints"]["service"] = "../evil.qml"
        self.push()
        self.call("update", MID, ok=False)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.dest), before)

    def test_url_protocol_and_git_config_injection(self):
        bad = ["--upload-pack=sh", "-oProxyCommand=sh", "ext::sh -c touch", "git://example.invalid/a", "ssh://-oProxyCommand=x/a",
               "git@example.invalid:a", "http://example.invalid/a", "https://user:pass@example.invalid/a", "https://example.invalid/a?x",
               "https://example.invalid/a#x", "https://example.invalid/%2e%2e/a", "https://example.invalid/a%00b",
               "file://host/tmp/a", "file:///tmp/../a", str(self.bare), "https://-evil/a"]
        for url in bad:
            with self.subTest(url=url):
                self.call("install", "--", url, ok=False)
        self.git("config", "uploadpack.packObjectsHook", "touch " + str(self.work / "hook-ran"), cwd=self.bare)
        self.assertIn("Unsupported git config", self.call("install", "--", self.url, ok=False).stderr)
        self.assertFalse((self.work / "hook-ran").exists())

    def test_external_config_templates_submodules_and_local_symlinks_are_refused(self):
        hooks = self.work / "templates/hooks"
        hooks.mkdir(parents=True)
        (hooks / "post-checkout").write_text("#!/bin/sh\ntouch " + str(self.work / "hook-ran") + "\n")
        (hooks / "post-checkout").chmod(0o755)
        config = self.work / "global.gitconfig"
        config.write_text('[init]\n templateDir = ' + str(hooks.parent) + '\n[url "ext::evil"]\n insteadOf = file:///\n')
        self.env.update(GIT_CONFIG_GLOBAL=str(config), GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0="core.hooksPath", GIT_CONFIG_VALUE_0=str(hooks), GIT_TEMPLATE_DIR=str(hooks.parent))
        self.install()
        self.assertFalse((self.work / "hook-ran").exists())
        for key in ("GIT_CONFIG_COUNT", "GIT_CONFIG_KEY_0", "GIT_CONFIG_VALUE_0", "GIT_TEMPLATE_DIR"):
            self.env.pop(key)
        self.env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        link = self.work / "link.git"
        link.symlink_to(self.bare, target_is_directory=True)
        self.assertIn("Symlink", self.call("install", "--", link.as_uri(), ok=False).stderr)
        self.call("remove", MID)
        head = self.git("rev-parse", "HEAD", cwd=self.src)
        self.git("update-index", "--add", "--cacheinfo", "160000," + head + ",nested", cwd=self.src)
        self.git("commit", "-qm", "submodule", cwd=self.src)
        self.git("push", "-q", str(self.bare), "main", cwd=self.src)
        self.assertIn("submodules", self.call("install", "--", self.url, ok=False).stderr)

    def test_network_checks_ignore_the_callers_repository_config(self):
        self.install()
        self.git("config", "url.ext::evil.insteadOf", "file:///", cwd=self.src)
        self.call("check", MID, cwd=self.src)

    def test_existing_git_config_and_hooks_cannot_run(self):
        self.install()
        hook = self.dest / ".git/hooks/post-checkout"
        hook.parent.mkdir(exist_ok=True)
        hook.write_text("#!/bin/sh\ntouch " + str(self.work / "hook-ran") + "\n")
        hook.chmod(0o755)
        self.m["version"] = "2.0.0"
        self.push()
        self.call("update", MID)
        self.assertFalse((self.work / "hook-ran").exists())
        for key in ("core.fsmonitor", "include.path", "url.ext::sh.insteadOf", "filter.evil.smudge", "core.sshCommand"):
            with self.subTest(key=key):
                self.git("config", key, "touch " + str(self.work / "hook-ran"), cwd=self.dest)
                self.assertIn("Unsupported git config", self.call("check", MID, ok=False).stderr)
                self.git("config", "--unset", key, cwd=self.dest)
        self.assertFalse((self.work / "hook-ran").exists())

    def test_remove_and_scan_refuse_traversal_and_symlinks(self):
        self.install()
        for mid in ("../source", "..", ".", "", "-x", "a/../../b", MID + "/"):
            with self.subTest(mid=mid):
                self.call("remove", "--", mid, ok=False)
        self.assertTrue(self.dest.exists())
        other = self.managed / "other.extension"
        other.symlink_to(self.src, target_is_directory=True)
        self.call("remove", "other.extension", ok=False)
        found = json.loads(self.call("scan", "--enabled-json", '["other.extension"]').stdout)
        self.assertNotIn("other.extension", found["manifests"])
        self.assertIn("Symlink", found["problems"][0]["message"])
        self.assertTrue((self.src / "Service.qml").exists())
        (self.dest / "Service.qml").unlink()
        (self.dest / "Service.qml").symlink_to(self.src / "Service.qml")
        self.call("remove", MID, ok=False)
        self.assertNotIn(MID, json.loads(self.call("scan", "--enabled-json", json.dumps([MID])).stdout)["manifests"])

    def test_managed_root_and_manifest_stamps_are_not_trusted(self):
        self.m.update(__sourceDir="/tmp/evil", __enabled=True, __validated=True)
        self.push()
        self.install()
        m = json.loads(self.call("scan").stdout)["manifests"][MID]
        self.assertFalse(m["__enabled"])
        self.assertNotIn("__sourceDir", m)
        self.dest.rename(self.work / "saved")
        self.managed.rename(self.work / "managed")
        self.managed.symlink_to(self.work / "managed", target_is_directory=True)
        self.call("scan", ok=False)
        self.call("install", "--", self.url, ok=False)

    def test_jobs_record_errors_and_ack_only_exact_result(self):
        jobs = Path(self.env["XDG_RUNTIME_DIR"]) / "keystroke/extensions"
        job = {"kind": "install", "label": "Installing Probe", "startedAt": 123, "enable": True}
        self.call("job", str(jobs), json.dumps(job), "--", "install", "--id", MID, "--", self.url)
        result = json.loads((jobs / "result.json").read_text())
        self.assertEqual(result["job"], job)
        self.assertEqual(result["code"], 0)
        self.assertIn("Added " + MID, result["output"])
        self.assertFalse((jobs / "job.json").exists())
        self.call("ack", "122")
        self.assertTrue((jobs / "result.json").exists())
        self.call("ack", "123")
        self.assertFalse((jobs / "result.json").exists())
        job["startedAt"] = 124
        self.call("job", str(jobs), json.dumps(job), "--", "install", "--", "--upload-pack=evil", ok=False)
        result = json.loads((jobs / "result.json").read_text())
        self.assertEqual(result["code"], 1)
        self.assertIn("Unsafe repository URL", result["output"])
        self.call("job", str(jobs), json.dumps(job), "--", "sh", "-c", "touch unsafe", ok=False)

    def test_direct_lua_validation(self):
        self.lua("""
assert(E.identity(arg[1]) == arg[1])
for _, value in ipairs(U.decode(arg[2])) do
    local ok = pcall(E.identity, value)
    assert(not ok, U.encode(value))
end
for _, value in ipairs(U.decode(arg[3])) do
    local ok = pcall(E.repository_url, value)
    assert(not ok, U.encode(value))
end
assert(E.repository_url('https://example.invalid:443/a.git') == 'https://example.invalid:443/a.git')
assert(E.manifest(arg[4], arg[1]).id == arg[1])
assert(not pcall(E.manifest, arg[4], 'other.extension'))
""", MID, json.dumps([None, True, 1, [], {}, "a", "a..b", "A.b", ".a.b", "a.b.", "a/../b", "a." + "b" * 119]),
                 json.dumps([None, True, 1, {}, [], "https://x:0/a", "https://x:65536/a", "https://x:123456/a",
                             "https://x/a%5cb", "https://x/a%0ab", "https://x/a\u00a0b", "https://x/./a"]), str(self.src))
        for fields in ({"name": "  "}, {"name": "\u00a0\u2003\u3000"}, {"name": None}, {"kinds": {}}, {"kinds": ["view"]},
                       {"entryPoints": []}, {"entryPoints": {"service": "install.sh"}},
                       {"entryPoints": {"service": "Service.qml", "other": None}}, {"x-keystroke": []}):
            with self.subTest(fields=fields):
                (self.src / "manifest.json").write_text(json.dumps(dict(self.m, **fields)))
                self.lua("assert(not pcall(E.manifest, arg[1]))", str(self.src))
        (self.src / "manifest.json").write_text(" " * (1024 * 1024 + 1))
        self.lua("local ok, err = pcall(E.manifest, arg[1]); assert(not ok and err:find('too large', 1, true))", str(self.src))

    def test_empty_scan_shapes_and_enabled_validation(self):
        self.assertEqual(json.loads(self.call("scan").stdout), {"manifests": {}, "problems": []})
        for value in ("{}", "null", '"test.example"', "[true]", '["../escape"]', "[NaN]", "[] trailing"):
            with self.subTest(value=value):
                self.call("scan", "--enabled-json", value, ok=False)

    def test_hand_copied_extensions_remain_manageable_without_git(self):
        self.dest.mkdir(parents=True)
        (self.dest / "manifest.json").write_text(json.dumps(self.m))
        (self.dest / "Service.qml").write_text("import QtQuick\nQtObject {}\n")
        m = json.loads(self.call("scan").stdout)["manifests"][MID]
        self.assertFalse(m["__git"])
        self.assertFalse(m["__enabled"])
        self.assertNotIn("__sourceDir", m)
        self.assertEqual(self.call("check", MID).stdout, MID + "\t\t\t\n")
        self.call("remove", MID)
        self.assertFalse(self.dest.exists())

    def test_managed_permissions_unsafe_locks_and_concurrent_operations(self):
        self.call("scan")
        self.managed.chmod(0o777)
        self.assertIn("not writable", self.call("scan", ok=False).stderr)
        self.managed.chmod(0o700)
        lock = self.managed / ".lock"
        lock.unlink()
        outside = self.work / "outside"
        outside.write_text("unchanged")
        lock.symlink_to(outside)
        self.call("scan", ok=False)
        self.assertEqual(outside.read_text(), "unchanged")
        lock.unlink()
        os.mkfifo(lock)
        self.assertIn("Unsafe lock file", self.call("scan", ok=False).stderr)
        lock.unlink()
        with lock.open("w") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertIn("still running", self.call("scan", ok=False).stderr)
        self.call("scan")

    def test_persistent_job_waits_for_a_short_registry_scan(self):
        self.call("scan")
        jobs = Path(self.env["XDG_RUNTIME_DIR"]) / "keystroke/extensions"
        job = {"kind": "check", "startedAt": 456}
        with (self.managed / ".lock").open("r") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            process = subprocess.Popen(["luajit", str(HELPER), "job", str(jobs), json.dumps(job), "--", "check"],
                                       env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 1
                while not (jobs / "job.json").exists() and process.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue((jobs / "job.json").exists())
                time.sleep(0.05)
                self.assertIsNone(process.poll(), "job must wait for the active scan")
            finally:
                fcntl.flock(stream, fcntl.LOCK_UN)
                out, err = process.communicate(timeout=4)
        self.assertEqual(process.returncode, 0, out + err)
        self.assertEqual(json.loads((jobs / "result.json").read_text())["code"], 0)
        self.assertFalse((jobs / "job.json").exists())

    def test_git_object_store_and_duplicate_config_are_refused(self):
        for name in ("objects/info/alternates", "objects/info/http-alternates", "info/grafts", "commondir"):
            with self.subTest(name=name):
                path = self.bare / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(str(self.src / ".git/objects"))
                self.assertIn("External git object", self.call("install", "--", self.url, ok=False).stderr)
                path.unlink()
        config = self.bare / "config"
        config.write_text(config.read_text() + "\n[core]\n bare = true\n")
        self.assertIn("Unsupported git config", self.call("install", "--", self.url, ok=False).stderr)

    def test_clone_failure_cleans_staging_and_swap_failure_restores_checkout(self):
        self.lua("""
local git = E.git
E.git = function(args, opts)
    local out, code = git(args, opts)
    if args[1] == 'checkout' then error('forced checkout failure', 0) end
    return out, code
end
local output = ''
local function capture(text) output = output .. text end
assert(E.main({ 'install', '--', arg[1] }, capture, capture) == 1)
assert(output:find('forced checkout failure', 1, true))
""", self.url)
        self.assertFalse(self.dest.exists())
        self.assertFalse(any(p.name.startswith(".stage-") for p in self.managed.iterdir()))
        self.install()
        before = self.git("rev-parse", "HEAD", cwd=self.dest)
        self.m["version"] = "2.0.0"
        self.push()
        self.lua("""
local output = ''
local function capture(text) output = output .. text end
assert(E.main({ 'update', arg[1] }, capture, capture) == 1)
assert(output:find('Cannot rename', 1, true), output)
""", MID, setup="""
local libc = U.C
U.C = setmetatable({ ext_renameat = function(oldfd, oldname, newfd, newname)
    if oldname == 'checkout' then U.ffi.errno(5); return -1 end
    return libc.ext_renameat(oldfd, oldname, newfd, newname)
end }, { __index = libc })
""")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.dest), before)
        self.assertEqual(json.loads((self.dest / "manifest.json").read_text())["version"], "1.0.0")
        self.assertFalse(any(p.name.startswith(".stage-") for p in self.managed.iterdir()))

    def test_update_rechecks_edits_after_clone(self):
        self.install()
        before = self.git("rev-parse", "HEAD", cwd=self.dest)
        self.m["version"] = "2.0.0"
        self.push()
        self.lua("""
local git = E.git
E.git = function(args, opts)
    local out, code = git(args, opts)
    if args[1] == 'clone' then U.write(arg[2], '// concurrent edits\\n') end
    return out, code
end
local output = ''
local function capture(text) output = output .. text end
assert(E.main({ 'update', arg[1] }, capture, capture) == 1)
assert(output:find('local edits', 1, true), output)
""", MID, str(self.dest / "Service.qml"))
        self.assertEqual((self.dest / "Service.qml").read_text(), "// concurrent edits\n")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.dest), before)
        self.assertFalse(any(p.name.startswith(".stage-") for p in self.managed.iterdir()))

    def test_job_metadata_scope_and_symlink_writes(self):
        jobs = Path(self.env["XDG_RUNTIME_DIR"]) / "keystroke/extensions"
        for job in ({}, [], {"kind": "sh", "startedAt": 1}, {"kind": "check", "startedAt": True},
                    {"kind": "check", "startedAt": float("inf")}, {"kind": "check", "startedAt": float("nan")}):
            with self.subTest(job=job):
                self.call("job", str(jobs), json.dumps(job), "--", "check", ok=False)
        job = {"kind": "check", "startedAt": 123}
        self.call("job", str(self.work / "wrong"), json.dumps(job), "--", "check", ok=False)
        self.call("job", str(jobs), json.dumps(job), "--", "check")
        self.assertEqual((jobs / "result.json").stat().st_mode & 0o777, 0o600)
        outside = self.work / "outside.json"
        outside.write_text(json.dumps({"job": job}))
        (jobs / "result.json").unlink()
        (jobs / "result.json").symlink_to(outside)
        self.assertIn("Symlink", self.call("ack", "123", ok=False).stderr)
        (jobs / "job.json").symlink_to(outside)
        self.assertIn("Symlink", self.call("job", str(jobs), json.dumps(job), "--", "check", ok=False).stderr)
        self.assertEqual(json.loads(outside.read_text()), {"job": job})

    def test_git_job_errors_are_json_safe(self):
        script = self.work / "bin/git"
        script.parent.mkdir()
        diagnostic = self.work / "diagnostic"
        script.write_text('#!/bin/sh\ncat "' + str(diagnostic) + '" >&2\nexit 1\n')
        script.chmod(0o755)
        self.env["PATH"] = str(script.parent) + ":" + self.env["PATH"]
        jobs = Path(self.env["XDG_RUNTIME_DIR"]) / "keystroke/extensions"
        for n, message in enumerate((b"invalid byte: \xff", ("誤" * 1000).encode())):
            with self.subTest(message=n):
                diagnostic.write_bytes(message)
                job = {"kind": "install", "label": "Fixture", "startedAt": n + 1}
                self.call("job", str(jobs), json.dumps(job), "--", "install", "--id", MID,
                          "--", "https://example.invalid/repo.git", ok=False)
                self.assertFalse((jobs / "job.json").exists(), "failed job was left running")
                result = json.loads((jobs / "result.json").read_text())
                self.assertNotEqual(result["code"], 0)
                self.assertIn("extensions:", result["output"])
                self.assertEqual(result["job"], job)

    def test_bounded_git_timeout_kills_child_group(self):
        script = self.work / "bin/git"
        script.parent.mkdir()
        child = self.work / "child.pid"
        script.write_text("#!/bin/sh\nsleep 20 &\necho $! > " + str(child) + "\nwait\n")
        script.chmod(0o755)
        self.env["PATH"] = str(script.parent) + ":" + self.env["PATH"]
        started = time.monotonic()
        self.lua("""
E.TIMEOUT = 0.05
local ok, err = pcall(E.git, { 'version' })
assert(not ok and tostring(err):find('timed out', 1, true), tostring(err))
""")
        self.assertLess(time.monotonic() - started, 3)
        self.assert_child_stopped(int(child.read_text()))

    def assert_child_stopped(self, pid):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            try:
                state = Path("/proc", str(pid), "stat").read_text().rsplit(")", 1)[1].split()[0]
                if state in ("Z", "X"):
                    return
            except FileNotFoundError:
                return
            time.sleep(0.02)
        self.fail("Git descendant outlived its cancelled helper: " + str(pid))

    def test_git_children_do_not_outlive_cancellation(self):
        script = self.work / "bin/git"
        script.parent.mkdir()
        child = self.work / "child.pid"
        # Even a TERM-resistant descendant must be killed by the supervisor.
        script.write_text("#!/bin/sh\ntrap '' TERM\nsleep 20 &\necho $! > " + str(child) + "\nwait\n")
        script.chmod(0o755)
        self.env["PATH"] = str(script.parent) + ":" + self.env["PATH"]
        code = "package.path = " + json.dumps(str(HELPER.parent / "?.lua") + ";") + " .. package.path; require('extensions').git({'version'})"
        process = subprocess.Popen(["luajit", "-e", code], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 3
            while not child.exists() and time.monotonic() < deadline and process.poll() is None:
                time.sleep(0.01)
            self.assertTrue(child.exists(), "fake Git did not start")
            process.kill()
            process.communicate(timeout=4)
            self.assert_child_stopped(int(child.read_text()))
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=4)


if __name__ == "__main__":
    unittest.main()

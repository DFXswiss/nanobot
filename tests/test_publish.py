import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEPLOY_PATH = ROOT / ".github" / "workflows" / "deploy.yml"
AUTO_PATH = ROOT / ".github" / "workflows" / "auto-release-pr.yaml"
AUDIENCE = "https://image-published.dfxserve.com/v1/image-published"


def workflow_steps(text):
    lines = text.splitlines()
    start_at = lines.index("    steps:") + 1
    body = lines[start_at:]
    starts = [index for index, line in enumerate(body) if line.startswith("      - ")]
    blocks = []
    for position, start in enumerate(starts):
        end = starts[position + 1] if position + 1 < len(starts) else len(body)
        blocks.append("\n".join(body[start:end]))
    return blocks


def step_name(block):
    for line in block.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            stripped = stripped[2:].lstrip()
        if stripped.startswith("name:"):
            return stripped.split(":", 1)[1].strip()
    return ""


def run_script(block):
    lines = block.splitlines()
    collecting = False
    script = []
    for line in lines:
        if not collecting:
            if line.strip() == "run: |":
                collecting = True
            continue
        if line.startswith("          ") or line.strip() == "":
            script.append(line)
            continue
        break
    return "\n".join(script)


class PublishWorkflowTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.deploy = DEPLOY_PATH.read_text(encoding="utf-8")
        cls.auto = AUTO_PATH.read_text(encoding="utf-8")
        cls.steps = workflow_steps(cls.deploy)
        cls.by_name = {}
        for block in cls.steps:
            name = step_name(block)
            if name:
                cls.by_name[name] = block

    def test_permissions_include_contents_read_and_id_token_write(self):
        lines = self.deploy.splitlines()
        start = lines.index("permissions:")
        end = start + 1
        while end < len(lines) and (lines[end].startswith(" ") or lines[end] == ""):
            end += 1
        block = "\n".join(lines[start:end])
        self.assertIn("contents: read", block)
        self.assertIn("id-token: write", block)

    def test_build_step_has_id_push(self):
        block = self.by_name["Build and push"]
        self.assertRegex(block, r"(?m)^        id: push$")

    def test_publish_step_runs_only_on_push_and_posts_digest(self):
        block = self.by_name["Notify image publish endpoint"]
        self.assertIn("if: github.event_name == 'push'", block)
        self.assertIn("IMAGE_DIGEST: ${{ steps.push.outputs.digest }}", block)
        self.assertIn("TAG: latest", block)
        script = run_script(block)
        self.assertIn(AUDIENCE, script)
        self.assertIn("^sha256:[0-9a-f]{64}$", script)
        self.assertIn("jq -nc", script)
        self.assertIn("--arg image", script)
        self.assertIn("--arg tag", script)
        self.assertIn("--arg digest", script)
        self.assertIn("Authorization: Bearer", script)
        self.assertIn("exit 1", script)
        self.assertNotIn("DISPATCH_TOKEN", script)
        self.assertNotIn("gh api", script)
        self.assertNotIn("client_payload", script)

    def test_downstream_step_remains_manual_dispatch(self):
        block = self.by_name["Notify downstream repo"]
        self.assertIn("if: github.event_name != 'push'", block)
        script = run_script(block)
        self.assertIn("gh api", script)
        self.assertIn("DISPATCH_TOKEN", script)
        self.assertIn("client_payload[sha]", script)
        self.assertIn("exit 0", script)

    def test_publish_step_sits_between_build_and_downstream(self):
        names = [step_name(block) for block in self.steps]
        build = names.index("Build and push")
        publish = names.index("Notify image publish endpoint")
        downstream = names.index("Notify downstream repo")
        self.assertEqual(publish, build + 1)
        self.assertEqual(downstream, publish + 1)

    def test_auto_release_workflow_has_no_publish_identity(self):
        self.assertNotIn("id-token", self.auto)
        self.assertNotIn(AUDIENCE, self.auto)


if __name__ == "__main__":
    unittest.main()

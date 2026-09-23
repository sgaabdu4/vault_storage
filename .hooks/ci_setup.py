"""Adapt existing CI and generate only explicitly configured new workflows."""

import json
import math
import re
import sys
from pathlib import Path

import yaml
from gate_config import GateConfig
from project_setup import dependency_command

MAINTENANCE_EVENTS = {"schedule", "workflow_dispatch"}
OLD_TRIGGERS = (
    "on:\n  push:\n    branches-ignore:\n      - 'feature/**'\n  pull_request:\n"
)
OLD_BASE = "${{ github.event.pull_request.base.sha || github.event.before }}"
NEW_BASE = "${{ inputs.base_sha || github.event.pull_request.base.sha || github.event.before }}"


def workflow_triggers(source: Path, base: str) -> tuple[str, str]:
    """The template trigger block and its copy for the project's base branch."""
    template = (source / ".github/workflows/hard-eng.yml").read_text()
    block = template[template.index("on:\n") : template.index("\n\npermissions:") + 1]
    return block, block.replace("      - main\n", f"      - {base}\n", 1)


def migrate_workflow_triggers(root: Path, source: Path, content: str) -> str:
    """Move generated push/PR triggers to default-branch pushes plus workflow_call."""
    from shipping import load_policy

    policy = load_policy(root, required=False)
    if policy is None or OLD_TRIGGERS not in content:
        return content
    _, triggers = workflow_triggers(source, policy["base"])
    return content.replace(OLD_TRIGGERS, triggers, 1).replace(OLD_BASE, NEW_BASE, 1)


def workflow_budget(root: Path, content: str) -> str:
    from shipping import load_policy

    policy = load_policy(root, required=False)
    if policy is None:
        return content
    return re.sub(
        r"(?m)^    timeout-minutes: \d+$",
        f"    timeout-minutes: {math.ceil(policy['ci_seconds'] / 60)}",
        content,
    )


def migrate_workflow_pins(content: str) -> str:
    for action, old, new, before, after in (
        (
            "actions/checkout",
            "fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09",
            "3d3c42e5aac5ba805825da76410c181273ba90b1",
            "v5",
            "v7.0.1",
        ),
        (
            "pnpm/setup",
            "c9883cc79df532ad1a7b81bf9ab944ceb090d65c",
            "703c52620218391530e48b9e8870d5c0082e1b9b",
            "v2.0.0",
            "v2.1.0",
        ),
    ):
        content = re.sub(
            rf"(?m)^([ \t]*(?:-[ \t]+)?uses:[ \t]+){re.escape(action)}@{old}([ \t]*(?:#.*)?)$",
            lambda match, action=action, new=new, before=before, after=after: (
                match[1]
                + action
                + "@"
                + new
                + match[2].replace(f"# {before}", f"# {after}", 1)
            ),
            content,
        )
    return content


def migrate_workflow_tools(content: str) -> str:
    launcher = "pnpm dlx --allow-build=@jdxcode/mise --package=@jdxcode/mise@latest mise --no-config"
    return re.sub(
        r"(?m)^        run: >-\n"
        r"          pnpm dlx --allow-build=@jdxcode/mise\n"
        r"          --package=@jdxcode/mise@latest mise --no-config exec\n"
        r"          (?P<tools>[^\n]+)\n"
        r"          -- (?P<check>uv run --no-project --with pyyaml python "
        r'\.hooks/hard-eng\.py check --base "\$BASE_SHA")\n',
        lambda match: (
            "        run: |\n"
            f"          {launcher} install {match['tools']} &&\n"
            f"          MISE_FETCH_REMOTE_VERSIONS_CACHE=1h {launcher} exec {match['tools']} -- {match['check']}\n"
        ),
        content,
    )


def migrate_docs_path(source: Path, content: str) -> str:
    """Add the template's docs-only steps to a generated workflow without them."""
    template = (source / ".github/workflows/hard-eng.yml").read_text()
    cache = "      - name: Cache native tool downloads\n"
    checks = "      - name: Run required checks\n"
    if "id: impact" in content:
        return content
    if any(
        content.count(step) != 1 or step + "        if:" in content
        for step in (cache, checks)
    ):
        print(
            "Docs-only CI steps not added: .github/workflows/hard-eng.yml is customised. "
            "Copy the `impact` and docs-only secret scan steps from the Hard Eng template "
            "to skip tool setup when only docs change.",
            file=sys.stderr,
        )
        return content
    impact = template[
        template.index("      - name: Find whether") : template.index(cache)
    ]
    scan = template[
        template.index("      - name: Run the secret") : template.index(checks)
    ]
    condition = "        if: steps.impact.outputs.docs_only != 'true'\n"
    content = content.replace(cache, impact + cache + condition)
    return content.replace(checks, scan + checks + condition)


def workflow_tools(root: Path, config: GateConfig) -> list[str]:
    tools = ["uv@latest", "python@3.12", "node@latest"]
    for package in config["packages"]:
        directory = root / package["path"]
        language = package.get("language")
        if language not in {"python", "javascript", "dart"}:
            continue
        manager, _, _ = dependency_command(directory, language)
        if manager in {"dart", "flutter", "pnpm", "yarn", "bun", "poetry"}:
            version = "latest"
            if language == "javascript":
                declared = json.loads((directory / "package.json").read_text()).get(
                    "packageManager", ""
                )
                if declared.startswith(manager + "@"):
                    version = declared.split("@", 1)[1].split("+", 1)[0]
            specification = manager + "@" + version
            if specification not in tools:
                tools.append(specification)
    if "flutter@latest" in tools and "dart@latest" in tools:
        tools.remove("dart@latest")
    return tools


def migrate_workflow_sdks(root: Path, config: GateConfig, content: str) -> str:
    """Add SDKs that packages added after CI generation need; keep project tools."""
    required = workflow_tools(root, config)[3:]
    pattern = re.compile(
        r"(?m)^(?P<indent> +)(?P<launcher>pnpm dlx \S+ \S+ mise --no-config) "
        r"install (?P<tools>[^&\n]+) &&\n"
        r"(?P=indent)MISE_FETCH_REMOTE_VERSIONS_CACHE=1h (?P=launcher) exec (?P=tools) -- "
    )
    match = pattern.search(content)
    if match is None:
        names = set(re.findall(r"\b([a-z]+)@", content))
        missing = [tool for tool in required if tool.split("@")[0] not in names]
        if missing:
            print(
                "CI tools not added: .github/workflows/hard-eng.yml is customised. "
                f"Add {' '.join(missing)} to its mise install and exec tool lists.",
                file=sys.stderr,
            )
        return content
    tools = match["tools"].split()
    names = {tool.split("@")[0] for tool in tools}
    tools += [tool for tool in required if tool.split("@")[0] not in names]
    if any(tool.startswith("flutter@") for tool in tools):
        tools = [tool for tool in tools if not tool.startswith("dart@")]
    if tools == match["tools"].split():
        return content
    updated = match.group(0).replace(match["tools"], " ".join(tools))
    return content.replace(match.group(0), updated, 1)


def maintenance_workflows_only(workflows: list[Path]) -> bool:
    """Allow a generated quality owner beside scheduled/manual maintenance jobs."""
    if not workflows:
        return False
    for path in workflows:
        try:
            workflow = yaml.safe_load(path.read_text())
        except yaml.YAMLError:
            return False
        if not isinstance(workflow, dict):
            return False
        triggers = workflow.get("on", workflow.get(True))
        events = (
            {triggers}
            if isinstance(triggers, str)
            else set(triggers)
            if isinstance(triggers, (list, dict))
            and all(isinstance(event, str) for event in triggers)
            else set()
        )
        if not events or not events <= MAINTENANCE_EVENTS:
            return False
        jobs = workflow.get("jobs")
        if isinstance(jobs, dict) and any(
            isinstance(step, dict)
            and isinstance(step.get("run"), str)
            and re.search(r"\.hooks/hard-eng\.py\s+check(?:\s|$)", step["run"])
            for job in jobs.values()
            if isinstance(job, dict) and isinstance(job.get("steps"), list)
            for step in job["steps"]
        ):
            return False
    return True


def configure_ci(
    root: Path, source: Path, config: GateConfig, changes: dict[str, str]
) -> None:
    name = ".github/workflows/hard-eng.yml"
    if (root / name).exists():
        original = (root / name).read_text()
        migrated = migrate_workflow_tools(migrate_workflow_pins(original))
        migrated = migrate_workflow_sdks(root, config, migrated)
        migrated = migrate_workflow_triggers(
            root, source, migrate_docs_path(source, migrated)
        )
        if migrated != original:
            changes[name] = migrated
        return
    workflows = [
        path
        for path in (root / ".github/workflows").glob("*")
        if path.is_file() and path.suffix in {".yml", ".yaml"}
    ]
    if workflows and not maintenance_workflows_only(workflows):
        print(
            "Existing CI retained: integrate missing Hard Eng checks into their current jobs and require those results in shipping.checks; do not add a duplicate full pipeline.",
            file=sys.stderr,
        )
        return
    from shipping import load_policy

    policy = load_policy(root, required=False)
    if policy is None:
        print(
            "CI setup pending: configure project shipping checks and a measured ci_seconds budget, then rerun setup. The source repository's timeout is not a project budget.",
            file=sys.stderr,
        )
        return
    shipping = config.get("shipping")
    checks = shipping.get("checks") if isinstance(shipping, dict) else None
    if not isinstance(checks, list) or not all(
        isinstance(check, str) for check in checks
    ):
        raise ValueError("Generated CI requires shipping checks in gate configuration")
    if "hard-eng" not in checks:
        checks.append("hard-eng")
    tools = workflow_tools(root, config)
    block, triggers = workflow_triggers(source, policy["base"])
    changes[name] = (
        (source / name)
        .read_text()
        .replace("uv@latest python@3.12 node@latest dart@latest", " ".join(tools))
        .replace(block, triggers, 1)
    )
    changes[name] = workflow_budget(root, changes[name])

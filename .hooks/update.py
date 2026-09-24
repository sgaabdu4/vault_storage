"""Install a CI-verified upstream revision with an isolated local Git commit."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from operator import itemgetter
from pathlib import Path

UPSTREAM = "sgaabdu4/hard-eng"
REPOSITORY = f"https://github.com/{UPSTREAM}.git"
SOURCE_FILE = ".hooks/hard-eng-source.json"


def github_json(endpoint: str) -> object:
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token and shutil.which("gh"):
        auth = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if auth.returncode == 0:
            token = auth.stdout.strip()
    headers = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"https://api.github.com/{endpoint}", headers=headers
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def verified_revision(revision: str) -> bool:
    report = github_json(f"repos/{UPSTREAM}/commits/{revision}/check-runs?per_page=100")
    if not isinstance(report, dict):
        raise TypeError("GitHub check response must be an object")
    checks: list[dict[str, object]] = [
        check
        for check in report.get("check_runs", [])
        if isinstance(check, dict)
        and check.get("name") == "hard-eng"
        and isinstance(check.get("app"), dict)
        and check.get("app", {}).get("slug") == "github-actions"
    ]
    if not checks:
        return False
    latest = max(checks, key=itemgetter("id"))
    return (
        latest.get("status") == "completed"
        and latest.get("conclusion") == "success"
        and latest.get("head_sha") == revision
    )


def latest_verified(previous: str) -> str | None:
    page = 1
    while True:
        commits = github_json(
            f"repos/{UPSTREAM}/commits?sha=main&per_page=100&page={page}"
        )
        if not isinstance(commits, list):
            raise TypeError("GitHub commits response must be a list")
        if not commits:
            return None
        for commit in commits:
            if not isinstance(commit, dict):
                raise TypeError("GitHub commit must be an object")
            revision = commit["sha"]
            if revision == previous:
                return None
            if not isinstance(revision, str) or not re.fullmatch(
                r"[0-9a-f]{40}", revision
            ):
                raise ValueError("GitHub returned an invalid commit")
            if verified_revision(revision):
                return revision
        page += 1


def require_current(root: Path) -> None:
    """Check installed-scaffold freshness without changing verified work."""
    marker = root / SOURCE_FILE
    if not marker.exists():
        return
    try:
        metadata = json.loads(marker.read_text())
        previous = metadata.get("revision") if isinstance(metadata, dict) else None
        if not isinstance(previous, str) or not re.fullmatch(r"[0-9a-f]{40}", previous):
            raise ValueError("installed revision is not a published commit")
        revision = latest_verified(previous)
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as error:
        raise ValueError(
            f"Hard Eng freshness could not be verified: {error}"
        ) from error
    if revision is not None:
        raise ValueError(
            f"Hard Eng freshness check found newer verified revision {revision}. "
            "Use the supported updater, preserve local edits, then reverify before shipping or claiming completion."
        )


def fetch_sources(temporary: Path, revision: str, previous: str) -> tuple[Path, Path]:
    source, old = temporary / "source", temporary / "previous"
    subprocess.run(
        [
            "git",
            "clone",
            "--quiet",
            "--filter=blob:none",
            REPOSITORY,
            str(source),
        ],
        check=True,
        timeout=120,
    )
    subprocess.run(
        ["git", "checkout", "--quiet", "--detach", revision],
        cwd=source,
        check=True,
        timeout=60,
    )
    subprocess.run(
        ["git", "merge-base", "--is-ancestor", previous, revision],
        cwd=source,
        check=True,
        timeout=30,
    )
    subprocess.run(
        ["git", "worktree", "add", "--quiet", "--detach", str(old), previous],
        cwd=source,
        check=True,
        timeout=60,
    )
    for tree in (source, old):
        if (tree / ".gitmodules").is_file():
            subprocess.run(
                ["git", "submodule", "update", "--init", "--recursive"],
                cwd=tree,
                check=True,
                timeout=120,
            )
    return source, old


def scaffold_files(source: Path) -> set[str]:
    from gate_config import repository_files

    skills = list((source / ".agents/skills").iterdir())
    if any(skill.is_symlink() and not skill.is_dir() for skill in skills):
        raise ValueError(
            "Unresolved skill link; run git submodule update --init --recursive"
        )
    return {
        str(path.relative_to(source)) for path in (source / ".hooks").glob("*.py")
    } | {
        str(path.relative_to(source))
        for skill in [
            source / ".agents/skills",
            *(skill for skill in skills if skill.is_symlink()),
        ]
        for path in repository_files(skill)
    }


def without_skills(files: set[str], skills: set[str]) -> set[str]:
    return {
        name
        for name in files
        if not any(name.startswith(f".agents/skills/{skill}/") for skill in skills)
    }


def pre_push_missing(root: Path) -> bool:
    from agent_hooks import project_pre_push

    hook = Path(
        subprocess.check_output(
            ["git", "rev-parse", "--git-path", "hooks/pre-push"],
            cwd=root,
            text=True,
        ).strip()
    )
    hook = hook if hook.is_absolute() else root / hook
    target = project_pre_push(root, hook)
    return not target.exists() and not target.is_symlink()


def planned_hook(root: Path, plan: object) -> tuple[str, str]:
    if not isinstance(plan, dict):
        raise TypeError("Setup plan must be an object")
    hook = plan.get("hook")
    if not isinstance(hook, dict):
        raise TypeError("Setup plan is missing the pre-push hook")
    hook_path, hook_content = hook.get("path"), hook.get("content")
    if not isinstance(hook_path, str) or not isinstance(hook_content, str):
        raise TypeError("Setup plan has an invalid pre-push hook")
    if hook_path == ".husky/pre-push":
        if (root / hook_path).is_symlink():
            raise ValueError("Preserve the existing hook symlink before updating")
        files = plan.get("files")
        if not isinstance(files, dict):
            raise TypeError("Setup plan must include file changes")
        files[hook_path] = hook_content
    return hook_path, hook_content


def update_plan(
    root: Path, source: Path, previous: Path
) -> tuple[dict[str, str | None], dict[str, str | None], tuple[str, str]]:
    output = subprocess.check_output(
        [
            "uv",
            "run",
            "--project",
            str(source),
            "--locked",
            "--no-dev",
            "--python",
            sys.executable,
            "python",
            str(source / "setup.py"),
            str(root),
            "--plan",
            "--previous-source",
            str(previous),
        ],
        cwd=root,
        text=True,
        timeout=60,
    )
    plan = json.loads(output)
    hook = planned_hook(root, plan)
    changes: dict[str, str | None] = {
        name: content
        for name, content in plan["files"].items()
        if not (root / name).is_file() or (root / name).read_text() != content
    }
    skills = {path.name for path in (source / ".agents/skills").iterdir()}
    unused = skills - {Path(name).name for name in plan["links"]}
    for name in scaffold_files(previous) - without_skills(
        scaffold_files(source), unused
    ):
        target = root / name
        if target.exists():
            if (
                target.is_symlink()
                or target.read_bytes() != (previous / name).read_bytes()
            ):
                raise ValueError(
                    f"Local scaffold edit in {name}; preserve it and ask before updating"
                )
            changes[name] = None
    links: dict[str, str | None] = {
        name: target
        for name, target in plan["links"].items()
        if not (root / name).is_symlink()
    }
    removed_skills = {path.name for path in (previous / ".agents/skills").iterdir()} - (
        skills - unused
    )
    for skill in removed_skills:
        name = ".claude/skills/" + skill
        link = root / name
        if link.is_symlink() and link.resolve() == root / ".agents/skills" / skill:
            links[name] = None
        elif link.exists() or link.is_symlink():
            raise ValueError(f"Local skill link differs: {name}")
    return changes, links, hook


def write_changes(root: Path, changes: dict[str, str | None]) -> None:
    for name, content in changes.items():
        target = root / name
        if content is None:
            target.unlink(missing_ok=True)
            for parent in target.parents:
                if parent == root or not parent.is_dir() or any(parent.iterdir()):
                    break
                parent.rmdir()
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)


def write_links(root: Path, links: dict[str, str | None]) -> None:
    for name, target in links.items():
        link = root / name
        if target is None:
            link.unlink(missing_ok=True)
        else:
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(target, target_is_directory=True)


def install_planned_hook(root: Path, hook: tuple[str, str]) -> bool:
    name, content = hook
    target = root / name
    if (
        target.is_file()
        and not target.is_symlink()
        and target.read_text() == content
        and target.stat().st_mode & 0o111
    ):
        return False
    if target.is_symlink():
        target.unlink()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    target.chmod(0o755)
    return True


def verify_candidate(
    root: Path,
    source: Path,
    changes: dict[str, str | None],
    links: dict[str, str | None],
    candidate: Path,
) -> None:
    # Both callers already verified upstream CI for this exact source revision.
    subprocess.run(
        ["git", "worktree", "add", "--quiet", "--detach", str(candidate), "HEAD"],
        cwd=root,
        check=True,
    )
    try:
        if (candidate / ".gitmodules").is_file():
            subprocess.run(
                ["git", "submodule", "update", "--init", "--recursive"],
                cwd=candidate,
                check=True,
            )
        write_changes(candidate, changes)
        write_links(candidate, links)
        names = sorted({*changes, *links})
        if names:
            subprocess.run(
                ["git", "add", "--force", "--", *names],
                cwd=candidate,
                check=True,
            )
        subprocess.run(
            ["git", "diff", "--cached", "--check"], cwd=candidate, check=True
        )
        only_scaffold = set(changes) <= scaffold_files(source) | scaffold_files(
            root
        ) | {
            "AGENTS.md",
            "CLAUDE.md",
            "AGENTS.override.md",
            SOURCE_FILE,
            ".husky/pre-push",
        }
        command = (
            [
                sys.executable,
                "-I",
                "-c",
                """import compileall, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from gate_config import parse_config
from gitleaks_scan import validate_current_files_gate
config = parse_config(Path('hard-eng.gates.json').read_text())
gates = config['shared'] + [gate for group in config['packages'] for gate in group['checks']]
for gate in gates:
    validate_current_files_gate(gate.get('role'), gate['command'])
raise SystemExit(not compileall.compile_dir('.hooks', quiet=1))
""",
                str(source / ".hooks"),
            ]
            if only_scaffold
            else [
                "uv",
                "run",
                "--project",
                str(source),
                "--locked",
                "--no-dev",
                "--python",
                sys.executable,
                "python",
                "-I",
                "-c",
                (
                    "import runpy, sys; "
                    "sys.path.insert(0, '.hooks'); "
                    "raise SystemExit(runpy.run_path('.hooks/hard-eng.py')['check']("
                    "base=sys.argv[1], verify_plan=False))"
                ),
            ]
        )
        if not only_scaffold:
            from ship_actions import remote_base
            from shipping import load_policy

            policy = load_policy(candidate, required=False)
            # An update candidate is verification input, not a completed task.
            if (
                "origin"
                in subprocess.check_output(
                    ["git", "remote"], cwd=candidate, text=True
                ).splitlines()
            ):
                command.append(
                    remote_base(candidate, policy["base"] if policy else None)
                )
            else:
                command.append("HEAD")
        subprocess.run(
            command, cwd=candidate, stdout=sys.stderr, check=True, timeout=3500
        )
    finally:
        subprocess.run(
            ["git", "worktree", "remove", "--force", str(candidate)],
            cwd=root,
            check=True,
        )


def commit_update(
    root: Path,
    changes: dict[str, str | None],
    links: dict[str, str | None],
    revision: str,
) -> None:
    names = sorted({*changes, *links})
    before = {
        name: (root / name).read_bytes() if (root / name).exists() else None
        for name in changes
    }
    before_links = {
        name: str((root / name).readlink()) if (root / name).is_symlink() else None
        for name in links
    }
    try:
        write_changes(root, changes)
        write_links(root, links)
        subprocess.run(
            ["git", "add", "--force", "--", *names],
            cwd=root,
            check=True,
        )
        message = f"Update Hard Eng to {revision}"
        result = subprocess.run(
            [
                "git",
                "commit",
                "--only",
                "-m",
                message,
                "--",
                *names,
            ],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
            timeout=3500,
        )
        sys.stderr.write(result.stdout)
        if result.returncode != 0:
            # SessionStart stderr never reaches the agent, so the error carries the reason.
            tail = " | ".join(result.stdout.strip().splitlines()[-5:])
            raise subprocess.SubprocessError(
                f"git commit exited {result.returncode}: {tail}".removesuffix(": ")
            )
    except (OSError, subprocess.SubprocessError):
        for name, content in before.items():
            target = root / name
            if content is None:
                target.unlink(missing_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
        for name, target in before_links.items():
            (root / name).unlink(missing_ok=True)
            if target is not None:
                (root / name).symlink_to(target, target_is_directory=True)
        subprocess.run(
            ["git", "reset", "--quiet", "HEAD", "--", *names], cwd=root, check=True
        )
        raise


def repair_current_hook(root: Path, previous: str) -> str:
    if not pre_push_missing(root):
        return "No newer CI-verified Hard Eng revision is available."
    with tempfile.TemporaryDirectory(prefix="hard-eng-update-") as temporary:
        source, old = fetch_sources(Path(temporary), previous, previous)
        _, _, hook = update_plan(root, source, old)
        install_planned_hook(root, hook)
    return "No newer CI-verified Hard Eng revision is available; installed the missing pre-push hook."


def update(root: Path) -> str:
    marker = root / SOURCE_FILE
    if not marker.exists():
        return "Automatic update unavailable: this checkout has no installed source revision."
    metadata = json.loads(marker.read_text())
    if not isinstance(metadata, dict):
        raise TypeError("Installed source metadata must be an object")
    previous = metadata.get("revision")
    if not isinstance(previous, str) or not re.fullmatch(r"[0-9a-f]{40}", previous):
        return "Installed from an uncommitted working copy; publish a verified source revision before automatic updates."
    revision = latest_verified(previous)
    if revision is None:
        return repair_current_hook(root, previous)
    with tempfile.TemporaryDirectory(prefix="hard-eng-update-") as temporary:
        source, old = fetch_sources(Path(temporary), revision, previous)
        changes, links, hook = update_plan(root, source, old)
        if not changes and not links:
            install_planned_hook(root, hook)
            return "Hard Eng already matches the verified source."
        names = sorted({*changes, *links})
        if subprocess.check_output(
            [
                "git",
                "status",
                "--porcelain",
                "--untracked-files=all",
                "--ignored",
                "--",
                *names,
            ],
            cwd=root,
            text=True,
        ):
            raise ValueError(
                "The update overlaps local edits; preserve them and ask before updating"
            )
        before = {
            name: (root / name).read_bytes() if (root / name).exists() else None
            for name in changes
        }
        verify_candidate(root, source, changes, links, Path(temporary) / "candidate")
        if any(
            ((root / name).read_bytes() if (root / name).exists() else None) != content
            for name, content in before.items()
        ):
            raise ValueError(
                "Files changed during verification; the update was not applied"
            )
        if subprocess.check_output(
            [
                "git",
                "status",
                "--porcelain",
                "--untracked-files=all",
                "--ignored",
                "--",
                *names,
            ],
            cwd=root,
            text=True,
        ):
            raise ValueError(
                "The update paths changed during verification; nothing was applied"
            )
        commit_update(root, changes, links, revision)
        if hook[0] not in changes:
            install_planned_hook(root, hook)
    return f"Updated Hard Eng to {revision}; created an isolated local commit without pushing."


def check_scaffold_update(root: Path, base: str) -> bool:
    marker = root / SOURCE_FILE
    if not marker.is_file():
        return False
    # Only a committed installation update can use this exemption. Local work
    # and uncertain impact retain the normal application checks.
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True):
        return False
    try:
        revision = json.loads(marker.read_text()).get("revision")
        previous = json.loads(
            subprocess.check_output(
                ["git", "show", f"{base}:{SOURCE_FILE}"],
                cwd=root,
                text=True,
                stderr=subprocess.DEVNULL,
            )
        ).get("revision")
        names = set(
            subprocess.check_output(
                ["git", "diff", "--name-only", "--no-renames", "-z", base, "--"],
                cwd=root,
                text=True,
            ).split("\0")
        ) - {""}
    except (subprocess.CalledProcessError, ValueError, AttributeError):
        return False
    if (
        SOURCE_FILE not in names
        or revision == previous
        or not all(
            isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value)
            for value in (previous, revision)
        )
    ):
        return False
    if not isinstance(previous, str) or not isinstance(revision, str):
        return False
    if not verified_revision(revision):
        raise ValueError(
            "Scaffold update does not identify a successful upstream hard-eng check"
        )
    with tempfile.TemporaryDirectory(prefix="hard-eng-scaffold-check-") as temporary:
        source, old = fetch_sources(Path(temporary), revision, previous)
        allowed = (
            scaffold_files(source)
            | scaffold_files(old)
            | {
                SOURCE_FILE,
                "AGENTS.md",
                "CLAUDE.md",
                "AGENTS.override.md",
                ".husky/pre-push",
            }
        )
        allowed |= {
            ".claude/skills/" + path.name
            for tree in (source, old)
            for path in (tree / ".agents/skills").iterdir()
            if path.is_dir()
        }
        changes, links, _ = update_plan(root, source, source)
        if not names <= allowed or changes or links:
            return False
        if any(
            (root / name).exists()
            for name in scaffold_files(old) - scaffold_files(source)
        ):
            return False
        if not preserved_instructions(root, base, names):
            return False
        print(
            "Scaffold-only update: source CI verified; checking installed Python hooks.",
            flush=True,
        )
        verify_candidate(root, source, {}, {}, Path(temporary) / "candidate")
    return True


def preserved_instructions(root: Path, base: str, names: set[str]) -> bool:
    end = "<!-- hard-eng:end -->\n\n"
    for name in names & {"AGENTS.md", "CLAUDE.md", "AGENTS.override.md"}:
        blob = f"{base}:{name}"
        original = subprocess.run(
            ["git", "show", blob],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
        ).stdout
        if original.split(end, 1)[-1] != (root / name).read_text().split(end, 1)[-1]:
            return False
    return True

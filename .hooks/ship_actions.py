"""Guard the mutations following verified PR delivery."""

import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from shipping import (
    PendingCheck,
    Shipment,
    ShippingError,
    gh,
    git,
    load_policy,
    verify,
)
from update import require_current


def remote_base(root: Path, branch: str | None) -> str:
    reference = f"refs/heads/{branch}" if branch else "HEAD"
    advertised = git(root, "ls-remote", "--exit-code", "origin", reference).split()
    if (
        len(advertised) != 2
        or advertised[1] != reference
        or re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", advertised[0]) is None
    ):
        raise ValueError("Cannot resolve the current remote base")
    revision = advertised[0]
    git(root, "fetch", "--no-tags", "--no-write-fetch-head", "origin", revision)
    return revision


def pre_push(root: Path) -> int:
    policy = load_policy(root)
    assert policy is not None
    started = time.monotonic()
    for line in sys.stdin:
        fields = line.split()
        if len(fields) != 4:
            raise ValueError("Invalid pre-push input")
        revision = fields[1]
        if fields[2] == f"refs/heads/{policy['base']}":
            raise ValueError(
                "Push a task branch and use a PR; direct base updates are blocked"
            )
        if set(revision) == {"0"}:
            continue
        base = fields[3]
        if set(base) == {"0"}:
            base = remote_base(root, policy["base"])
        environment = os.environ.copy()
        for name in git(root, "rev-parse", "--local-env-vars").splitlines():
            environment.pop(name, None)
        with tempfile.TemporaryDirectory(prefix="hard-eng-push-") as temporary:
            checkout = Path(temporary) / "project"
            subprocess.run(
                ["git", "worktree", "add", "--detach", str(checkout), revision],
                cwd=root,
                env=environment,
                check=True,
            )
            try:
                if (checkout / ".gitmodules").is_file():
                    subprocess.run(
                        ["git", "submodule", "update", "--init", "--recursive"],
                        cwd=checkout,
                        env=environment,
                        check=True,
                    )
                result = subprocess.run(
                    [
                        sys.executable,
                        str(checkout / ".hooks/hard-eng.py"),
                        "check",
                        "--base",
                        base,
                    ],
                    cwd=checkout,
                    env=environment,
                    check=False,
                )
                if result.returncode:
                    return result.returncode
            finally:
                subprocess.run(
                    ["git", "worktree", "remove", "--force", str(checkout)],
                    cwd=root,
                    env=environment,
                    check=True,
                )
        if time.monotonic() - started > policy["pre_push_seconds"]:
            raise ValueError(
                "Pre-push verification exceeded its configured time budget"
            )
    print(f"Pre-push verification: {time.monotonic() - started:.2f}s")
    return 0


def worktrees(root: Path) -> list[dict[str, str]]:
    records = git(root, "worktree", "list", "--porcelain", "-z")
    return [
        dict(field.partition(" ")[::2] for field in record.split("\0") if field)
        for record in records.split("\0\0")
        if record
    ]


def common_directory(root: Path) -> Path:
    return Path(
        git(root, "rev-parse", "--path-format=absolute", "--git-common-dir").strip()
    ).resolve()


def unchanged_checkout(shipment: Shipment) -> None:
    target = shipment.root.resolve()
    index_lock = Path(git(target, "rev-parse", "--git-path", "index.lock").strip())
    if (target / index_lock).exists():
        raise ValueError("Cleanup preserves a task with an active Git index lock")
    if git(
        target,
        "status",
        "--porcelain",
        "--untracked-files=all",
        "--ignored=matching",
        "--ignore-submodules=none",
    ).strip():
        raise ValueError("Cleanup preserves modified, untracked or ignored work")
    if git(target, "rev-parse", "HEAD").strip() != shipment.head_sha:
        raise ValueError("Cleanup preserves commits added after the verified PR")


def cleanup_guard(coordinator: Path, shipment: Shipment) -> None:
    target = shipment.root.resolve()
    if common_directory(coordinator) != common_directory(target):
        raise ValueError("Cleanup target is not in the coordinator's repository")
    if Path.cwd().resolve().is_relative_to(target):
        raise ValueError("Run cleanup outside the task's current worktree")
    records = worktrees(coordinator)
    if not records or Path(records[0]["worktree"]).resolve() == target:
        raise ValueError("The main worktree must be preserved")
    matches = [
        record for record in records if Path(record["worktree"]).resolve() == target
    ]
    if len(matches) != 1 or "locked" in matches[0] or "prunable" in matches[0]:
        raise ValueError("Cleanup needs one available, unlocked task worktree")
    branch = f"refs/heads/{shipment.branch}"
    if matches[0].get("branch") != branch:
        raise ValueError("Cleanup target no longer owns the verified task branch")
    if sum(record.get("branch") == branch for record in records) != 1:
        raise ValueError("Another worktree uses the task branch")
    unchanged_checkout(shipment)
    if any(
        not line.startswith("-")
        for line in git(target, "submodule", "status", "--recursive").splitlines()
    ):
        raise ValueError(
            "Cleanup preserves initialized submodules; use the repository's procedure"
        )
    if shipment.branch == shipment.base or not shipment.merged_sha:
        raise ValueError("Cleanup requires a merged task branch, never the base")


def remote_branch(root: Path, remote: str, branch: str) -> str | None:
    lines = git(root, "ls-remote", "--heads", remote, f"refs/heads/{branch}")
    rows = [line.split() for line in lines.splitlines() if line.strip()]
    if not rows:
        return None
    if len(rows) != 1 or len(rows[0]) != 2 or rows[0][1] != f"refs/heads/{branch}":
        raise ValueError("Task remote branch is ambiguous")
    return rows[0][0]


def cleanup(coordinator: Path, shipment: Shipment) -> None:
    cleanup_guard(coordinator, shipment)
    if (
        git(shipment.root, "remote", "get-url", shipment.remote).strip()
        != shipment.remote_url
    ):
        raise ValueError(
            "Cleanup preserves a task whose remote changed after verification"
        )
    push_urls = git(
        shipment.root, "remote", "get-url", "--push", "--all", shipment.remote
    ).splitlines()
    if push_urls != [shipment.remote_url]:
        raise ValueError("Cleanup preserves a task with a different push endpoint")
    remote_head = remote_branch(shipment.root, shipment.remote_url, shipment.branch)
    if remote_head not in (None, shipment.head_sha):
        raise ValueError("Cleanup preserves a remote branch with additional work")
    if remote_head is not None:
        reference = f"refs/heads/{shipment.branch}"
        git(
            shipment.root,
            "push",
            f"--force-with-lease={reference}:{shipment.head_sha}",
            shipment.remote_url,
            f":{reference}",
        )
        if (
            remote_branch(shipment.root, shipment.remote_url, shipment.branch)
            is not None
        ):
            raise ValueError("Remote branch still exists; local worktree retained")
        print(f"Removed remote task branch {shipment.branch}", flush=True)
    tracking = f"refs/remotes/{shipment.remote}/{shipment.branch}"
    references = git(coordinator, "for-each-ref", "--format=%(refname)", tracking)
    if tracking in references.splitlines():
        git(coordinator, "update-ref", "-d", tracking, shipment.head_sha)
    cleanup_guard(coordinator, shipment)
    # Git refuses any worktree with a submodule gitlink; the guard proved it clean.
    git(coordinator, "worktree", "remove", "--force", str(shipment.root))
    print(f"Removed task worktree {shipment.root}", flush=True)
    git(
        coordinator,
        "update-ref",
        "-d",
        f"refs/heads/{shipment.branch}",
        shipment.head_sha,
    )
    print(f"Removed local task branch {shipment.branch}", flush=True)


def run(
    coordinator: Path,
    plan: str,
    pr_url: str,
    stage: str,
    worktree: str | None,
    merge_method: str | None,
) -> int:
    target = Path(worktree).resolve() if worktree else coordinator.resolve()
    if common_directory(coordinator) != common_directory(target):
        raise ValueError("Shipping target belongs to a different repository")
    plan_path = (target / plan).resolve()
    if not plan_path.is_relative_to(target):
        raise ValueError("Use the selected task's plan inside its worktree")
    if stage not in {"ready", "merge", "delivered", "cleanup"}:
        raise ValueError("Unknown shipping stage")
    if stage == "merge" and merge_method not in {"merge", "squash", "rebase"}:
        raise ValueError("Select the repository's merge method with --merge-method")
    proof_stage = "ready" if stage in {"ready", "merge"} else "delivered"
    require_current(target)
    shipment = verify(target, plan_path, pr_url, proof_stage)
    if stage == "merge":
        if shipment.delivery_target == "PR":
            raise ValueError("The plan authorizes PR delivery, not merging")
        gh(
            target,
            "pr",
            "merge",
            pr_url,
            f"--{merge_method}",
            "--match-head-commit",
            shipment.head_sha,
        )
        try:
            shipment = verify(target, plan_path, pr_url, "delivered")
        except PendingCheck as error:
            raise ShippingError(
                f"Merged; base-branch CI has not finished ({error}). Run ship "
                "--stage delivered once it completes; do not retry the merge."
            ) from error
        except ShippingError as error:
            raise ShippingError(
                "Merge command succeeded; post-merge delivery verification is pending "
                f"or failed: {error}. Inspect the PR before retrying and do not claim "
                "that the merge was undone."
            ) from error
    if stage == "cleanup":
        cleanup(coordinator, shipment)
    revision = shipment.merged_sha or shipment.head_sha
    print(f"PASS ship {stage}: {pr_url} at {revision}")
    return 0

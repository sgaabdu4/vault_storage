"""Review and traverse explicit package-impact dependencies."""

from __future__ import annotations

from collections import deque
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from gate_config import Group


def dependency_review_guidance(packages: list[Group]) -> str | None:
    if len(packages) < 2:
        return None
    missing = [group["path"] for group in packages if "depends_on" not in group]
    if not missing:
        return None
    return (
        "Review `depends_on` in hard-eng.gates.json for "
        + ", ".join(missing)
        + "; list direct internal dependencies, including root "
        "packages that supply shared lockfiles or tools. Use [] only after review "
        "confirms none."
    )


def expand_dependents(
    packages: list[Group], by_path: dict[str, Group], selected: set[str]
) -> set[str]:
    dependents: dict[str, list[str]] = {name: [] for name in by_path}
    for group in packages:
        for dependency in group["depends_on"]:
            if dependency not in by_path:
                raise ValueError(f"Unknown package dependency: {dependency}")
            dependents[dependency].append(group["path"])
    pending = deque(selected)
    while pending:
        for dependent in dependents[pending.popleft()]:
            if dependent not in selected:
                selected.add(dependent)
                pending.append(dependent)
    return selected


def secrets_only(shared: Group) -> Group:
    """Plans and top-level docs are read only by the secret scan."""
    print("Only plans or top-level docs changed; running the secret scan only.")
    roles = {"secrets-files", "secrets-history"}
    checks = [gate for gate in shared["checks"] if gate.get("role") in roles]
    return {**shared, "checks": checks}

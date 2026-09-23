"""Provision current native tools before concurrent gate execution."""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from fallow_report import native_scanner_command
from gate_config import Group
from project_setup import package_script_invocation

NATIVE_SCANNERS = {
    "dart-decimate": "dart-decimate",
    "react-doctor": "React Doctor",
}
MANAGED_PYTHON_SCANNERS = {"ruff", "pyrefly", "vulture", "semgrep", "zizmor", "poetry"}


def ensure_python_runtime() -> None:
    """Run the installed CLI with its YAML dependency without changing host Python."""
    if importlib.util.find_spec("yaml") is None:
        os.execvp(
            "uv",
            [
                "uv",
                "run",
                "--no-project",
                "--with",
                "pyyaml",
                "--python",
                sys.executable,
                "python",
                *sys.argv,
            ],
        )


def managed_command(command: list[str], directory: Path | None = None) -> list[str]:
    if directory is not None:
        command = managed_scanner_command(command, directory)
    if command[0] in MANAGED_PYTHON_SCANNERS:
        return ["uvx", command[0] + "@latest", *command[1:]]
    return command


def managed_scanner_command(command: list[str], directory: Path) -> list[str]:
    """Keep supported scanner arguments without a stale package-local binary."""
    arguments, resolved = package_script_invocation(command, directory)
    invocation = native_scanner_command(arguments)
    if invocation is not None:
        scanner = (
            "Fallow" if invocation[0] == "fallow" else NATIVE_SCANNERS[invocation[0]]
        )
        if resolved.resolve() != directory.resolve():
            raise ValueError(
                f"Configure the {scanner} gate in its explicit package directory"
            )
        if any(value in arguments for value in ("&&", "||", ";", "|", ">", "2>")):
            if scanner == "Fallow":
                raise ValueError(
                    "Fallow audit must be one native invocation with its arguments"
                )
            raise ValueError(
                f"{scanner} must be one native invocation with its arguments"
            )
        return invocation
    return command


def provision_tools(root: Path, groups: list[Group], timeout: float) -> None:
    packages = {
        "uv": "uv",
        "gitleaks": "aqua:gitleaks/gitleaks",
        "osv-scanner": "aqua:google/osv-scanner",
        "actionlint": "aqua:rhysd/actionlint",
        "shellcheck": "aqua:koalaman/shellcheck",
        "trivy": "aqua:aquasecurity/trivy",
        "biome": "npm:@biomejs/biome",
        "tsc": "npm:typescript",
        "fallow": "npm:fallow",
        "dart-decimate": 'npm:dart-decimate[allow_builds=["dart-decimate"]]',
        "react-doctor": "npm:react-doctor",
        "jscpd": "npm:jscpd",
        "lhci": "npm:@lhci/cli",
        "k6": "aqua:grafana/k6",
    }
    commands = [
        package_script_invocation(
            managed_scanner_command(gate["command"], root / group["path"]),
            root / group["path"],
        )[0]
        for group in groups
        for gate in group["checks"]
    ]
    executables = {command[0] for command in commands}
    if executables & MANAGED_PYTHON_SCANNERS:
        executables.add("uv")
    executables.update(
        argument
        for command in commands
        for argument in command[1:]
        if argument in packages
    )
    selected = sorted(
        packages[name] + "@latest" for name in executables & packages.keys()
    )
    for use_npm in (False, True):
        batch = [
            item
            for item in selected
            if item.startswith("npm:dart-decimate[") == use_npm
        ]
        if not batch:
            continue
        provision_batch(root, batch, timeout, use_npm=use_npm)


def provision_batch(
    root: Path, batch: list[str], timeout: float, *, use_npm: bool
) -> None:
    storage = (
        Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir())) / "hard-eng-tools"
    )
    environment = os.environ.copy()
    for name, directory in {
        "MISE_DATA_DIR": "mise/data",
        "MISE_CACHE_DIR": "mise/cache",
        "MISE_STATE_DIR": "mise/state",
        "PNPM_CONFIG_STORE_DIR": "pnpm/store",
        "PNPM_CONFIG_CACHE_DIR": "pnpm/cache",
        "NPM_CONFIG_CACHE": "npm/cache",
    }.items():
        environment.setdefault(name, str(storage / directory))
    data_directory = Path(environment["MISE_DATA_DIR"])
    if shutil.which("gh"):
        environment.setdefault(
            "MISE_GITHUB_CREDENTIAL_COMMAND",
            'gh auth token --hostname "$MISE_CREDENTIAL_HOST"',
        )
    command = [
        "env",
        *(["MISE_NPM_PACKAGE_MANAGER=npm"] if use_npm else []),
        "MISE_PREFER_OFFLINE=false",
        "MISE_USE_VERSIONS_HOST=false",
        "MISE_MINIMUM_RELEASE_AGE=0s",
        "pnpm",
        "dlx",
        "--allow-build=@jdxcode/mise",
        "--package=@jdxcode/mise@latest",
        "mise",
        "--no-config",
    ]
    print("Prepare latest native tools: " + ", ".join(batch), flush=True)
    for arguments in (["install", *batch], ["env", "--json", *batch]):
        result = subprocess.run(
            [*command, *arguments],
            cwd=root,
            text=True,
            timeout=timeout,
            capture_output=True,
            check=False,
            env={
                **environment,
                "PNPM_CONFIG_DLX_CACHE_MAX_AGE": "0"
                if arguments[0] == "install"
                else "60",
                "MISE_FETCH_REMOTE_VERSIONS_CACHE": "0s"
                if arguments[0] == "install"
                else "1h",
            },
        )
        print(result.stderr, file=sys.stderr, end="")
        result.check_returncode()
        if "Failed to resolve tool version" in result.stderr:
            raise ValueError(
                "Latest tool versions could not be resolved; retry provisioning"
            )
    environment = json.loads(result.stdout)
    if not isinstance(environment, dict) or not isinstance(
        environment.get("PATH"), str
    ):
        raise TypeError("Native tool setup did not return an executable PATH")
    tool_paths = [
        path
        for path in environment["PATH"].split(os.pathsep)
        if Path(path).resolve().is_relative_to(data_directory.resolve())
    ]
    os.environ["PATH"] = os.pathsep.join([*tool_paths, os.environ["PATH"]])

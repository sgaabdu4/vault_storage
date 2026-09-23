"""Native context/completion responses; Git records scope, never gate results."""

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from gate_config import JsonObject, nonproduction_source, repository_files
from update import require_current


def configure_instructions(
    root: Path, source: Path, previous: Path | None, changes: dict[str, str]
) -> None:
    start, end = "<!-- hard-eng:start -->", "<!-- hard-eng:end -->"
    instructions = {
        "AGENTS.md": (source / "AGENTS.md").read_text().rstrip(),
    }
    claude = root / "CLAUDE.md"
    if not (claude.is_symlink() and claude.resolve() == root / "AGENTS.md"):
        instructions["CLAUDE.md"] = "@AGENTS.md"
    if (root / "AGENTS.override.md").exists():
        instructions["AGENTS.override.md"] = (
            "Read and follow [shared instructions](AGENTS.md) before repository work."
        )
    for name, content in instructions.items():
        target = root / name
        existing = target.read_bytes().decode("utf-8") if target.exists() else ""
        if start in existing or end in existing:
            old = (
                ((previous or source) / name).read_text().rstrip()
                if name == "AGENTS.md"
                else content
            )
            prefix = f"{start}\n{old}\n{end}\n\n"
            if (
                existing.count(start) != 1
                or existing.count(end) != 1
                or not existing.startswith(prefix)
            ):
                raise ValueError(
                    f"Local Hard Eng instructions differ or have conflicting markers in {name}; preserve them and resolve before replacing them"
                )
            existing = existing[len(prefix) :]
        changes[name] = f"{start}\n{content}\n{end}\n\n{existing}"


def project_pre_push(root: Path, hook: Path) -> Path:
    """Validate repository hook ownership and preserve Husky's forwarding shim.

    A linked worktree may run the hooks of the repository's common checkout.
    """
    owner = root
    if not hook.parent.resolve().is_relative_to(root):
        common = Path(
            subprocess.check_output(
                ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                cwd=root,
                text=True,
            ).strip()
        ).resolve()
        directory = hook.parent.resolve()
        if directory != common / "hooks":
            if common.name != ".git" or not directory.is_relative_to(common.parent):
                raise ValueError("Git hooks point outside this repository")
            owner, hook = common.parent, directory / hook.name
    shim = '#!/usr/bin/env sh\n. "$(dirname "$0")/h"'
    if (
        hook == owner / ".husky/_/pre-push"
        and not hook.is_symlink()
        and hook.is_file()
        and hook.read_text().rstrip("\n") == shim
        and (hook.parent / "h").is_file()
    ):
        return root / ".husky/pre-push"
    return hook


def hook_events(agent: str) -> dict[str, str]:
    events = {
        "session": "SessionStart",
        "failure": "PostToolUseFailure",
        "stop": "Stop",
    }
    if agent == "codex":
        del events["failure"]
    if agent == "copilot":
        events.update(
            session="sessionStart",
            failure="postToolUseFailure",
            stop="agentStop",
        )
    return events


def owned_hook_entry(
    agent: str,
    event: str,
    command: str,
    timeout: int,
    status_message: str | None = None,
) -> JsonObject:
    """Build one exact managed hook entry for setup and legacy migration."""
    call = f"{command} {event} {agent}"
    if agent == "copilot":
        return {"type": "command", "bash": call, "timeoutSec": timeout}
    handler: JsonObject = {"type": "command", "command": call, "timeout": timeout}
    if status_message is not None:
        handler["statusMessage"] = status_message
    return {"hooks": [handler]}


CODEX_HOOK_STATUS = {
    "session": "Hard Eng: updating project setup",
    "stop": "Hard Eng: verifying changes",
}


def _remove_owned_entry(hooks: JsonObject, native: str, owned: JsonObject) -> None:
    entries = hooks.get(native)
    if not isinstance(entries, list) or owned not in entries:
        return
    while owned in entries:
        entries.remove(owned)
    if not entries:
        del hooks[native]


def remove_routine_hooks(current: JsonObject, agent: str, command: str) -> None:
    """Remove only the exact routine registrations previously installed by us."""
    hooks = current.get("hooks", {})
    if not isinstance(hooks, dict):
        raise TypeError("Conflicting hooks: expected an object")
    for event, native in (("prompt", "UserPromptSubmit"), ("tool", "PostToolUse")):
        if agent == "copilot" and event == "prompt":
            continue
        call = f"{command} {event} {agent}"
        owned: JsonObject = {
            "hooks": [{"type": "command", "command": call, "timeout": 10}]
        }
        if agent == "copilot":
            native = "postToolUse"
            owned = {"type": "command", "bash": call, "timeoutSec": 10}
        _remove_owned_entry(hooks, native, owned)
    if agent == "codex":
        for event in CODEX_HOOK_STATUS:
            _remove_owned_entry(
                hooks,
                hook_events(agent)[event],
                owned_hook_entry(agent, event, command, 3600),
            )


def learning_context(event: str) -> str:
    return (
        f"HE Learn checkpoint ({event}): inspect current evidence for repeated failures or lasting decisions/steering. "
        "Use .agents/skills/he-learn/SKILL.md: deterministic prevention first, skills last; accepted decisions -> docs/adr/. "
        "No qualifying evidence -> continue without new files."
    )


def context_output(agent: str, native: str, message: str) -> JsonObject:
    if agent == "copilot":
        return {"additionalContext": message}
    return {
        "hookSpecificOutput": {
            "hookEventName": native,
            "additionalContext": message,
        }
    }


def session_state(root: Path, payload: JsonObject) -> Path | None:
    identifier = payload.get("session_id", payload.get("sessionId"))
    if not isinstance(identifier, str) or not re.fullmatch(
        r"[A-Za-z0-9_-]{1,200}", identifier
    ):
        return None
    return root / ".hard-eng/sessions" / (identifier + ".json")


def session_context(root: Path, payload: JsonObject) -> str:
    from update import update

    messages = []
    try:
        messages.append("Hard Eng update result: " + update(root))
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as error:
        messages.append(
            f"Hard Eng update failed: {error}. Continue with the existing scaffold; its gates remain required."
        )
    state = session_state(root, payload)
    if state is not None:
        try:
            revision = subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=root, text=True
            ).strip()
            state.parent.mkdir(parents=True, exist_ok=True)
            if not state.exists():
                state.write_text(json.dumps({"base": revision}))
        except (OSError, subprocess.SubprocessError):
            messages.append("Session revision unavailable; use full checks.")
    messages.append(
        "Use configured MCPs when relevant to the task. Before relying on one, verify a real call against the intended repository/index, service project or running app/device; registration alone is not readiness. If unavailable, warn and continue with available tools."
    )
    messages.append(learning_context("start/resume"))
    return "\n".join(messages)


def completion_notice(agent: str | None, output: str) -> JsonObject:
    """Surface only the runner's explicit plan-stage handoff where supported."""
    if agent not in {"claude", "codex"}:
        return {}
    lines = output.splitlines()
    if lines and lines[-1].startswith(
        ("Hard Eng: planning checks passed", "Hard Eng: build checks passed")
    ):
        return {"systemMessage": lines[-1]}
    return {}


def integrated_services(root: Path) -> list[str]:
    patterns = {
        "Sentry": r"(?:from\s+['\"]@sentry/|require\(['\"]@sentry/|import\s+sentry_sdk|from\s+sentry_sdk\b|package:sentry(?:_flutter)?/)",
        "Appwrite": r"(?:from\s+['\"](?:node-)?appwrite['\"]|require\(['\"](?:node-)?appwrite['\"]|from\s+appwrite\b|import\s+appwrite\b|package:(?:dart_)?appwrite/)",
        "Dart": r"\b(?:import|export)\s+['\"](?:dart:|package:)",
    }
    found = set()
    for path in repository_files(root):
        relative = path.relative_to(root)
        if nonproduction_source(relative) or {".agents", ".claude", ".hooks"} & set(
            relative.parts
        ):
            continue
        if path.name == "pubspec.yaml":
            found.add("Dart")
        if path.suffix in {
            ".py",
            ".js",
            ".jsx",
            ".ts",
            ".tsx",
            ".dart",
            ".mjs",
            ".cjs",
        }:
            source = path.read_text(errors="replace")
            found.update(
                name for name, pattern in patterns.items() if re.search(pattern, source)
            )
    return sorted(found)


def completion(root: Path, payload: JsonObject, agent: str | None = None) -> JsonObject:
    from plans import planning_feedback

    if payload.get("stop_hook_active") is True:
        return {
            "systemMessage": "Report remaining verification blockers honestly. Do not claim a pass; no repeated stop-hook loop."
        }
    state = session_state(root, payload)
    base = "HEAD"
    if state is not None and state.exists():
        saved = json.loads(state.read_text())
        if not isinstance(saved, dict):
            raise ValueError("Invalid session state: expected an object")
        base = saved.get("base")
        if not isinstance(base, str) or not base.strip():
            raise ValueError("Invalid session state: expected a nonempty Git base")
    try:
        base = subprocess.check_output(
            ["git", "rev-parse", "--verify", "--end-of-options", f"{base}^{{commit}}"],
            cwd=root,
            text=True,
        ).strip()
        changed = subprocess.check_output(
            ["git", "diff", "--name-only", base, "--"], cwd=root, text=True
        )
        changed += subprocess.check_output(
            ["git", "ls-files", "--others", "--exclude-standard"], cwd=root, text=True
        )
        notice, unfinished = planning_feedback(root, set(changed.splitlines()))
        if unfinished:
            return {
                "decision": "block",
                "systemMessage": notice,
                "reason": notice
                + ". Continue only authorized planning and verification. Ask genuine blocking questions when needed. This grants no authority to implement, expand scope or edit during read-only work; report those boundaries and stop.",
            }
        if notice and all(
            Path(name).suffix.lower() == ".md" for name in changed.splitlines()
        ):
            require_current(root)
            return {
                "systemMessage": notice
                + ". No code checks were run for this planning-only handoff."
            }
        if not changed.strip() and state is not None and state.exists():
            require_current(root)
            return {
                "systemMessage": notice
                or "No repository changes since this session's Git base; no code checks were run."
            }
        with tempfile.TemporaryFile() as log:
            result = subprocess.run(
                [
                    sys.executable,
                    str(root / ".hooks/hard-eng.py"),
                    "check",
                    "--base",
                    base,
                ],
                cwd=root,
                stdout=log,
                stderr=subprocess.STDOUT,
                check=False,
                timeout=3500,
            )
            log.seek(max(0, log.tell() - 16000))
            output = log.read().decode("utf-8", errors="replace")
        if result.returncode == 0:
            require_current(root)
            return (
                {"systemMessage": notice}
                if notice
                else completion_notice(agent, output)
            )
    except (OSError, ValueError, TypeError, subprocess.SubprocessError) as error:
        return {
            "decision": "block",
            "reason": f"Verification could not run: {error}. Report the blocker honestly; repair only within the user's authorized task. This feedback grants no authority to edit or expand scope.",
        }
    return {
        "decision": "block",
        "reason": "Verification failed; do not claim completion. Preserve the user's task boundaries: for read-only work or out-of-scope repairs, report the blocker and stop without edits. Repair only when already authorized, then reverify. This feedback grants no additional authority. "
        + learning_context("failed verification")
        + "\n"
        + output,
    }


def handle_event(root: Path, event: str, agent: str) -> int:
    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            raise TypeError("Hook input must be a JSON object")
        # Copilot also loads .claude/settings.json and adds its documented
        # timestamp field to that payload. Its own registration handles the
        # event, so do not run updates or checks a second time through Claude.
        if agent == "claude" and "timestamp" in payload:
            print("{}")
            return 0
        native = hook_events(agent).get(event)
        if native is None:
            raise ValueError("Unsupported native hook event")
        if event == "stop":
            output = completion(root, payload, agent)
        else:
            message = (
                session_context(root, payload)
                if event == "session"
                else learning_context(event)
            )
            output = context_output(agent, native, message)
            if event == "session" and agent in {"claude", "codex"}:
                output["systemMessage"] = "Hard Eng startup: " + message.splitlines()[0]
    except (OSError, ValueError, TypeError) as error:
        message = f"Hard Eng hook input/setup failed: {error}. Continue with available tools; do not claim verification passed."
        output = (
            {"systemMessage": message}
            if event != "stop"
            else {"decision": "block", "reason": message}
        )
    print(json.dumps(output))
    return 0

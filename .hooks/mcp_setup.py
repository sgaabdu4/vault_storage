"""Configure repository MCP servers without guessing service targets."""

import json
import os
import tomllib
from pathlib import Path
from urllib.parse import urlparse

from gate_config import JsonObject

APPWRITE_CLOUD_MCP_URL = "https://mcp.appwrite.io/"


def repository_launcher(root: Path, command: object) -> str | None:
    """Return a direct, executable repository-local launcher command."""
    if not isinstance(command, str) or not command.startswith("./"):
        return None
    launcher = (root / command).resolve()
    if (
        not launcher.is_relative_to(root.resolve())
        or not launcher.is_file()
        or not os.access(launcher, os.X_OK)
    ):
        return None
    return command


def appwrite_cloud_url(value: object) -> bool:
    return value in (APPWRITE_CLOUD_MCP_URL, APPWRITE_CLOUD_MCP_URL.rstrip("/"))


def appwrite_cloud_endpoint(endpoint_value: str) -> bool:
    endpoint = urlparse(endpoint_value)
    if endpoint.scheme not in {"http", "https"} or not endpoint.hostname:
        raise ValueError("APPWRITE_ENDPOINT must be the deployed HTTP(S) endpoint")
    return endpoint.hostname == "cloud.appwrite.io" or endpoint.hostname.endswith(
        ".cloud.appwrite.io"
    )


def existing_servers(root: Path, service: str) -> list[JsonObject]:
    existing: list[JsonObject] = []
    for name in (
        ".mcp.json",
        ".github/mcp.json",
        ".codex/config.toml",
    ):
        path = root / name
        if not path.exists():
            continue
        content = path.read_text()
        parsed = (
            tomllib.loads(content) if name.endswith(".toml") else json.loads(content)
        )
        servers = parsed.get(
            "mcp_servers" if name.endswith(".toml") else "mcpServers", {}
        )
        if isinstance(servers, dict) and isinstance(servers.get(service), dict):
            existing.append(servers[service])
    return existing


def service_value(existing: list[JsonObject], variable: str) -> str | None:
    values = {os.environ[variable]} if os.environ.get(variable) else set()
    for server in existing:
        environment = server.get("env", {})
        if isinstance(environment, dict) and environment.get(variable):
            values.add(str(environment[variable]))
    if len(values) > 1:
        raise ValueError(
            f"Conflicting {variable} targets; resolve the intended service before setup"
        )
    return values.pop() if values else None


def appwrite_server(root: Path) -> JsonObject | None:
    """Reuse a known target; never default Cloud projects to API-key auth."""
    existing = existing_servers(root, "appwrite")
    endpoint_value = service_value(existing, "APPWRITE_ENDPOINT")
    launchers = {
        launcher
        for server in existing
        if (launcher := repository_launcher(root, server.get("command"))) is not None
    }
    if len(launchers) > 1:
        raise ValueError(
            "Conflicting Appwrite launcher definitions; resolve the intended service before setup"
        )
    configured_launcher = next(iter(launchers), None)
    configured_cloud = any(appwrite_cloud_url(server.get("url")) for server in existing)
    cloud = (
        appwrite_cloud_endpoint(endpoint_value)
        if endpoint_value is not None
        else configured_cloud
    )
    legacy = any(
        server.get("command") == "uvx" and server.get("args") == ["mcp-server-appwrite"]
        for server in existing
    )
    if cloud:
        if configured_launcher or legacy:
            raise ValueError(
                "Existing Appwrite local MCP conflicts with Cloud OAuth; preserve it and resolve the migration before setup"
            )
        return {"url": APPWRITE_CLOUD_MCP_URL}
    if configured_cloud:
        raise ValueError(
            "Existing Appwrite Cloud MCP conflicts with the self-hosted endpoint; resolve the migration before setup"
        )
    if legacy:
        raise ValueError(
            "Legacy Appwrite stdio entry needs the repository secret-loading launcher; preserve settings and migrate before setup"
        )
    if configured_launcher:
        if any(
            server.get("command") == configured_launcher
            and (server.get("args") or server.get("env"))
            for server in existing
        ):
            raise ValueError(
                "Reuse the Appwrite launcher with its existing secret owner; migrate arguments/env before sharing it across hosts"
            )
        return {"command": configured_launcher}
    launcher = repository_launcher(root, "./scripts/appwrite-mcp")
    if launcher:
        return {"command": launcher}
    if endpoint_value is None:
        print(
            "MCP setup pending: Appwrite needs the deployed endpoint. Reuse the project's existing configuration; "
            "ask only if unresolved, then supply APPWRITE_ENDPOINT. Follow "
            ".agents/skills/appwrite-backend/references/mcp-servers.md for Cloud OAuth or the self-hosted launcher."
        )
        return None
    print(
        "MCP setup pending: self-hosted Appwrite requires executable scripts/appwrite-mcp loading the existing gitignored env file; "
        "follow the canonical Appwrite MCP guidance before setup. Never put the API key in tracked MCP configuration."
    )
    return None


def sentry_server(root: Path) -> JsonObject | None:
    existing = existing_servers(root, "sentry")
    host = service_value(existing, "SENTRY_HOST")
    cloud = host is not None and (host == "sentry.io" or host.endswith(".sentry.io"))
    targets = {str(server.get("url") or server.get("command")) for server in existing}
    if os.environ.get("SENTRY_MCP_URL"):
        targets.add(os.environ["SENTRY_MCP_URL"])
    if len(targets) > 1:
        raise ValueError(
            "Conflicting Sentry MCP targets; resolve the intended service before setup"
        )
    if targets:
        target = targets.pop()
        parsed = urlparse(target)
        if (
            parsed.scheme == "https"
            and parsed.netloc == "mcp.sentry.dev"
            and (parsed.path == "/mcp" or parsed.path.startswith("/mcp/"))
        ):
            if host and not cloud:
                raise ValueError(
                    "Existing Sentry Cloud MCP conflicts with self-hosting; resolve the migration before setup"
                )
            return {"url": target}
        launcher = repository_launcher(root, target)
        if launcher:
            if any(server.get("args") or server.get("env") for server in existing):
                raise ValueError(
                    "Reuse the Sentry launcher with its existing secret owner; migrate arguments/env before sharing it across hosts"
                )
            return {"command": launcher}
        print(
            "MCP setup pending: existing Sentry MCP target is not a supported hosted URL or direct repository-local launcher; "
            "preserve it and configure missing hosts manually."
        )
        return None
    launcher = repository_launcher(root, "./scripts/sentry-mcp")
    if not cloud and launcher:
        return {"command": launcher}
    print(
        "MCP setup pending: Sentry needs the existing service target: SENTRY_MCP_URL for SaaS (prefer the intended organization/project scope), "
        "or a repository scripts/sentry-mcp launcher loading self-hosted credentials from the existing gitignored env file. "
        "Reuse existing project choices; ask only if unresolved."
    )
    return None


def marionette_server(root: Path) -> JsonObject | None:
    """Register for any Flutter app; pin to the locked package when present."""
    import yaml
    from gate_config import nonproduction_source, repository_files

    for path in repository_files(root):
        relative = path.relative_to(root)
        if path.name != "pubspec.yaml" or nonproduction_source(relative):
            continue
        if {".agents", ".claude", ".hooks"} & set(relative.parts):
            continue
        manifest = yaml.safe_load(path.read_text())
        dependencies = {
            **(manifest.get("dependencies") or {}),
            **(manifest.get("dev_dependencies") or {}),
        }
        if not any(
            isinstance(value, dict) and value.get("sdk") == "flutter"
            for value in dependencies.values()
        ):
            continue
        lock = path.parent / "pubspec.lock"
        locked = (
            yaml.safe_load(lock.read_text())
            .get("packages", {})
            .get("marionette_flutter", {})
            if lock.is_file()
            else {}
        )
        return {
            "command": "dart",
            "args": ["run", f"marionette_mcp@{locked.get('version', '')}"],
        }
    return None


def detected_servers(root: Path) -> dict[str, JsonObject]:
    from agent_hooks import integrated_services

    optional: dict[str, JsonObject | None] = {
        "Dart": {"command": "dart", "args": ["mcp-server"]},
        "Marionette": marionette_server(root),
    }
    services = [*integrated_services(root), "Marionette"]
    if any(
        server.get("command") == "dart"
        and server.get("args") == ["run", "dart_mcp_server@"]
        for server in existing_servers(root, "dart")
    ):
        raise ValueError(
            "Legacy Dart MCP entry: replace only its package command with dart mcp-server, preserving custom settings, then rerun setup"
        )
    if "Appwrite" in services:
        optional["Appwrite"] = appwrite_server(root)
    if "Sentry" in services:
        optional["Sentry"] = sentry_server(root)
    return {
        service.lower(): settings
        for service in services
        if (settings := optional[service]) is not None
    }


def configure_mcp(root: Path, changes: dict[str, str]) -> None:
    detected = detected_servers(root)
    for name in (".mcp.json", ".github/mcp.json"):
        target = root / name
        current: JsonObject = json.loads(target.read_text()) if target.exists() else {}
        plugins = (
            ["codebase-memory-mcp"]
            if name == ".mcp.json"
            else ["context-mode", "codebase-memory-mcp"]
        )
        servers: JsonObject = {
            plugin: {"command": "pnpm", "args": ["dlx", f"{plugin}@latest"]}
            for plugin in plugins
        }
        existing = current.setdefault("mcpServers", {})
        if not isinstance(existing, dict):
            raise TypeError(f"Conflicting MCP servers in {name}; expected an object")
        servers = {
            plugin: settings
            for plugin, settings in servers.items()
            if plugin not in existing
        }
        for plugin in sorted(detected.keys() - existing.keys()):
            settings = detected[plugin]
            servers[plugin] = (
                {"type": "http", **settings} if "url" in settings else settings
            )
        existing.update(servers)
        changes[name] = json.dumps(current, indent=2) + "\n"
    target = root / ".codex/config.toml"
    codex_config = target.read_text() if target.exists() else ""
    parsed = tomllib.loads(codex_config)
    for plugin in ("context-mode", "codebase-memory-mcp"):
        existing_server = parsed.get("mcp_servers", {}).get(plugin)
        if existing_server is None:
            codex_config += f'\n[mcp_servers."{plugin}"]\ncommand = "pnpm"\nargs = ["dlx", "{plugin}@latest"]\n'
    for plugin, settings in detected.items():
        if plugin not in parsed.get("mcp_servers", {}):
            codex_config += f'\n[mcp_servers."{plugin}"]\n'
            codex_config += "".join(
                f"{key} = {json.dumps(value)}\n" for key, value in settings.items()
            )
    changes[".codex/config.toml"] = codex_config

# MCP Servers

## Contract

- Server choice = deployed endpoint, never preference; wrong choice authenticates against the wrong instance and reads nothing.
- Cloud project (`*.cloud.appwrite.io`) = hosted remote server `https://mcp.appwrite.io/`, HTTP transport + OAuth, no key stored.
- Self-hosted instance (any other domain) = local stdio server `uvx mcp-server-appwrite` + API key. The hosted server authenticates against Appwrite Cloud only and can never reach a self-hosted instance.
- API key never appears in a committed harness config; one repository launcher owns secret loading.
- MCP session acts on the live project with that key's scopes; every mutating tool = production change under [production-migrations](production-migrations.md) and [destructive-erasure](destructive-erasure.md).
- CLI work stays with [appwrite-cli](appwrite-cli.md); MCP never substitutes for the CLI safety gate.

## Self-Hosted Launcher

Prerequisite = `uv` installed (`uvx` on PATH) + API key with the scopes every intended tool needs.

1. Create one tracked executable repository launcher (`scripts/appwrite-mcp`).
2. Resolve the repository root from the script's own path; MCP clients do not guarantee the launch working directory.
3. Source the repository's existing gitignored Appwrite env file; reuse the CLI wrapper's file rather than adding a second secret owner.
4. Fail before exec with a stderr message when the env file or any of `APPWRITE_ENDPOINT` + `APPWRITE_PROJECT_ID` + `APPWRITE_API_KEY` is missing.
5. End with `exec uvx mcp-server-appwrite "$@"` so the ambient environment passes through.
6. Read `uvx mcp-server-appwrite --help` before adding arguments. Published docs list per-service flags (`--tablesdb`, `--users`, `--storage`); current releases reject them and register services automatically.

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
env_file="${APPWRITE_ENV_FILE:-$repo_root/.env.appwrite.local}"

[[ -f "$env_file" ]] || { echo "appwrite-mcp: missing $env_file" >&2; exit 1; }

set -a
# shellcheck source=/dev/null
source "$env_file"
set +a

for name in APPWRITE_ENDPOINT APPWRITE_PROJECT_ID APPWRITE_API_KEY; do
  [[ -n "${!name:-}" ]] || { echo "appwrite-mcp: $name is not set in $env_file" >&2; exit 1; }
done

exec uvx mcp-server-appwrite "$@"
```

## Harness Wiring

No single config file serves every harness. One pointer per harness, each aimed at the launcher; on Cloud each carries the remote URL instead.

| Harness | Committed file | Shape |
|---|---|---|
| Claude Code + Copilot agent host/CLI | `.mcp.json` | `mcpServers.appwrite` = `"type": "stdio"` + `"command": "./scripts/appwrite-mcp"` |
| Copilot chat in VS Code | `.vscode/mcp.json` | `servers.appwrite` = `"type": "stdio"` + `"command": "${workspaceFolder}/scripts/appwrite-mcp"` |
| OpenCode | `opencode.json` | `mcp.appwrite` = `"type": "local"` + `"command": ["./scripts/appwrite-mcp"]`; Cloud = `"type": "remote"` + `url` |
| Codex | `.codex/config.toml` | `[mcp_servers.appwrite]` + `command = "./scripts/appwrite-mcp"`; loads only when the repository is trusted, and overrides a same-named global server |

- Committed configs carry relative paths or `${workspaceFolder}` only; absolute home paths, emails, project IDs, and keys stay out.
- Codex trust is per machine: the repository path needs `[projects."<absolute-repo>"] trust_level = "trusted"` in `~/.codex/config.toml`, written by answering yes on first run in that directory. Untrusted repository = project file silently ignored.
- `codex mcp add` writes the global `~/.codex/config.toml` and leaks one repository's server into every other repository; prefer the project file and keep the global command only as a documented fallback.
- `codex mcp list` and `codex doctor` read the merged view from the current directory; run them inside the repository, and treat a server missing there as untrusted rather than unconfigured.
- Repository copies ignored files into new worktrees (for example `.worktreeinclude`) → the Appwrite env file belongs on that list; tracked configs travel with the branch already.
- Hosted server on a host without a browser → `claude mcp login appwrite --no-browser`, then paste the full localhost callback URL back into the prompt.

## Surface

- Exposed tools = `appwrite_get_context` + `appwrite_search_tools` + `appwrite_call_tool`; the full service catalog is hidden behind search and call rather than registered individually.
- Mutating calls require `confirm_write=true`; that flag is the only thing between an agent and live production data.
- First connection prompts once per harness (Claude Code approval, VS Code trust, OpenCode OAuth on Cloud).

## Documentation Search

- Built-in `appwrite_search_docs` activates only when the bundled index and `OPENAI_API_KEY` are both present; startup logs state which branch applied.
- The index ships inside the package; the key buys ranking, not content.
- Embeddings are bound to OpenAI `text-embedding-3-small`, so no other provider substitutes; vectors from a different model rank as noise.
- Key-free replacement = Appwrite's own machine-readable manual, preferred default:

| Fact | Value |
|---|---|
| Feed | `https://appwrite.io/llms-full.txt` (index-only variant `llms.txt`; single page = append `.md` to its URL) |
| Page split | line `## <Title>` immediately followed by a line starting `https://appwrite.io/` |
| Blocked default | Python `urllib` default User-Agent returns `403`; send an identifying User-Agent |
| Cache | gitignored repository folder, re-download when older than 7 days |
| Ranking | weight title + URL path segments above body; demote `blog/` below guides |
| Cleanup | strip `{% ... %}` template tags when printing a page |

## Proof

1. Name the branch first: print the deployed endpoint and state Cloud or self-hosted before writing any config.
2. Drive the launcher over stdio by hand: send `initialize`, confirm `serverInfo` returns and the startup log names the deployed endpoint.
3. Send `tools/list` and report the actual tool names.
4. Confirm registration per harness (`claude mcp list`, `codex mcp list` from inside the repository); declare which harnesses were verified live and which were configured from documentation only.
5. Prove Codex isolation: the server resolves inside the repository and `codex mcp get appwrite` fails in an unrelated repository.
6. Scan every new file for secrets before commit.
7. `PASS` = branch proven + handshake against the deployed endpoint + per-harness registration stated + no secret in a committed file.

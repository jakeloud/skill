# JakeLoud Agent Skill

Manage a self-hosted [JakeLoud](https://github.com/jakeloud/jl) service from Codex, OpenCode, Claude Code, Cursor, and other agents that support the Agent Skills format.

The skill provides three operations:

- List projects.
- Get a project's deployment status, runtime details, and recent logs.
- Start a full project reboot using its saved repository, domain, and command.

It uses JakeLoud's existing HTTP API. No MCP server or JakeLoud server modification is required.

## Install

Install globally for Codex and OpenCode:

```bash
npx skills add jakeloud/skill -g -a codex -a opencode
```

Install interactively for any supported agent:

```bash
npx skills add jakeloud/skill
```

Install from a local clone while developing:

```bash
npx skills add .
```

For a manual drag-and-drop installation, copy the `skills/jakeloud` directory into the agent's skills directory. Common global locations are `~/.codex/skills/jakeloud` for Codex and `~/.config/opencode/skills/jakeloud` for OpenCode.

Restart a running agent after installing so it discovers the new skill.

## Requirements

- Bash 3.2 or newer
- `curl`
- `jq`

## Configure

Run the bundled client directly from the installed skill directory. For example:

```bash
# Codex
bash ~/.codex/skills/jakeloud/scripts/jakeloud.sh configure

# OpenCode
bash ~/.config/opencode/skills/jakeloud/scripts/jakeloud.sh configure
```

It prompts for:

- The base URL of your self-hosted JakeLoud service, such as `https://jl.example.com`
- Your JakeLoud email
- Your JakeLoud password, with terminal input hidden

Configuration is stored at:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/jakeloud/config.json
```

The directory is mode `0700` and the file is mode `0600`. The client reads the JSON as data and never sources it as shell code. Credentials are sent only inside the HTTPS request body and are not placed in process arguments or environment variables.

Remote services must use HTTPS. For a trusted private service where HTTP is unavoidable, opt in explicitly:

```bash
bash scripts/jakeloud.sh configure --allow-http
```

Plain HTTP is accepted without that flag only for `localhost`, `127.0.0.1`, and `[::1]`.

## Client Usage

```bash
# List projects
bash scripts/jakeloud.sh projects

# Get status and recent logs
bash scripts/jakeloud.sh status my-project

# Return machine-readable JSON
bash scripts/jakeloud.sh projects --json
bash scripts/jakeloud.sh status my-project --json

# Full reboot after reviewing and confirming the operation
bash scripts/jakeloud.sh reboot my-project --yes
```

The reboot command deliberately requires `--yes`. Agents are instructed to obtain explicit confirmation before adding it.

## Development

Run the test suite:

```bash
bash tests/test.sh
```

Tests use a mocked `curl` command and never contact a JakeLoud service.

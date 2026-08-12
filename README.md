# iasi-tools

Automation scripts and operational utilities for the IASI ecosystem.

## Command-line interface

The public interface is the `iasi` command:

```text
iasi <command> [options]
```

Available commands:

- `iasi clone [options] [workspace]`
- `iasi pull [options] [repository]`
- `iasi sync file [file...]`
- `iasi publish "message" [directory]`
- `iasi commit "message" [repository]`
- `iasi init [options] [workspace]`
- `iasi docker [start|stop|status]`
- `iasi help [command]`

Command output from underlying tools is written to timestamped files under the
workspace `logs` directory; the console only shows IASI status messages.

Add `bin` to `PATH` to invoke `iasi` from any directory. Scripts under `lib`
are internal implementation details and are not part of the public interface.

Internal code is grouped by responsibility under `lib/commands`, `lib/core`,
and `lib/install`. Docker configuration lives at the repository root under
`docker`.

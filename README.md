# iasi-tools-dev

Automation scripts and operational utilities for the IASI ecosystem.

## Command-line interface

The development interface is the `iasi-dev` command:

```text
iasi-dev <command> [options]
```

Available commands:

- `iasi-dev clone [options] [workspace]`
- `iasi-dev pull [options] [repository]`
- `iasi-dev sync path [path...]`
- `iasi-dev publish "message" [directory]`
- `iasi-dev commit "message" [repository]`
- `iasi-dev init [options] [workspace]`
- `iasi-dev docker [start|stop|status]`
- `iasi-dev help [command]`

Command output from underlying tools is written to timestamped files under the
workspace `logs` directory; the console only shows IASI status messages.

Add `bin` to `PATH` to invoke `iasi-dev` from any directory. Scripts under `lib`
are internal implementation details and are not part of the public interface.

Internal code is grouped by responsibility under `lib/commands`, `lib/core`,
and `lib/install`. Docker configuration lives at the repository root under
`docker`.

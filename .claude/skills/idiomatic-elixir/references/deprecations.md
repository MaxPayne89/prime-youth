# Elixir Deprecations (1.17–1.20)

Patterns to avoid and their replacements. Run `mix format --migrate` to auto-fix many of these.

---

## Hard Deprecations (warnings emitted)

| Deprecated | Replacement | Since |
|---|---|---|
| `'foo'` (single-quoted charlists) | `~c"foo"` | 1.17 |
| `left..right` in patterns (no step) | `left..right//step` | 1.17 |
| `IO.read(device, :all)` | `IO.read(device, :eof)` | 1.17 |
| `mix profile.cprof` / `mix profile.eprof` | `mix profile.tprof` | 1.17 |
| `<%#` in EEx templates | `<%!--` or `<% #` | 1.18 |
| `List.zip/1` | `Enum.zip/1` | 1.18 |
| `Module.eval_quoted/3` | `Code.eval_quoted/3` | 1.18 |
| `Tuple.append/2` | `Tuple.insert_at/3` | 1.18 |
| `mix cmd --app APP` | `mix do --app APP` | 1.18 |
| `:warnings_as_errors` in `:elixirc_options` | `--warnings-as-errors` CLI flag | 1.18 |
| `:default_task`, `:preferred_cli_env` in `project/0` | Move to `def cli` | 1.19 |
| Comma separator in `mix do` | Use `+` separator | 1.19 |
| Logger's `:backends` config | `:default_handler` or app callback | 1.19 |
| `File.stream!(path, modes, lines_or_bytes)` | `File.stream!(path, lines_or_bytes, modes)` | 1.20 |
| `Logger.enable/1` / `disable/1` | `Logger.put_process_level/2` / `delete_process_level/1` | 1.20 |
| `map.foo()` (calling function on map) | Raises error (not just warning) | 1.20 |

## Soft Deprecations (prefer new way)

| Deprecated | Replacement | Since |
|---|---|---|
| `unless` expressions | `if !condition do` | 1.18 |
| `Macro.struct!/2` | `Macro.struct_info!/2` | 1.18 |
| `Node.start/2-3` positional args | `Node.start/2` with keyword list | 1.19 |
| `--no-protocol-consolidation` | `--no-consolidate-protocols` | 1.19 |

## Patterns That Break on OTP 28+

- **Regexes as default struct field values** — use factory functions instead
- **Line-break characters** (U+2028, U+2029) in strings — error in 1.20 (security: line spoofing)

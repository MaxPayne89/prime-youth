# MCP Server Integration

The project uses **Model Context Protocol (MCP) servers** for enhanced development workflows.

## Tidewave MCP Server (Elixir/Phoenix)

**Purpose:** Interactive Elixir REPL and Phoenix application interaction

### When to Use Tidewave Instead of Bash

- Evaluating Elixir code: `project_eval`
- Getting documentation: `get_docs`
- Finding source code: `get_source_location`
- Executing SQL queries: `execute_sql_query`
- Checking logs: `get_logs`
- Inspecting Ecto schemas: `get_ecto_schemas`

### Common Tidewave Commands

```elixir
# Evaluate Elixir code in project context
project_eval(code: "KlassHero.Repo.all(KlassHero.Accounts.User)")

# Get documentation for a module or function
get_docs(reference: "Ecto.Changeset")

# Find source location
get_source_location(reference: "KlassHero.Accounts")

# Execute SQL query
execute_sql_query(query: "SELECT * FROM users LIMIT 5")

# Get application logs
get_logs(tail: 50, grep: "error")
```

### Critical: Tidewave MCP Integration Priority

For this Phoenix/Elixir project, Tidewave MCP is essential for optimal development workflow:

- **Always prefer Tidewave** over bash/shell tools for any Elixir evaluation, documentation, or project introspection
- **Maximize Tidewave usage** - it provides superior project context and direct interaction with running Phoenix application
- **Alert immediately if Tidewave becomes unavailable** - this indicates a critical development environment issue requiring user attention

### Tidewave Unavailability Alert Protocol

When Tidewave is not connected or fails to respond:

1. **Immediate notification**: Clearly alert the user with:
   ```
   TIDEWAVE MCP NOT RESPONDING
   [Reason: describe what failed]
   [Impact: what functionality is unavailable]
   [Next step: suggest remedial action]
   ```

2. **Investigation required**: Tidewave unavailability suggests:
   - Phoenix server not running (`mix phx.server` needed)
   - MCP connection issue requiring restart
   - Development environment misconfiguration

3. **Never silently degrade**: Do not fall back to bash/shell evaluation without explicitly notifying the user that Tidewave is unavailable

## Playwright MCP Server (Browser Testing)

**Purpose:** Automated browser testing and interaction

### Use Playwright For

- Testing LiveView interactions and flows
- Verifying mobile-responsive designs
- Taking screenshots of UI changes
- Navigating through multi-step processes (enrollment, booking)

### Common Playwright Commands

```javascript
// Navigate to a page
browser_navigate(url: "http://localhost:4000/programs")

// Take screenshot
browser_take_screenshot()

// Click element
browser_click(element: "Sign Up button", ref: "...")

// Fill form
browser_fill_form(fields: [...])
```

## Testing Workflow with MCP

1. Start Phoenix server: `mix phx.server`
2. Use **Tidewave** to check application state, run queries, evaluate code
3. Use **Playwright** to test UI flows and interactions
4. Use **Tidewave** to check logs for warnings/errors
5. Treat all warnings as errors to be addressed immediately

## Important Note

- **Always use Tidewave MCP server** for Phoenix application interaction instead of bash tools
- **Always use Playwright and/or Tidewave** to test changes by going through affected module flows

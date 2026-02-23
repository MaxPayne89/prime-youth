# CSV Import Controller Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire `ImportEnrollmentCsv` use case to a POST controller endpoint for E2E backend testing.

**Architecture:** Phoenix controller under `/provider/enrollment/import` with `:browser` + `:require_authenticated_user` pipeline. Provider role check in controller. JSON responses. Error tuples converted to JSON-serializable maps.

**Tech Stack:** Phoenix Controller, Plug.Upload, Jason

---

### Task 1: Add route to router

**Files:**
- Modify: `lib/klass_hero_web/router.ex:150-166`

**Step 1: Add provider controller scope**

Add a new scope block for provider controller routes, placed right after the existing `require_authenticated_user` scope (after line 166):

```elixir
scope "/provider", KlassHeroWeb.Provider do
  pipe_through [:browser, :require_authenticated_user]

  post "/enrollment/import", EnrollmentImportController, :create
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compile warning about missing controller module (this is expected — controller doesn't exist yet)

**Step 3: Commit**

```bash
git add lib/klass_hero_web/router.ex
git commit -m "feat(enrollment): add CSV import route (#176)"
```

---

### Task 2: Write controller tests (RED phase)

**Files:**
- Create: `test/klass_hero_web/controllers/provider/enrollment_import_controller_test.exs`

**Step 1: Write auth and error handling tests**

Reference patterns from `test/klass_hero_web/controllers/user_data_export_controller_test.exs`.
Use `setup :register_and_log_in_provider` from ConnCase for provider auth setup.
Use `KlassHero.Factory.insert/2` for test data (`:provider_profile_schema`, `:program_schema`).

Tests needed:

1. **Unauthenticated** — `POST /provider/enrollment/import` without login → redirect to `/users/log-in`
2. **Not a provider** — logged in user without provider profile → 403 JSON
3. **No file uploaded** — provider logged in, no file param → 400 JSON
4. **Happy path** — provider with programs, valid CSV upload → 201 JSON with `created` count
5. **Validation error** — invalid CSV content → 422 JSON with `validation_errors`
6. **Parse error** — empty CSV → 422 JSON with `parse_errors`

For file uploads in tests, use `%Plug.Upload{}`:
```elixir
upload = %Plug.Upload{
  path: path,
  filename: "import.csv",
  content_type: "text/csv"
}
post(conn, ~p"/provider/enrollment/import", %{"file" => upload})
```

For the CSV content, write to a temp file via `Plug.Upload`:
```elixir
path = Path.join(System.tmp_dir!(), "test_import.csv")
File.write!(path, csv_content)
# ... use in upload, then File.rm(path) in on_exit
```

**Step 2: Run tests to see them fail**

Run: `mix test test/klass_hero_web/controllers/provider/enrollment_import_controller_test.exs`
Expected: All tests fail (controller module doesn't exist)

**Step 3: Commit**

```bash
git add test/klass_hero_web/controllers/provider/enrollment_import_controller_test.exs
git commit -m "test(enrollment): add CSV import controller tests (#176)"
```

---

### Task 3: Implement controller (GREEN phase)

**Files:**
- Create: `lib/klass_hero_web/controllers/provider/enrollment_import_controller.ex`

**Step 1: Write the controller**

Key implementation details:

1. **Provider resolution**: Use `Scope.resolve_roles/1` on `conn.assigns.current_scope` to populate the provider field, then check `Scope.provider?/1`.
2. **File reading**: `Plug.Upload` gives `%{path: path}` — the file is already on disk. `File.read!/1` reads it.
3. **Error formatting**: The use case returns tuples like `{row_num, message}` which aren't JSON-serializable. Convert to maps: `%{row: row_num, message: msg}`.
4. **File size check**: `File.stat!/1` on the upload path, reject if > 2MB.

Controller shape:
```elixir
defmodule KlassHeroWeb.Provider.EnrollmentImportController do
  use KlassHeroWeb, :controller

  alias KlassHero.Accounts.Scope
  alias KlassHero.Enrollment

  require Logger

  @max_file_size 2_000_000

  def create(conn, params) do
    with {:ok, provider_id} <- resolve_provider(conn),
         {:ok, csv_binary} <- read_upload(params) do
      case Enrollment.import_enrollment_csv(provider_id, csv_binary) do
        {:ok, %{created: count}} ->
          conn |> put_status(:created) |> json(%{created: count})

        {:error, error_report} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(error_report)})
      end
    end
  end

  # resolve_provider/1 — resolve roles, return provider_id or send 403
  # read_upload/1 — extract Plug.Upload, check size, File.read!
  # format_errors/1 — convert tuples to JSON-serializable maps
end
```

**Error formatting functions** (important — tuples aren't JSON-serializable):
```elixir
defp format_errors(%{parse_errors: errors}) do
  %{parse_errors: Enum.map(errors, fn {row, msg} -> %{row: row, message: msg} end)}
end

defp format_errors(%{validation_errors: errors}) do
  %{validation_errors: Enum.map(errors, fn
    {row, field_errors} when is_list(field_errors) ->
      %{row: row, errors: Map.new(field_errors)}
    {row, msg} when is_binary(msg) ->
      %{row: row, message: msg}
  end)}
end

defp format_errors(%{duplicate_errors: errors}) do
  %{duplicate_errors: Enum.map(errors, fn {row, msg} -> %{row: row, message: msg} end)}
end
```

**`resolve_provider/1` must send response and halt** when not a provider. Use the pattern from `UserDataExportController` — don't use `with` for the 403 case. Instead, either:
- Return `{:error, conn}` and handle in `create/2`'s else clause
- Or use `halt()` + early return pattern

Recommended approach — the `with` else branch handles tagged errors:
```elixir
defp resolve_provider(conn) do
  scope = Scope.resolve_roles(conn.assigns.current_scope)

  if Scope.provider?(scope) do
    {:ok, scope.provider.id}
  else
    {:error, :not_provider}
  end
end
```

Then in `create/2`'s `with` else:
```elixir
else
  {:error, :not_provider} ->
    conn |> put_status(:forbidden) |> json(%{error: "Provider profile required"})
  {:error, :no_file} ->
    conn |> put_status(:bad_request) |> json(%{error: "No file uploaded"})
  {:error, :file_too_large} ->
    conn |> put_status(:request_entity_too_large) |> json(%{error: "File too large (max 2MB)"})
end
```

**Step 2: Run tests**

Run: `mix test test/klass_hero_web/controllers/provider/enrollment_import_controller_test.exs`
Expected: All tests pass

**Step 3: Run full test suite**

Run: `mix test`
Expected: All tests pass, no regressions

**Step 4: Run precommit**

Run: `mix precommit`
Expected: Compile clean, format clean, all tests pass

**Step 5: Commit**

```bash
git add lib/klass_hero_web/controllers/provider/enrollment_import_controller.ex
git commit -m "feat(enrollment): implement CSV import controller (#176)"
```

---

### Task 4: Manual E2E verification

**Step 1: Start server**

Run: `iex -S mix phx.server`

**Step 2: Verify route exists**

Use Tidewave `project_eval` to check the route:
```elixir
KlassHeroWeb.Router.__routes__()
|> Enum.filter(& &1.path =~ "enrollment/import")
```

**Step 3: Test with curl (optional)**

Log in via browser, grab session cookie, then:
```bash
curl -X POST http://localhost:4000/provider/enrollment/import \
  -H "Cookie: _klass_hero_web_key=<session>" \
  -H "x-csrf-token: <token>" \
  -F "file=@program.import.template.Klass.Hero.csv"
```

---

## Notes

- `Plug.Upload` streams the request body to a temp file on disk — the upload itself is memory-safe
- The only in-memory read is `File.read!/1` on the temp file, bounded by the 2MB check
- Error tuples from the use case MUST be converted to maps before JSON encoding (Jason rejects tuples)
- CSRF token required for POST — standard Phoenix browser security

# Modern Elixir (1.17–1.20)

New language features and patterns. Prefer these over older alternatives.

---

## Type System Awareness

Elixir 1.17+ has a gradual set-theoretic type system that grows with each release. By 1.20, full function-level inference including guards is active.

**Impact on code style:**
- The compiler catches type mismatches, unreachable clauses, invalid tuple indexing, and dead code
- Write clear pattern matches and guards — the type system propagates information automatically
- Reduce defensive runtime type checks where the compiler already verifies correctness
- Bang functions (`Map.fetch!/2`) help the type system track key presence

```elixir
# The compiler infers that `data` must be a map with :foo and :bar keys
# containing integer() or float() values
def add_foo_and_bar(data) do
  data.foo + data.bar
end

# Cross-clause narrowing: after matching nil in clause 1,
# clause 2 knows the value is not nil
def process(nil), do: {:error, :missing}
def process(value), do: {:ok, String.upcase(value)}
```

---

## Duration and Timeouts

### `Duration` type (1.17+)

Calendar-aware time shifts. Important: lacks associativity.

```elixir
# Shift dates by calendar units
~D[2024-01-31] |> Date.shift(month: 1)
# => ~D[2024-02-29] (leap year aware)

~U[2024-03-10 01:00:00Z] |> DateTime.shift(hour: 2)
```

### `Kernel.to_timeout/1` (1.17+)

Normalize durations to millisecond timeouts. Replaces manual math.

```elixir
# Before
Process.send_after(pid, :wake_up, 3_600_000)

# After
Process.send_after(pid, :wake_up, to_timeout(hour: 1))

GenServer.call(server, :request, to_timeout(second: 30))
```

---

## Built-in JSON Module (1.18+)

Replaces Jason for basic encode/decode. No dependency needed.

```elixir
JSON.encode!(%{name: "Alice", age: 30})
# => "{\"age\":30,\"name\":\"Alice\"}"

JSON.decode!("{\"name\":\"Alice\"}")
# => %{"name" => "Alice"}

# Custom encoding via protocol
defmodule User do
  @derive {JSON.Encoder, only: [:id, :name, :email]}
  defstruct [:id, :name, :email, :password_hash]
end
```

**Note:** Jason is still needed for advanced features (custom encoders with options, streaming, sorting keys). Use the built-in module for standard encode/decode.

---

## New Guards

### `is_non_struct_map/1` (1.17+)

Distinguish plain maps from structs in guards. Solves the `%{}` matches everything problem.

```elixir
def process(data) when is_non_struct_map(data) do
  # Only plain maps, not structs
  Map.keys(data)
end

def process(%MyStruct{} = data) do
  # Only MyStruct
end
```

### `min/2` and `max/2` as guards (1.19+)

```elixir
def clamp(value, lo, hi) when min(max(value, lo), hi) == value do
  value
end
```

---

## ExUnit Parameterized Tests (1.18+)

Test multiple configurations concurrently without code generation.

```elixir
defmodule MyTest do
  use ExUnit.Case,
    async: true,
    parameterize: [
      %{adapter: :postgres, pool_size: 5},
      %{adapter: :sqlite, pool_size: 1}
    ]

  test "connects to database", %{adapter: adapter, pool_size: pool_size} do
    assert {:ok, _conn} = connect(adapter, pool_size: pool_size)
  end
end
```

---

## Process Debugging

### `Process.set_label/1` (1.17+)

Label GenServers and processes for logger output and debugging.

```elixir
def init(state) do
  Process.set_label({:order_processor, state.order_id})
  {:ok, state}
end
```

---

## New Enum/String Functions

### `Enum.sum_by/2` and `Enum.product_by/2` (1.18+)

```elixir
# Before
orders |> Enum.map(& &1.total) |> Enum.sum()

# After
Enum.sum_by(orders, & &1.total)
Enum.product_by(items, & &1.quantity)
```

### `String.count/2` (1.19+)

```elixir
String.count("hello world", "l")
# => 3
```

### `List.first!/1` and `List.last!/1` (1.20+)

Bang variants that raise on empty list instead of returning nil.

---

## Registry.lock/3 (1.18+)

Simple in-process key-based locking without external dependencies.

```elixir
Registry.lock(MyRegistry, :import_job, fn _entries ->
  # Only one process executes this at a time for this key
  run_import()
end)
```

---

## mix format --migrate (1.18+)

Auto-converts deprecated syntax. Run periodically:

```bash
mix format --migrate
```

Converts:
- `'foo'` → `~c"foo"` (charlists)
- `unless cond do` → `if !cond do`
- `<<foo::binary()>>` → `<<foo::binary>>`

---

## mix test Improvements

- `--dry-run` (1.20) — preview which tests run without executing
- `--name-pattern` (1.19) — filter tests by name pattern
- `mix help Enum.zip` (1.19+) — look up docs from CLI

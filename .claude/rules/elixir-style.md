# Elixir Style Guide

## Core Elixir Guidelines

### List Access

Elixir lists **do not support index based access via the access syntax**.

**Never do this (invalid)**:

```elixir
i = 0
mylist = ["blue", "green"]
mylist[i]
```

Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access:

```elixir
i = 0
mylist = ["blue", "green"]
Enum.at(mylist, i)
```

### Variable Rebinding in Blocks

Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression:

```elixir
# INVALID: we are rebinding inside the `if` and the result never gets assigned
if connected?(socket) do
  socket = assign(socket, :val, val)
end

# VALID: we rebind the result of the `if` to a new variable
socket =
  if connected?(socket) do
    assign(socket, :val, val)
  end
```

### Module Organization

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors

### Struct Access

- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default
- For regular structs, you **must** access the fields directly, such as `my_struct.field`
- For changesets, use `Ecto.Changeset.get_field/2`

### Standard Library

- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces
- **Never** install additional dependencies unless asked or for date/time parsing (use `date_time_parser` package)

### Naming Conventions

- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark
- Names like `is_thing` should be reserved for guards

### OTP Primitives

Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry` require names in the child spec:

```elixir
{DynamicSupervisor, name: MyApp.MyDynamicSup}
```

Then you can use:

```elixir
DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)
```

### Concurrent Enumeration

Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option.

## Pattern Matching

- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling

- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid

- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design

- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`

## Data Structures

- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

## OTP Usage Rules

### GenServer Best Practices

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

### Process Communication

- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

### Fault Tolerance

- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

### Task and Async

- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

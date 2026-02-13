# Phoenix Framework

## Router Guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias:

```elixir
scope "/admin", AppWeb.Admin do
  pipe_through :browser

  live "/users", UserLive, :index
end
```

The UserLive route would point to the `AppWeb.Admin.UserLive` module.

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it

## HEEx Templates

### Template Syntax

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`

### Forms

- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms
- **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)

### Conditionals

Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

**Never do this (invalid)**:

```heex
<%= if condition do %>
  ...
<% else if other_condition %>
  ...
<% end %>
```

Instead **always** do this:

```heex
<%= cond do %>
  <% condition -> %>
    ...
  <% condition2 -> %>
    ...
  <% true -> %>
    ...
<% end %>
```

### Literal Curly Braces

HEEx requires special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

```heex
<code phx-no-curly-interpolation>
  let obj = {key: "val"}
</code>
```

Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax.

### Class Attributes

HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

```heex
<a class={[
  "px-2 text-white",
  @some_flag && "py-5",
  if(@other_condition, do: "border-red-500", else: "border-blue-100"),
  ...
]}>Text</a>
```

**Always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`).

**Never** do this, since it's invalid (note the missing `[` and `]`):

```heex
<a class={
  "px-2 text-white",
  @some_flag && "py-5"
}> ...
=> Raises compile syntax error on invalid HEEx attr syntax
```

### Iteration

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`

### Comments

- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)

### Interpolation

HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies.

- **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies
- **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`

**Always** do this:

```heex
<div id={@id}>
  {@my_assign}
  <%= if @some_block_condition do %>
    {@another_assign}
  <% end %>
</div>
```

**Never** do this – the program will terminate with a syntax error:

```heex
<%!-- THIS IS INVALID NEVER EVER DO THIS --%>
<div id="<%= @invalid_interpolation %>">
  {if @invalid_block_construct do}
  {end}
</div>
```

## App-Wide Template Imports

For "app wide" template imports, you can import/alias into the `klass_hero_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponents, and all modules that do `use KlassHeroWeb, :html`.

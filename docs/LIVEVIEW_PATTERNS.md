# LiveView Patterns Guide

This document establishes patterns for Phoenix LiveView development in Klass Hero, ensuring consistency and best practices across the codebase.

## Stream Usage

### When to Use Streams

**Always use streams for collections** to avoid memory bloating and potential runtime termination:

```elixir
# Mount
def mount(_params, _session, socket) do
  {:ok, items} = ListItems.execute()

  socket =
    socket
    |> stream(:items, items)
    |> assign(:items_empty?, Enum.empty?(items))

  {:ok, socket}
end
```

### Template Pattern

Streams require specific template structure:

```heex
<div id="items" phx-update="stream" class="...">
  <.item_component
    :for={{dom_id, item} <- @streams.items}
    id={dom_id}
    item={item}
  />
</div>
```

**Required elements:**
1. Container with unique `id` attribute
2. `phx-update="stream"` on the container
3. Access via `@streams.items` (not `@items`)
4. Use `dom_id` as the element's `id`

### Stream Operations

| Operation | Usage |
|-----------|-------|
| Initial load | `stream(socket, :items, items)` |
| Reset/filter | `stream(socket, :items, items, reset: true)` |
| Insert single | `stream_insert(socket, :items, item)` |
| Delete | `stream_delete(socket, :items, item)` |
| Prepend | `stream(socket, :items, [item], at: -1)` |

### Empty State Handling

Streams don't support counting. Track empty state separately:

```elixir
socket
|> stream(:items, items)
|> assign(:items_empty?, Enum.empty?(items))
```

Template options:

**Option 1: Conditional rendering with assign**
```heex
<div id="items" phx-update="stream">
  <.item :for={{dom_id, item} <- @streams.items} id={dom_id} item={item} />
  <.empty_state :if={@items_empty?} />
</div>
```

**Option 2: CSS-only approach**
```heex
<div id="items" phx-update="stream">
  <div class="hidden only:block">No items yet</div>
  <.item :for={{dom_id, item} <- @streams.items} id={dom_id} item={item} />
</div>
```

Note: CSS approach only works when empty state is the only sibling to the stream comprehension.

## Real-Time Updates with PubSub

### Architecture Pattern

For real-time updates across clients:

1. **Use cases publish domain events** via PubSubEventPublisher
2. **LiveViews subscribe** to relevant topics on mount
3. **handle_info receives events** and updates streams

### Implementation

**1. Subscribe on mount (only when connected):**

```elixir
alias KlassHero.Shared.Adapters.Driven.Events.PubSubEventPublisher

def mount(_params, _session, socket) do
  if connected?(socket), do: subscribe_to_events()
  # ... rest of mount
end

defp subscribe_to_events do
  topics = [
    PubSubEventPublisher.build_topic(:entity, :event_name),
    PubSubEventPublisher.build_topic(:entity, :other_event)
  ]
  Enum.each(topics, &Phoenix.PubSub.subscribe(KlassHero.PubSub, &1))
end
```

**2. Event handlers delegate to use cases:**

```elixir
def handle_event("action", %{"id" => id}, socket) do
  {:ok, _result} = SomeUseCase.execute(id)
  # Don't update state here - PubSub will handle it
  {:noreply, socket}
end
```

**3. Handle incoming events:**

```elixir
alias KlassHero.Shared.Domain.Events.DomainEvent

def handle_info({:domain_event, %DomainEvent{payload: %{entity: entity}}}, socket) do
  {:noreply, stream_insert(socket, :entities, entity)}
end
```

### Event Payload Requirements

Domain events must include the full entity for stream_insert to work:

```elixir
base_payload = %{
  entity_id: entity.id,
  entity: entity  # Required for LiveView stream_insert
}
```

## Test Patterns

### Prefer Selectors Over Raw HTML

**Avoid:**
```elixir
assert html =~ "Some Text"
```

**Prefer:**
```elixir
assert has_element?(view, "[data-testid='element-name']", "Some Text")
assert has_element?(view, "#specific-id")
```

### Data-Testid Attributes

Add `data-testid` attributes to components for reliable test selection:

```heex
<article id={@id} data-testid="social-post" data-post-id={@post_id}>
  <div data-testid="post-author">{@author}</div>
  <div data-testid="post-content">{@content}</div>
  <button data-testid="like-button" phx-click="like">
    <span data-testid="like-count">{@likes}</span>
  </button>
</article>
```

### Test Structure

```elixir
test "displays items correctly", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/path")

  # Verify structure exists
  assert has_element?(view, "#items[phx-update='stream']")

  # Verify content using data-testid
  assert has_element?(view, "[data-testid='item']")
  assert has_element?(view, "[data-testid='item-title']", "Expected Title")
end

test "handles user interaction", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/path")

  # Trigger event
  render_click(view, "action", %{"id" => "123"})

  # Verify state after event
  assert has_element?(view, "[data-testid='item']")
end
```

## Hook Compliance

When using JavaScript hooks that manage their own DOM:

```heex
<div id="chart" phx-hook="ChartHook" phx-update="ignore">
  <!-- Hook manages this DOM -->
</div>
```

**Required:** Always pair `phx-hook` with `phx-update="ignore"` when the hook controls the DOM.

## Navigation

### Link Components

**Always use:**
```heex
<.link navigate={~p"/path"}>Navigate</.link>
<.link patch={~p"/path"}>Patch</.link>
```

**Never use (deprecated):**
```elixir
live_redirect(socket, to: "/path")
live_patch(socket, to: "/path")
```

### Programmatic Navigation

```elixir
def handle_event("navigate", _params, socket) do
  {:noreply, push_navigate(socket, to: ~p"/destination")}
end

def handle_event("patch", _params, socket) do
  {:noreply, push_patch(socket, to: ~p"/same-liveview")}
end
```

## Form Handling

### Form Setup

```elixir
def mount(_params, _session, socket) do
  changeset = Entity.changeset(%Entity{}, %{})
  {:ok, assign(socket, form: to_form(changeset))}
end
```

### Template Usage

```heex
<.form for={@form} id="entity-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:field]} type="text" />
  <button type="submit">Save</button>
</.form>
```

**Required:**
- Always assign form via `to_form/1`
- Always provide unique `id` to forms
- Access fields via `@form[:field]`
- Never access changeset directly in templates

## Checklist

When creating a new LiveView:

- [ ] Use streams for all collections
- [ ] Track empty state with separate assign if needed
- [ ] Subscribe to PubSub topics when connected
- [ ] Add data-testid attributes to key elements
- [ ] Use `has_element?` in tests instead of raw HTML matching
- [ ] Use `push_navigate`/`push_patch` for programmatic navigation
- [ ] Use `<.link navigate={}>` in templates
- [ ] Assign forms via `to_form/1`
- [ ] Add `phx-update="ignore"` when using hooks that manage DOM

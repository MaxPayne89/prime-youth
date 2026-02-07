# Admin Verification Detail Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the `:show` action for `VerificationsLive` — display document details, inline preview via signed URL, approve/reject workflow.

**Architecture:** Add `get_for_admin_review/1` to the repository port/adapter, expose via `Identity.get_verification_document_for_admin/1`, then implement the `:show` action in the existing `VerificationsLive` module with `handle_params` dispatching on `live_action`.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, Tailwind CSS

---

### Task 1: Add `get_for_admin_review/1` to Repository Port

**Files:**
- Modify: `lib/klass_hero/identity/domain/ports/for_storing_verification_documents.ex:94-97`

**Step 1: Add the callback**

After the existing `list_for_admin_review/1` callback (line 94), add:

```elixir
@doc """
Retrieves a single verification document with provider business name for admin review.

Returns:
- `{:ok, %{document: VerificationDocument.t(), provider_business_name: String.t()}}`
- `{:error, :not_found}` if no document exists with this ID
"""
@callback get_for_admin_review(id :: String.t()) ::
            {:ok, %{document: VerificationDocument.t(), provider_business_name: String.t()}}
            | {:error, :not_found}
```

**Step 2: Commit**

```bash
git add lib/klass_hero/identity/domain/ports/for_storing_verification_documents.ex
git commit -m "feat: add get_for_admin_review/1 callback to verification document port"
```

---

### Task 2: Implement `get_for_admin_review/1` in Repository

**Files:**
- Modify: `lib/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository.ex:189`

**Step 1: Add the implementation**

Before the final `end` (line 190), add:

```elixir
@impl true
@doc """
Retrieves a single verification document joined with provider business name.

Returns:
- `{:ok, %{document: VerificationDocument.t(), provider_business_name: String.t()}}`
- `{:error, :not_found}` when no document exists with the given ID
"""
def get_for_admin_review(id) do
  query =
    from d in VerificationDocumentSchema,
      join: p in ProviderProfileSchema,
      on: d.provider_id == p.id,
      where: d.id == ^id,
      select: {d, p.business_name}

  case Repo.one(query) do
    nil -> {:error, :not_found}
    {schema, business_name} ->
      {:ok,
       %{
         document: VerificationDocumentMapper.to_domain(schema),
         provider_business_name: business_name
       }}
  end
end
```

**Step 2: Commit**

```bash
git add lib/klass_hero/identity/adapters/driven/persistence/repositories/verification_document_repository.ex
git commit -m "feat: implement get_for_admin_review/1 in verification document repository"
```

---

### Task 3: Expose `get_verification_document_for_admin/1` in Identity Context

**Files:**
- Modify: `lib/klass_hero/identity.ex:628`

**Step 1: Add the public function**

After `list_verification_documents_for_admin/1` (line 628), add:

```elixir
@doc """
Get a single verification document with provider info for admin review.

Returns:
- `{:ok, %{document: VerificationDocument.t(), provider_business_name: String.t()}}`
- `{:error, :not_found}` if document doesn't exist
"""
def get_verification_document_for_admin(document_id) do
  @verification_document_repository.get_for_admin_review(document_id)
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Clean compile

**Step 3: Commit**

```bash
git add lib/klass_hero/identity.ex
git commit -m "feat: expose get_verification_document_for_admin/1 in Identity context"
```

---

### Task 4: Implement `:show` Action in VerificationsLive

**Files:**
- Modify: `lib/klass_hero_web/live/admin/verifications_live.ex`

This is the main task. Modify the existing LiveView to handle both `:index` and `:show` actions.

**Step 1: Add Storage alias and file extension helper**

At top of module, after `alias KlassHeroWeb.Theme` (line 13), add:

```elixir
alias KlassHero.Shared.Storage
```

At the bottom of the helpers section (before final `end`), add:

```elixir
# Trigger: filename has a known image extension
# Why: determines whether to show inline preview or download-only
# Outcome: returns :image, :pdf, or :other for template branching
defp file_preview_type(filename) when is_binary(filename) do
  filename
  |> String.downcase()
  |> Path.extname()
  |> case do
    ext when ext in ~w(.jpg .jpeg .png .gif .webp) -> :image
    ".pdf" -> :pdf
    _ -> :other
  end
end

defp file_preview_type(_), do: :other
```

**Step 2: Split `handle_params` by `live_action`**

Replace the existing `handle_params` (lines 23-38) with:

```elixir
@impl true
def handle_params(params, _uri, socket) do
  {:noreply, apply_action(socket, socket.assigns.live_action, params)}
end

defp apply_action(socket, :index, params) do
  status = parse_status_filter(params)
  {:ok, results} = Identity.list_verification_documents_for_admin(status)

  socket
  |> assign(:page_title, gettext("Verifications"))
  |> assign(:current_status, status)
  |> assign(:document_count, length(results))
  |> stream(:documents, results,
    reset: true,
    dom_id: fn %{document: doc} -> "doc-#{doc.id}" end
  )
end

defp apply_action(socket, :show, %{"id" => id}) do
  case Identity.get_verification_document_for_admin(id) do
    {:ok, %{document: document, provider_business_name: business_name}} ->
      signed_url = fetch_signed_url(document.file_url)

      socket
      |> assign(:page_title, humanize_document_type(document.document_type))
      |> assign(:document, document)
      |> assign(:provider_business_name, business_name)
      |> assign(:signed_url, signed_url)
      |> assign(:preview_type, file_preview_type(document.original_filename))
      |> assign(:show_reject_form, false)
      |> assign(:reject_form, to_form(%{"reason" => ""}, as: :rejection))

    {:error, :not_found} ->
      socket
      |> put_flash(:error, gettext("Verification document not found."))
      |> push_navigate(to: ~p"/admin/verifications")
  end
end

# Trigger: document has a file_url stored in private bucket
# Why: signed URLs expire, so we generate fresh ones on each page load
# Outcome: returns URL string on success, nil on failure
defp fetch_signed_url(file_url) when is_binary(file_url) do
  case Storage.signed_url(:private, file_url, 900) do
    {:ok, url} -> url
    {:error, _} -> nil
  end
end

defp fetch_signed_url(_), do: nil
```

**Step 3: Update `mount` to remove page_title (now set in apply_action)**

Replace mount (line 18-20) with:

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok, socket}
end
```

**Step 4: Add event handlers for approve/reject**

After the `handle_params` section, add:

```elixir
@impl true
def handle_event("approve", _params, socket) do
  document = socket.assigns.document
  reviewer_id = socket.assigns.current_scope.user.id

  case Identity.approve_verification_document(document.id, reviewer_id) do
    {:ok, updated} ->
      {:noreply,
       socket
       |> assign(:document, updated)
       |> put_flash(:info, gettext("Document approved successfully."))}

    {:error, :document_not_pending} ->
      {:noreply, put_flash(socket, :error, gettext("Document has already been reviewed."))}

    {:error, _reason} ->
      {:noreply, put_flash(socket, :error, gettext("Failed to approve document."))}
  end
end

def handle_event("toggle_reject_form", _params, socket) do
  {:noreply, assign(socket, :show_reject_form, !socket.assigns.show_reject_form)}
end

def handle_event("reject", %{"rejection" => %{"reason" => reason}}, socket) do
  document = socket.assigns.document
  reviewer_id = socket.assigns.current_scope.user.id

  case Identity.reject_verification_document(document.id, reviewer_id, reason) do
    {:ok, updated} ->
      {:noreply,
       socket
       |> assign(:document, updated)
       |> assign(:show_reject_form, false)
       |> put_flash(:info, gettext("Document rejected."))}

    {:error, :reason_required} ->
      {:noreply, put_flash(socket, :error, gettext("Please provide a rejection reason."))}

    {:error, :document_not_pending} ->
      {:noreply, put_flash(socket, :error, gettext("Document has already been reviewed."))}

    {:error, _reason} ->
      {:noreply, put_flash(socket, :error, gettext("Failed to reject document."))}
  end
end
```

**Step 5: Split render by live_action**

Replace existing `render/1` (lines 50-150) with a dispatch:

```elixir
@impl true
def render(assigns) do
  render_action(assigns)
end

defp render_action(%{live_action: :index} = assigns) do
  # ... keep the existing index template exactly as-is ...
end

defp render_action(%{live_action: :show} = assigns) do
  ~H"""
  <div class="min-h-screen p-4 md:p-6 max-w-4xl mx-auto">
    <%!-- Back link --%>
    <.link
      navigate={~p"/admin/verifications"}
      class={["inline-flex items-center gap-1 mb-6 text-sm", Theme.text_color(:muted), "hover:text-gray-900"]}
    >
      <.icon name="hero-arrow-left-mini" class="w-4 h-4" />
      {gettext("Back to verifications")}
    </.link>

    <%!-- Header --%>
    <div class="flex items-center justify-between mb-6">
      <h1 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
        {humanize_document_type(@document.document_type)}
      </h1>
      <.status_badge status={@document.status} />
    </div>

    <%!-- Info grid --%>
    <div id="document-info" class={[Theme.card_variant(:default), "p-4 md:p-6 mb-6"]}>
      <dl class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <dt class={["text-sm font-medium", Theme.text_color(:muted)]}>{gettext("Business")}</dt>
          <dd class="mt-1 text-sm">{@provider_business_name}</dd>
        </div>
        <div>
          <dt class={["text-sm font-medium", Theme.text_color(:muted)]}>{gettext("File")}</dt>
          <dd class="mt-1 text-sm truncate">{@document.original_filename}</dd>
        </div>
        <div>
          <dt class={["text-sm font-medium", Theme.text_color(:muted)]}>{gettext("Submitted")}</dt>
          <dd class="mt-1 text-sm">{format_date(@document.inserted_at)}</dd>
        </div>
        <%= if @document.reviewed_at do %>
          <div>
            <dt class={["text-sm font-medium", Theme.text_color(:muted)]}>{gettext("Reviewed")}</dt>
            <dd class="mt-1 text-sm">{format_date(@document.reviewed_at)}</dd>
          </div>
        <% end %>
      </dl>

      <%!-- Rejection reason (shown only for rejected documents) --%>
      <%= if @document.status == :rejected && @document.rejection_reason do %>
        <div id="rejection-reason" class="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
          <p class="text-sm font-medium text-red-800">{gettext("Rejection reason")}</p>
          <p class="mt-1 text-sm text-red-700">{@document.rejection_reason}</p>
        </div>
      <% end %>
    </div>

    <%!-- Document preview --%>
    <div id="document-preview" class={[Theme.card_variant(:default), "p-4 md:p-6 mb-6"]}>
      <h2 class={["text-sm font-medium mb-4", Theme.text_color(:muted)]}>{gettext("Document preview")}</h2>

      <%= if @signed_url do %>
        <.document_viewer preview_type={@preview_type} signed_url={@signed_url} />
        <div class="mt-3">
          <a
            href={@signed_url}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1 text-sm text-blue-600 hover:text-blue-800"
          >
            <.icon name="hero-arrow-down-tray-mini" class="w-4 h-4" />
            {gettext("Download document")}
          </a>
        </div>
      <% else %>
        <div class="text-center py-8">
          <.icon name="hero-exclamation-triangle" class={"w-8 h-8 mx-auto mb-2 #{Theme.text_color(:muted)}"} />
          <p class={["text-sm", Theme.text_color(:muted)]}>{gettext("Unable to load document preview.")}</p>
        </div>
      <% end %>
    </div>

    <%!-- Action buttons (pending only) --%>
    <%= if @document.status == :pending do %>
      <div id="review-actions" class={[Theme.card_variant(:default), "p-4 md:p-6"]}>
        <div class="flex gap-3">
          <button
            id="approve-button"
            phx-click="approve"
            data-confirm={gettext("Are you sure you want to approve this document?")}
            class="inline-flex items-center px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-lg hover:bg-green-700 transition-colors"
          >
            <.icon name="hero-check-mini" class="w-4 h-4 mr-1" />
            {gettext("Approve")}
          </button>
          <button
            id="reject-button"
            phx-click="toggle_reject_form"
            class="inline-flex items-center px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-lg hover:bg-red-700 transition-colors"
          >
            <.icon name="hero-x-mark-mini" class="w-4 h-4 mr-1" />
            {gettext("Reject")}
          </button>
        </div>

        <%!-- Rejection form (toggled by Reject button) --%>
        <%= if @show_reject_form do %>
          <.form for={@reject_form} id="reject-form" phx-submit="reject" class="mt-4">
            <.input
              field={@reject_form[:reason]}
              type="textarea"
              label={gettext("Rejection reason")}
              required
              rows="3"
              placeholder={gettext("Explain why this document is being rejected...")}
            />
            <div class="flex gap-3 mt-3">
              <button
                id="confirm-reject-button"
                type="submit"
                class="inline-flex items-center px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-lg hover:bg-red-700 transition-colors"
              >
                {gettext("Confirm rejection")}
              </button>
              <button
                type="button"
                phx-click="toggle_reject_form"
                class={["px-4 py-2 text-sm font-medium rounded-lg", Theme.text_color(:muted), "hover:bg-gray-100 transition-colors"]}
              >
                {gettext("Cancel")}
              </button>
            </div>
          </.form>
        <% end %>
      </div>
    <% end %>
  </div>
  """
end
```

**Step 6: Add document_viewer component**

In the components section (after `documents_empty_state`), add:

```elixir
attr :preview_type, :atom, required: true
attr :signed_url, :string, required: true

defp document_viewer(%{preview_type: :image} = assigns) do
  ~H"""
  <a href={@signed_url} target="_blank" rel="noopener noreferrer">
    <img
      src={@signed_url}
      alt={gettext("Document preview")}
      class="max-w-full max-h-[600px] rounded-lg border border-gray-200"
    />
  </a>
  """
end

defp document_viewer(%{preview_type: :pdf} = assigns) do
  ~H"""
  <iframe
    src={@signed_url}
    class="w-full h-[600px] rounded-lg border border-gray-200"
    title={gettext("Document preview")}
  >
  </iframe>
  """
end

defp document_viewer(assigns) do
  ~H"""
  <div class="text-center py-8">
    <.icon name="hero-document" class={"w-12 h-12 mx-auto mb-2 #{Theme.text_color(:muted)}"} />
    <p class={["text-sm", Theme.text_color(:muted)]}>{gettext("Preview not available for this file type.")}</p>
  </div>
  """
end
```

**Step 7: Verify compilation and run tests**

Run: `mix compile --warnings-as-errors`
Expected: Clean compile

Run: `mix test`
Expected: All existing tests pass

**Step 8: Commit**

```bash
git add lib/klass_hero_web/live/admin/verifications_live.ex
git commit -m "feat: implement admin verification detail page with approve/reject"
```

---

### Task 5: Run `mix precommit`

**Step 1: Run full pre-commit checks**

Run: `mix precommit`
Expected: Compile, format, test all pass

**Step 2: Fix any issues if they arise**

---

### Task 6: Close beads issue

```bash
bd close prime-youth-jrm --reason="Implemented show action with document preview, approve/reject workflow"
```

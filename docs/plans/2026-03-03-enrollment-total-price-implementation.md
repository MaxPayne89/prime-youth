# Enrollment Total Price Fix — Implementation Plan (TDD)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make enrollment total match exactly the price the provider entered during program creation — no derived fees, no weekly multiplication.

**Architecture:** Remove the fee calculation layer entirely. BookingLive reads `program.price` and uses it directly as the total. Enrollment schema fields (`subtotal`, `vat_amount`, `card_fee_amount`, `total_amount`) are kept for forward compatibility but zeroed except `total_amount`.

**Tech Stack:** Elixir/Phoenix LiveView, Ecto, ExUnit

**Approach:** TDD — write failing tests that assert correct behavior, watch them fail, then change production code to pass.

---

### Task 1: RED — Write failing tests for correct pricing behavior

Write new tests that assert the desired behavior: total = program.price, no fees.

**Files:**
- Modify: `test/klass_hero_web/live/booking_live_test.exs`

**Step 1: Replace the `"BookingLive fee calculations"` describe block (lines 81-138) with new tests**

```elixir
  describe "BookingLive pricing display" do
    setup :register_and_log_in_user

    test "displays total matching program price exactly", %{conn: conn} do
      program = insert(:program_schema, price: Decimal.new("149.99"))
      {:ok, _view, html} = live(conn, ~p"/programs/#{program.id}/booking")

      assert html =~ "Program fee:"
      assert html =~ "€149.99"
      assert html =~ "Total due today:"
      refute html =~ "Registration fee"
      refute html =~ "VAT"
      refute html =~ "Credit card fee"
    end

    test "total is the same regardless of payment method", %{conn: conn} do
      program = insert(:program_schema, price: Decimal.new("75.00"))
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      # Switch to transfer — total unchanged
      view
      |> element("[phx-click='select_payment_method'][phx-value-method='transfer']")
      |> render_click()

      html = render(view)
      assert html =~ "€75.00"
      refute html =~ "Credit card fee"
    end
  end
```

**Step 2: Replace the `select_payment_method` test (lines 187-203) inside `"BookingLive enrollment validation"`**

```elixir
    test "select_payment_method updates payment method selection", %{conn: conn} do
      program = insert(:program_schema)
      {:ok, view, _html} = live(conn, ~p"/programs/#{program.id}/booking")

      # Switch to transfer
      view
      |> element("[phx-click='select_payment_method'][phx-value-method='transfer']")
      |> render_click()

      # Switch back to card
      view
      |> element("[phx-click='select_payment_method'][phx-value-method='card']")
      |> render_click()

      # No crash, page still renders
      assert has_element?(view, "h1", "Enrollment")
    end
```

**Step 3: Verify RED**

```bash
mix test test/klass_hero_web/live/booking_live_test.exs
```

Expected: FAIL — tests assert no "Registration fee", no "VAT", no "Credit card fee", but current code renders them all. The `refute html =~ "Registration fee"` and similar assertions should fail.

**Step 4: Commit the failing tests**

```bash
git add test/klass_hero_web/live/booking_live_test.exs
git commit -m "test(enrollment): add failing tests for direct pricing (#195)

Tests assert total = program.price with no derived fees.
Currently fail because BookingLive adds registration, VAT, card fees."
```

---

### Task 2: GREEN — Simplify BookingLive to pass the new tests

Change production code minimally to make the failing tests pass.

**Files:**
- Modify: `lib/klass_hero_web/live/booking_live.ex`

**Step 1: Rewrite mount assigns (lines 24-58)**

Replace lines 24-58 (from `# Program price is a Decimal` through `|> apply_fee_calculation()`) with:

```elixir
      # Provider's price is the total amount the parent pays — no derived fees
      total_amount = program.price || Decimal.new("0.00")

      socket =
        socket
        |> assign(
          page_title: gettext("Enrollment - %{title}", title: program.title),
          program: program,
          schedule_brief: ProgramPresenter.format_schedule_brief(program),
          children: children_for_view,
          children_by_id: children_by_id,
          selected_child_id: nil,
          eligibility_status: nil,
          special_requirements: "",
          payment_method: "card",
          total_amount: total_amount
        )
        |> assign_booking_limit_info()
```

**Step 2: Simplify `handle_event("select_payment_method")` (lines 102-109)**

Replace with:

```elixir
  @impl true
  def handle_event("select_payment_method", %{"method" => method}, socket) do
    {:noreply, assign(socket, payment_method: method)}
  end
```

**Step 3: Replace the payment summary in the template (lines 559-587)**

Replace the `<.booking_summary>` block with:

```heex
        <.booking_summary title={gettext("Payment Summary")}>
          <:line_item
            label={gettext("Program fee:")}
            value={"€#{Decimal.to_string(@total_amount)}"}
          />
          <:total
            label={gettext("Total due today:")}
            value={"€#{Decimal.to_string(@total_amount)}"}
          />
        </.booking_summary>
```

**Step 4: Update the "Total Price" in the activity summary (line 421)**

Replace:
```heex
                  €{:erlang.float_to_binary(@total, decimals: 2)}
```
with:
```heex
                  €{Decimal.to_string(@total_amount)}
```

**Step 5: Simplify `create_enrollment/2` (lines 298-314)**

Replace with:

```elixir
  defp create_enrollment(socket, params) do
    identity_id = socket.assigns.current_scope.user.id

    enrollment_params = %{
      identity_id: identity_id,
      program_id: socket.assigns.program.id,
      child_id: params["child_id"],
      payment_method: socket.assigns.payment_method,
      subtotal: Decimal.new("0.00"),
      vat_amount: Decimal.new("0.00"),
      card_fee_amount: Decimal.new("0.00"),
      total_amount: socket.assigns.total_amount,
      special_requirements: params["special_requirements"]
    }

    Enrollment.create_enrollment(enrollment_params)
  end
```

**Step 6: Delete `apply_fee_calculation/1` (lines 241-257)**

Delete the entire function.

**Step 7: Delete `calculate_weeks/2` (all three clauses, lines 338-366)**

Delete all three function clauses.

**Step 8: Remove `require Logger` (line 13) if no other Logger calls remain in the file**

Check first — if `Logger` is still used elsewhere in the file, keep it.

**Step 9: Verify GREEN**

```bash
mix test test/klass_hero_web/live/booking_live_test.exs
```

Expected: ALL PASS

**Step 10: Commit**

```bash
git add lib/klass_hero_web/live/booking_live.ex
git commit -m "fix(enrollment): use program.price directly as total (#195)

Removes weekly fee multiplication, registration fee, VAT, and card
processing fee. Provider's price is what the parent pays."
```

---

### Task 3: REFACTOR — Remove dead fee calculation code

Now that tests are green, clean up code that is no longer called.

**Files:**
- Delete: `lib/klass_hero/enrollment/application/use_cases/calculate_enrollment_fees.ex`
- Delete: `lib/klass_hero/enrollment/domain/models/fee_calculation.ex`
- Delete: `test/klass_hero/enrollment/application/use_cases/calculate_enrollment_fees_test.exs`
- Modify: `lib/klass_hero/enrollment.ex` — remove `calculate_fees/1` and its alias
- Modify: `config/config.exs` — remove `:booking` config block (lines 67-71)
- Modify: `lib/klass_hero/program_catalog/domain/services/program_pricing.ex` — remove `calculate_total/1`, `format_total_price/1`, `default_program_weeks/0`, and `@default_program_weeks` attribute (all unused)

**Step 1: Delete the fee calculation files**

```bash
rm lib/klass_hero/enrollment/application/use_cases/calculate_enrollment_fees.ex
rm lib/klass_hero/enrollment/domain/models/fee_calculation.ex
rm test/klass_hero/enrollment/application/use_cases/calculate_enrollment_fees_test.exs
```

**Step 2: Remove from `lib/klass_hero/enrollment.ex`**

- Delete the alias on line 51: `alias KlassHero.Enrollment.Application.UseCases.CalculateEnrollmentFees`
- Delete lines 195-214: the fee calculation section header, `@doc`, and `calculate_fees/1` function

**Step 3: Remove booking config from `config/config.exs`**

Delete lines 67-71:
```elixir
# Booking fee defaults — business constants not tied to specific programs
config :klass_hero, :booking,
  registration_fee: 25.00,
  vat_rate: 0.19,
  card_processing_fee: 2.50
```

**Step 4: Clean up `ProgramPricing`**

In `lib/klass_hero/program_catalog/domain/services/program_pricing.ex`, delete:
- `@default_program_weeks 4` (line 9)
- `calculate_total/1` (lines 42-55)
- `format_total_price/1` (lines 57-74)
- `default_program_weeks/0` (lines 76-80)

Keep `format_price/1` and `default_currency/0`.

**Step 5: Verify still GREEN**

```bash
mix test test/klass_hero_web/live/booking_live_test.exs
```

Expected: ALL PASS (refactor didn't break anything)

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor(enrollment): remove dead fee calculation code (#195)

Removes CalculateEnrollmentFees use case, FeeCalculation model,
booking config, and unused ProgramPricing weekly helpers."
```

---

### Task 4: Full suite verification

**Step 1: Run precommit**

```bash
mix precommit
```

Expected: Zero warnings, all tests green.

**Step 2: If any failures, fix and commit**

Possible issues:
- `create_enrollment_test.exs` line 61 test "accepts optional fee amounts" — should still pass since it sets fee fields directly, not via calculator
- Any other test referencing deleted config key

**Step 3: Commit fixes if needed**

```bash
git add -A
git commit -m "fix(enrollment): address remaining test issues (#195)"
```

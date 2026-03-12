defmodule KlassHeroWeb.BackpexCompat do
  @moduledoc """
  Workaround for Elixir 1.20 type checker + Backpex `@before_compile` conflict.

  Backpex unconditionally appends default callback implementations via
  `@before_compile`, creating redundant clauses when the implementing module
  already defines them. This module provides an `override/3` macro that
  stores the user's definition and re-emits it after Backpex's defaults,
  using `Module.delete_definition/2` to collapse the duplicates.

  Remove when Backpex adds `Module.defines?/2` guards to its `@before_compile`.
  """

  @doc """
  Wraps a Backpex callback override to prevent redundant-clause warnings.

  The function is defined immediately (so it exists during compilation)
  AND stored for re-emission after Backpex's `@before_compile` injects
  its defaults. The `@before_compile` callback deletes all clauses and
  redefines only the user's implementation.

  ## Example

      require KlassHeroWeb.BackpexCompat

      KlassHeroWeb.BackpexCompat.override :confirm_label, 1 do
        @impl Backpex.ItemAction
        def confirm_label(_assigns), do: "Cancel Booking"
      end
  """
  defmacro override(name, arity, do: block) do
    escaped_block = Macro.escape(block)

    quote do
      if !Module.get_attribute(__MODULE__, :__backpex_compat_registered__) do
        Module.register_attribute(__MODULE__, :__backpex_overrides__, accumulate: true)
        @before_compile KlassHeroWeb.BackpexCompat
        Module.put_attribute(__MODULE__, :__backpex_compat_registered__, true)
      end

      Module.put_attribute(
        __MODULE__,
        :__backpex_overrides__,
        {unquote(name), unquote(arity), unquote(escaped_block)}
      )

      # Define now so the function exists during module body compilation
      unquote(block)
    end
  end

  defmacro __before_compile__(env) do
    overrides = Module.get_attribute(env.module, :__backpex_overrides__, [])

    stmts =
      Enum.map(overrides, fn {name, arity, body_ast} ->
        quote do
          Module.delete_definition(__MODULE__, {unquote(name), unquote(arity)})
          unquote(body_ast)
        end
      end)

    {:__block__, [], stmts}
  end
end

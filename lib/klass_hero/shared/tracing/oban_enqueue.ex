defmodule KlassHero.Shared.Tracing.ObanEnqueue do
  @moduledoc """
  Helper for enqueuing Oban jobs with tracing context propagation.

  Injects the current tracing context into the worker args so the job's
  span can be linked back to the originating request.
  """

  alias KlassHero.Shared.Tracing.Context

  @doc """
  Builds a job for `worker_module` with `args`, propagating tracing context,
  and inserts it via `Oban.insert/1`.
  """
  @spec with_context(module(), map()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def with_context(worker_module, args) when is_atom(worker_module) and is_map(args) do
    args
    |> Context.inject_into_args()
    |> worker_module.new()
    |> Oban.insert()
  end
end

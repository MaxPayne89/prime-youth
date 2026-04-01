defmodule KlassHero.Shared.Tracing.TracedWorker do
  @moduledoc """
  Macro module that replaces `use Oban.Worker` for workers that should be traced.

  ## Usage

      defmodule MyApp.Workers.MyWorker do
        use KlassHero.Shared.Tracing.TracedWorker, queue: :email, max_attempts: 3

        @impl KlassHero.Shared.Tracing.TracedWorker
        def execute(%Oban.Job{args: args}) do
          # ... do work
          :ok
        end
      end

  All options are passed through to `use Oban.Worker`. The macro generates a
  `perform/1` implementation that:

  1. Extracts and attaches trace context from `job.args["trace_context"]`
  2. Wraps `execute/1` in a span named from the worker module
  3. Sets standard `oban.*` attributes on the span
  4. Records retry status and error status on `{:error, _}` returns

  The `backoff/1` and `timeout/1` callbacks remain overridable by concrete workers.
  """

  @callback execute(Oban.Job.t()) :: :ok | {:ok, term()} | {:error, term()}

  defmacro __using__(opts) do
    quote do
      @behaviour KlassHero.Shared.Tracing.TracedWorker

      use Oban.Worker, unquote(opts)
      use KlassHero.Shared.Tracing

      alias KlassHero.Shared.Tracing
      alias KlassHero.Shared.Tracing.Context

      @impl Oban.Worker
      def perform(%Oban.Job{} = job) do
        # Attach trace context BEFORE creating any spans
        Context.attach_from_args(job.args)

        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        span_name = Tracing.gen_span_name_for_worker(__MODULE__)
        worker_name = String.replace_suffix(span_name, ".execute/1", "")

        tracer = :opentelemetry.get_application_tracer(__MODULE__)

        :otel_tracer.with_span(tracer, span_name, %{}, fn _ctx ->
          set_attribute("oban.queue", job.queue)
          set_attribute("oban.worker", worker_name)
          set_attribute("oban.attempt", job.attempt)
          set_attribute("oban.max_attempts", job.max_attempts)

          result =
            try do
              execute(job)
            rescue
              exception ->
                set_attribute("exception.type", inspect(exception.__struct__))
                set_attribute("exception.message", Exception.message(exception))

                set_attribute(
                  "exception.stacktrace",
                  Exception.format_stacktrace(__STACKTRACE__)
                )

                OpenTelemetry.Tracer.set_status(:error, "exception")
                reraise exception, __STACKTRACE__
            end

          case result do
            {:error, _reason} ->
              will_retry = job.attempt < job.max_attempts
              set_attribute("oban.will_retry", will_retry)
              OpenTelemetry.Tracer.set_status(:error, "job failed")

            _ ->
              :ok
          end

          result
        end)
      end

      defoverridable perform: 1
    end
  end
end

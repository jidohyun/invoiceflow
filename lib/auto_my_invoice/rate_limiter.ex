defmodule AutoMyInvoice.RateLimiter do
  @moduledoc """
  AMI-15 — in-memory token bucket for API rate limiting.

  Hammer 7 wants a backend module per "limiter". One ETS table covers
  every key we throw at it; the scale (`60 RPM = 60_000 ms window`,
  10 RPM, etc.) is decided per-call.

  Single-node deploys (Fly.io machines, Render web service) are the
  v1 target, so ETS is enough. When we scale horizontally we swap the
  backend to `Hammer.ETS.Mnesia` or `Hammer.Redis` in a one-line
  config change.
  """

  use Hammer, backend: :ets
end

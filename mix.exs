defmodule Protohackers.MixProject do
  use Mix.Project

  def project do
    [
      app: :protohackers,
      version: "0.1.0",
      elixir: "~> 1.15",
      dialyzer: [flags: ["-Wunmatched_returns", :error_handling, :underspecs]],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:runtime_tools, :observer, :logger],
      mod: {Protohackers.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end

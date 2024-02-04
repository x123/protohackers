defmodule Protohackers.EchoServer do
  @moduledoc false
  use GenServer

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defstruct [:listen_socket, :supervisor]

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    listen_options = [
      ifaddr: {0, 0, 0, 0},
      active: false,
      exit_on_close: false,
      mode: :binary,
      reuseaddr: true
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started echo server on port:#{port}")
        state = %__MODULE__{listen_socket: listen_socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Logger.info("gen_tcp.accept socket:#{inspect(socket)}")

        {:ok, _pid} =
          Task.Supervisor.start_child(state.supervisor, fn -> handle_connection(socket) end)

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("Error in handle_continue with gen_tcp.accept:#{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp handle_connection(socket) do
    _ =
      case recv_until_closed(socket, _buffer = "", _buffered_size = 0) do
        {:ok, data} ->
          :gen_tcp.send(socket, data)

        {:error, reason} ->
          Logger.error("Failed to receive data #{inspect(reason)}")
      end

    :gen_tcp.close(socket)
  end

  @limit _100_kb = 1024 * 100

  defp recv_until_closed(socket, buffer, buffered_size) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} when buffered_size + byte_size(data) > @limit ->
        {:error, :buffer_overflow}

      {:ok, data} ->
        Logger.info("gen_tcp.recv data:#{inspect(data)}")
        recv_until_closed(socket, [buffer, data], buffered_size + byte_size(data))

      {:error, :closed} ->
        {:ok, buffer}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

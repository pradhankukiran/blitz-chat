defmodule BlitzChat.Chat.RoomServer do
  use GenServer, restart: :transient, shutdown: 30_000
  require Logger

  alias BlitzChat.Chat

  @idle_check_interval :timer.seconds(60)
  @idle_timeout :timer.minutes(5)
  @max_body_bytes 5000

  defstruct [:room_id, :room_slug, :last_activity]

  # Client API

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via(room_id))
  end

  def send_message(room_id, user_id, body) do
    GenServer.call(via(room_id), {:send_message, user_id, body})
  end

  def get_stats(room_id) do
    GenServer.call(via(room_id), :get_stats)
  end

  def via(room_id) do
    {:via, Registry, {BlitzChat.RoomRegistry, room_id}}
  end

  # Server callbacks

  @impl true
  def init(room_id) do
    room = Chat.get_room!(room_id)

    state = %__MODULE__{
      room_id: room_id,
      room_slug: room.slug,
      last_activity: System.monotonic_time(:millisecond)
    }

    schedule_idle_check()

    :telemetry.execute([:blitz_chat, :room, :started], %{count: 1}, %{room_id: room_id})
    Logger.info("Room process started: #{room.slug} (#{room_id})")

    {:ok, state}
  end

  @impl true
  def handle_call({:send_message, user_id, body}, _from, state) do
    cond do
      not is_binary(body) or String.trim(body) == "" ->
        {:reply, {:error, :empty_body}, state}

      byte_size(body) > @max_body_bytes ->
        {:reply, {:error, :body_too_long}, state}

      true ->
        case Chat.create_message(%{body: body}, state.room_id, user_id) do
          {:ok, message} ->
            Phoenix.PubSub.broadcast(
              BlitzChat.PubSub,
              "room:#{state.room_id}",
              {:new_message, message}
            )

            :telemetry.execute(
              [:blitz_chat, :room, :message_sent],
              %{count: 1},
              %{room_id: state.room_id}
            )

            {:reply, {:ok, message}, touch_activity(state)}

          {:error, changeset} ->
            {:reply, {:error, changeset}, state}
        end
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {_, memory} = :erlang.process_info(self(), :memory)

    stats = %{
      room_id: state.room_id,
      room_slug: state.room_slug,
      memory: memory
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:check_idle, state) do
    idle_ms = System.monotonic_time(:millisecond) - state.last_activity
    {_, mailbox_len} = Process.info(self(), :message_queue_len)

    if idle_ms > @idle_timeout and mailbox_len == 0 do
      Logger.info("Room idle, shutting down: #{state.room_slug}")
      {:stop, :normal, state}
    else
      schedule_idle_check()
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    :telemetry.execute([:blitz_chat, :room, :stopped], %{count: 1}, %{room_id: state.room_id})
    Logger.info("Room process stopped: #{state.room_slug}")
    :ok
  end

  defp touch_activity(state) do
    %{state | last_activity: System.monotonic_time(:millisecond)}
  end

  defp schedule_idle_check do
    Process.send_after(self(), :check_idle, @idle_check_interval)
  end
end

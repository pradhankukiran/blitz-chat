defmodule BlitzChat.Chat.RoomServer do
  use GenServer
  require Logger

  alias BlitzChat.Chat

  @flush_interval :timer.seconds(5)
  @idle_check_interval :timer.seconds(60)
  @idle_timeout :timer.minutes(5)
  @throughput_interval :timer.seconds(1)

  defstruct [
    :room_id,
    :room_slug,
    message_buffer: [],
    buffer_size: 0,
    message_count: 0,
    last_activity: nil
  ]

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

    schedule_flush()
    schedule_idle_check()
    schedule_throughput()

    :telemetry.execute([:blitz_chat, :room, :started], %{count: 1}, %{room_id: room_id})
    Logger.info("Room process started: #{room.slug} (#{room_id})")

    {:ok, state}
  end

  @impl true
  def handle_call({:send_message, user_id, body}, _from, state) do
    message_attrs = %{
      body: body,
      room_id: state.room_id,
      user_id: user_id
    }

    state = %{
      state
      | message_buffer: [message_attrs | state.message_buffer],
        buffer_size: state.buffer_size + 1,
        message_count: state.message_count + 1,
        last_activity: System.monotonic_time(:millisecond)
    }

    # Broadcast to all subscribers
    Phoenix.PubSub.broadcast(
      BlitzChat.PubSub,
      "room:#{state.room_id}",
      {:new_message, Map.put(message_attrs, :inserted_at, DateTime.utc_now())}
    )

    :telemetry.execute(
      [:blitz_chat, :room, :message_sent],
      %{count: 1},
      %{room_id: state.room_id}
    )

    # Flush immediately if buffer is large
    state =
      if state.buffer_size >= 50 do
        flush_buffer(state)
      else
        state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      room_id: state.room_id,
      room_slug: state.room_slug,
      buffer_size: state.buffer_size,
      total_messages: state.message_count,
      memory: :erlang.process_info(self(), :memory) |> elem(1)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:flush_buffer, state) do
    state = flush_buffer(state)
    schedule_flush()
    {:noreply, state}
  end

  @impl true
  def handle_info(:check_idle, state) do
    idle_ms = System.monotonic_time(:millisecond) - state.last_activity

    if idle_ms > @idle_timeout do
      Logger.info("Room idle, shutting down: #{state.room_slug}")
      {:stop, :normal, state}
    else
      schedule_idle_check()
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:calculate_throughput, state) do
    :telemetry.execute(
      [:blitz_chat, :room, :throughput],
      %{messages: state.message_count},
      %{room_id: state.room_id}
    )

    schedule_throughput()
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    flush_buffer(state)

    :telemetry.execute([:blitz_chat, :room, :stopped], %{count: 1}, %{room_id: state.room_id})
    Logger.info("Room process stopped: #{state.room_slug}")

    :ok
  end

  # Private

  defp flush_buffer(%{buffer_size: 0} = state), do: state

  defp flush_buffer(state) do
    case Chat.insert_messages_batch(Enum.reverse(state.message_buffer)) do
      {count, _} ->
        :telemetry.execute(
          [:blitz_chat, :room, :buffer_flushed],
          %{batch_size: count},
          %{room_id: state.room_id}
        )

      _ ->
        :ok
    end

    %{state | message_buffer: [], buffer_size: 0}
  end

  defp schedule_flush, do: Process.send_after(self(), :flush_buffer, @flush_interval)
  defp schedule_idle_check, do: Process.send_after(self(), :check_idle, @idle_check_interval)
  defp schedule_throughput, do: Process.send_after(self(), :calculate_throughput, @throughput_interval)
end

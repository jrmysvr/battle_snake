defmodule BattleSnake.GameChannel do
  alias BattleSnake.{
    World,
    GameServer,
    GameForm,
    GameServer.State.Event
  }

  use BattleSnake.Web, :channel

  @spec join(binary, %{}, Phoenix.Socket.t) ::
  {:ok, Phoenix.Socket.t} |
  {:error, any}
  def join("game:" <> game_id, payload, socket) do
    if authorized?(payload) do
      socket = assign(socket, :game_id, game_id)
      GameServer.PubSub.subscribe(game_id)

      callback = & &1

      with({:ok, game_form} <- load_game_form(game_id),
           {:ok, game_server_pid} <- load_game_server_pid(game_form, callback),
           send(self(), :after_join),
        do: {:ok,
             socket
             |> assign(:game_server_pid, game_server_pid)
             |> assign(:game_form, game_form)})
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("replay", _, socket) do
    game_server_pid = socket.assigns.game_server_pid
    :ok = GameServer.replay(game_server_pid)
    {:reply, :ok, socket}
  end

  def handle_in("start", _, socket) do
    game_server_pid = socket.assigns.game_server_pid
    :ok = GameServer.resume(game_server_pid)
    {:reply, :ok, socket}
  end

  def load_game_form(game_id) do
    GameForm.get(game_id)
  end

  @spec load_game_server_pid(GameForm.t) :: {:ok, pid} | {:error, any}
  def load_game_server_pid(game_form, callback \\ &(&1)) do
    case GameServer.Registry.lookup(game_form.id) do
      [{game_server_pid, _}] ->
        {:ok, game_server_pid}
      [] ->
        state = BattleSnake.GameServerConfig.setup(game_form, callback)
        {:ok, game_server_pid} = GameServer.Registry.create(game_form.id, state)
        {:ok, game_server_pid}
    end
  end

  @spec handle_info(:after_join, Phoenix.Socket.t) ::
  {:noreply, Phoenix.Socket.t}
  def handle_info(:after_join,
    %{assigns: %{game_server_pid: game_server_pid}}
    = socket) do
    state = GameServer.get_status(game_server_pid)
    push(socket, "state_change", %{data: state})
    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    {:noreply, socket}
  end

  @doc """
  Handle notifications from the GameSever. This is used to render the state of
  the game as an svg and broadcast it to all channel subscribers.
  """
  def handle_info(%Event{name: name, data: state}, socket) do
    case name do
      _ ->
        html =
          Phoenix.View.render_to_string(
            BattleSnake.PlayView,
            "board.html",
            state: state,
            world: state.world)
        broadcast(socket, "tick", %{html: html})
    end
    {:noreply, socket}
  end

  def handle_info({:render, state}, socket) do
    html = Phoenix.View.render_to_string(
      BattleSnake.PlayView,
      "board.html",
      state: state,
      world: state.world)

    broadcast socket, "tick", %{html: html}

    {:noreply, socket}
  end

  def handle_in("pause", _, socket) do
    :ok = socket.assigns.game_server_pid
    |> GameServer.pause()
    {:reply, :ok, socket}
  end

  def handle_in("next", _, socket) do
    socket.assigns.game_server_pid
    |> GameServer.next()
    {:reply, :ok, socket}
  end

  def handle_in("stop", _, socket) do
    game_server_pid = socket.assigns.game_server_pid
    :ok = GenServer.stop(game_server_pid, :normal)
    {:reply, :ok, socket}
  end

  def handle_in("prev", _, socket) do
    socket.assigns.game_server_pid
    |> GameServer.prev()
    {:reply, :ok, socket}
  end

  defp game_id(%{topic: "game:" <> id}),
    do: id

  defp authorized?(_payload) do
    true
  end
end

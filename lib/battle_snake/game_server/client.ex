defmodule BattleSnake.GameServer.Client do
  alias BattleSnake.GameServer

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def get_game_state(pid) do
    GenServer.call(pid, :get_game_state)
  end

  def get_status(pid) do
    GenServer.call(pid, :get_status)
  end

  def next(pid) do
    GenServer.call(pid, :next)
  end

  def pause(pid) do
    GenServer.call(pid, :pause)
  end

  def prev(pid) do
    GenServer.call(pid, :prev)
  end

  def resume(pid) do
    GenServer.call(pid, :resume)
  end

  @doc "Replay the current game."
  @spec replay(GameServer.server) :: term
  def replay(pid) do
    GenServer.call(pid, :replay)
  end
end

defmodule Acceptor do
  @moduledoc false

  defp next(ballot, accepted) do
    {ballot, accepted} = receive do
      {:p1a, leader, received_ballot} ->
        ballot = if received_ballot > ballot, do: received_ballot, else: ballot
        send(leader, {:p1b, ballot, accepted})
        {ballot, accepted}
      {:p2a, leader, {received_ballot, slot, cmd}} ->
        send(leader, {:p2b, ballot})
        {
          ballot,
          (if received_ballot == ballot, do: Map.put(accepted, slot, {ballot, cmd}), else: accepted)
        }
    end
    next(ballot, accepted)
  end

  def start(config) do
    next({-1,-1}, Map.new())
  end
end

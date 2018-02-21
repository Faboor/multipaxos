# Author: Peter Kovary <pk3115@ic.ac.uk>

defmodule Acceptor do
  @moduledoc false

  defp next(ballot, accepted) do
    {ballot, accepted} =
      receive do
        {:p1a, leader, received_ballot} ->
          ballot = if received_ballot > ballot, do: received_ballot, else: ballot
          send(leader, {:p1b, ballot, accepted})
          {ballot, accepted}

        {:p2a, leader, {received_ballot, slot, cmd}} ->
          send(leader, {:p2b, ballot})

          if received_ballot == ballot do
            {ballot, MapSet.put(accepted, {ballot, slot, cmd})}
          else
            {ballot, accepted}
          end
      end

    next(ballot, accepted)
  end

  def start(_) do
    next({-1, -1}, MapSet.new())
  end
end

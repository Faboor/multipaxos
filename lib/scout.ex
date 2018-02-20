# Author: Peter Kovary <pk3115@ic.ac.uk>

defmodule Scout do
  @moduledoc false

  defp next(leader, waitfor, ballot, pvals) do
    if waitfor <= 0 do
      send(leader, {:adopted, ballot, pvals})
      Process.exit(self(), :normal)
    end

    receive do
      {:p1b, other_ballot, pval} ->
        if ballot == other_ballot do
          next(leader, waitfor - 1, ballot, MapSet.union(pvals, pval))
        else
          send(leader, {:preemted, other_ballot})
          Process.exit(self(), :normal)
        end
    end
  end

  def start(leader, acceptors, ballot) do
    for a <- acceptors, do: send(a, {:p1a, self(), ballot})
    next(leader, div(length(acceptors) + 1, 2), ballot, MapSet.new())
  end
end

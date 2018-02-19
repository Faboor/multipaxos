defmodule Commander do
  @moduledoc false

  defp next(leader, waitfor, replicas, {ballot, slot, cmd}) do
    if waitfor <= 0 do
      for r <- replicas, do: send(r, {:decision, slot, cmd})
      Process.exit(self(), :normal)
    end

    receive do
      {:p2b, other_ballot} ->
        if ballot == other_ballot do
          next(leader, waitfor - 1, replicas, {ballot, slot, cmd})
        else
          send(leader, {:preemted, other_ballot})
          Process.exit(self(), :normal)
        end
    end
  end

  def start(leader, acceptors, replicas, pval) do
    for a <- acceptors, do: send(a, {:p2a, self(), pval})
    next(leader, Float.ceil((length(acceptors) + 1) / 2), replicas, pval)
  end
end

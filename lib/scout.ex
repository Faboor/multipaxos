# Author: Peter Kovary <pk3115@ic.ac.uk>

defmodule Scout do
  @moduledoc false

  defp maxp(orig, new) do
    List.foldl(Map.to_list(new), orig, fn {slot, {n_ballot, n_cmd}}, orig ->
      Map.update(orig, slot, {n_ballot, n_cmd}, fn {o_ballot, o_cmd}->
        if n_ballot > o_ballot, do: {n_ballot, n_cmd}, else: {o_ballot, o_cmd}
      end)
    end)
  end

  defp next(leader, waitfor, ballot, pvals) do
    if waitfor <= 0 do
      send(leader, {:adopted, ballot, pvals})
      Process.exit(self(), :normal)
    end

    receive do
      {:p1b, other_ballot, pval} ->
        if ballot == other_ballot do
          next(leader, waitfor - 1, ballot, maxp(pvals, pval))
        else
          send(leader, {:preempted, other_ballot})
          Process.exit(self(), :normal)
        end
    end
  end

  def start(leader, acceptors, ballot) do
    for a <- acceptors, do: send(a, {:p1a, self(), ballot})
    next(leader, div(length(acceptors) + 1, 2), ballot, Map.new())
  end
end

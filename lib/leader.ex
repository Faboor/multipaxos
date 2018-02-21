# Author: Peter Kovary <pk3115@ic.ac.uk>

defmodule Leader do
  @moduledoc false

  defp pmax(pvals) do
    List.foldl(Map.to_list(pvals), Map.new(), fn {slot, {_, cmd}}, slot_to_cmd ->
      Map.put(slot_to_cmd, slot, cmd)
    end)
  end

  defp next(ballot, active, proposals, replicas, acceptors) do
    {active, ballot, proposals} =
      receive do
        {:propose, slot, cmd} ->
          {active, ballot,
           Map.put_new_lazy(proposals, slot, fn ->
             if active do
               spawn(Commander, :start, [self(), acceptors, replicas, {ballot, slot, cmd}])
             end

             cmd
           end)}

        {:adopted, ballot, pvals} ->
          proposals_ = Map.merge(proposals, pmax(pvals))

          for {slot, cmd} <- proposals_ do
            spawn(Commander, :start, [self(), acceptors, replicas, {ballot, slot, cmd}])
          end

          {true, ballot, proposals_}

        {:preempted, other_ballot} ->
          if other_ballot > ballot do
            {other_ballot_num, _} = other_ballot
            {_, server_num} = ballot
            ballot = {other_ballot_num + 1, server_num}
            Process.sleep(100) #10 + :rand.uniform(90)) # possible sleep
            spawn(Scout, :start, [self(), acceptors, ballot])
            {false, ballot, proposals}
          else
            {active, ballot, proposals}
          end
      end

    next(ballot, active, proposals, replicas, acceptors)
  end

  def start(config) do
    ballot = {0, config.server_num}
    receive do
      {:bind, acceptors, replicas} ->
        spawn(Scout, :start, [self(), acceptors, ballot])
        next(ballot, false, Map.new(), replicas, acceptors)
    end
  end
end

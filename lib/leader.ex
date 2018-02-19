defmodule Leader do
  @moduledoc false

  defp pmax(pvals) do
    slot_to_ballot_and_command =
      List.foldl(Map.to_list(pvals), Map.new(), fn {ballot, slot, cmd}, res ->
        Map.update(res, slot, {ballot, cmd}, fn {ballot2, cmd2} ->
          if ballot > ballot2, do: cmd, else: cmd2
        end)
      end)

    slot_to_command =
      List.foldl(Map.to_list(slot_to_ballot_and_command), Map.new(), fn {slot, {ballot, cmd}},
                                                                        slot_to_cmd ->
        Map.put(slot_to_cmd, slot, cmd)
      end)

    slot_to_command
    # TODO: do it in the acceptors and scouts
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

        {:preemted, other_ballot} ->
          if other_ballot > ballot do
            {other_ballot_num, _} = other_ballot
            {_, server_num} = ballot
            ballot = {other_ballot_num + 1, server_num}
            # possible sleep
            spawn(Scout, :start, [self(), acceptors, ballot])
            {false, ballot, proposals}
          else
            {active, ballot, proposals}
          end
      end

    next(ballot, active, proposals, replicas, acceptors)
  end

  def start(config) do
    recieve do
      {:bind, replicas, acceptors} ->
        spawn(Scout, :start, [self(), acceptors, {0, config.server_num}])
        next({0, config.server_num}, false, Map.new(), replicas, acceptors)
    end
  end
end

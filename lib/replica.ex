defmodule Replica do
  @moduledoc false

  defp perform(slot_out, decisions, db) do
    cmd = Map.get(decisions, slot_out)

    if cmd == nil do
      slot_out
    else
      send(db, {:execute, cmd})
      perform(slot_out + 1, decisions, db)
    end
  end

  defp propose(requests, slot_in, proposals, leaders) do
    {
      MapSet.new(),
      List.foldl(MapSet.to_list(requests), {slot_in, proposals}, fn cmd, {slot_in, proposals} ->
        for leader <- leaders, do: send(leader, {:propose, slot_in, cmd})

        {
          slot_in + 1,
          Map.put(proposals, slot_in, cmd)
        }
      end)
    }
  end

  defp next(server_num, leaders, db, monitor, slot_in, slot_out, requests, proposals, decisions) do
    {requests, proposals, decisions} =
      receive do
        {:client_request, cmd} ->
          send(monitor, {:client_request, server_num})

          {
            MapSet.put(requests, cmd),
            proposals,
            decisions
          }

        {:decision, slot, decided_cmd} ->
          {proposed_cmd, proposals} = Map.pop(proposals, slot)

          {
            (if proposed_cmd != decided_cmd, do: MapSet.put(requests, proposed_cmd), else: requests),
            proposals,
            Map.put_new(decisions, slot, decided_cmd)
          }
      end

    slot_out = perform(slot_out, decisions, db)

    {requests, {slot_in, proposals}} =
      propose(requests, max(slot_in, slot_out), proposals, leaders)

    next(server_num, leaders, db, monitor, slot_in, slot_out, requests, proposals, decisions)
  end

  def start(config, db, monitor) do
    receive do
      {:bind, leaders} ->
        next(config.server_num, leaders, db, monitor, 0, 0, MapSet.new(), Map.new(), Map.new())
    end
  end
end

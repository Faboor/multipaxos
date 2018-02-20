# Author: Peter Kovary <pk3115@ic.ac.uk>

defmodule Replica do
  @moduledoc false

  defp perform(slot_out, decisions, db, server_num) do
#    if server_num == 1 do
#    IO.inspect [server_num, slot_out, decisions]
#    end
    cmd = Map.get(decisions, slot_out)

    if cmd == nil do
      slot_out
    else
      #IO.puts "replica #{server_num} - Slot #{slot_out} executed"
      {_, _, actual_cmd} = cmd
      send(db, {:execute, actual_cmd})
      perform(slot_out + 1, decisions, db, server_num)
    end
  end

  defp propose(requests, slot_in, max_props, proposals, leaders) do
    List.foldl(MapSet.to_list(requests), {requests, slot_in, proposals},
      fn cmd, {requests, slot_in, proposals} ->
        if slot_in < max_props do
          for leader <- leaders, do: send(leader, {:propose, slot_in, cmd})
          #IO.puts "Proposing request on #{slot_in}"
          {
            MapSet.delete(requests, cmd),
            slot_in + 1,
            Map.put(proposals, slot_in, cmd)
          }
        else
          {
            requests,
            slot_in,
            proposals
          }
        end
      end)
  end

  defp next(server_num, window,
         leaders, db, monitor,
         slot_in, slot_out,
         requests, proposals, decisions) do
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
          if proposed_cmd && proposed_cmd != decided_cmd do
            {
              MapSet.put(requests, proposed_cmd),
              proposals,
              Map.put_new(decisions, slot, decided_cmd)
            }
          else
            {
              requests,
              proposals,
              Map.put_new(decisions, slot, decided_cmd)
            }
          end
      end

    slot_out = perform(slot_out, decisions, db, server_num)
    # IO.puts "repl #{server_num} - slot out = #{slot_out}"
    {requests, slot_in, proposals} =
      propose(requests, max(slot_in, slot_out), slot_out + window, proposals, leaders)

    next(server_num, window,
      leaders, db, monitor,
      slot_in, slot_out,
      requests, proposals, decisions)
  end

  def start(config, db, monitor) do
    receive do
      {:bind, leaders} ->
        next(config.server_num, config.window, # configs
          leaders, db, monitor,                # addresses
          0, 0,                                # slot_in, slot_out
          MapSet.new(), Map.new(), Map.new())  # requests, proposals, decisions
    end
  end
end

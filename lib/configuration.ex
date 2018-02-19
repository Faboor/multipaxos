# distributed algorithms, n.dulay, 2 feb 18
# multi-paxos, configuration parameters v1

defmodule Configuration do
  # configuration 1
  def version(1) do
    %{
      # debug level 
      debug_level: 0,
      # time (ms) to wait for containers to start up
      docker_delay: 5_000,
      # max requests each client will make
      max_requests: 500,
      # time (ms) to sleep before sending new request
      client_sleep: 5,
      # time (ms) to stop sending further requests
      client_stop: 10_000,
      # number of active bank accounts
      n_accounts: 100,
      # max amount moved between accounts
      max_amount: 1000,
      # print transaction log summary every print_after msecs
      print_after: 1_000

      # add your own here
    }
  end

  # same as version 1 with higher debug level
  def version(2) do
    config = version(1)
    Map.put(config, :debug_level, 1)
  end

  # configuration 3
  def version(3) do
  end
end

# module -----------------------

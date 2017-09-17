
defmodule Actor do
  use GenServer
    
  def hash_code_match(check_str, zero_count, client) do
    zero_String = String.duplicate("0", zero_count)
    hash =  Base.encode16(:crypto.hash(:sha256, check_str))
    val = String.starts_with? hash, zero_String
    
    if (val == :true) do
      #IO.puts val
      #IO.puts check_str
      #IO.puts hash
      send(client, {val, check_str, hash, self()})
    end
  end

  def gen_strings(str, k, cur, zero_count, client) when k == 0 do
    hash_code_match(str, zero_count, client)
  end

  def gen_strings(str, k, cur, zero_count, client) when (cur > 125) do
      
  end

  def gen_strings(str, k, cur, zero_count, client) do
      gen_strings(str <> <<cur::utf8>>, k-1, 33, zero_count, client)
      gen_strings(str, k, cur+1, zero_count, client)
  end
  
  def handle_cast({:process, client, str, k, zero_count}, state) do
    IO.puts k
    gen_strings(str, k, 33, zero_count, client)
    send(client, {:done, self()})
    {:noreply, []}
  end

  def findKeys(pid, {:process, client, str, k, zero_count}) do
    GenServer.cast(pid, {:process, client, str, k, zero_count})
  end
  
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

end


defmodule Client do
  def startClient(serverAddr) do
    {:ok, ipAddList} = :inet.getif()
      ipAddr = "client@" <> Server.getIPAdress(ipAddList)
      Node.start(String.to_atom(ipAddr))
      Node.set_cookie(:"project1")
      Node.connect(String.to_atom("server@" <> serverAddr))
  end

  def listen(k, limit, zeroes) do
    receive do
      {:true, res, hash, pid} -> 
        IO.puts "yes"
        IO.puts res
        IO.puts hash
        listen(k, limit, zeroes)
      {:done, pid} ->
        if (k > limit) do
          listen(k, limit, zeroes)
        else
          Actor.findKeys(pid, {:process, self(), "abhinavpodduturi:", k, zeroes});
          listen(k+1, limit, zeroes)
        end        
    end
  end

  def startDistributor(start, limit, zeroes) do
    {:ok, pidOne} = Actor.start_link()
    {:ok, pidTwo} = Actor.start_link()
    {:ok, pidThree} = Actor.start_link()
    {:ok, pidFour} = Actor.start_link()
    {:ok, pidFive} = Actor.start_link()
    {:ok, pidSix} = Actor.start_link()
    {:ok, pidSeven} = Actor.start_link()
    {:ok, pidEight} = Actor.start_link()

    Actor.findKeys(pidOne, {:process, self(), "abhinavpodduturi:", start, zeroes})
    Actor.findKeys(pidTwo, {:process, self(), "abhinavpodduturi:", start+1, zeroes})
    Actor.findKeys(pidThree, {:process, self(), "abhinavpodduturi:", start+2, zeroes})
    Actor.findKeys(pidFour, {:process, self(), "abhinavpodduturi:", start+3, zeroes})
    Actor.findKeys(pidFive, {:process, self(), "abhinavpodduturi:", start+4, zeroes})
    Actor.findKeys(pidSix, {:process, self(), "abhinavpodduturi:", start+5, zeroes})
    Actor.findKeys(pidSeven, {:process, self(), "abhinavpodduturi:", start+6, zeroes})
    Actor.findKeys(pidEight, {:process, self(), "abhinavpodduturi:", start+7, zeroes})
    
    listen(start+8, limit, zeroes)
  end
end

defmodule Server do  
  def getIPAdress(ipAddList) when ipAddList == [] do
    ""
  end

  def getIPAdress(ipAddList) do
    [head | tail] = ipAddList
    {ip,_,_} = head
    {one, two, three, four} = ip
    if (one == 10 || (one == 192 && two == 168)) do
      Integer.to_string(one) <> "." <> Integer.to_string(two) <> "." 
      <> Integer.to_string(three) <> "." <> Integer.to_string(four)
    else
      getIPAdress(tail)
    end
  end

  def assignToNode(list, cur, zeroes) when list == [] do
    cur
  end

  def assignToNode(list, cur, zeroes) do
    [head | tail] = list
    Node.spawn(head, Client, :startDistributor, [cur, cur+7, zeroes])
    assignToNode(tail, cur+8, zeroes)
  end

  def monitorNewConnections(cur, zeroes, list) do
    newList = Node.list()
    Enum.sort(newList)
    diffList = newList -- list
    list = newList
    cur = assignToNode(diffList, cur, zeroes)
    :timer.sleep(5000)
    monitorNewConnections(cur, zeroes, list)
  end

  def startServer(zeroes) do
      {:ok, ipAddList} = :inet.getif()
      ipAddr = "server@" <> getIPAdress(ipAddList)
      Node.start(String.to_atom(ipAddr))
      Node.set_cookie(:"project1")
      spawn(Client, :startDistributor, [1, 13, zeroes])
      monitorNewConnections(14, zeroes, [])
  end
end

defmodule Project1 do
  def main([]) do
    IO.puts "Enter Valid Number of Zeros or IP Address that connects to Server"
  end

  def main(argv) do
    val = List.first(argv)
    if String.contains? val, "." do
      Client.startClient(val)
    else
      zero_count = String.to_integer(val)
      Server.startServer(zero_count)
    end
    
  end
end

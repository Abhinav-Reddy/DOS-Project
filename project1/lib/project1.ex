
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
  
  def checkForTermination(serverAddr) do
    :timer.sleep(5000)
    if (Enum.member?(Node.list(), serverAddr) == true) do
      checkForTermination(serverAddr)
    end
    
  end
  
  def startClient(serverAddr) do
    {:ok, ipAddList} = :inet.getif()
      ipAddr = "client@" <> Server.getIPAdress(ipAddList)
      Node.start(String.to_atom(ipAddr))
      Node.set_cookie(:"project1")
      Node.connect(String.to_atom("server@" <> serverAddr))
      checkForTermination(String.to_atom("server@" <> serverAddr))
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

  def startDistributor(start, limit, zeroes, num) when num == 0 do
    listen(start, limit, zeroes)
  end

  def startDistributor(start, limit, zeroes, num) do
    {:ok, pidOne} = Actor.start_link()
    Actor.findKeys(pidOne, {:process, self(), "abhinavpodduturi:", start, zeroes})
    startDistributor(start+1, limit, zeroes, num-1)
  end
end

defmodule Server do  
  def getIPAdress(ipAddList) when ipAddList == [] do
    [head | tail] = ipAddList
    {ip,_,_} = head
    {one, two, three, four} = ip
    Integer.to_string(one) <> "." <> Integer.to_string(two) <> "." 
    <> Integer.to_string(three) <> "." <> Integer.to_string(four)
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

  def assignToNode(list, cur, zeroes, processCnt) when list == [] do
    cur
  end

  def assignToNode(list, cur, zeroes, processCnt) do
    [head | tail] = list
    Node.spawn(head, Client, :startDistributor, [cur, cur+processCnt-1, zeroes, processCnt])
    assignToNode(tail, cur+processCnt, zeroes, processCnt)
  end

  def monitorNewConnections(cur, zeroes, list, processCnt) do
    newList = Node.list()
    Enum.sort(newList)
    diffList = newList -- list
    list = newList
    cur = assignToNode(diffList, cur, zeroes, processCnt)
    :timer.sleep(5000)
    monitorNewConnections(cur, zeroes, list, processCnt)
  end

  def startServer(zeroes) do
      {:ok, ipAddList} = :inet.getif()
      ipAddr = "server@" <> getIPAdress(ipAddList)
      Node.start(String.to_atom(ipAddr))
      Node.set_cookie(:"project1")
      processCnt = 16
      spawn(Client, :startDistributor, [1, processCnt+4, zeroes, processCnt])
      monitorNewConnections(processCnt+5, zeroes, [], processCnt)
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

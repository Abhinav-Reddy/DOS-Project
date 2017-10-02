defmodule Actor do
  use GenServer
    
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def handle_cast({neighbors, mainProcess, curPos}, state) do
    receiveGossip(neighbors, mainProcess, curPos, 1, 0, self())
    {:noreply, []}
  end

  def setNeighbors(pid, {neighbors, mainProcess, curPos}) do
    GenServer.cast(pid, {neighbors, mainProcess, curPos})
  end


  def sendGossip(neighbors, mainProcess) do
    pid = GOSSIP.getRandom(neighbors, -1, 1)
    send(pid, {:gossip})
    send(mainProcess, {:sent})
    sendGossip(neighbors, mainProcess)
  end

  def sendFinalMessage(neighbors) when neighbors == [] do
    
  end

  def sendFinalMessage(neighbors) do
    [head | tail] = neighbors
    send(head, {:bye, self()})
    sendFinalMessage(tail)
  end

  def receiveGossip(neighbors, mainProcess, sum, weight, count, recPid) do
    
    receive do
      {:push, s,w} ->
        {sum, weight, count} = 
          if (count < 3) do
            s = sum + s
            w = weight + w
            
            pid = GOSSIP.getRandom(neighbors, -1, 1)
            send(pid, {:push, s/2, w/2})
            send(mainProcess, {:sent})
            counter = if (abs(sum/weight - s/w) <= 0.0000000001) do
                        count + 1
                      else
                        0
                      end
            {s, w, counter}
          else
            {2*sum, 2*weight, count}
          end
        IO.puts sum/weight
        receiveGossip(neighbors, mainProcess, sum/2, weight/2, count, recPid)
      {:gossip} ->
        recPid = 
          if (count == 0) do
            spawn(Actor, :sendGossip, [neighbors, mainProcess])
          else
            recPid
          end
        if (count == 9) do
          Process.exit(recPid, :kill)
          sendFinalMessage(neighbors)
        end
        IO.puts sum
        receiveGossip(neighbors, mainProcess, sum, weight, count+1, recPid)
      
      {:bye, pid} ->
        neighbors = neighbors -- [pid]
        if (neighbors == []) do
          Process.exit(recPid, :kill)
        else
          receiveGossip(neighbors, mainProcess, sum, weight, count, recPid)
        end

    end
  end

end


defmodule GOSSIP do

  def createAgents(numNodes, pids) when numNodes == 0 do
    pids
  end

  def createAgents(numNodes, pids) do
    {:ok, pid} = Actor.start_link()
    pids = pids ++ [pid]
    createAgents(numNodes-1, pids)
  end

  
  def createFullTopology(agents, remAgents, curPos) when remAgents == [] do

  end

  def createFullTopology(agents, remAgents, curPos) do
    [head | tail] = remAgents
    neighbors = agents -- [head]
    Actor.setNeighbors(head, {neighbors, self(), curPos})
    IO.puts "Length"
    IO.puts length(neighbors)
    createFullTopology(agents, tail, curPos+1)
  end
  
  def getNthNode(agentsList, cur) when cur == 0 do
    [head | _] = agentsList
    head
  end

  def getNthNode(agentsList, cur) do
    [head | tail] = agentsList
    getNthNode(tail, cur-1)
  end

  def create2D(agents, cur, numNodes) when cur == numNodes do
    
  end

  def create2D(agents, cur, numNodes) do
    curNode = getNthNode(agents, cur)
    neighbors = []
    sq = :math.sqrt(numNodes)
    x = cur/sq
    y = rem(cur,sq)
    
    
    neighbors = if (x+1 <  sq) do
                  neighbors ++ [getNthNode(agents, (x+1)*sq+y)]
                else
                  neighbors
                end

    neighbors = if (y+1 <  sq) do
                  neighbors ++ [getNthNode(agents, x*sq+(y+1))]
                else
                  neighbors
                end

    neighbors = if (x-1 >= 0) do
                  neighbors ++ [getNthNode(agents, (x-1)*sq+y)]
                else
                  neighbors
                end

    neighbors = if (y-1 >=  0) do
                  neighbors ++ [getNthNode(agents, x*sq+(y-1))]
                else
                  neighbors
                end

    Actor.setNeighbors(curNode, {neighbors, self(), cur+1})
    create2D(agents, cur+1, numNodes)
  end

  def getRandomForNode(x, y, sq) do
    a = :rand.uniform(sq)
    b = :rand.uniform(sq)
    cond  do
      a==x && b==y -> getRandomForNode(x, y, sq)
      a==x-1 && b==y -> getRandomForNode(x, y, sq)
      a==x && b==y-1 -> getRandomForNode(x, y, sq)
      a==x+1 && b==y -> getRandomForNode(x, y, sq)
      a==x && b==y+1 -> getRandomForNode(x, y, sq)
      true -> x*sq+y
    end
  end

  def createImp2D(agents, cur, numNodes) when cur == numNodes do
    
  end

  def createImp2D(agents, cur, numNodes) do
    curNode = getNthNode(agents, cur)
    neighbors = []
    sq = :math.sqrt(numNodes)
    x = cur/sq
    y = rem(cur,sq)
    
    neighbors = if (x+1 <  sq) do
                  neighbors ++ [getNthNode(agents, (x+1)*sq+y)]
                else
                  neighbors
                end

    neighbors = if (y+1 <  sq) do
                  neighbors ++ [getNthNode(agents, x*sq+(y+1))]
                else
                  neighbors
                end

    neighbors = if (x-1 >= 0) do
                  neighbors ++ [getNthNode(agents, (x-1)*sq+y)]
                else
                  neighbors
                end

    neighbors = if (y-1 >=  0) do
                  neighbors ++ [getNthNode(agents, x*sq+(y-1))]
                else
                  neighbors
                end

    neighbors = neighbors ++ [getNthNode(agents, getRandomForNode(x,y,sq))]
    Actor.setNeighbors(curNode, {neighbors, self(), cur+1})
    create2D(agents, cur+1, numNodes)
  end

  def getNearestSquare(cur, numNodes) do
    if (cur*cur >= numNodes) do
      (cur*cur)
    else
      getNearestSquare(cur+1, numNodes)
    end
  end

  def createLine(prev, remAgents, curPos) do
    [cur | tail] = remAgents
    if tail == [] do
      
    else
      [next | _] = tail
      neighbors = prev ++ [next]
      Actor.setNeighbors(cur, {neighbors, self(), curPos})
      createLine([cur], tail, curPos+1)
    end
  end


  def getRandom(nodes, cur, len) when nodes == [] do
    cur
  end

  def getRandom(nodes, cur, len) do
    
    [head | tail] = nodes
    cur = if (:rand.uniform(len) == len) do
            head
          else 
            cur
          end
    getRandom(tail, cur, len+1)
  end

  def receiveResponse(cur, limit) when cur >= limit-1 do
    
  end

  def receiveResponse() do
    
    receive do
      {:sent} -> 
        receiveResponse()
      
    after
      1_000 -> IO.puts "Nothing"
    end
  end

  def start(numNodes, topology, algorithm) do
    numNodes = if (topology == "2D" || topology == "imp2D") do
                  getNearestSquare(1, numNodes)
               else
                  numNodes
               end

    agents = createAgents(numNodes, [])
    case topology do
      "Full" -> createFullTopology(agents, agents, 1)
      "2D" -> create2D(agents,  0, numNodes)
      "line" -> createLine( [], agents, 1)
      "imp2D" -> createImp2D(agents, 0, numNodes)
    end
    IO.puts "Start Gossip"
    cur = :os.system_time(:millisecond)
    pid = getRandom(agents, -1, 1)
    if (algorithm == "gossip") do
      send(pid, {:gossip})
    else
      send(pid, {:push, 0,0})  
    end
    receiveResponse()
    IO.puts (:os.system_time(:millisecond) - cur)
  end
end

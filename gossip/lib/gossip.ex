defmodule Bucket do
  use Agent

  def start_link(opts) do
    Agent.start_link(fn -> opts end)
  end

end



defmodule Actor do
  
  def sendGossip(neighbors, count) do
    pid = GOSSIP.getRandom(neighbors, -1, 1)
    send(pid, {:gossip})
    #if (count >= length())
    :timer.sleep(1)
    sendGossip(neighbors)
  end

  def sendPushMessage(bucket, neighbors) do
    {s, w} = Agent.get(bucket, fn state -> state end)
    Agent.update(bucket, fn state -> {sum, wei} = state
                                      {sum - s/2, wei - w/2} end)
    pid = GOSSIP.getRandom(neighbors, -1, 1)
    send(pid, {:push, s/2, w/2})
    :timer.sleep(1)
    sendPushMessage(bucket, neighbors)
  end

  def receiveGossip(bucket, mainProcess, count, isFirst, neighbors, senderThread) do
    
    receive do
      {:push, s,w} ->
        {sum, weight} = Agent.get(bucket, fn state -> state end)
        Agent.update(bucket, fn state -> {sm, wei} = state
                                    {sm + s, wei + w} end)
        {isFirst, senderThread} = if (isFirst == 1) do
            tmpSenderThread = spawn(Actor, :sendPushMessage, [bucket, neighbors])
            {0, tmpSenderThread}
          else
            {isFirst, senderThread}
          end
        s = sum + s
        w = weight + w
        
        count = if (count < 3) do    
                  counter = if (abs(sum/weight - s/w) <= 0.0000000001) do
                              count + 1
                            else
                              0
                            end
                  counter
                end

        if (count == 3) do
          Process.exit(senderThread, :kill)
          send(mainProcess, {:killall})
        end
        #IO.puts sum/weight
        receiveGossip(bucket, mainProcess, count, isFirst, neighbors, senderThread)
      
      {:gossip} ->
        senderThread =  if (count == 0) do
                          send(mainProcess, {:receivedFirst})
                          spawn(Actor, :sendGossip, [neighbors])
                        else
                          senderThread
                        end
        
        {sum, _} = Agent.get(bucket, fn state -> state end)
        #IO.puts sum
        
        if (count == 10) do
          Process.exit(senderThread, :kill)
        end
        
        receiveGossip(bucket, mainProcess, count+1, isFirst, neighbors, senderThread)
      
      {:stop} ->
        if (senderThread != self() && Process.alive?(senderThread)) do
          Process.exit(senderThread, :kill)
        end
        {sum, weight} = Agent.get(bucket, fn state -> state end)
        #IO.puts "Done with thread " <> to_string(sum/weight)
        Process.exit(bucket, :kill)
    end
  end


  def start() do
    receive do
      {neighbors, mainProcess, curPos} ->
          {:ok, bucket} = Bucket.start_link({curPos, 1}) 
          receiveGossip(bucket, mainProcess, 0, 1, neighbors, self())
    end
    
  end

end


defmodule GOSSIP do

  
  def createAgents(numNodes, pids) when numNodes == 0 do
    pids
  end

  def createAgents(numNodes, pids) do
    pid = spawn(Actor, :start, [])
    pids = [pid | pids]
    createAgents(numNodes-1, pids)
  end

  def reorderNeighbors(neighbors, cur, newList, head, len) when cur == 0 do
    newList
  end

  def reorderNeighbors(neighbors, cur, newList, head, len) do
    tmp = :rand.uniform(len)
    tmp = Map.get(neighbors, tmp-1)
    if (tmp != head) do
      reorderNeighbors(neighbors, cur-1, [tmp | newList], head, len)
    else
      reorderNeighbors(neighbors, cur, newList, head, len)
    end
  end


  def createFullTopology(mapAgents, agents, remAgents, curPos) when remAgents == [] do

  end
  

  def createFullTopology(mapAgents, agents, remAgents, curPos) do
    [head | tail] = remAgents
    neighbors = if (map_size(mapAgents) > 200) do
                        reorderNeighbors(mapAgents, round(:math.sqrt(map_size(mapAgents)))+1, [], head, map_size(mapAgents))
                      else
                        agents -- [head]
                      end
    send(head, {neighbors, self(), curPos})
    #IO.puts "Length"
    #IO.puts length(neighbors)
    createFullTopology(mapAgents, agents, tail, curPos+1)
  end
  
  def getNthNode(agentsList, cur) when cur == 0 do
    [head | tail] = agentsList
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
    sq = round(sq)
    x = div(cur, sq)
    #IO.puts cur
    #IO.puts sq
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

    send(curNode, {neighbors, self(), cur+1})
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
    sq = round(sq)
    x = div(cur, sq)
    #IO.puts cur
    #IO.puts sq
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
    send(curNode, {neighbors, self(), cur+1})
    create2D(agents, cur+1, numNodes)
  end

  def getNearestSquare(cur, numNodes) do
    if (cur*cur >= numNodes) do
      (cur*cur)
    else
      getNearestSquare(cur+1, numNodes)
    end
  end

  
  def createLine(prev, remAgents, curPos) when remAgents == [] do
    
  end

  def createLine(prev, remAgents, curPos) do
    [cur | tail] = remAgents
    next = if tail == [] do
              []
           else 
              [tmpNext | _] = tail
              [tmpNext]
           end
      neighbors = prev ++ next
      send(cur, {neighbors, self(), curPos})
      createLine([cur], tail, curPos+1)
  end


  def getRandom(nodes, cur, len) do
    
    tmp = :rand.uniform(length(nodes))
    Enum.at(nodes, tmp-1)

  end

  def killChildProcess(agents) when agents == [] do
    
  end

  def killChildProcess(agents) do
    [head | tail] = agents
    send(head, {:stop})
    killChildProcess(tail)
  end
  
  def receiveResponse(counter, numNodes, agents) do
    
    receive do
      {:killall} ->
        killChildProcess(agents)
      {:receivedFirst} ->
        counter = counter + 1
        if (100*counter >= 95*numNodes) do
          killChildProcess(agents)
        else
          receiveResponse(counter, numNodes, agents)
        end
    end
  end

  def sendToAll(agents) when agents == [] do
    
  end

  def sendToAll(agents) do
    [head | tail] = agents
    send(head, {:push, 0, 0})
    sendToAll(tail)
  end

  def receiveDuplicateKills() do
    receive do
      {_} -> receiveDuplicateKills();
    after 5_00 -> 

    end
  end

  
  def getMappedAgents(agents, res, cur) when agents == [] do
    res
  end

  def getMappedAgents(agents, res, cur) do
    [head | tail] = agents
    res = Map.put(res, cur, head)
    getMappedAgents(tail, res, cur+1)
  end

  def start(numNodes, topology, algorithm) do
    numNodes = if (topology == "2D" || topology == "imp2D") do
                  getNearestSquare(1, numNodes)
               else
                  numNodes
               end

    agents = createAgents(numNodes, [])
    case topology do
      "full" -> createFullTopology(getMappedAgents(agents, %{}, 0), agents, agents, 1)
      "2D" -> create2D(agents,  0, numNodes)
      "line" -> createLine( [], agents, 1)
      "imp2D" -> createImp2D(agents, 0, numNodes)
    end
    #IO.puts "Start Gossip"
    cur = :os.system_time(:millisecond)
    if (algorithm == "gossip") do
      pid = getRandom(agents, -1, 1)
      send(pid, {:gossip})
    else
      sendToAll(agents)  
    end
    receiveResponse(0, numNodes, agents)
    #flush()
    cur = :os.system_time(:millisecond) - cur
    receiveDuplicateKills()
    #IO.puts "Done"
    cur
    
  end

  def startTestFor(_,_, cur, limit) when cur > limit do
    
  end

  def startTestFor(topology, algorithm, cur, limit) do
    res = start(cur, topology, algorithm)
    IO.puts to_string(cur) <> " " <> topology <> " " <> algorithm <> " " <> to_string(res)
    startTestFor(topology, algorithm, 2*cur, limit)
  end

  def startTest() do
    startTestFor("full", "gossip", 2, 4096)
    startTestFor("full", "push-sum", 2, 4096)
    startTestFor("2D", "gossip", 2, 4096)
    startTestFor("2D", "push-sum", 2, 4096)
    startTestFor("imp2D", "gossip", 2, 4096)
    startTestFor("imp2D", "push-sum", 2, 4096)
    startTestFor("line", "gossip", 2, 4096)
    startTestFor("line", "push-sum", 2, 4096)

  end

end

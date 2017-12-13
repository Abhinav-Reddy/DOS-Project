
defmodule Clientmodule do

  def createChannel(channelName) do
    {:ok, pid} = PhoenixChannelClient.start_link()
    {:ok, socket} = PhoenixChannelClient.connect(pid,
      host: "localhost",
      port: 4000,
      path: "/socket/websocket",
      params: %{"isUser" => "true"}
      )
      channel = PhoenixChannelClient.channel(socket, channelName, %{name: channelName})
      case PhoenixChannelClient.join(channel) do
        {:ok, _} -> {:ok}
        {:error, reason} -> {:stop, reason}
        :timeout -> {:stop, :timeout}
      end
      channel 
  end

  def userFunctions(channel, timeLine, allUsers, userName) do
    channel = if(channel == :null) do
               createChannel("login:"<>userName)
             else
               channel
             end 
    timeLine = receive do
      {:login} -> PhoenixChannelClient.push(channel, "new_msg", %{"msg" => Tuple.to_list({:login, userName})})
      PhoenixChannelClient.push(channel, "new_msg", %{"msg" => Tuple.to_list({:subscribedTweets, userName})})
                  timeLine
      {:logout} -> PhoenixChannelClient.push(channel, "new_msg", %{"msg" => Tuple.to_list({:logout ,userName})})
                    timeLine
      {:follow, user} -> 
          PhoenixChannelClient.push(channel, "new_msg", %{"msg" => Tuple.to_list({:follow ,user, userName})})
          timeLine
      {:tweet} -> PhoenixChannelClient.push(channel, "new_msg", %{"msg" => Tuple.to_list({:tweet, userName, 
                                          to_string(:os.system_time(:millisecond))})})
          timeLine
      {:tweet, :mention, user} -> PhoenixChannelClient.push(channel, "new_msg", %{"msg" => 
            Tuple.to_list({:tweet, userName, to_string(:os.system_time(:millisecond)) <> " @" <> user})})
          timeLine
      {:tweet, :tag, tag} -> PhoenixChannelClient.push(channel, "new_msg", %{"msg" => Tuple.to_list(
                {:tweet, userName, to_string(:os.system_time(:millisecond)) <> " #" <> tag})})
          timeLine        
      {:myMention} -> PhoenixChannelClient.push(channel, "new_msg", %{"msg" => 
            Tuple.to_list({:myMention, userName})})
          timeLine
    
      {:gettweetsWithTag, tag} -> PhoenixChannelClient.push(channel, "new_msg", 
            %{"msg" => Tuple.to_list({:tweetsWithTag, tag, userName})})
          timeLine
    
      {:getsubscribedTweets} -> PhoenixChannelClient.push(channel, "new_msg", 
            %{"msg" => Tuple.to_list({:subscribedTweets ,userName})})
          timeLine
    
      {:retweet} ->
          len = length(timeLine)
          if (len > 0) do
              len = :rand.uniform(len) - 1
              [_, tweet] = Enum.at(timeLine, len)
              PhoenixChannelClient.push(channel, "new_msg", %{"msg" => 
                    Tuple.to_list({:retweet, userName, tweet})}) 
          end
          timeLine
       {"out_msg", event} ->
            event = event["msg"]
            #IO.inspect(userName)
            #IO.inspect(event)
            if (Enum.at(event, 0) == "subscribedTweets" && Enum.at(event, 1) != nil) do
                Enum.at(event, 1)
            else
                timeLine
            end
        event ->
            timeLine
      end
      userFunctions(channel, timeLine, allUsers, userName)
    end

    def registerUsers( users, readerPids, _) when users == [] do
        readerPids
    end

    def registerUsers(users, readerPids, allUsers) do
        [userName | tl] = users
        channel = createChannel("login:"<>userName)
        PhoenixChannelClient.push(channel, "new_msg", %{"msg" => Tuple.to_list({:register, userName})})
        receive do
            event -> 1 #IO.inspect(event)
        end
        receive do
            event -> 1 #IO.inspect(event)
        end
        PhoenixChannelClient.leave(channel)
        timeLine = []
        readerPid = spawn(Clientmodule, :userFunctions, [:null, timeLine, allUsers, userName])
        registerUsers(tl, [readerPid | readerPids], allUsers)
    end


    def loginUsers(_, readerPids) when readerPids == [] do

    end
    
    def loginUsers(allUsers, readerPids) do
        [hdPid | tlPids] = readerPids
        send(hdPid, {:login})
        loginUsers(allUsers, tlPids)
    end


    def getRandomName(len, res, _) when len == 0 do
        res
    end

    def getRandomName(len, res, chars) do
        getRandomName(len-1, res<>String.at(chars, :rand.uniform(52)-1), chars)
    end

    def getRandomNames(numUsers, res, _) when numUsers == 0 do
        res
    end

    def getRandomNames(numUsers, res, chars) do
        len = 4+:rand.uniform(5)
        getRandomNames(numUsers-1, [getRandomName(len, "", chars) | res], chars)
    end


    def sendFollowRequests(_, follwers, _) when follwers == [] do
        
    end

    def sendFollowRequests(user, follwers, userFuncPid) do
        [hd | tl] = follwers
        send(userFuncPid, {:follow, hd})
        sendFollowRequests(user, tl, userFuncPid)
    end

    def getRandomUsers(_, _, cnt, res, _) when cnt <= 0 do
        res
    end

    def getRandomUsers(user, allUsers, cnt, res, len) do
        nextUser = Enum.at(allUsers, :rand.uniform(len)-1)
        if (nextUser == user) do
            getRandomUsers(user, allUsers, cnt, res, len)
        else
            getRandomUsers(user, allUsers, cnt-1, [nextUser | res], len)
        end
    end

    def addFollowers(remUsers, _, _, _, _) when remUsers == [] do
        
    end

    def addFollowers(remUsers, allUsers, count, factor, readerPids) do
        
        [hd | tl] = remUsers
        [hdPid | tlPids] = readerPids
        tmpCnt = if (count/factor > 5) do
                    count/factor
                  else
                    min(count, 5)
                  end
        randUsers = getRandomUsers(hd, allUsers, tmpCnt, [], length(allUsers))
        sendFollowRequests(hd, randUsers, hdPid)
        addFollowers(tl, allUsers, count, factor+1, tlPids)
    end

    def startWorker(pid, userNames, randTags, waitTime) do
        :timer.sleep(waitTime)
        action = :rand.uniform(85)
        if (action <= 15) do
            tweetAction = :rand.uniform(3)
            if (tweetAction == 1) do
                send(pid, {:tweet})
            else if (tweetAction == 2) do
                send(pid, {:tweet, :mention, Enum.at(userNames, :rand.uniform(length(userNames)-1))})
            else
                send(pid, {:tweet, :tag, Enum.at(randTags, :rand.uniform(length(randTags)-1))})
            end
            end
        else if (action <= 30) do
                send(pid, {:retweet})
        else if (action <= 45) do
                send(pid, {:getsubscribedTweets})
        else if (action <= 60) do
                send(pid, {:myMention})
        else if (action <= 75) do
                send(pid, {:gettweetsWithTag, Enum.at(randTags, :rand.uniform(length(randTags)-1))})
        else if (action == 83) do
                send(pid, {:logout})
                :timer.sleep(5000)
        else if (action == 84) do
                send(pid, {:login})
                :timer.sleep(5000)
        end
        end
        end
        end
        end
        end
        end
        startWorker(pid, userNames, randTags, waitTime)
    end

    def createWorkGenerators(readerPids, _, _, _, _, _) when readerPids == [] do
        
    end

    def createWorkGenerators(readerPids, userNames, randTags, count, pos, numReq) do
        #:timer.sleep(5000)
        [hd | tl] = readerPids
        waitTime = 1000*count/numReq
      #   waitTime = round(Float.ceil(count/5)*(count/5000))
        waitTime = round(Float.ceil(waitTime - waitTime/(3*pos)))
        spawn(Clientmodule, :startWorker, [hd, userNames, randTags, waitTime])
        :timer.sleep(10)
        createWorkGenerators(tl, userNames, randTags, count, pos+1, numReq)
    end

    def loop() do
        :timer.sleep(2)
        loop()
    end
    
    def startClients(numUsers, numReq) do
        #{:ok, server} = TWITTER.start_link([])
        userNames = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        randTags = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        readerPids = registerUsers(userNames, [], userNames)
        readerPids = Enum.reverse(readerPids)
        :timer.sleep(3000)
        loginUsers(userNames, readerPids)
        :timer.sleep(3000)
        addFollowers(userNames, userNames, 7*length(userNames)/100+1, 1, readerPids)
        :timer.sleep(3000)
        createWorkGenerators(readerPids, userNames, randTags, length(userNames), 1, numReq)
        loop()
    end

    def test(numUsers) do
      #{:ok, server} = TWITTER.start_link([])
      userNames = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
      randTags = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
      readerPids = registerUsers(userNames, [], userNames)
      readerPids = Enum.reverse(readerPids)
      :timer.sleep(numUsers)
      loginUsers(userNames, readerPids)
      :timer.sleep(numUsers)
      addFollowers(userNames, userNames, length(userNames)/2+1, 1, readerPids)
      :timer.sleep(numUsers)
      
      #IO.puts(TWITTER.getLoad(server))
      :timer.sleep(100)
      
      send(Enum.at(readerPids, 0), {:tweet})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 0), {:tweet, :mention, Enum.at(userNames, 1)})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 0), {:tweet, :tag, Enum.at(randTags, 0)})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 0), {:tweet, :mention, Enum.at(userNames, 1)})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 0), {:gettweetsWithTag, Enum.at(randTags, 0)})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 1), {:myMention})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 1), {:tweet})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 1), {:logout})
      :timer.sleep(1000)
      send(Enum.at(readerPids, 0), {:tweet})
      :timer.sleep(100)
      #IO.puts(TWITTER.getLoad(server))
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:login})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:login})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:getsubscribedTweets})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:tweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:retweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 2), {:tweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:getsubscribedTweets})
      :timer.sleep(100)
      #IO.puts(TWITTER.getLoad(server))
    end
    
    def startClient(numUsers, numReq) do
        startClients(numUsers, numReq)
        #test(numUsers)
    end
  end

  defmodule ClientmoduleStart do
    def main([]) do
      IO.puts "Enter Valid Number of Clients"
    end
  
    def main(argv) do
        val = List.first(argv)
        user_count = String.to_integer(val)
        Clientmodule.startClient(user_count)
    end
      
end

      




defmodule SERVER do
  use GenServer
  
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, {%{}, %{}, %{}}}
  end

  def register(server, {userName}) do
    GenServer.cast(server, {:register, userName})
  end

  def login(server, {userName}) do
    GenServer.cast(server, {:login, userName})
  end

  def logout(server, {userName}) do
    GenServer.cast(server, {:logout, userName})
  end

  def update(server, {users, tweetid, action, tweet}) do
    GenServer.cast(server, {:updateUsers, users, tweetid, action, tweet})
  end

  def myMention(server, {userName}) do
    GenServer.cast(server, {:myMention, userName})
  end

  def getTweetsWithTag(server, {tag, userName}) do
    GenServer.cast(server, {:tweetsWithTag, tag, userName})
  end

  def getSubscribedTweets(server, {userName}) do
    GenServer.cast(server, {:subscribedTweets, userName})
  end

  def ping(server) do
    GenServer.call(server, {:ping})
  end

  def getTweetsFromIds(_, tweetids, res) when tweetids == [] do
    res
  end

  def getTweetsFromIds(tweets, tweetids, res) do
    [{tweetid, action} | tl] = tweetids
    getTweetsFromIds(tweets, tl, [{action, Map.get(tweets, tweetid)} | res])
  end

  def getTweetsWithAction(_, tweetids, _, res) when tweetids == [] do
    res
  end

  def getTweetsWithAction(_, tweetids, _, res) when tweetids == nil do
    res
  end

  def getTweetsWithAction(tweets, tweetids, cmp, res) do
    [{tweetid, action} | tl] = tweetids
    if (String.contains?(action, cmp) == true) do
      getTweetsWithAction(tweets, tl, cmp, [{action, Map.get(tweets, tweetid)} | res])
    else
      getTweetsWithAction(tweets, tl, cmp, res)
    end
  end


  def updateTimeLines(users, _, _, timeLines, _, _) when users == [] do
    timeLines
  end

  def updateTimeLines(users, tweetid, action, timeLines, registeredUsers, tweets) do
    [hd | tl] = users
    tmpList = if (Map.has_key?(timeLines, hd)) do
                Map.get(timeLines, hd)
              else
                []
              end
    tmpList = if (tmpList > 100) do
                Enum.slice(tmpList, 0, 50)
              else
                tmpList
              end
    if (registeredUsers != %{}) do
      channel = Map.get(registeredUsers, hd)
      if (channel != :null) do
        PhoenixChannelClient.push(channel, "out_msg", 
        %{"msg" => {:timeLine, {action, Map.get(tweets, tweetid)}}})
      end
    end
    updateTimeLines(tl, tweetid, action, Map.put(timeLines, hd, [{tweetid, action} | tmpList]), 
      registeredUsers, tweets)
  end

  def createChannel(channelName) do
    {:ok, pid} = PhoenixChannelClient.start_link()
    {:ok, socket} = PhoenixChannelClient.connect(pid,
      host: "localhost",
      port: 4000,
      path: "/socket/websocket",
    )
    channel = PhoenixChannelClient.channel(socket, channelName, %{name: channelName})
    case PhoenixChannelClient.join(channel) do
      {:ok, _} -> {:ok}
      {:error, reason} -> {:stop, reason}
      :timeout -> {:stop, :timeout}
    end
    channel 
  end

  def handle_cast({:register, userName}, 
                    {timeLines, tweets, registeredUsers}) do
    
    channel = createChannel("login:"<>userName)
    if Map.has_key?(registeredUsers, userName) do
      PhoenixChannelClient.push(channel, "out_msg", 
        %{"msg" => {:failed, "User name already exists " <> userName}})
      PhoenixChannelClient.leave(channel)
      {:noreply, {timeLines, tweets, registeredUsers}}
    else
      PhoenixChannelClient.push(channel, "out_msg",
        %{"msg" => {:success, "Registered successfully " <> userName}})
      PhoenixChannelClient.leave(channel)
      {:noreply, {timeLines, tweets, Map.put(registeredUsers, userName, :null)} }
    end
  end

  def handle_cast({:login, userName}, 
                    {timeLines, tweets, registeredUsers}) do
    channel = createChannel("login:"<>userName)
    if Map.has_key?(registeredUsers, userName) == false do
      PhoenixChannelClient.push(channel, "out_msg",
        %{"msg" => {:failed, "User name doesnt exist "<> userName}})
      PhoenixChannelClient.leave(channel)
      {:noreply, {timeLines, tweets, registeredUsers}}
    else
      PhoenixChannelClient.push(channel, "out_msg",
        %{"msg" => {:success, "Login successfull " <> userName}})
      { :noreply, {timeLines, tweets, Map.put(registeredUsers, userName, channel)} }
    end
  end

  def handle_cast({:logout, userName}, 
                    {timeLines, tweets, registeredUsers}) do
    if Map.has_key?(registeredUsers, userName) == false do
      {:noreply, {timeLines, tweets, registeredUsers}}
    else
      channel = Map.get(registeredUsers, userName)
      PhoenixChannelClient.push(channel, "out_msg",
        %{"msg" => {:success, "Logout successfull " <> userName}})
      { :noreply, {timeLines, tweets, Map.put(registeredUsers, userName, :null)} }
    end
  end

  def handle_cast({:updateUsers, users, tweetid, action, tweet}, 
                    {timeLines, tweets, registeredUsers}) do
    tweets = Map.put(tweets, tweetid, tweet)
    {:noreply, {updateTimeLines(users, tweetid, action, timeLines, registeredUsers, tweets),
       tweets, registeredUsers}}
  end

  def handle_cast({:myMention, userName}, 
                    {timeLines, tweets, registeredUsers}) do
    tweetids = Map.get(timeLines, userName)
    sendInfo = if (tweetids != nil) do
                  getTweetsWithAction(tweets, tweetids, "mention", [])
               else
                  tweetids
               end
    channel = registeredUsers[userName]
    PhoenixChannelClient.push(channel, "out_msg",
      %{"msg" => {:myMention, sendInfo}})
    {:noreply, {timeLines, tweets, registeredUsers}}
  end

  def handle_cast({:tweetsWithTag, tag, userName}, 
                    {timeLines, tweets, registeredUsers}) do
    tweetids = Map.get(timeLines, tag)
    sendInfo = if (tweetids != nil) do
                getTweetsFromIds(tweets, tweetids, [])
               else
                tweetids
               end
    channel = registeredUsers[userName]
    PhoenixChannelClient.push(channel, "out_msg",
      %{"msg" => {:tweetsWithTag, sendInfo}})
    {:noreply, {timeLines, tweets, registeredUsers}}
  end

  def handle_cast({:subscribedTweets, userName}, 
                    {timeLines, tweets, registeredUsers}) do
    tweetids = Map.get(timeLines, userName)
    sendInfo = if (tweetids != nil) do
                getTweetsWithAction(tweets, tweetids, "tweet", [])
               else
                tweetids
               end
    channel = registeredUsers[userName]
    PhoenixChannelClient.push(channel, "out_msg",
      %{"msg" => {:subscribedTweets, sendInfo}})
    {:noreply, {timeLines, tweets, registeredUsers}}
  end

  def handle_call({:ping}, __from, {timeLines,tweets, registeredUsers}) do
    {:reply, :ok, {timeLines, tweets, registeredUsers}}
  end

end
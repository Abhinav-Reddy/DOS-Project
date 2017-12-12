defmodule Project5testWeb.LoginChannel do
    use Phoenix.Channel
  
    def join(userName, message, socket) do
        {:ok, socket}
    end

    def handle_in("new_msg", query, socket) do
        GenServer.cast(MyServer, List.to_tuple(query["msg"]))
        {:noreply, socket}
    end

    def handle_in("out_msg", query, socket) do
        broadcast! socket, "out_msg", query
        {:noreply, socket}
    end

    intercept ["out_msg"]
    
    def handle_out("out_msg", msg, socket) do
      if (socket.assigns["isUser"] == "false") do
        {:noreply, socket}
      else
        push socket, "out_msg", msg
        {:noreply, socket}
      end
    end

  end


#   defmodule Project5testWeb.RegisterChannel do
#     use Phoenix.Channel
  
#     def join(userName, _message, socket) do
#       {:ok, socket}
#     end

#     def handle_in("new_msg", query, socket) do
#         GenServer.cast(Myserver, query[:msg])
#         {:noreply, socket}
#     end

#     # intercept ["user_joined"]
    
#     # def handle_out("user_joined", msg, socket) do
#     #   if Accounts.ignoring_user?(socket.assigns[:user], msg.user_id) do
#     #     {:noreply, socket}
#     #   else
#     #     push socket, "user_joined", msg
#     #     {:noreply, socket}
#     #   end
#     # end

#   end
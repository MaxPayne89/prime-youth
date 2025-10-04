defmodule PrimeYouthWeb.HighlightsLive do
  use PrimeYouthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    posts = [
      %{
        id: "post_1",
        author: "Ms. Sarah - Art Instructor",
        avatar_bg: "bg-prime-cyan-400",
        avatar_emoji: "👩‍🏫",
        timestamp: "2 hours ago",
        content: "Amazing creativity from our Art World students today! 🎨 They're working on their masterpieces for the upcoming showcase. So proud of their progress!",
        type: :photo,
        photo_emoji: "🎨📸",
        likes: 12,
        comment_count: 5,
        user_liked: false,
        comments: [
          %{author: "Parent Maria", text: "Emma loves this class!"},
          %{author: "Parent John", text: "Can't wait for the showcase! 🎭"}
        ]
      },
      %{
        id: "post_2",
        author: "Mr. David - Chess Coach",
        avatar_bg: "bg-prime-magenta-400",
        avatar_emoji: "👨‍🏫",
        timestamp: "5 hours ago",
        content: "Reminder: Chess tournament registration closes this Friday! 🏆 Great opportunity for our advanced students to showcase their skills. Prize ceremony will include medals and certificates! ♟️",
        type: :text,
        likes: 8,
        comment_count: 3,
        user_liked: false,
        comments: []
      },
      %{
        id: "post_3",
        author: "Prime Youth Admin",
        avatar_bg: "bg-prime-yellow-400",
        avatar_emoji: "📋",
        timestamp: "1 day ago",
        content: "🎉 Exciting News! We're hosting a Family Fun Day next Saturday! Join us for games, food trucks, and showcase performances from all our programs. Free entry for all Prime Youth families!",
        type: :event,
        event_details: %{
          title: "📅 Family Fun Day",
          date: "Saturday, March 15th • 10 AM - 4 PM",
          location: "Greenwood Elementary School"
        },
        likes: 25,
        comment_count: 12,
        user_liked: false,
        comments: []
      }
    ]

    socket =
      socket
      |> assign(page_title: "Highlights")
      |> assign(posts: posts)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_like", %{"post_id" => post_id}, socket) do
    posts = Enum.map(socket.assigns.posts, fn post ->
      if post.id == post_id do
        if post.user_liked do
          %{post | user_liked: false, likes: post.likes - 1}
        else
          %{post | user_liked: true, likes: post.likes + 1}
        end
      else
        post
      end
    end)

    {:noreply, assign(socket, posts: posts)}
  end

  @impl true
  def handle_event("add_comment", %{"post_id" => post_id, "comment" => comment_text}, socket) do
    if String.trim(comment_text) == "" do
      {:noreply, socket}
    else
      posts = Enum.map(socket.assigns.posts, fn post ->
        if post.id == post_id do
          new_comment = %{author: "You", text: comment_text}
          %{post | comments: post.comments ++ [new_comment], comment_count: post.comment_count + 1}
        else
          post
        end
      end)

      {:noreply, assign(socket, posts: posts)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-prime-cyan-400/10 via-prime-magenta-400/10 to-prime-yellow-400/10">
      <div class="max-w-2xl mx-auto px-4 py-6">
        <!-- Header -->
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-3xl font-bold text-gray-800">Highlights</h1>
          <button class="btn btn-circle btn-ghost">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
            </svg>
          </button>
        </div>

        <!-- Feed Posts -->
        <div class="space-y-4">
          <%= for post <- @posts do %>
            <div class="card bg-white shadow-lg">
              <div class="card-body p-4">
                <!-- Post Header -->
                <div class="flex items-center gap-3 mb-4">
                  <div class={"w-10 h-10 rounded-full #{post.avatar_bg} text-white flex items-center justify-center text-xl"}>
                    <%= post.avatar_emoji %>
                  </div>
                  <div class="flex-1">
                    <div class="font-semibold text-gray-800"><%= post.author %></div>
                    <div class="text-sm text-gray-500"><%= post.timestamp %></div>
                  </div>
                </div>

                <!-- Post Content -->
                <p class="text-gray-700 mb-4 leading-relaxed">
                  <%= post.content %>
                </p>

                <!-- Photo Post -->
                <%= if post.type == :photo do %>
                  <div class="h-48 bg-gradient-to-br from-prime-yellow-400/30 to-prime-yellow-400/50 rounded-lg flex items-center justify-center text-5xl mb-4">
                    <%= post.photo_emoji %>
                  </div>
                <% end %>

                <!-- Event Post -->
                <%= if post.type == :event do %>
                  <div class="bg-prime-cyan-400/10 border-2 border-prime-cyan-400 rounded-lg p-4 mb-4">
                    <div class="font-semibold text-gray-800 mb-1"><%= post.event_details.title %></div>
                    <div class="text-sm text-gray-600"><%= post.event_details.date %></div>
                    <div class="text-sm text-gray-600"><%= post.event_details.location %></div>
                  </div>
                <% end %>

                <!-- Post Actions -->
                <div class="border-t border-gray-100 pt-4">
                  <div class="flex gap-6 mb-3">
                    <button
                      phx-click="toggle_like"
                      phx-value-post_id={post.id}
                      class={"flex items-center gap-2 #{if post.user_liked, do: "text-red-500", else: "text-gray-500 hover:text-red-500"} transition-colors"}
                    >
                      <span class="text-xl"><%= if post.user_liked, do: "❤️", else: "🤍" %></span>
                      <span class="text-sm font-medium"><%= post.likes %></span>
                    </button>
                    <button class="flex items-center gap-2 text-gray-500 hover:text-prime-cyan-400 transition-colors">
                      <span class="text-xl">💬</span>
                      <span class="text-sm font-medium"><%= post.comment_count %></span>
                    </button>
                  </div>

                  <!-- Comments Preview -->
                  <%= if length(post.comments) > 0 do %>
                    <div class="bg-gray-50 rounded-lg p-3 mb-3 space-y-2">
                      <%= for comment <- post.comments do %>
                        <div class="flex gap-2">
                          <span class="font-semibold text-gray-800 text-sm"><%= comment.author %>:</span>
                          <span class="text-gray-600 text-sm"><%= comment.text %></span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <!-- Add Comment -->
                  <form phx-submit="add_comment" class="flex gap-2">
                    <input type="hidden" name="post_id" value={post.id} />
                    <input
                      type="text"
                      name="comment"
                      placeholder="Write a comment..."
                      class="flex-1 input input-bordered input-sm bg-white border-gray-300 focus:border-prime-cyan-400 focus:ring-1 focus:ring-prime-cyan-400"
                      autocomplete="off"
                    />
                    <button type="submit" class="btn btn-sm bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white border-0 hover:shadow-lg">
                      Post
                    </button>
                  </form>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

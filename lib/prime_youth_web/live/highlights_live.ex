defmodule PrimeYouthWeb.HighlightsLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.CompositeComponents

  if Mix.env() == :dev do
    import PrimeYouthWeb.Live.SampleFixtures

    use PrimeYouthWeb.DevAuthToggle
  end

  @impl true
  def mount(_params, _session, socket) do
    posts = [
      %{
        id: "post_1",
        author: "Ms. Sarah - Art Instructor",
        avatar_bg: "bg-prime-cyan-400",
        avatar_emoji: "👩‍🏫",
        timestamp: "2 hours ago",
        content:
          "Amazing creativity from our Art World students today! 🎨 They're working on their masterpieces for the upcoming showcase. So proud of their progress!",
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
        content:
          "Reminder: Chess tournament registration closes this Friday! 🏆 Great opportunity for our advanced students to showcase their skills. Prize ceremony will include medals and certificates! ♟️",
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
        content:
          "🎉 Exciting News! We're hosting a Family Fun Day next Saturday! Join us for games, food trucks, and showcase performances from all our programs. Free entry for all Prime Youth families!",
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
      |> assign(current_user: nil)
      |> stream(:posts, posts)
      |> assign(:posts_empty?, Enum.empty?(posts))

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_like", %{"post_id" => post_id}, socket) do
    # Find and update the post in the stream
    posts = get_all_posts()
    updated_posts = Enum.map(posts, &toggle_post_like(&1, post_id))

    {:noreply, stream(socket, :posts, updated_posts, reset: true)}
  end

  @impl true
  def handle_event("add_comment", %{"post_id" => post_id, "comment" => comment_text}, socket) do
    case String.trim(comment_text) do
      "" ->
        {:noreply, socket}

      trimmed_comment ->
        posts = get_all_posts()
        updated_posts = Enum.map(posts, &add_comment_to_post(&1, post_id, trimmed_comment))
        {:noreply, stream(socket, :posts, updated_posts, reset: true)}
    end
  end

  # Private helpers - Data fetching
  defp get_all_posts do
    [
      %{
        id: "post_1",
        author: "Ms. Sarah - Art Instructor",
        avatar_bg: "bg-prime-cyan-400",
        avatar_emoji: "👩‍🏫",
        timestamp: "2 hours ago",
        content:
          "Amazing creativity from our Art World students today! 🎨 They're working on their masterpieces for the upcoming showcase. So proud of their progress!",
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
        content:
          "Reminder: Chess tournament registration closes this Friday! 🏆 Great opportunity for our advanced students to showcase their skills. Prize ceremony will include medals and certificates! ♟️",
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
        content:
          "🎉 Exciting News! We're hosting a Family Fun Day next Saturday! Join us for games, food trucks, and showcase performances from all our programs. Free entry for all Prime Youth families!",
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
  end

  # Private helpers - Business logic
  defp toggle_post_like(post, post_id) when post.id == post_id do
    if post.user_liked do
      %{post | user_liked: false, likes: post.likes - 1}
    else
      %{post | user_liked: true, likes: post.likes + 1}
    end
  end

  defp toggle_post_like(post, _post_id), do: post

  defp add_comment_to_post(post, post_id, comment_text) when post.id == post_id do
    new_comment = %{author: "You", text: comment_text}
    %{post | comments: post.comments ++ [new_comment], comment_count: post.comment_count + 1}
  end

  defp add_comment_to_post(post, _post_id, _comment_text), do: post

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-prime-cyan-400/10 via-prime-magenta-400/10 to-prime-yellow-400/10">
      <div class="max-w-2xl mx-auto px-4 py-6">
        <!-- Header -->
        <.page_header class="!p-0 !bg-transparent !shadow-none mb-6">
          <:title>
            <h1 class="text-3xl font-bold text-gray-800">Highlights</h1>
          </:title>
          <:actions>
            <button class="btn btn-circle btn-ghost">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                />
              </svg>
            </button>
          </:actions>
        </.page_header>
        
    <!-- Feed Posts -->
        <div id="posts" phx-update="stream" class="space-y-4">
          <.social_post
            :for={{dom_id, post} <- @streams.posts}
            id={dom_id}
            post_id={post.id}
            author={post.author}
            avatar_bg={post.avatar_bg}
            avatar_emoji={post.avatar_emoji}
            timestamp={post.timestamp}
            content={post.content}
            likes={post.likes}
            comment_count={post.comment_count}
            user_liked={post.user_liked}
          >
            <:photo_content :if={post.type == :photo}>
              <div class="h-48 bg-gradient-to-br from-prime-yellow-400/30 to-prime-yellow-400/50 rounded-lg flex items-center justify-center text-5xl">
                {post.photo_emoji}
              </div>
            </:photo_content>
            <:event_content :if={post.type == :event}>
              <div class="bg-prime-cyan-400/10 border-2 border-prime-cyan-400 rounded-lg p-4">
                <div class="font-semibold text-gray-800 mb-1">{post.event_details.title}</div>
                <div class="text-sm text-gray-600">{post.event_details.date}</div>
                <div class="text-sm text-gray-600">{post.event_details.location}</div>
              </div>
            </:event_content>
            <:comments :if={length(post.comments) > 0}>
              <div class="bg-gray-50 rounded-lg p-3 space-y-2">
                <%= for comment <- post.comments do %>
                  <div class="flex gap-2">
                    <span class="font-semibold text-gray-800 text-sm">{comment.author}:</span>
                    <span class="text-gray-600 text-sm">{comment.text}</span>
                  </div>
                <% end %>
              </div>
            </:comments>
          </.social_post>
          <.empty_state
            :if={@posts_empty?}
            icon_path="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"
            title="No highlights yet"
            description="Stay tuned for updates, photos, and announcements from instructors and the Prime Youth community."
          />
        </div>
      </div>
    </div>
    """
  end
end

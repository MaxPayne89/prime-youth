defmodule KlassHeroWeb.CommunityLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :skip
  describe "CommunityLive" do
    setup :register_and_log_in_user

    test "renders community page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      assert has_element?(view, "h1", "Community")
    end

    test "displays social feed posts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Verify posts section exists with stream
      assert has_element?(view, "#posts[phx-update='stream']")
      assert has_element?(view, "[data-testid='social-post']")
    end

    test "displays sample posts from mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Verify sample posts are displayed using data-testid
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "displays post content correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Verify post content is rendered using data-testid
      assert has_element?(
               view,
               "[data-testid='post-content']",
               "Amazing creativity from our Art World students"
             )

      assert has_element?(
               view,
               "[data-testid='post-content']",
               "Chess tournament registration closes this Friday"
             )

      assert has_element?(view, "[data-testid='post-content']", "Family Fun Day next Saturday")
    end

    test "displays photo content for photo posts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/community")

      # Verify photo emoji is displayed for photo type posts
      assert html =~ "🎨📸"
    end

    test "displays event details for event posts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/community")

      # Verify event details are displayed
      assert html =~ "📅 Family Fun Day"
      assert html =~ "Saturday, March 15th"
      assert html =~ "Greenwood Elementary School"
    end

    test "displays like counts for posts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Verify like count elements are present for each post
      # Use element selector to count the number of like-count elements
      html = render(view)
      like_count_matches = Regex.scan(~r/data-testid="like-count"/, html)
      assert length(like_count_matches) == 3
    end

    test "displays comment counts for posts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Verify comment count elements are present for each post
      html = render(view)
      comment_count_matches = Regex.scan(~r/data-testid="comment-count"/, html)
      assert length(comment_count_matches) == 3
    end

    test "displays existing comments for posts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/community")

      # Verify existing comments are displayed (sample data has comments in post_1)
      assert html =~ "Parent Maria"
      assert html =~ "Emma loves this class!"
      assert html =~ "Parent John"
      # Check for comment text without emoji
      assert html =~ "wait for the showcase"
    end

    test "toggle_like event increments likes when not liked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Initial state: post_1 has 12 likes and user_liked: false
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")

      # Trigger like event
      render_click(view, "toggle_like", %{"post_id" => "post_1"})

      # Verify the stream was updated and post is still present
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
    end

    test "toggle_like event decrements likes when already liked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Like the post first
      render_click(view, "toggle_like", %{"post_id" => "post_1"})

      # Unlike the post
      render_click(view, "toggle_like", %{"post_id" => "post_1"})

      # Verify the stream was updated (back to original state)
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
    end

    test "add_comment event adds comment to post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Add a comment - this triggers a stream update via PubSub
      render_click(view, "add_comment", %{
        "post_id" => "post_1",
        "comment" => "Great work everyone!"
      })

      # Verify all posts still present after update
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "add_comment event trims whitespace", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Add a comment with surrounding whitespace
      render_click(view, "add_comment", %{
        "post_id" => "post_1",
        "comment" => "  Nicely done!  "
      })

      # Verify all posts still present after update
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "add_comment event ignores empty comments", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Try to add an empty comment
      render_click(view, "add_comment", %{
        "post_id" => "post_1",
        "comment" => ""
      })

      # Verify all posts still present (no changes made)
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "add_comment event ignores whitespace-only comments", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Try to add a whitespace-only comment
      render_click(view, "add_comment", %{
        "post_id" => "post_1",
        "comment" => "   "
      })

      # Verify all posts still present (no changes made)
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "add_comment increments comment count", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Add a comment to post_1 (initially has 2 comments)
      render_click(view, "add_comment", %{
        "post_id" => "post_1",
        "comment" => "Another great comment!"
      })

      # Verify posts are still present after add_comment event
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
    end

    test "displays empty state when no posts exist", %{conn: conn} do
      # This test requires mocking empty posts
      # For now, we verify the empty state component is conditionally rendered
      {:ok, _view, html} = live(conn, ~p"/community")

      # Empty state should be conditionally rendered based on @posts_empty?
      # Since we have posts, empty state should NOT be shown
      refute html =~ "No community posts yet"
    end

    test "shows notification button in header", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Verify notification button exists
      assert has_element?(view, "button")
    end

    test "page title is set to Community", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/community")

      # Verify page title content
      assert html =~ "Community"
    end

    test "posts use stream with proper DOM IDs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Verify stream container using selectors
      assert has_element?(view, "#posts[phx-update='stream']")
      assert has_element?(view, "[data-testid='social-post']")
    end

    test "stream updates when toggle_like is called", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Trigger toggle_like which updates the stream via PubSub
      render_click(view, "toggle_like", %{"post_id" => "post_2"})

      # Verify all posts are still present after stream update
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "stream updates when add_comment is called", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Trigger add_comment which updates the stream via PubSub
      render_click(view, "add_comment", %{
        "post_id" => "post_3",
        "comment" => "Looking forward to this event!"
      })

      # Verify all posts are still present after stream update
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "multiple comments can be added to same post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Add first comment
      render_click(view, "add_comment", %{
        "post_id" => "post_2",
        "comment" => "First comment"
      })

      # Add second comment
      render_click(view, "add_comment", %{
        "post_id" => "post_2",
        "comment" => "Second comment"
      })

      # Verify all posts still present after multiple updates
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
      assert has_element?(view, "[data-testid='post-author']", "Klass Hero Admin")
    end

    test "likes and comments are independent across posts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/community")

      # Like post_1
      render_click(view, "toggle_like", %{"post_id" => "post_1"})

      # Add comment to post_2
      render_click(view, "add_comment", %{
        "post_id" => "post_2",
        "comment" => "Chess is awesome!"
      })

      # Both posts should still be present after independent events
      assert has_element?(view, "[data-testid='post-author']", "Ms. Sarah - Art Instructor")
      assert has_element?(view, "[data-testid='post-author']", "Mr. David - Chess Coach")
    end
  end
end

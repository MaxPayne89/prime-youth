defmodule KlassHero.Shared.CategoriesTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Categories

  describe "icon_name/1" do
    test "returns heroicon name for each valid category" do
      assert Categories.icon_name("sports") == "hero-trophy"
      assert Categories.icon_name("arts") == "hero-paint-brush"
      assert Categories.icon_name("music") == "hero-musical-note"
      assert Categories.icon_name("education") == "hero-academic-cap"
      assert Categories.icon_name("life-skills") == "hero-light-bulb"
      assert Categories.icon_name("camps") == "hero-fire"
      assert Categories.icon_name("workshops") == "hero-wrench-screwdriver"
    end

    test "returns fallback for unknown category" do
      assert Categories.icon_name("unknown") == "hero-academic-cap"
    end

    test "returns fallback for nil" do
      assert Categories.icon_name(nil) == "hero-academic-cap"
    end
  end
end

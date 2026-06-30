defmodule GrowthPushRouter.HelpersTest do
  use ExUnit.Case, async: true

  alias GrowthPushRouter.Helpers

  doctest GrowthPushRouter.Helpers

  describe "normalize_string/1" do
    test "trims and downcases strings" do
      assert Helpers.normalize_string(" Both ") == "both"
      assert Helpers.normalize_string(" EdGe ") == "edge"
      assert Helpers.normalize_string("AGENT") == "agent"
    end

    test "normalizes nil to an empty string" do
      assert Helpers.normalize_string(nil) == ""
    end
  end
end

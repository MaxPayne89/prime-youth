defmodule KlassHero.Shared.EmailHtmlTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.EmailHtml

  describe "esc/1" do
    test "passes through plain text unchanged" do
      assert EmailHtml.esc("Hello World") == "Hello World"
    end

    test "escapes < as &lt;" do
      assert EmailHtml.esc("<") == "&lt;"
    end

    test "escapes > as &gt;" do
      assert EmailHtml.esc(">") == "&gt;"
    end

    test "escapes & as &amp;" do
      assert EmailHtml.esc("&") == "&amp;"
    end

    test "escapes \" as &quot;" do
      assert EmailHtml.esc(~s(")) == "&quot;"
    end

    test "escapes ' as &#39;" do
      assert EmailHtml.esc("'") == "&#39;"
    end

    test "escapes all special characters in a mixed string" do
      assert EmailHtml.esc("<script>alert('XSS & \"fun\"')</script>") ==
               "&lt;script&gt;alert(&#39;XSS &amp; &quot;fun&quot;&#39;)&lt;/script&gt;"
    end

    test "handles empty string" do
      assert EmailHtml.esc("") == ""
    end

    test "coerces non-binary terms via to_string before escaping" do
      assert EmailHtml.esc(42) == "42"
      assert EmailHtml.esc(:ok) == "ok"
      assert EmailHtml.esc(nil) == ""
    end

    test "handles multi-byte UTF-8 characters" do
      assert EmailHtml.esc("Schüler & Lehrer") == "Schüler &amp; Lehrer"
    end
  end

  describe "wrap/2" do
    test "includes inner_html verbatim in the output" do
      result = EmailHtml.wrap("<p>Hello</p>")
      assert result =~ "<p>Hello</p>"
    end

    test "includes KlassHero branding" do
      result = EmailHtml.wrap("<p>body</p>")
      assert result =~ "KlassHero"
    end

    test "renders a valid HTML document" do
      result = EmailHtml.wrap("<p>body</p>")
      assert result =~ "<!DOCTYPE html>"
      assert result =~ "<html>"
      assert result =~ "</html>"
    end

    test "includes the default footer message (escaped)" do
      result = EmailHtml.wrap("<p>body</p>")
      assert result =~ "If you didn&#39;t expect this email"
    end

    test "escapes a custom :footer_message option" do
      result = EmailHtml.wrap("<p>body</p>", footer_message: "Visit <example.com>")
      assert result =~ "Visit &lt;example.com&gt;"
    end

    test "uses custom :footer_message when provided" do
      result = EmailHtml.wrap("<p>body</p>", footer_message: "Custom footer text")
      assert result =~ "Custom footer text"
    end
  end
end

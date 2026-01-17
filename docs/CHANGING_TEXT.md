# Changing Text in Klass Hero

A step-by-step guide for updating text content in the app.

## Why We Use Gettext

Klass Hero supports multiple languages (English and German). Instead of hardcoding text like "Book Now" directly in the code, we use a system called **Gettext** that:

1. Keeps all translatable text in dedicated files
2. Makes it easy to add translations for new languages
3. Ensures the same text is consistent across the app

When you see code like `{gettext("Book Now")}`, it means:
- Show "Book Now" in English
- Show "Jetzt buchen" in German (or whatever the German translation is)

## Where Text Lives

All translations are stored in the `priv/gettext/` folder:

```
priv/gettext/
├── default.pot          # Master list of all text (source of truth)
├── en/LC_MESSAGES/
│   └── default.po       # English translations
└── de/LC_MESSAGES/
    └── default.po       # German translations
```

## Changing Existing Text

### Scenario: Changing "Book Now" to "Reserve Your Spot"

**Step 1: Find where the text is used**

Search for the text in the codebase. The text will be wrapped in `gettext()`:

```heex
<.button>{gettext("Book Now")}</.button>
```

**Step 2: Update the source code**

Change the text inside `gettext()`:

```heex
<.button>{gettext("Reserve Your Spot")}</.button>
```

**Step 3: Update the translation files**

Run this command in your terminal:

```bash
mix gettext.extract --merge
```

This command:
- Finds all `gettext()` calls in the code
- Updates the translation files with the new text
- Removes old text that's no longer used

**Step 4: Add the German translation**

Open `priv/gettext/de/LC_MESSAGES/default.po` and find the new entry:

```
msgid "Reserve Your Spot"
msgstr ""
```

Add the German translation:

```
msgid "Reserve Your Spot"
msgstr "Platz reservieren"
```

**Step 5: Test it**

Start the dev server and check both languages:

```bash
mix phx.server
```

Visit `http://localhost:4000` and use the language switcher (flags in the navigation) to verify both translations work.

## Adding New Text

If you're adding text to a new part of the app:

**Step 1: Wrap the text with gettext**

```heex
<h1>{gettext("Welcome to Klass Hero")}</h1>
<p>{gettext("Find the perfect activity for your child")}</p>
```

**Step 2: Extract and merge translations**

```bash
mix gettext.extract --merge
```

**Step 3: Add German translations**

Open `priv/gettext/de/LC_MESSAGES/default.po` and find your new entries. Add the German translations.

## Quick Reference

| Task | Command |
|------|---------|
| Extract new text and update translation files | `mix gettext.extract --merge` |
| Start dev server | `mix phx.server` |
| Run pre-commit checks | `mix precommit` |

## Translation File Format

The `.po` files have a simple format:

```
#: lib/klass_hero_web/components/booking_components.ex:42
msgid "Book Now"
msgstr "Jetzt buchen"
```

- `#:` comment shows where this text is used (file and line number)
- `msgid` is the original English text (this matches what's in the code)
- `msgstr` is the translation (empty for English, filled in for German)

## Tips

1. **Always run `mix gettext.extract --merge`** after changing text in the code
2. **Don't edit `default.pot`** directly - it gets regenerated automatically
3. **Test both languages** before committing
4. **Keep translations short** - UI space is limited, especially on mobile
5. **Run `mix precommit`** before pushing to ensure everything works

## Common Patterns in the Code

Text in templates:
```heex
<span>{gettext("Dashboard")}</span>
```

Text with variables:
```heex
<p>{gettext("Hello, %{name}!", name: @user.name)}</p>
```

Plural forms:
```heex
<span>{ngettext("1 session", "%{count} sessions", @count)}</span>
```

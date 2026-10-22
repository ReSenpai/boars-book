# Translating the book

A translation is one more JSON file of the same book: `book/<locale>.json`. The addon offers `ruRU` and `enUS`
today; another language also needs its interface strings in `Locales/`.

1. Copy `book/enUS.json` (or the original, `book/ruRU.json`) to `book/<locale>.json`.
2. In the copy, change:
   - `bookId` — every translation has its own (for example `dur.boars.habitats.de`), so reading places do not mix;
   - `locale`;
   - everything the reader sees: `title`, `authorName`, `summary`, `tags`, `changelog`, `contentNotice`, chapter
     `title`s, the `text` of paragraphs and headings, list `items`, fact rows (`label` / `value`), and the `alt` and
     `caption` of pictures.
3. Do **not** change chapter and block `id`s, `assetId`s or `style`: with the same ids, switching the language keeps
   the reader on the same passage, and boar finds keep pointing at the right headings.
4. Use the game's own NPC names for the boars in your language.
5. Add the translation to `addon.json` (`"books"`) and the boars' names to `book/achievements.json` (`"title"`).

The build checks the translation with the addon's own validator. A language without a translation shows the
original, with one note in the chat.

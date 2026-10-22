# Contributing to Boars Book

Thanks for taking a look. Bug reports, fixes to the book's facts, translations and pull requests are welcome.

## Licensing of contributions

Boars Book is licensed under the [GNU GPL v3.0 or later](LICENSE). By sending a pull request you agree that your
contribution is licensed under the same terms, and that you have the right to license it.

Sign your commits off with `git commit -s` (the [Developer Certificate of Origin](https://developercertificate.org/)),
which adds a `Signed-off-by` line to the commit message.

## How the repository is laid out

The repository root is the addon itself (`BoarsBook.toc` at the top), so it can be linked straight into the game:

```
mklink /J "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\BoarsBook" "<path>\boars-book"
```

- `book/` — the sources of the book: `ruRU.json` (the original) and `enUS.json`, `illustrations.json` (pictures),
  `achievements.json` (the NPC ids behind each boar's heading and the region achievements).
- `Books/` — the same, generated as Lua for the client. Do not edit by hand.
- `Core/`, `Domain/`, `Layout/`, `Services/`, `Storage/`, `UI/`, `Compat/`, `Locales/` — the reader engine, shared
  with the author's Lore Book addon and copied into this repository by its build script.
- `Assets/` — parchments, illustrations and the boar medallion as uncompressed 32-bit TGA.
- `art/` — the medallion's source drawing. `docs/` — screenshots and notes. Neither goes into the release zip.

The author rebuilds `Books/` and the engine files with the Lore Book build tool before a release. In a pull request,
change the sources (`book/*.json`, engine Lua files) and describe what you changed; the generated files will be
brought in line.

## The book's text and translations

- Keep the `id` of every chapter and block and every `assetId`: reading places, translations and boar finds rely on
  them.
- Boar names in English are the game's own NPC names (Elder Crag Boar, Mottled Boar, Helboar…).
- A new language is one more `book/<locale>.json` with its own `bookId`; see [docs/TRANSLATING.md](docs/TRANSLATING.md).

## Working style

- Test in the game client (Classic Era 1.15). New textures need a full client restart; code changes need `/reload`.
- Every string the player sees goes through `Locales/` (`enUS.lua` and `ruRU.lua` have the same keys).
- Text files use LF line endings and UTF-8 (`.gitattributes`, `.editorconfig`).

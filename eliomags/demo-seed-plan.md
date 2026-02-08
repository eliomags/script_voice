# Demo Writer Seed Data Plan — Elio Mags

## Goal
Create a seed file for a demo writer user "Elio Mags" with 3 projects and standalone episodes, each with complete block data so ALL rendering paths work: Editor, Reader View, Script View, Legacy View, Browse, Dashboard, Profile, and Project pages.

## Demo User Profile
- **Name:** Elio Mags
- **Email:** elio@scriptvivo.com
- **Type:** writer
- **Verification:** verified
- **Bio:** "Writer exploring the intersections of time, language, and identity through historical drama and literary fiction."

---

## 3 Projects (Series) + Their Episodes

### Project 1: "Across All Time"
- **Type:** series
- **Genre:** Sci-Fi (historical drama/sci-fi hybrid)
- **Format:** 60min episodes
- **Logline:** "When a multicultural American family discovers their bedtime history discussions transport them to the events they debate, they must survive the past while discovering what truly holds them together."
- **Status:** active, public
- **Seasons:** 1 (Season 1, 13 episodes planned)
- **Episode to seed:** S01E02 "Friends of Khufu" (from episode2.md)
  - Full blocks from the screenplay: TEASER through TAG
  - All block types represented: chapter, scene_break, narration, dialogue (with parentheticals), sfx, music, pause
  - Characters: DAVID, CATE, THEO, LEILA, ELENA, KHUFU, HEMIUNU, MERIT, NEFERT, ANKH, OVERSEER
- **Series Bible:** From "Across All Time" bible .md file — full content
- **Project Characters:** 6+ characters with roles, backstories, arc_notes

### Project 2: "Babel"
- **Type:** limited_series
- **Genre:** Drama (literary fiction)
- **Format:** 45min episodes
- **Logline:** "A linguist discovers that the world's dying languages contain fragments of a universal truth — and someone is killing the last speakers to keep it buried."
- **Status:** active, public
- **Seasons:** 1 (Season 1, 7 parts)
- **Episode to seed:** S01E01 "Part One" (original content based on babel PDFs)
  - Block types: chapter, narration, dialogue, sfx, scene_break, pause
  - Characters: DR. SARA OSMAN, PROFESSOR ELIAS KHOURY, YUSUF, THE COLLECTOR
- **Series Bible:** Minimal but present
- **Project Characters:** 4 characters

### Project 3: "The Lion's Daughter"
- **Type:** limited_series
- **Genre:** Drama
- **Format:** 45min episodes
- **Logline:** "A woman receives a letter from her dead father — postmarked from Azerbaijan, the land he fled thirty years ago — and must journey to Baku to uncover the truth he spent his life hiding."
- **Status:** active, public
- **Seasons:** 1 (Season 1, 6 chapters)
- **Episode to seed:** S01E01 "The Letter" (original content inspired by thelionsdaughter PDFs)
  - Temporal structure: NOW/BEFORE/BETWEEN markers
  - Block types: chapter, narration, dialogue, scene_break, sfx, music
  - Characters: NAOMI, PAPA (FARID), MAMA (HELEN), DAVID (brother), MR. MAMMADOV
- **Series Bible:** Minimal but present
- **Project Characters:** 5 characters

---

## 2 Standalone Screenplays (no project)

### Standalone 1: "The Supra" (Short)
- **Genre:** Drama
- **Logline:** "At a traditional Georgian feast, three generations clash over what it means to remember — and what it costs to forget."
- **Page count:** ~6
- **Blocks:** Full short screenplay with chapter, narration, dialogue, sfx, pause
- **Characters:** TAMADA (GRANDPA GIORGI), NINO, DATO, MANANA

### Standalone 2: "Signal Lost" (Short)
- **Genre:** Sci-Fi
- **Logline:** "An astronaut on a solo deep-space mission receives a transmission from Earth — but Earth went silent three years ago."
- **Page count:** ~5
- **Blocks:** Screenplay with narration, dialogue, sfx, music, scene_break
- **Characters:** COMMANDER AYSEL HASANOVA, MISSION CONTROL (ARCHIVAL), THE VOICE

---

## Data Requirements Per Record

### Each Episode/Screenplay MUST have:
1. `title`, `genre`, `logline` (required by changeset)
2. `writer_id`, `writer_name` (FK + denormalized)
3. `blocks` — array of maps with ALL block types used, each with `id: Ecto.UUID.generate()`
4. `script_content` — plain text version matching blocks (for legacy view)
5. `page_count` — calculated from word count
6. `characters` — embedded character list with name, gender, estimated_lines
7. For episodes: `project_id`, `season_id`, `episode_number`, `episode_code`, `screenplay_type`
8. `character_ids` — array of ProjectCharacter IDs (for episodes)
9. `is_published: true`, `is_public: true`

### Each Project MUST have:
1. `title`, `genre`, `logline`, `owner_id`, `owner_name`
2. `is_public: true` (for browse page)
3. At least 1 Season
4. At least 1 Episode (screenplay)
5. Project Characters
6. Series Bible (even minimal)

### Block Types to Cover (ALL must appear at least once across the seed):
- `chapter` — needs: title
- `scene_break` — needs: title
- `narration` — needs: text
- `dialogue` — needs: text, character_name; optional: parenthetical
- `sfx` — needs: description
- `music` — needs: description
- `pause` — optional: description

---

## Implementation Order

### Task 1: Create the seed file with demo user
- Insert User record for Elio Mags

### Task 2: Create Project 1 "Across All Time" with full data
- Project, Season, ProjectCharacters, SeriesBible
- Episode S01E02 with complete blocks from episode2.md (TEASER section only to keep manageable, ~40 blocks)

### Task 3: Create Project 2 "Babel" with full data
- Project, Season, ProjectCharacters, SeriesBible
- Episode S01E01 with original blocks (~30 blocks)

### Task 4: Create Project 3 "The Lion's Daughter" with full data
- Project, Season, ProjectCharacters, SeriesBible
- Episode S01E01 with original blocks (~25 blocks)

### Task 5: Create Standalone 1 "The Supra"
- Screenplay with blocks and embedded characters (~25 blocks)

### Task 6: Create Standalone 2 "Signal Lost"
- Screenplay with blocks and embedded characters (~20 blocks)

### Task 7: Verify — compile, check all rendering paths work
- `mix compile --force` (zero errors)
- Verify seed runs: `mix ecto.reset` or `mix run priv/repo/seeds/eliomags_demo.exs`

---

## File Location
`priv/repo/seeds/eliomags_demo.exs` — separate from main seeds.exs for clean isolation

## Verification Checklist
- [ ] Dashboard shows all 3 projects + 2 standalone stories
- [ ] Browse page shows all 3 projects (public) + standalone stories
- [ ] Each episode opens in Editor with correct segments
- [ ] Each episode renders in Reader View with all block types styled
- [ ] Each episode renders in Script View with timestamps
- [ ] Each episode shows in Legacy view with plain text
- [ ] Project pages show seasons, episodes, characters, bible
- [ ] Profile page shows all stories for Elio Mags
- [ ] Story stats compute correctly (word count, duration, scene count, etc.)

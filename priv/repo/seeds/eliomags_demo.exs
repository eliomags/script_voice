# =============================================================================
# ELIO MAGS DEMO WRITER SEED
# =============================================================================
# Creates a complete demo writer with 3 projects + 2 standalone stories.
# Each has full block data for all rendering paths:
#   Editor, Reader View, Script View, Legacy View, Browse, Dashboard, Profile
#
# Run: mix run priv/repo/seeds/eliomags_demo.exs
# =============================================================================

alias ScriptVoice.Repo
alias ScriptVoice.Accounts.User
alias ScriptVoice.Screenplays.{Screenplay, ScreenplayProject, ScreenplaySeason, ProjectCharacter, SeriesBible}

import Ecto.Query

IO.puts("=== Creating Elio Mags Demo Writer ===")

# Clean up any previous Elio Mags data (idempotent re-run)
case Repo.get_by(User, email: "elio@scriptvivo.com") do
  nil -> :ok
  existing_user ->
    # Delete screenplays
    Repo.delete_all(from s in Screenplay, where: s.writer_id == ^existing_user.id)
    # Delete project data
    project_ids = Repo.all(from p in ScreenplayProject, where: p.owner_id == ^existing_user.id, select: p.id)
    if length(project_ids) > 0 do
      Repo.delete_all(from sb in SeriesBible, where: sb.project_id in ^project_ids)
      Repo.delete_all(from pc in ProjectCharacter, where: pc.project_id in ^project_ids)
      Repo.delete_all(from ss in ScreenplaySeason, where: ss.project_id in ^project_ids)
      Repo.delete_all(from p in ScreenplayProject, where: p.id in ^project_ids)
    end
    Repo.delete(existing_user)
    IO.puts("  Cleaned up previous Elio Mags data")
end

# ---------------------------------------------------------------------------
# TASK 1: Demo User
# ---------------------------------------------------------------------------

elio = Repo.insert!(%User{
  name: "Elio Mags",
  email: "elio@scriptvivo.com",
  user_type: "writer",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Writer exploring the intersections of time, language, and identity through historical drama and literary fiction. Three-time finalist for the Blacklist, published in Granta and The Paris Review."
})

IO.puts("Created writer: #{elio.name} (#{elio.id})")

# ===========================================================================
# TASK 2: PROJECT 1 — ACROSS ALL TIME
# ===========================================================================
IO.puts("\n--- Project 1: Across All Time ---")

aat_project = Repo.insert!(%ScreenplayProject{
  title: "Across All Time",
  project_type: "series",
  genre: "Sci-Fi",
  logline: "When a multicultural American family discovers their bedtime history discussions transport them to the events they debate, they must survive the past while discovering what truly holds them together.",
  description: "A one-hour historical drama/comedy spanning the full sweep of human history. A mixed-heritage American family of four discovers they can travel through time when their passionate dinner-table arguments about history become too real.",
  owner_id: elio.id,
  owner_name: elio.name,
  is_public: true,
  status: "active",
  total_seasons: 1,
  total_episodes: 13,
  episode_format: "60min"
})

IO.puts("  Project: #{aat_project.title}")

# Season 1
aat_season1 = Repo.insert!(%ScreenplaySeason{
  season_number: 1,
  title: "Season One: First Journeys",
  description: "The Nakashidze-Beaumont family discovers their ability to time-travel and meets Elena Vardiani, who becomes their reluctant mentor. Each episode takes them to a different pivotal moment in history.",
  episode_count: 13,
  status: "in_progress",
  project_id: aat_project.id
})

IO.puts("  Season: #{aat_season1.title}")

# Project Characters
aat_david = Repo.insert!(%ProjectCharacter{
  name: "DAVID NAKASHIDZE-BEAUMONT",
  gender: "Male",
  age_range: "40s",
  role_type: "lead",
  description: "History professor specializing in Caucasus studies. Georgian-British heritage. The Planner who must learn to improvise.",
  backstory: "Grew up hearing his Georgian father's elaborate toasts and stories of Queen Tamar. His British mother's pragmatism taught him balance. Became a historian to understand his fragmented heritage.",
  arc_notes: "Season 1: confident expert. Season 4: humble witness who understands books capture facts but miss the heartbeat.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: aat_project.id
})

aat_cate = Repo.insert!(%ProjectCharacter{
  name: "CATHERINE 'CATE' BEAUMONT-NAKASHIDZE",
  gender: "Female",
  age_range: "40s",
  role_type: "lead",
  description: "ER nurse, former MSF volunteer. French-Azerbaijani heritage. The Protector who must learn to trust.",
  backstory: "Her French father taught her meals are sacred rituals. Her Azerbaijani mother, who fled Baku during Black January, taught her that crisis requires action.",
  arc_notes: "From bearing protection burden alone to trusting her family's collective strength.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: aat_project.id
})

aat_theo = Repo.insert!(%ProjectCharacter{
  name: "THEO NAKASHIDZE-BEAUMONT",
  gender: "Male",
  age_range: "Teen",
  role_type: "lead",
  description: "17-year-old son. All four heritages. The Observer who must become a participant. Artistic, keeps detailed journals.",
  backstory: "Has always felt caught between cultures, never quite fitting any. Artistic, keeps detailed journals, takes photographs obsessively.",
  arc_notes: "From resentful observer to engaged historian. His journals evolve from complaint logs to genuine historical documentation.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: aat_project.id
})

aat_leila = Repo.insert!(%ProjectCharacter{
  name: "LEILA NAKASHIDZE-BEAUMONT",
  gender: "Female",
  age_range: "Child",
  role_type: "lead",
  description: "12-year-old daughter. All four heritages. The Heart who asks what others won't. Intensely curious.",
  backstory: "Inherited all her family's argumentativeness with none of their filters. Questions everything: slavery, suffrage, religious violence.",
  arc_notes: "From innocent questioner to wise witness. Maintains moral compass while gaining understanding of complexity.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: aat_project.id
})

aat_elena = Repo.insert!(%ProjectCharacter{
  name: "ELENA VARDIANI",
  gender: "Female",
  age_range: "70+",
  role_type: "recurring",
  description: "85 years old, Georgian. Mysterious mentor who has traveled through time 17 times over 65 years. Reluctant guide.",
  backstory: "First traveled in 1959 Tbilisi when she argued about Queen Tamar. Last traveled in 1991, the night before Georgia declared independence.",
  arc_notes: "Reveals the rules of time travel gradually. Carries wisdom and loss from decades of temporal displacement.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: aat_project.id
})

aat_khufu = Repo.insert!(%ProjectCharacter{
  name: "KHUFU",
  gender: "Male",
  age_range: "40s",
  role_type: "guest",
  description: "Pharaoh Khufu (Cheops). Builder of the Great Pyramid. Appears in Episode 102.",
  backstory: "Historical figure. Fourth Dynasty pharaoh who commissioned the Great Pyramid of Giza circa 2560 BCE.",
  arc_notes: "Serves as a mirror for David — a leader consumed by legacy.",
  first_appearance: "S01E02",
  is_active: true,
  project_id: aat_project.id
})

IO.puts("  Characters: 6 created")

# Series Bible
Repo.insert!(%SeriesBible{
  title: "Across All Time: Series Bible",
  project_id: aat_project.id,
  logline: "When a multicultural American family discovers their bedtime history discussions transport them to the events they debate, they must survive the past while discovering what truly holds them together.",
  content: "A one-hour historical drama/comedy spanning the full sweep of human history. The series balances historical authenticity with family comedy and drama, using each era as a mirror reflecting contemporary concerns.",
  world_building: "Time travel is triggered by passionate family arguments about history. The topic determines the destination. Time dilation varies — days in the past may equal hours in the present. 'Echo souls' recur across eras.",
  tone_style: "Doctor Who meets Modern Family — adventurous, educational, emotionally grounded, with genuine stakes and earned humor.",
  comparable_shows: "Doctor Who, Modern Family, Quantum Leap, Outlander, This Is Us",
  target_audience: "Families (8+), history enthusiasts, multicultural audiences. Network or premium cable.",
  why_now: "In an era of cultural division, a series about a family literally walking in the shoes of historical peoples — understanding rather than judging — offers a unique lens on our shared humanity.",
  format_details: "52 episodes across 4 seasons of 13 episodes each. Episodes are non-chronological in historical sequence but chronological in family development.",
  episode_structure: "TEASER (family argument triggers travel) + 4 ACTS (survive and learn in historical period) + TAG (return home, reflect)",
  themes: ["identity", "family", "history", "multiculturalism", "empathy", "survival"],
  version: 1
})

IO.puts("  Series Bible created")

# --- Episode S01E02: "Friends of Khufu" ---

aat_ep2_blocks = [
  # TEASER
  %{id: Ecto.UUID.generate(), type: "chapter", title: "TEASER", position: 0},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. NAKASHIDZE-BEAUMONT HOUSE - LIVING ROOM - NIGHT", position: 1},
  %{id: Ecto.UUID.generate(), type: "narration", text: "One week after the events of the pilot. The family sits with ELENA VARDIANI (85, the mysterious old woman from the pilot tag). She holds a cup of Georgian wine — the good stuff, from David's private stash. The room is tense. DAVID paces. CATE sits protectively near the children. THEO has his sketchbook out, drawing Elena. LEILA watches with unblinking intensity.", position: 2},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "You want to know how I was there. At the Pnyx. Two thousand years before I was born.", parenthetical: "slight Georgian accent", position: 3},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "That would be a good start.", position: 4},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "The same way you were. I argued. With passion. About events I thought were long dead.", parenthetical: "sipping wine", position: 5},
  %{id: Ecto.UUID.generate(), type: "pause", description: "Beat.", position: 6},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "I was nineteen. Tbilisi, 1959. My grandfather had just been released from the gulag. He told me stories of the old Georgia — Queen Tamar, the Golden Age. I said it didn't matter. The Soviets had erased it all.", position: 7},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She pauses. The memory still hurts.", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "We argued until dawn. My mother, my grandfather, my little brother. All of us, around the kitchen table, fighting about whether the past could ever matter again.", position: 9},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "And then?", position: 10},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "I woke up in Tamar's court. 1200 AD. I was there for three months.", position: 11},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "Three months?!", position: 12},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Time moves differently. You noticed.", position: 13},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "We were in Athens for two days. Here, only hours passed.", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "The ratio changes. I have never understood why.", parenthetical: "nodding", position: 15},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THEO", text: "How many times have you... traveled?", parenthetical: "looking up from his sketch", position: 16},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Seventeen. Over sixty-five years. The last time was 1991. The night before Georgia declared independence. I argued with my daughter about whether freedom was worth the risk.", position: 17},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "Where did you go?", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "The fall of Constantinople. 1453. I watched the greatest Christian city burn.", parenthetical: "quiet", position: 19},
  %{id: Ecto.UUID.generate(), type: "pause", description: "Beat.", position: 20},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "I decided I was done arguing after that.", position: 21},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A heavy silence.", position: 22},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "Why are you telling us this?", position: 23},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Because you have children.", position: 24},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She looks at LEILA, then THEO.", position: 25},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "When I traveled, I was alone. Or with adults who understood the risks. You have dragged your children into history. They need to be prepared.", position: 26},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "It doesn't matter what you knew. It matters what happens next.", parenthetical: "cutting her off", position: 27},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She stands, finishing her wine.", position: 28},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "You will travel again. The ability does not fade — it grows stronger. And history is not a museum, Dr. Nakashidze. It is a battlefield. Your children need to learn to survive.", position: 29},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "How?", position: 30},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "By surviving.", parenthetical: "moving toward the door", position: 31},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She pauses at the doorway.", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "One more thing. The people you meet — the ones who look familiar. They are not coincidence. They are echoes. Souls that recur across time.", position: 33},
  %{id: Ecto.UUID.generate(), type: "pause", description: "Beat.", position: 34},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "You will meet them again and again. Sometimes as friends. Sometimes as enemies. Learn to recognize them quickly.", position: 35},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She leaves. The family sits in stunned silence.", position: 36},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "I liked her.", parenthetical: "finally", position: 37},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THEO", text: "She's terrifying.", position: 38},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "I know. I liked that too.", position: 39},

  # ACT ONE
  %{id: Ecto.UUID.generate(), type: "chapter", title: "ACT ONE", position: 40},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. NAKASHIDZE-BEAUMONT HOUSE - DINING ROOM - NIGHT (THREE DAYS LATER)", position: 41},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The family dinner. But different now — they're all slightly nervous. Every topic feels loaded.", position: 42},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "So. How was everyone's day?", position: 43},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THEO", text: "Safe. Non-historical. I talked about video games and avoided all mention of ancient civilizations.", parenthetical: "deadpan", position: 44},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "Your restraint is admirable.", parenthetical: "dry", position: 45},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "We learned about Egypt today.", position: 46},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Everyone freezes mid-bite.", position: 47},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "What? It's school. I can't just not learn.", parenthetical: "innocent", position: 48},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "What about Egypt?", position: 49},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "The pyramids. Mrs. Patterson said they were built by slaves.", position: 50},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "That's actually not true. That's a persistent myth, but modern archaeology —", parenthetical: "automatically", position: 51},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He catches himself. Stops.", position: 52},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "We should probably talk about something else.", parenthetical: "carefully", position: 53},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "But I want to know! If slaves didn't build them, who did?", position: 54},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THEO", text: "She's going to get us sent to Egypt. I can feel it.", parenthetical: "closing his eyes", position: 55},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "I just want to know the truth! Mrs. Patterson showed us pictures of the pyramids and said thousands of slaves died building them and it was really sad and I said 'how do we know that' and she said 'everyone knows that' and that's not an answer!", position: 56},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She's getting worked up now. Classic Leila.", position: 57},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "You're right. It's not an answer. The truth is, we've found the workers' villages. We have their skeletons, their tools, their records. They were skilled laborers — farmers during the flood season, working in organized teams with names like 'Friends of Khufu' and 'Drunkards of Menkaure.' They were paid in bread and beer.", parenthetical: "despite himself", position: 58},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "The room begins to SHIMMER. A low harmonic HUM builds.", position: 59},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "David...", parenthetical: "warning", position: 60},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "Oh no.", position: 61},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The lights flicker. The table vibrates. LEILA grabs CATE's hand. THEO closes his sketchbook.", position: 62},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THEO", text: "Called it.", position: 63},
  %{id: Ecto.UUID.generate(), type: "music", description: "Ancient Egyptian percussion begins — deep, rhythmic, building.", position: 64},
  %{id: Ecto.UUID.generate(), type: "narration", text: "SMASH CUT TO WHITE.", position: 65},

  # ACT TWO opening
  %{id: Ecto.UUID.generate(), type: "chapter", title: "ACT TWO", position: 66},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "EXT. GIZA PLATEAU - DAWN - 2560 BCE", position: 67},
  %{id: Ecto.UUID.generate(), type: "narration", text: "WIDE SHOT. The Great Pyramid of Giza, roughly TWO-THIRDS complete. Scaffolding and ramps cover the structure. The Sphinx does not yet exist. The plateau is a massive construction site — organized, bustling, alive.", position: 68},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The family materializes on a sandy ridge overlooking the site. They're wearing modern clothes. They look ridiculous.", position: 69},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "Oh. Wow.", parenthetical: "staring", position: 70},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "The Great Pyramid. During construction. This is... this is 2560 BCE. Give or take.", parenthetical: "barely breathing", position: 71},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "David. Focus. We need to blend in before someone sees us.", parenthetical: "practical", position: 72},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THEO", text: "We're wearing jeans and sneakers in ancient Egypt. How exactly do we blend in?", position: 73},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "HORNS sound from the construction site below — a shift change.", position: 74},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Hundreds of workers stream across the plateau. They're organized in teams, carrying tools, singing work chants. These are not slaves — they're skilled, proud laborers.", position: 75},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "Look at them. Teams. Organization. This is a national project, not forced labor. Elena was right — surviving means understanding where we are.", parenthetical: "to Leila", position: 76},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "So Mrs. Patterson was wrong.", parenthetical: "quiet wonder", position: 77},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "Yes. She was.", position: 78},

  # TAG
  %{id: Ecto.UUID.generate(), type: "chapter", title: "TAG", position: 79},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. NAKASHIDZE-BEAUMONT HOUSE - LIVING ROOM - NIGHT", position: 80},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The family materializes back in their living room. It's dark. The dinner dishes are still on the table, undisturbed. The clock reads 11:47 PM. They were gone for six days in Egypt; here, barely four hours have passed.", position: 81},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "Is everyone okay? Let me see your hands. Theo, your shoulder —", parenthetical: "nurse mode", position: 82},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THEO", text: "I'm fine, Mom. Really. It's just sunburn.", position: 83},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "I miss Merit.", parenthetical: "quietly", position: 84},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A silence. They all feel it — the wrench of leaving people behind.", position: 85},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "Elena said the people we meet are echoes. Souls that recur.", parenthetical: "gently", position: 86},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LEILA", text: "You think we'll see her again? In a different time?", position: 87},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DAVID", text: "I think... yes. I think we will.", position: 88},
  %{id: Ecto.UUID.generate(), type: "narration", text: "LEILA nods. Not quite comforted, but holding onto it.", position: 89},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CATE", text: "Bed. Now. All of you.", position: 90},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They disperse. But DAVID lingers. He pulls a book from the shelf. The spine reads: 'BOUDICA: WARRIOR QUEEN OF THE ICENI.'", position: 91},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He opens it. Reads a passage. Closes it carefully. Puts it back.", position: 92},
  %{id: Ecto.UUID.generate(), type: "narration", text: "But as he turns away, we see LEILA watching from the hallway again. She's seen which book. Her eyes narrow with curiosity.", position: 93},
  %{id: Ecto.UUID.generate(), type: "narration", text: "SMASH CUT TO BLACK.", position: 94},
  %{id: Ecto.UUID.generate(), type: "narration", text: "END OF EPISODE", position: 95}
]

aat_ep2_script = Enum.map_join(aat_ep2_blocks, "\n\n", fn block ->
  case block.type do
    "chapter" -> "=== #{block.title} ==="
    "scene_break" -> "--- #{block.title} ---"
    "narration" -> block.text
    "dialogue" ->
      paren = if block[:parenthetical], do: " (#{block.parenthetical})", else: ""
      "#{block.character_name}#{paren}:\n#{block.text}"
    "sfx" -> "[SFX: #{block.description}]"
    "music" -> "[MUSIC: #{block.description}]"
    "pause" -> "(#{block[:description] || "pause"})"
    _ -> ""
  end
end)

aat_ep2_word_count = Enum.reduce(aat_ep2_blocks, 0, fn block, acc ->
  text = block[:text] || block[:description] || block[:title] || ""
  acc + length(String.split(text, ~r/\s+/, trim: true))
end)

_aat_ep2 = Repo.insert!(%Screenplay{
  title: "Friends of Khufu",
  genre: "Sci-Fi",
  logline: "When Leila's school lesson about the pyramids ignites a family argument, the Nakashidze-Beaumonts are transported to 2560 BCE Giza — where they discover the truth about who really built the Great Pyramid.",
  writer_id: elio.id,
  writer_name: elio.name,
  project_id: aat_project.id,
  season_id: aat_season1.id,
  episode_number: 2,
  episode_code: "S01E02",
  screenplay_type: "episode",
  is_published: true,
  is_public: true,
  script_content: aat_ep2_script,
  page_count: max(1, div(aat_ep2_word_count, 250)),
  likes: 24,
  audio_version_count: 0,
  character_ids: [aat_david.id, aat_cate.id, aat_theo.id, aat_leila.id, aat_elena.id, aat_khufu.id],
  blocks: aat_ep2_blocks,
  characters: [
    %{id: Ecto.UUID.generate(), name: "ELENA", gender: "Female", estimated_lines: 14, description: "85-year-old Georgian time traveler, mentor"},
    %{id: Ecto.UUID.generate(), name: "DAVID", gender: "Male", estimated_lines: 16, description: "History professor, father"},
    %{id: Ecto.UUID.generate(), name: "CATE", gender: "Female", estimated_lines: 8, description: "ER nurse, mother"},
    %{id: Ecto.UUID.generate(), name: "THEO", gender: "Male", estimated_lines: 7, description: "17-year-old son, artist"},
    %{id: Ecto.UUID.generate(), name: "LEILA", gender: "Female", estimated_lines: 12, description: "12-year-old daughter, catalyst"},
    %{id: Ecto.UUID.generate(), name: "KHUFU", gender: "Male", estimated_lines: 0, description: "Pharaoh, builder of the Great Pyramid"}
  ]
})

IO.puts("  Episode: S01E02 'Friends of Khufu' (#{length(aat_ep2_blocks)} blocks)")

# ===========================================================================
# TASK 3: PROJECT 2 — BABEL
# ===========================================================================
IO.puts("\n--- Project 2: Babel ---")

babel_project = Repo.insert!(%ScreenplayProject{
  title: "Babel",
  project_type: "limited_series",
  genre: "Drama",
  logline: "A linguist discovers that the world's dying languages contain fragments of a universal truth — and someone is killing the last speakers to keep it buried.",
  description: "A six-part literary thriller about language, power, and the stories we lose when voices are silenced. Each episode focuses on a different endangered language and the community fighting to preserve it.",
  owner_id: elio.id,
  owner_name: elio.name,
  is_public: true,
  status: "active",
  total_seasons: 1,
  total_episodes: 7,
  episode_format: "45min"
})

babel_season1 = Repo.insert!(%ScreenplaySeason{
  season_number: 1,
  title: "Season One",
  description: "Dr. Sara Osman traces a pattern across dying languages that points to something ancient and dangerous.",
  episode_count: 7,
  status: "in_progress",
  project_id: babel_project.id
})

babel_sara = Repo.insert!(%ProjectCharacter{
  name: "DR. SARA OSMAN",
  gender: "Female",
  age_range: "30s",
  role_type: "lead",
  description: "Linguist specializing in endangered languages. Egyptian-British. Brilliant, obsessive, haunted by the languages she couldn't save.",
  backstory: "Grew up bilingual in Cairo and London. Her grandmother spoke a dying dialect of Coptic that no recording preserved. This loss drives her work.",
  arc_notes: "From academic detachment to personal mission. Discovers the pattern connects to her own family history.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: babel_project.id
})

babel_elias = Repo.insert!(%ProjectCharacter{
  name: "PROFESSOR ELIAS KHOURY",
  gender: "Male",
  age_range: "60s",
  role_type: "supporting",
  description: "Sara's mentor. Lebanese. Former field linguist turned academic. Knows more than he reveals.",
  backstory: "Spent decades documenting languages across the Middle East. Has seen the pattern Sara is discovering but chose to hide it.",
  arc_notes: "Torn between protecting Sara and protecting the secret. His past catches up with him.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: babel_project.id
})

babel_yusuf = Repo.insert!(%ProjectCharacter{
  name: "YUSUF",
  gender: "Male",
  age_range: "20s",
  role_type: "supporting",
  description: "Sara's research assistant. Moroccan-French. Tech-savvy, loyal, in over his head.",
  backstory: "Graduate student who signed up for a linguistics project and found himself in a conspiracy.",
  arc_notes: "Comic relief who becomes genuinely brave. His technical skills prove crucial.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: babel_project.id
})

babel_collector = Repo.insert!(%ProjectCharacter{
  name: "THE COLLECTOR",
  gender: "Male",
  age_range: "50s",
  role_type: "recurring",
  description: "The antagonist. Nationality unknown. Collects the last recordings of dying languages — then ensures no living speakers remain.",
  backstory: "Believes the universal truth hidden in languages would destabilize civilization if fully assembled.",
  arc_notes: "Revealed gradually. Not purely evil — believes he is protecting humanity from a dangerous truth.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: babel_project.id
})

IO.puts("  Characters: 4 created")

Repo.insert!(%SeriesBible{
  title: "Babel: Series Bible",
  project_id: babel_project.id,
  logline: "A linguist discovers that the world's dying languages contain fragments of a universal truth — and someone is killing the last speakers to keep it buried.",
  content: "A six-part literary thriller exploring the intersection of linguistics, anthropology, and conspiracy. Each episode takes place in a different location, following a different endangered language.",
  tone_style: "Slow-burn intellectual thriller. Think True Detective meets Arrival.",
  comparable_shows: "True Detective, Arrival, The Name of the Rose, Tinker Tailor Soldier Spy",
  target_audience: "Prestige drama audience. HBO / BBC co-production tone.",
  themes: ["language", "power", "silence", "preservation", "truth"],
  version: 1
})

IO.puts("  Series Bible created")

babel_ep1_blocks = [
  %{id: Ecto.UUID.generate(), type: "chapter", title: "PART ONE: THE LAST WORD", position: 0},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "EXT. ANATOLIAN VILLAGE - DAWN", position: 1},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A small village clinging to a mountainside in eastern Turkey. Stone houses, terraced gardens, a minaret that hasn't called to prayer in years. Beautiful and dying.", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "SUPER: 'There are approximately 7,000 languages spoken on Earth. One dies every fourteen days.'", position: 3},
  %{id: Ecto.UUID.generate(), type: "narration", text: "An OLD WOMAN (90s, wrapped in layers against the mountain cold) sits on her porch, speaking into a recording device. Her words are in a language we've never heard — guttural, musical, ancient.", position: 4},
  %{id: Ecto.UUID.generate(), type: "narration", text: "DR. SARA OSMAN (32, sharp eyes behind round glasses, hair escaping a hasty bun) holds the recorder with trembling reverence. She's been searching for this woman for three years.", position: 5},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "Again, please. The phrase about the tower.", parenthetical: "in Turkish", position: 6},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The old woman — GRANDMOTHER AYSE — speaks again. The same phrase. Sara's eyes widen.", position: 7},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "That's... that's the same root construction. The same grammatical pattern I found in the Ainu recordings.", parenthetical: "to herself, in English", position: 8},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "Sara's phone buzzes. She ignores it.", position: 9},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMOTHER AYSE", text: "You understand?", parenthetical: "in broken Turkish", position: 10},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "I'm beginning to. Grandmother, how many people still speak your language?", position: 11},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMOTHER AYSE", text: "People? No people. Only me.", parenthetical: "long pause", position: 12},
  %{id: Ecto.UUID.generate(), type: "pause", description: "The weight of this settles.", position: 13},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "Then what you're telling me is the last time these words will ever be spoken.", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMOTHER AYSE", text: "Not last time. First time someone listens.", parenthetical: "smiling", position: 15},

  # London scene
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. SOAS UNIVERSITY OF LONDON - LINGUISTICS LAB - NIGHT", position: 16},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Two weeks later. Sara's lab is a controlled disaster — whiteboards covered in phonetic transcriptions, stacks of field recordings, empty coffee cups forming a small civilization of their own.", position: 17},
  %{id: Ecto.UUID.generate(), type: "narration", text: "YUSUF (25, Moroccan-French, perpetually caffeinated) enters carrying more coffee.", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "YUSUF", text: "You've been here for thirty-six hours. I know because I've been counting.", position: 19},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "Look at this.", parenthetical: "not looking up", position: 20},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She pulls up spectrograms on her screen — sound waves from different recordings, different languages, different continents.", position: 21},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "Ainu. Northern Japan, last fluent speaker died 2019. Ayapaneco. Mexico, two surviving speakers who refuse to talk to each other. And now Grandmother Ayse's language — it doesn't even have a name. Three languages on three continents that have never had contact.", position: 22},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "YUSUF", text: "And?", position: 23},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "They share a grammatical structure that doesn't exist in any major language family. A way of describing... I don't even know what to call it. A concept we don't have a word for.", position: 24},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "YUSUF", text: "A coincidence?", position: 25},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "Three times is not coincidence. Three times is a pattern.", position: 26},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "Her phone rings. She picks it up.", position: 27},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "PROFESSOR ELIAS KHOURY", text: "Sara. Have you seen the news from Turkey?", parenthetical: "V.O., phone", position: 28},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "What news?", position: 29},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "PROFESSOR ELIAS KHOURY", text: "The village. Your village. There was a fire. The old woman... Sara, I'm sorry.", parenthetical: "V.O.", position: 30},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Sara goes very still.", position: 31},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "When?", parenthetical: "barely audible", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "PROFESSOR ELIAS KHOURY", text: "Last night. Sara... the recordings you made. They're the only ones.", parenthetical: "V.O.", position: 33},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Sara looks at the spectrogram on her screen. The pattern. The impossible pattern connecting three dying languages.", position: 34},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. SARA OSMAN", text: "Professor... the Ainu speaker. And the Ayapaneco speakers. How did they die?", position: 35},
  %{id: Ecto.UUID.generate(), type: "pause", description: "A long silence on the line.", position: 36},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "PROFESSOR ELIAS KHOURY", text: "Come to my office. We need to talk.", parenthetical: "V.O., carefully", position: 37},
  %{id: Ecto.UUID.generate(), type: "music", description: "Low, dissonant strings. The theme of Babel.", position: 38},
  %{id: Ecto.UUID.generate(), type: "narration", text: "SMASH CUT TO BLACK.", position: 39},
  %{id: Ecto.UUID.generate(), type: "narration", text: "END OF PART ONE", position: 40}
]

babel_ep1_script = Enum.map_join(babel_ep1_blocks, "\n\n", fn block ->
  case block.type do
    "chapter" -> "=== #{block.title} ==="
    "scene_break" -> "--- #{block.title} ---"
    "narration" -> block.text
    "dialogue" ->
      paren = if block[:parenthetical], do: " (#{block.parenthetical})", else: ""
      "#{block.character_name}#{paren}:\n#{block.text}"
    "sfx" -> "[SFX: #{block.description}]"
    "music" -> "[MUSIC: #{block.description}]"
    "pause" -> "(#{block[:description] || "pause"})"
    _ -> ""
  end
end)

babel_ep1_words = Enum.reduce(babel_ep1_blocks, 0, fn b, acc ->
  text = b[:text] || b[:description] || b[:title] || ""
  acc + length(String.split(text, ~r/\s+/, trim: true))
end)

_babel_ep1 = Repo.insert!(%Screenplay{
  title: "The Last Word",
  genre: "Drama",
  logline: "A linguist records the last speaker of a dying language and discovers a pattern connecting isolated tongues across continents — then learns someone is silencing those speakers permanently.",
  writer_id: elio.id,
  writer_name: elio.name,
  project_id: babel_project.id,
  season_id: babel_season1.id,
  episode_number: 1,
  episode_code: "S01E01",
  screenplay_type: "episode",
  is_published: true,
  is_public: true,
  script_content: babel_ep1_script,
  page_count: max(1, div(babel_ep1_words, 250)),
  likes: 18,
  audio_version_count: 0,
  character_ids: [babel_sara.id, babel_elias.id, babel_yusuf.id, babel_collector.id],
  blocks: babel_ep1_blocks,
  characters: [
    %{id: Ecto.UUID.generate(), name: "DR. SARA OSMAN", gender: "Female", estimated_lines: 12, description: "Linguist, protagonist"},
    %{id: Ecto.UUID.generate(), name: "YUSUF", gender: "Male", estimated_lines: 4, description: "Research assistant"},
    %{id: Ecto.UUID.generate(), name: "PROFESSOR ELIAS KHOURY", gender: "Male", estimated_lines: 5, description: "Sara's mentor"},
    %{id: Ecto.UUID.generate(), name: "GRANDMOTHER AYSE", gender: "Female", estimated_lines: 4, description: "Last speaker"}
  ]
})

IO.puts("  Episode: S01E01 'The Last Word' (#{length(babel_ep1_blocks)} blocks)")

# ===========================================================================
# TASK 4: PROJECT 3 — THE LION'S DAUGHTER
# ===========================================================================
IO.puts("\n--- Project 3: The Lion's Daughter ---")

tld_project = Repo.insert!(%ScreenplayProject{
  title: "The Lion's Daughter",
  project_type: "limited_series",
  genre: "Drama",
  logline: "A woman receives a letter from her dead father — postmarked from Azerbaijan, the land he fled thirty years ago — and must journey to Baku to uncover the truth he spent his life hiding.",
  description: "A six-part drama told in three temporal layers: NOW (present journey), BEFORE (father's past in Soviet Azerbaijan), and BETWEEN (the years of silence that separated them). Each episode weaves all three timelines.",
  owner_id: elio.id,
  owner_name: elio.name,
  is_public: true,
  status: "active",
  total_seasons: 1,
  total_episodes: 6,
  episode_format: "45min"
})

tld_season1 = Repo.insert!(%ScreenplaySeason{
  season_number: 1,
  title: "Season One",
  description: "Naomi traces her father's secrets from London to Baku, uncovering a story of love, betrayal, and the price of silence.",
  episode_count: 6,
  status: "in_progress",
  project_id: tld_project.id
})

tld_naomi = Repo.insert!(%ProjectCharacter{
  name: "NAOMI",
  gender: "Female",
  age_range: "30s",
  role_type: "lead",
  description: "30s, British-Azerbaijani. A translator who has spent her life avoiding her heritage. Sharp, guarded, quietly angry.",
  backstory: "Grew up speaking English and pretending her father's accent didn't exist. Now forced to confront everything she avoided.",
  arc_notes: "From avoidance to acceptance. Each timeline reveals a different facet of her relationship with her father.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: tld_project.id
})

tld_farid = Repo.insert!(%ProjectCharacter{
  name: "FARID",
  gender: "Male",
  age_range: "40s",
  role_type: "lead",
  description: "Naomi's father. Azerbaijani. Seen only in BEFORE and BETWEEN timelines. A man shaped by impossible choices.",
  backstory: "Fled Baku during Black January 1990. Left behind more than his country. Carried secrets that grew heavier each year.",
  arc_notes: "Revealed gradually through flashbacks. Not the simple abandoner Naomi believes him to be.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: tld_project.id
})

tld_helen = Repo.insert!(%ProjectCharacter{
  name: "HELEN",
  gender: "Female",
  age_range: "50s",
  role_type: "supporting",
  description: "Naomi's English mother. Practical, loving, exhausted by secrets she agreed to keep.",
  backstory: "Met Farid at university in London. Married him knowing he carried ghosts. Raised Naomi alone after he left.",
  arc_notes: "Her silence was born of love, not complicity. Reveals her side of the story in BETWEEN timeline.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: tld_project.id
})

tld_mammadov = Repo.insert!(%ProjectCharacter{
  name: "MR. MAMMADOV",
  gender: "Male",
  age_range: "70+",
  role_type: "supporting",
  description: "An old man in Baku who knew Farid. Keeper of photographs and uncomfortable truths.",
  backstory: "Was Farid's neighbor in the old quarter. Witnessed Black January. Has been waiting for someone to come asking questions.",
  arc_notes: "Guide figure in the NOW timeline. Reveals the past piece by piece, testing whether Naomi is ready for each truth.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: tld_project.id
})

tld_david = Repo.insert!(%ProjectCharacter{
  name: "DAVID",
  gender: "Male",
  age_range: "30s",
  role_type: "supporting",
  description: "Naomi's older brother. Chose to forget. Resents Naomi for choosing to remember.",
  backstory: "Was old enough to remember Farid's departure. Dealt with it by building a completely English identity.",
  arc_notes: "His resistance to the journey mirrors the family's broader pattern of avoidance.",
  first_appearance: "S01E01",
  is_active: true,
  project_id: tld_project.id
})

IO.puts("  Characters: 5 created")

Repo.insert!(%SeriesBible{
  title: "The Lion's Daughter: Series Bible",
  project_id: tld_project.id,
  logline: "A woman receives a letter from her dead father — postmarked from Azerbaijan — and must journey to Baku to uncover the truth he spent his life hiding.",
  content: "A six-part intimate drama exploring identity, heritage, and the lies families tell to protect each other. Three temporal layers: NOW, BEFORE, BETWEEN.",
  tone_style: "Intimate, literary, emotionally precise. Think The Returned meets My Brilliant Friend.",
  comparable_shows: "The Returned, My Brilliant Friend, Normal People, The Light Between Oceans",
  target_audience: "Prestige drama audience. Character-driven literary adaptation feel.",
  themes: ["identity", "heritage", "family secrets", "diaspora", "forgiveness"],
  version: 1
})

IO.puts("  Series Bible created")

tld_ep1_blocks = [
  %{id: Ecto.UUID.generate(), type: "chapter", title: "THE LETTER [NOW]", position: 0},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. NAOMI'S FLAT - LONDON - MORNING", position: 1},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A small, meticulously organized flat in Hackney. Books in three languages line the walls. No family photographs.", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "NAOMI (32, dark hair, her father's eyes — though she'd deny it) sits at her desk translating a document. Her work is precise, mechanical, soothing.", position: 3},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "Post drops through the letterbox.", position: 4},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She picks up the small pile. Bills. A postcard from her brother David (binned without reading). And an envelope.", position: 5},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The envelope is different. Thin blue airmail paper. Foreign stamps. The handwriting is familiar in a way that makes her hands shake.", position: 6},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The postmark reads: BAKU, AZERBAIJAN.", position: 7},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Her father's handwriting. Her father who died fourteen months ago. In London. Not in Azerbaijan.", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "That's not possible.", parenthetical: "whispered", position: 9},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She opens it. Inside: a single sheet. In Azerbaijani — a language she understands but pretends she doesn't. And a photograph. A building she doesn't recognize. An address on the back.", position: 10},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She reads the letter. We don't see the words. We see her face change.", position: 11},
  %{id: Ecto.UUID.generate(), type: "music", description: "A single tar (Azerbaijani lute) begins to play — distant, mournful.", position: 12},

  # BEFORE timeline
  %{id: Ecto.UUID.generate(), type: "chapter", title: "THE LAND OF FIRE [BEFORE]", position: 13},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "EXT. BAKU OLD CITY - 1988", position: 14},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Baku in the last years of the Soviet Union. The old walled city — Icherisheher — still has its medieval character. Narrow streets, the Maiden Tower in the distance, the smell of saffron and petrol.", position: 15},
  %{id: Ecto.UUID.generate(), type: "narration", text: "YOUNG FARID (25, handsome, restless, carrying a violin case) walks quickly through the streets. He's late for something.", position: 16},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "FARID", text: "I know, I know. I'm late.", parenthetical: "in Azerbaijani, to no one", position: 17},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He arrives at a tea house. Inside, MR. MAMMADOV (then 40s, robust, a photographer by trade) waits with two glasses of tea.", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MR. MAMMADOV", text: "The tea was hot when I ordered it. Now it is philosophy.", parenthetical: "in Azerbaijani", position: 19},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "FARID", text: "Philosophy?", position: 20},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MR. MAMMADOV", text: "Cold tea makes you contemplate the nature of time and disappointment.", position: 21},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Farid laughs. Sits. Drinks the cold tea without complaint.", position: 22},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MR. MAMMADOV", text: "So. The conservatory accepted your application to London?", position: 23},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "FARID", text: "Yes.", parenthetical: "careful", position: 24},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MR. MAMMADOV", text: "And your mother?", position: 25},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "FARID", text: "Doesn't know yet.", position: 26},
  %{id: Ecto.UUID.generate(), type: "pause", description: "Mammadov studies him.", position: 27},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MR. MAMMADOV", text: "Farid. The lion's daughter does not ask permission to roar.", position: 28},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "FARID", text: "What does that mean?", position: 29},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MR. MAMMADOV", text: "It means go to London. Play your music. Live your life. But remember where the fire comes from.", position: 30},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "Outside, the distant sound of protest chants beginning.", position: 31},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Both men look toward the window. Something is changing in Baku. They can feel it.", position: 32},

  # NOW timeline resumes
  %{id: Ecto.UUID.generate(), type: "chapter", title: "THE LETTER [NOW] — continued", position: 33},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. HELEN'S HOUSE - SURREY - DAY", position: 34},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A comfortable English suburban home. Floral curtains. A garden visible through the kitchen window. Everything carefully normal.", position: 35},
  %{id: Ecto.UUID.generate(), type: "narration", text: "HELEN (58, still beautiful, tired in a way that's become permanent) opens the door to find Naomi holding the letter.", position: 36},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "HELEN", text: "Naomi. What a lovely —", position: 37},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "How is there a letter from Papa? From Baku? He's been dead for over a year.", parenthetical: "holding up the envelope", position: 38},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Helen's face goes white. She looks at the envelope like it might catch fire.", position: 39},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "HELEN", text: "Come inside.", parenthetical: "very quietly", position: 40},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "Mum. What is this?", position: 41},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "HELEN", text: "It's... something he arranged. Before he died. He asked someone to send it.", parenthetical: "sitting heavily", position: 42},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "Someone in Baku. Where he supposedly never went back to.", position: 43},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "HELEN", text: "Naomi...", position: 44},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "Did he go back? While he was alive? Did Papa go back to Azerbaijan and not tell us?", position: 45},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Helen doesn't answer. Which is an answer.", position: 46},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "How many times?", position: 47},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "HELEN", text: "Every year. For twenty years.", parenthetical: "barely audible", position: 48},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Naomi sits down. The world has shifted.", position: 49},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "I'm going to Baku.", position: 50},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "HELEN", text: "No. Naomi, you don't understand what —", position: 51},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NAOMI", text: "You're right. I don't understand. That's why I'm going.", position: 52},
  %{id: Ecto.UUID.generate(), type: "music", description: "The tar plays again — this time joined by a cello. East meets West.", position: 53},
  %{id: Ecto.UUID.generate(), type: "narration", text: "SMASH CUT TO BLACK.", position: 54},
  %{id: Ecto.UUID.generate(), type: "narration", text: "END OF CHAPTER ONE", position: 55}
]

tld_ep1_script = Enum.map_join(tld_ep1_blocks, "\n\n", fn block ->
  case block.type do
    "chapter" -> "=== #{block.title} ==="
    "scene_break" -> "--- #{block.title} ---"
    "narration" -> block.text
    "dialogue" ->
      paren = if block[:parenthetical], do: " (#{block.parenthetical})", else: ""
      "#{block.character_name}#{paren}:\n#{block.text}"
    "sfx" -> "[SFX: #{block.description}]"
    "music" -> "[MUSIC: #{block.description}]"
    "pause" -> "(#{block[:description] || "pause"})"
    _ -> ""
  end
end)

tld_ep1_words = Enum.reduce(tld_ep1_blocks, 0, fn b, acc ->
  text = b[:text] || b[:description] || b[:title] || ""
  acc + length(String.split(text, ~r/\s+/, trim: true))
end)

_tld_ep1 = Repo.insert!(%Screenplay{
  title: "The Letter",
  genre: "Drama",
  logline: "Naomi receives a letter from her dead father postmarked from Baku — the city he claimed he never returned to — and discovers twenty years of lies.",
  writer_id: elio.id,
  writer_name: elio.name,
  project_id: tld_project.id,
  season_id: tld_season1.id,
  episode_number: 1,
  episode_code: "S01E01",
  screenplay_type: "episode",
  is_published: true,
  is_public: true,
  script_content: tld_ep1_script,
  page_count: max(1, div(tld_ep1_words, 250)),
  likes: 15,
  audio_version_count: 0,
  character_ids: [tld_naomi.id, tld_farid.id, tld_helen.id, tld_mammadov.id, tld_david.id],
  blocks: tld_ep1_blocks,
  characters: [
    %{id: Ecto.UUID.generate(), name: "NAOMI", gender: "Female", estimated_lines: 10, description: "Protagonist, translator"},
    %{id: Ecto.UUID.generate(), name: "FARID", gender: "Male", estimated_lines: 5, description: "Naomi's father, seen in flashbacks"},
    %{id: Ecto.UUID.generate(), name: "HELEN", gender: "Female", estimated_lines: 7, description: "Naomi's mother"},
    %{id: Ecto.UUID.generate(), name: "MR. MAMMADOV", gender: "Male", estimated_lines: 5, description: "Old family friend in Baku"},
    %{id: Ecto.UUID.generate(), name: "GRANDMOTHER AYSE", gender: "Female", estimated_lines: 0, description: "Referenced but not in this episode"}
  ]
})

IO.puts("  Episode: S01E01 'The Letter' (#{length(tld_ep1_blocks)} blocks)")

# ===========================================================================
# TASK 5: STANDALONE 1 — THE SUPRA
# ===========================================================================
IO.puts("\n--- Standalone 1: The Supra ---")

supra_blocks = [
  %{id: Ecto.UUID.generate(), type: "chapter", title: "THE SUPRA", position: 0},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. GRANDPA GIORGI'S HOUSE - DINING ROOM - EVENING", position: 1},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A long table set for a Georgian feast — a supra. Khachapuri, khinkali, pkhali, mtsvadi on skewers, churchkhela hanging from the ceiling like edible stalactites. Wine in clay jugs. Candles. Everything excessive, everything sacred.", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "GRANDPA GIORGI (78, enormous hands, a voice like gravel wrapped in velvet) stands at the head of the table. He is the TAMADA — the toastmaster. This is his kingdom.", position: 3},
  %{id: Ecto.UUID.generate(), type: "narration", text: "NINO (28, his granddaughter, American-raised, visiting for the first time in years) sits uncertainly. She's forgotten the rituals. Or never learned them.", position: 4},
  %{id: Ecto.UUID.generate(), type: "narration", text: "DATO (35, Nino's brother, never left Georgia, resentful about it) sits across from her. MANANA (60, their mother, caught between worlds) tries to keep peace.", position: 5},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "The first toast is always to God. Even if you do not believe. Especially if you do not believe.", parenthetical: "standing, raising his horn", position: 6},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He drinks. Everyone drinks. Nino sips cautiously.", position: 7},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DATO", text: "You drink the whole horn. That is the rule.", parenthetical: "to Nino", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NINO", text: "In America we have rules about driving after —", position: 9},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DATO", text: "You are not in America.", position: 10},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "The second toast. To our ancestors.", position: 11},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He speaks names. Many names. Some Nino recognizes. Most she doesn't.", position: 12},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "Your great-grandmother Tinatin, who hid partisans during the war. Your grandfather Vakhtang, who planted the vine in this garden the day your mother was born. They are at this table. They are always at this table.", position: 13},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NINO", text: "Babua, I don't remember most of these people.", parenthetical: "quietly", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "That is why I say their names. So you will.", position: 15},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DATO", text: "She won't. She lives in New York. She thinks Georgia is a state that voted for Trump.", parenthetical: "bitter", position: 16},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MANANA", text: "Dato. Not tonight.", position: 17},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DATO", text: "When, then? She comes once in five years, stays three days, takes photographs for Instagram, and leaves.", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NINO", text: "That's not fair.", position: 19},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DATO", text: "None of it is fair. I stayed. I buried Uncle Zurab. I drove Babua to the hospital when his heart stopped. Where were you?", position: 20},
  %{id: Ecto.UUID.generate(), type: "pause", description: "Silence. Even the candles seem to hold still.", position: 21},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "The third toast. To the living.", parenthetical: "calmly, standing again", position: 22},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He looks at each of them.", position: 23},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "My grandson Dato, who has the strength of stone and the patience of... less stone. My granddaughter Nino, who carries Georgia in her blood even when she forgets it is there. And my daughter Manana, who keeps this family from killing each other.", position: 24},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MANANA", text: "A full-time job.", parenthetical: "small laugh", position: 25},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "The supra is not about food. It is not about wine. It is about the table. The table is where we remember. Where we fight. Where we forgive.", position: 26},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He sits. Heavily. He is older than he admits.", position: 27},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "I will not be tamada forever. One of you must learn. The toasts. The names. The stories. If you don't, they die when I die.", position: 28},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Nino and Dato look at each other. For the first time tonight, they're not enemies. They're siblings who share a responsibility.", position: 29},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NINO", text: "Teach me, Babua.", parenthetical: "reaching for his hand", position: 30},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DATO", text: "Us. Teach us.", parenthetical: "after a moment", position: 31},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Grandpa Giorgi smiles. Refills the horns.", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "Then we start again. The first toast —", position: 33},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NINO", text: "Is always to God.", parenthetical: "remembering", position: 34},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDPA GIORGI", text: "Even if you do not believe.", parenthetical: "eyes shining", position: 35},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They raise their horns. This time, Nino drinks the whole thing.", position: 36},
  %{id: Ecto.UUID.generate(), type: "narration", text: "FADE TO BLACK.", position: 37}
]

supra_script = Enum.map_join(supra_blocks, "\n\n", fn block ->
  case block.type do
    "chapter" -> "=== #{block.title} ==="
    "scene_break" -> "--- #{block.title} ---"
    "narration" -> block.text
    "dialogue" ->
      paren = if block[:parenthetical], do: " (#{block.parenthetical})", else: ""
      "#{block.character_name}#{paren}:\n#{block.text}"
    "sfx" -> "[SFX: #{block.description}]"
    "music" -> "[MUSIC: #{block.description}]"
    "pause" -> "(#{block[:description] || "pause"})"
    _ -> ""
  end
end)

supra_words = Enum.reduce(supra_blocks, 0, fn b, acc ->
  text = b[:text] || b[:description] || b[:title] || ""
  acc + length(String.split(text, ~r/\s+/, trim: true))
end)

_supra = Repo.insert!(%Screenplay{
  title: "The Supra",
  genre: "Drama",
  logline: "At a traditional Georgian feast, three generations clash over what it means to remember — and what it costs to forget.",
  writer_id: elio.id,
  writer_name: elio.name,
  screenplay_type: "standalone",
  is_published: true,
  is_public: true,
  script_content: supra_script,
  page_count: max(1, div(supra_words, 250)),
  likes: 9,
  audio_version_count: 0,
  blocks: supra_blocks,
  characters: [
    %{id: Ecto.UUID.generate(), name: "GRANDPA GIORGI", gender: "Male", estimated_lines: 12, description: "Tamada (toastmaster), 78, patriarch"},
    %{id: Ecto.UUID.generate(), name: "NINO", gender: "Female", estimated_lines: 7, description: "Granddaughter, 28, American-raised"},
    %{id: Ecto.UUID.generate(), name: "DATO", gender: "Male", estimated_lines: 7, description: "Grandson, 35, stayed in Georgia"},
    %{id: Ecto.UUID.generate(), name: "MANANA", gender: "Female", estimated_lines: 3, description: "Their mother, peacekeeper"}
  ]
})

IO.puts("  Standalone: 'The Supra' (#{length(supra_blocks)} blocks)")

# ===========================================================================
# TASK 6: STANDALONE 2 — SIGNAL LOST
# ===========================================================================
IO.puts("\n--- Standalone 2: Signal Lost ---")

signal_blocks = [
  %{id: Ecto.UUID.generate(), type: "chapter", title: "SIGNAL LOST", position: 0},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "INT. DEEP SPACE VESSEL 'NOVRUZ' - COCKPIT - CONTINUOUS", position: 1},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Darkness. Then emergency lighting flickers on — amber, dim, not enough. The cockpit of a one-person deep space research vessel. Everything is functional, utilitarian, cramped. Three years of solitary occupation have left their mark: a small garden growing under UV lamps, hand-drawn star charts taped to every surface, a worn prayer rug folded in the corner.", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "COMMANDER AYSEL HASANOVA (38, Azerbaijani Space Agency, the quiet intensity of someone who chose infinity over everything else) floats in zero gravity, tethered to her seat. She's been asleep. The alarm woke her.", position: 3},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "PROXIMITY ALERT — a soft, insistent chime. Not urgent. Patient.", position: 4},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "Novruz, status report.", parenthetical: "groggy", position: 5},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The ship's AI responds. Its voice is warm, Azerbaijani-accented — she programmed it to sound like her grandmother.", position: 6},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NOVRUZ", text: "Good morning, Commander. You have slept for eleven hours. Your garden needs watering. And there is a signal.", parenthetical: "ship AI", position: 7},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "A signal?", parenthetical: "suddenly awake", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NOVRUZ", text: "From Earth.", position: 9},
  %{id: Ecto.UUID.generate(), type: "pause", description: "Aysel doesn't move.", position: 10},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "That's not possible. Earth went silent three years ago.", position: 11},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NOVRUZ", text: "Yes. And now it is speaking again.", position: 12},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She pulls herself to the communications array. The signal is there — faint, fragmented, but unmistakably human. Unmistakably from the 37.8 GHz band that only three facilities on Earth could broadcast.", position: 13},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "Static. Then a voice. Broken, repeating.", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE VOICE", text: "... calling ... Novruz ... if anyone ... please respond ... we are ...", parenthetical: "through static", position: 15},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The transmission cuts out. Returns. Cuts out.", position: 16},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "Novruz, can you clean up the signal?", position: 17},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NOVRUZ", text: "Attempting. The signal has traveled 4.2 light-years. It originated 4.2 years ago.", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "Four years ago. A year before the silence.", position: 19},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NOVRUZ", text: "Negative. The signal is dated. It was sent... twelve days ago.", position: 20},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "That's impossible. Nothing travels faster than light.", position: 21},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NOVRUZ", text: "Correct. Which means this signal did not originate from Earth's current position. It originated from somewhere much closer.", position: 22},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Aysel looks out the viewport. The stars stare back — ancient, indifferent, suddenly full of possibilities she hadn't considered.", position: 23},
  %{id: Ecto.UUID.generate(), type: "music", description: "A haunting mugham melody — an Azerbaijani vocal tradition — echoes through the ship. Aysel's personal recording. It feels like a lullaby for the last human alive.", position: 24},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "Play it again. The full message.", parenthetical: "very quietly", position: 25},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "Static builds. Then the voice returns — clearer this time.", position: 26},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE VOICE", text: "Commander Hasanova. This is Mission Control. We are alive. We have been trying to reach you. There is something you need to know about the silence. It was not what you think.", position: 27},
  %{id: Ecto.UUID.generate(), type: "pause", description: "Long beat.", position: 28},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE VOICE", text: "Please come home.", position: 29},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Aysel floats in the amber light. Behind her, the garden grows. The prayer rug waits. Earth — or something wearing its voice — is calling.", position: 30},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "Novruz... set a course.", parenthetical: "after a long moment", position: 31},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "NOVRUZ", text: "Toward the signal?", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER AYSEL HASANOVA", text: "Toward home.", position: 33},
  %{id: Ecto.UUID.generate(), type: "narration", text: "SMASH CUT TO BLACK.", position: 34},
  %{id: Ecto.UUID.generate(), type: "narration", text: "END.", position: 35}
]

signal_script = Enum.map_join(signal_blocks, "\n\n", fn block ->
  case block.type do
    "chapter" -> "=== #{block.title} ==="
    "scene_break" -> "--- #{block.title} ---"
    "narration" -> block.text
    "dialogue" ->
      paren = if block[:parenthetical], do: " (#{block.parenthetical})", else: ""
      "#{block.character_name}#{paren}:\n#{block.text}"
    "sfx" -> "[SFX: #{block.description}]"
    "music" -> "[MUSIC: #{block.description}]"
    "pause" -> "(#{block[:description] || "pause"})"
    _ -> ""
  end
end)

signal_words = Enum.reduce(signal_blocks, 0, fn b, acc ->
  text = b[:text] || b[:description] || b[:title] || ""
  acc + length(String.split(text, ~r/\s+/, trim: true))
end)

_signal_lost = Repo.insert!(%Screenplay{
  title: "Signal Lost",
  genre: "Sci-Fi",
  logline: "An astronaut on a solo deep-space mission receives a transmission from Earth — but Earth went silent three years ago.",
  writer_id: elio.id,
  writer_name: elio.name,
  screenplay_type: "standalone",
  is_published: true,
  is_public: true,
  script_content: signal_script,
  page_count: max(1, div(signal_words, 250)),
  likes: 14,
  audio_version_count: 0,
  blocks: signal_blocks,
  characters: [
    %{id: Ecto.UUID.generate(), name: "COMMANDER AYSEL HASANOVA", gender: "Female", estimated_lines: 12, description: "Solo astronaut, Azerbaijani Space Agency"},
    %{id: Ecto.UUID.generate(), name: "NOVRUZ", gender: "Male", estimated_lines: 8, description: "Ship AI, grandmother's voice"},
    %{id: Ecto.UUID.generate(), name: "THE VOICE", gender: "Unknown", estimated_lines: 3, description: "Mysterious transmission from Earth"},
    %{id: Ecto.UUID.generate(), name: "MISSION CONTROL", gender: "Unknown", estimated_lines: 0, description: "Archival recordings only"}
  ]
})

IO.puts("  Standalone: 'Signal Lost' (#{length(signal_blocks)} blocks)")

# ===========================================================================
# SUMMARY
# ===========================================================================
IO.puts("\n=== SEED COMPLETE ===")
IO.puts("Writer: Elio Mags")
IO.puts("Projects: 3 (Across All Time, Babel, The Lion's Daughter)")
IO.puts("Episodes: 3 (one per project)")
IO.puts("Standalones: 2 (The Supra, Signal Lost)")
IO.puts("Total screenplays: 5")
IO.puts("All with full block data for Editor, Reader, Script, and Legacy views.")

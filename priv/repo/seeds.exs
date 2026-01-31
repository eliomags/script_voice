# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ScriptVoice.Repo.insert!(%ScriptVoice.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ScriptVoice.Repo
alias ScriptVoice.Accounts.User
alias ScriptVoice.Screenplays.Screenplay
alias ScriptVoice.Audio.AudioVersion

# Create sample users
IO.puts("Creating sample users...")

sarah = Repo.insert!(%User{
  name: "Sarah Chen",
  email: "sarah@example.com",
  user_type: "writer",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now()
})

marcus = Repo.insert!(%User{
  name: "Marcus Webb",
  email: "marcus@example.com",
  user_type: "writer",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now()
})

aisha = Repo.insert!(%User{
  name: "Aisha Patel",
  email: "aisha@example.com",
  user_type: "writer",
  verification_status: "verified",
  verified_via: "phone",
  verified_at: DateTime.utc_now()
})

jake = Repo.insert!(%User{
  name: "Jake Morrison",
  email: "jake@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now()
})

emma = Repo.insert!(%User{
  name: "Emma Stone",
  email: "emma@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "phone",
  verified_at: DateTime.utc_now()
})

# Create sample screenplays
IO.puts("Creating sample screenplays...")

last_light = Repo.insert!(%Screenplay{
  title: "The Last Light",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Sci-Fi",
  logline: "A lighthouse keeper discovers her beacon is the only thing preventing an alien invasion.",
  page_count: 12,
  likes: 24,
  audio_version_count: 3,
  characters: [
    %{id: Ecto.UUID.generate(), name: "MAYA", gender: "Female", estimated_lines: 45, description: "Lighthouse keeper, 40s, weathered but determined"},
    %{id: Ecto.UUID.generate(), name: "COMMANDER VOSS", gender: "Male", estimated_lines: 28, description: "Military officer, 50s, skeptical"},
    %{id: Ecto.UUID.generate(), name: "THE VOICE", gender: "Unknown", estimated_lines: 15, description: "Alien entity, ethereal"},
    %{id: Ecto.UUID.generate(), name: "TOMMY", gender: "Male", estimated_lines: 12, description: "Maya's nephew, 10, curious"}
  ]
})

coffee = Repo.insert!(%Screenplay{
  title: "Coffee for Two",
  writer_id: marcus.id,
  writer_name: marcus.name,
  genre: "Romance",
  logline: "Two strangers share a table at a crowded café and discover they're both running from the same past.",
  page_count: 8,
  likes: 18,
  audio_version_count: 1,
  characters: [
    %{id: Ecto.UUID.generate(), name: "ELENA", gender: "Female", estimated_lines: 52, description: "Journalist, 30s, guarded"},
    %{id: Ecto.UUID.generate(), name: "JAMES", gender: "Male", estimated_lines: 48, description: "Former musician, 30s, melancholic"},
    %{id: Ecto.UUID.generate(), name: "BARISTA", gender: "Any", estimated_lines: 6, description: "Friendly café worker"}
  ]
})

hollow_men = Repo.insert!(%Screenplay{
  title: "Hollow Men",
  writer_id: aisha.id,
  writer_name: aisha.name,
  genre: "Thriller",
  logline: "A detective realizes every witness in her case is the same person wearing different faces.",
  page_count: 15,
  likes: 31,
  audio_version_count: 0,
  characters: [
    %{id: Ecto.UUID.generate(), name: "DET. REYES", gender: "Female", estimated_lines: 67, description: "Homicide detective, 40s, sharp"},
    %{id: Ecto.UUID.generate(), name: "THE SHAPESHIFTER", gender: "Any", estimated_lines: 34, description: "Multiple identities"},
    %{id: Ecto.UUID.generate(), name: "CAPTAIN MORRIS", gender: "Male", estimated_lines: 18, description: "Precinct captain, 50s"},
    %{id: Ecto.UUID.generate(), name: "DR. WEBB", gender: "Female", estimated_lines: 14, description: "Forensic psychologist"}
  ]
})

sunday_dinner = Repo.insert!(%Screenplay{
  title: "Sunday Dinner",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Drama",
  logline: "Three generations gather for a meal that will tear the family apart—or finally heal it.",
  page_count: 6,
  likes: 12,
  audio_version_count: 2,
  characters: [
    %{id: Ecto.UUID.generate(), name: "GRANDMA ROSE", gender: "Female", estimated_lines: 28, description: "Family matriarch, 80s"},
    %{id: Ecto.UUID.generate(), name: "MICHAEL", gender: "Male", estimated_lines: 32, description: "Son, 50s, resentful"},
    %{id: Ecto.UUID.generate(), name: "SARAH", gender: "Female", estimated_lines: 26, description: "Daughter, 45, peacemaker"},
    %{id: Ecto.UUID.generate(), name: "LILY", gender: "Female", estimated_lines: 18, description: "Granddaughter, 20s, outsider perspective"}
  ]
})

# Create sample audio versions
IO.puts("Creating sample audio versions...")

Repo.insert!(%AudioVersion{
  screenplay_id: last_light.id,
  submitted_by_id: jake.id,
  performer_type: "group",
  group_name: "The Lighthouse Collective",
  performers: ["Jake Morrison", "Lin Zhou", "Sam Peters", "Mia Chen"],
  casting: %{"MAYA" => "Lin Zhou", "COMMANDER VOSS" => "Jake Morrison", "THE VOICE" => "Sam Peters", "TOMMY" => "Mia Chen"},
  audio_url: "/uploads/audio/last_light_collective.mp3",
  duration: "18:24",
  likes: 12,
  author_pick: true,
  verified: true,
  date: "Jan 15, 2026"
})

Repo.insert!(%AudioVersion{
  screenplay_id: last_light.id,
  submitted_by_id: emma.id,
  performer_type: "solo",
  group_name: nil,
  performers: ["Emma Stone"],
  casting: %{},
  audio_url: "/uploads/audio/last_light_emma.mp3",
  duration: "16:45",
  likes: 19,
  author_pick: false,
  verified: true,
  date: "Jan 8, 2026"
})

Repo.insert!(%AudioVersion{
  screenplay_id: coffee.id,
  submitted_by_id: jake.id,
  performer_type: "duo",
  group_name: nil,
  performers: ["David Kim", "Rachel Torres"],
  casting: %{"ELENA" => "Rachel Torres", "JAMES" => "David Kim", "BARISTA" => "David Kim"},
  audio_url: "/uploads/audio/coffee_duo.mp3",
  duration: "12:30",
  likes: 7,
  author_pick: true,
  verified: true,
  date: "Jan 18, 2026"
})

Repo.insert!(%AudioVersion{
  screenplay_id: sunday_dinner.id,
  submitted_by_id: jake.id,
  performer_type: "solo",
  group_name: nil,
  performers: ["Michael Chang"],
  casting: %{},
  audio_url: "/uploads/audio/sunday_michael.mp3",
  duration: "11:08",
  likes: 3,
  author_pick: true,
  verified: true,
  date: "Jan 19, 2026"
})

IO.puts("Seeds completed!")

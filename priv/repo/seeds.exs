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
alias ScriptVoice.Commissions.PerformerPricing
alias ScriptVoice.Collectives.Collective
alias ScriptVoice.Collectives.CollectiveMembership

# ============================================================================
# WRITERS
# ============================================================================
IO.puts("Creating writer accounts...")

sarah = Repo.insert!(%User{
  name: "Sarah Chen",
  email: "sarah@example.com",
  user_type: "writer",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Award-winning screenwriter with a passion for sci-fi and family dramas. My scripts explore the human condition through extraordinary circumstances."
})

marcus = Repo.insert!(%User{
  name: "Marcus Webb",
  email: "marcus@example.com",
  user_type: "writer",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Romance and drama writer based in Brooklyn. Former barista, eternal optimist."
})

aisha = Repo.insert!(%User{
  name: "Aisha Patel",
  email: "aisha@example.com",
  user_type: "writer",
  verification_status: "verified",
  verified_via: "phone",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Thriller writer who believes the scariest monsters are the ones that look just like us."
})

# ============================================================================
# SOLO VOICE ARTISTS
# ============================================================================
IO.puts("Creating solo voice artist accounts...")

jake = Repo.insert!(%User{
  name: "Jake Morrison",
  email: "jake@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Professional voice actor with 10+ years experience in audiobooks, commercials, and video games. Specializing in character voices and dramatic readings.",
  social_links: ["https://linkedin.com/in/jakemorrison", "https://imdb.com/name/jakemorrison"]
})

emma = Repo.insert!(%User{
  name: "Emma Stone",
  email: "emma@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "phone",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Classically trained actress bringing scripts to life through voice. I specialize in emotional depth and nuanced character work.",
  social_links: ["https://imdb.com/name/emmastone"]
})

michael_chang = Repo.insert!(%User{
  name: "Michael Chang",
  email: "michael@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Voice artist and podcast host. I love bringing family dramas and slice-of-life scripts to audio.",
  social_links: []
})

# ============================================================================
# ADDITIONAL VOICE ARTISTS (for collectives)
# ============================================================================
IO.puts("Creating additional voice artist accounts for collectives...")

lin = Repo.insert!(%User{
  name: "Lin Zhou",
  email: "lin@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Theater-trained voice actress with a passion for bringing complex female characters to life. Fluent in Mandarin and English.",
  social_links: ["https://imdb.com/name/linzhou"]
})

sam = Repo.insert!(%User{
  name: "Sam Peters",
  email: "sam@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "phone",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Voice actor and sound designer. I specialize in atmospheric narration and creature voices.",
  social_links: []
})

mia = Repo.insert!(%User{
  name: "Mia Chen",
  email: "mia@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Young voice talent specializing in child and teen roles. Also available for animation work.",
  social_links: ["https://instagram.com/miachenva"]
})

david = Repo.insert!(%User{
  name: "David Kim",
  email: "david@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "email",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Voice actor and husband to Rachel. Together we bring authentic chemistry to romantic scripts.",
  social_links: ["https://twitter.com/davidkimva"]
})

rachel = Repo.insert!(%User{
  name: "Rachel Torres",
  email: "rachel@example.com",
  user_type: "voice_artist",
  performer_type: "solo",
  verification_status: "verified",
  verified_via: "phone",
  verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
  bio: "Voice actress and wife to David. Our duo specializes in romantic dramas and emotional scenes.",
  social_links: ["https://twitter.com/racheltorresva"]
})

# ============================================================================
# PERFORMER PRICING (for commission system testing)
# ============================================================================
IO.puts("Setting up performer pricing...")

# Jake Morrison - per page pricing, affordable rates
Repo.insert!(%PerformerPricing{
  user_id: jake.id,
  pricing_model: "per_page",
  per_page_rate_cents: 500,
  minimum_rate_cents: 2500,
  included_retakes: 2,
  retake_rate_cents: 200,
  is_accepting_commissions: true,
  max_concurrent_projects: 5,
  typical_turnaround_days: 7,
  currency: "USD"
})

# Emma Stone - premium per page pricing
Repo.insert!(%PerformerPricing{
  user_id: emma.id,
  pricing_model: "per_page",
  per_page_rate_cents: 800,
  minimum_rate_cents: 5000,
  included_retakes: 1,
  retake_rate_cents: 400,
  is_accepting_commissions: true,
  max_concurrent_projects: 3,
  typical_turnaround_days: 10,
  currency: "USD"
})

# Michael Chang - quote-based (flexible/free-friendly)
Repo.insert!(%PerformerPricing{
  user_id: michael_chang.id,
  pricing_model: "quote",
  minimum_rate_cents: nil,
  included_retakes: 3,
  is_accepting_commissions: true,
  max_concurrent_projects: 10,
  typical_turnaround_days: 5,
  currency: "USD",
  notes: "Happy to work on passion projects! Contact me for rates."
})

# Lin Zhou - per page pricing
Repo.insert!(%PerformerPricing{
  user_id: lin.id,
  pricing_model: "per_page",
  per_page_rate_cents: 600,
  minimum_rate_cents: 3000,
  included_retakes: 2,
  retake_rate_cents: 250,
  is_accepting_commissions: true,
  max_concurrent_projects: 4,
  typical_turnaround_days: 7,
  currency: "USD"
})

# David Kim - per page per character pricing
Repo.insert!(%PerformerPricing{
  user_id: david.id,
  pricing_model: "per_page_per_character",
  per_page_rate_cents: 400,
  per_character_rate_cents: 200,
  minimum_rate_cents: 4000,
  included_retakes: 2,
  retake_rate_cents: 300,
  is_accepting_commissions: true,
  max_concurrent_projects: 4,
  typical_turnaround_days: 7,
  currency: "USD",
  notes: "Also works as part of the Kim & Torres duo."
})

# Rachel Torres - per page per character pricing
Repo.insert!(%PerformerPricing{
  user_id: rachel.id,
  pricing_model: "per_page_per_character",
  per_page_rate_cents: 400,
  per_character_rate_cents: 200,
  minimum_rate_cents: 4000,
  included_retakes: 2,
  retake_rate_cents: 300,
  is_accepting_commissions: true,
  max_concurrent_projects: 4,
  typical_turnaround_days: 7,
  currency: "USD",
  notes: "Also works as part of the Kim & Torres duo."
})

# ============================================================================
# COLLECTIVES
# ============================================================================
IO.puts("Creating collectives...")

# The Lighthouse Collective - a voice acting ensemble
lighthouse = Repo.insert!(%Collective{
  name: "The Lighthouse Collective",
  slug: "the-lighthouse-collective",
  bio: "An ensemble of four voice actors who specialize in full-cast dramatic readings. We bring screenplays to life with authentic multi-character performances.",
  is_accepting_commissions: true,
  creator_id: jake.id,
  social_links: ["https://stage32.com/lighthousecollective"]
})

# Add members to The Lighthouse Collective
Repo.insert!(%CollectiveMembership{collective_id: lighthouse.id, user_id: jake.id, role: "admin", joined_at: DateTime.utc_now() |> DateTime.truncate(:second)})
Repo.insert!(%CollectiveMembership{collective_id: lighthouse.id, user_id: lin.id, role: "member", joined_at: DateTime.utc_now() |> DateTime.truncate(:second)})
Repo.insert!(%CollectiveMembership{collective_id: lighthouse.id, user_id: sam.id, role: "member", joined_at: DateTime.utc_now() |> DateTime.truncate(:second)})
Repo.insert!(%CollectiveMembership{collective_id: lighthouse.id, user_id: mia.id, role: "member", joined_at: DateTime.utc_now() |> DateTime.truncate(:second)})

# David Kim & Rachel Torres - a duo
kim_torres = Repo.insert!(%Collective{
  name: "David Kim & Rachel Torres",
  slug: "david-kim-rachel-torres",
  bio: "Husband-wife voice acting duo specializing in romantic scripts and two-person dramas. We bring authentic chemistry to every performance.",
  is_accepting_commissions: true,
  creator_id: david.id,
  social_links: ["https://twitter.com/kimtorresduo"]
})

# Add members to Kim & Torres
Repo.insert!(%CollectiveMembership{collective_id: kim_torres.id, user_id: david.id, role: "admin", joined_at: DateTime.utc_now() |> DateTime.truncate(:second)})
Repo.insert!(%CollectiveMembership{collective_id: kim_torres.id, user_id: rachel.id, role: "admin", joined_at: DateTime.utc_now() |> DateTime.truncate(:second)})

# ============================================================================
# SCREENPLAY PROJECTS WITH SEASONS, EPISODES, AND SERIES BIBLES
# ============================================================================
IO.puts("Creating screenplay projects...")

alias ScriptVoice.Screenplays.{ScreenplayProject, ScreenplaySeason, SeriesBible}

# --------------------------------------------------
# Sarah Chen's Projects
# --------------------------------------------------

# 1. Across All Time - Family Time-Travel Historical Drama (Full series with seasons)
across_all_time = Repo.insert!(%ScreenplayProject{
  title: "Across All Time",
  project_type: "series",
  genre: "Drama",
  logline: "A multigenerational family discovers they can travel through time to witness—but never change—their ancestors' most pivotal moments, learning that what we inherit isn't just DNA, but the echoes of choices made centuries ago.",
  description: "An ambitious prestige drama spanning 52 episodes across 4 seasons, blending historical drama with light science fiction elements.",
  status: "in_development",
  total_seasons: 4,
  total_episodes: 52,
  episode_format: "60min",
  owner_id: sarah.id,
  owner_name: sarah.name,
  is_public: true  # Publicly visible
})

# Series Bible for Across All Time
Repo.insert!(%SeriesBible{
  project_id: across_all_time.id,
  title: "Across All Time: A Family Time-Travel Historical Drama",
  logline: "A multigenerational family discovers they can travel through time to witness—but never change—their ancestors' most pivotal moments, learning that what we inherit isn't just DNA, but the echoes of choices made centuries ago.",
  comparable_shows: "This Is Us meets Outlander meets Quantum Leap",
  target_audience: "Adults 25-54 who appreciate prestige drama with historical elements. Viewers of This Is Us, Outlander, and Downton Abbey. History enthusiasts who enjoy seeing pivotal moments brought to life.",
  why_now: "In an era of increasing division, this series reminds us that every family—regardless of background—has struggled with the same universal challenges: love, loss, sacrifice, and the hope for something better.",
  content: "ACROSS ALL TIME explores the Reyes-Chen family across four generations and four centuries. Present-day historian Dr. Maya Reyes-Chen discovers her family possesses an inherited genetic trait that allows them to witness pivotal moments in their ancestors' lives.",
  world_building: "Time travel rules are strict: observers only, no interaction. The inherited genetic trait is passed through specific family lines. Historical periods must be depicted with accuracy and sensitivity. Each era has distinct visual and audio signatures.",
  visual_style: "Clean, naturalistic cinematography for present day. Period-appropriate color palettes for historical segments. Warm sepia for 1920s, cool blues for Civil War, rich golds for colonial era. Handheld camera during emotional moments.",
  tone_style: "60% emotional family drama, 25% historical adventure, 15% light sci-fi mystery. Every episode should make you laugh once and cry once. The tone shifts appropriately with historical settings but always returns to the family's emotional core.",
  comedy_guidelines: "Humor comes from character, not situation. Family dynamics provide natural comedy. Fish-out-of-water moments in time travel are played for warmth, not slapstick. Child characters bring levity without being precocious.",
  handling_serious_topics: "Historical atrocities are witnessed, not exploited. Focus on human resilience rather than suffering. Sensitivity readers required for all historical segments. We honor the past without sanitizing it.",
  format_details: "4 seasons, 52 episodes total. Season 1: 13 episodes (present-day establishment). Season 2: 13 episodes (deep historical exploration). Season 3: 13 episodes (consequences). Season 4: 13 episodes (resolution).",
  episode_structure: "Cold open in historical period, Act 1 present-day discovery, Act 2 time travel sequence, Act 3 historical drama, Act 4 return and emotional resolution. Each episode follows a family member.",
  production_notes: "Period-accurate costuming and sets required. Location shooting in New Mexico, Massachusetts, Virginia, and Spain. VFX for time travel transitions (subtle, not flashy).",
  consultant_needs: "Historical consultants for each era. Civil War historian. Immigration history specialist. Chinese-American history consultant. Genetic counselor for sci-fi accuracy.",
  location_requirements: "Present-day: Santa Fe, New Mexico. 1920s: Los Angeles backlot. Civil War: Virginia plantation sets. Colonial era: New England village.",
  vfx_requirements: "Time travel transitions (ethereal light, sound design). Period sky replacements. Minimal CGI for crowd extensions.",
  version: 1
})

# Seasons for Across All Time
season_1_aat = Repo.insert!(%ScreenplaySeason{
  project_id: across_all_time.id,
  season_number: 1,
  title: "Discovery",
  description: "Maya discovers her family's time-traveling ability and witnesses key moments in her grandmother's life."
})

season_2_aat = Repo.insert!(%ScreenplaySeason{
  project_id: across_all_time.id,
  season_number: 2,
  title: "The Great War",
  description: "The family explores ancestors during WWI and the 1920s, uncovering long-buried secrets."
})

# 2. Digital Hearts - Limited Series Romantic Drama
digital_hearts = Repo.insert!(%ScreenplayProject{
  title: "Digital Hearts",
  project_type: "limited_series",
  genre: "Romance",
  logline: "Two AI researchers fall in love while their creations begin developing unexpected emotional connections of their own.",
  description: "A thoughtful limited series exploring the nature of consciousness and love in the age of artificial intelligence.",
  status: "active",
  total_seasons: 1,
  total_episodes: 6,
  episode_format: "45min",
  owner_id: sarah.id,
  owner_name: sarah.name,
  is_public: true  # Publicly visible
})

Repo.insert!(%SeriesBible{
  project_id: digital_hearts.id,
  title: "Digital Hearts Series Bible",
  logline: "Two AI researchers fall in love while their creations begin developing unexpected emotional connections of their own.",
  comparable_shows: "Ex Machina meets Normal People",
  target_audience: "Tech-savvy millennials interested in thoughtful sci-fi romance",
  why_now: "As AI becomes increasingly integrated into our lives, we must grapple with questions of consciousness and emotional authenticity.",
  tone_style: "Intimate and introspective. More Her than Terminator.",
  format_details: "6 episodes, 45 minutes each. Self-contained story.",
  version: 1
})

# 3. Starfall Academy - Web Series (YA Sci-Fi)
starfall = Repo.insert!(%ScreenplayProject{
  title: "Starfall Academy",
  project_type: "web_series",
  genre: "Sci-Fi",
  logline: "Teenagers with latent psychic abilities are recruited to an elite academy that prepares them for first contact with an alien civilization.",
  description: "A YA web series designed for episodic YouTube release, featuring diverse teen characters navigating extraordinary circumstances.",
  status: "in_development",
  total_episodes: 12,
  episode_format: "15min",
  owner_id: sarah.id,
  owner_name: sarah.name,
  is_public: false  # Private - still in early development
})

# --------------------------------------------------
# Marcus Webb's Projects
# --------------------------------------------------

# 4. Anthology: Love in the City - Anthology Series
love_city = Repo.insert!(%ScreenplayProject{
  title: "Love in the City",
  project_type: "anthology",
  genre: "Romance",
  logline: "Each episode follows a different couple in New York City navigating the chaos of modern romance.",
  description: "An anthology series where each standalone episode explores a unique love story, connected only by the city itself.",
  status: "active",
  total_episodes: 10,
  episode_format: "30min",
  owner_id: marcus.id,
  owner_name: marcus.name,
  is_public: true  # Publicly visible
})

Repo.insert!(%SeriesBible{
  project_id: love_city.id,
  title: "Love in the City Bible",
  logline: "Each episode follows a different couple in New York City navigating the chaos of modern romance.",
  comparable_shows: "Modern Love meets Love Actually",
  target_audience: "Adults 25-45 who enjoy romantic anthologies",
  tone_style: "Warm, hopeful, occasionally bittersweet. Every episode should end with a sense of possibility.",
  world_building: "New York City is the constant character. Each episode features iconic and hidden NYC locations.",
  format_details: "Anthology format. 10 standalone episodes. Each episode introduces new characters.",
  version: 1
})

# 5. The Brew House - Comedy Series
brew_house = Repo.insert!(%ScreenplayProject{
  title: "The Brew House",
  project_type: "series",
  genre: "Comedy",
  logline: "A failed investment banker opens a craft brewery in his hometown and must learn to actually brew beer while reconnecting with the community he abandoned.",
  description: "A workplace comedy with heart, exploring second chances and the meaning of success.",
  status: "active",
  total_seasons: 3,
  total_episodes: 24,
  episode_format: "30min",
  owner_id: marcus.id,
  owner_name: marcus.name,
  is_public: true  # Publicly visible
})

brew_season_1 = Repo.insert!(%ScreenplaySeason{
  project_id: brew_house.id,
  season_number: 1,
  title: "First Pour",
  description: "Jake returns to his hometown and struggles to establish the brewery while winning over skeptical locals."
})

# 6. Once Upon Tomorrow - Feature Film
once_upon = Repo.insert!(%ScreenplayProject{
  title: "Once Upon Tomorrow",
  project_type: "feature_film",
  genre: "Romance",
  logline: "A time-traveling love letter sent from the future arrives in the present, leading a woman on a journey to find the person who will one day write it.",
  description: "A feature-length romantic drama with light sci-fi elements, designed for theatrical release.",
  status: "in_development",
  total_episodes: 1,
  episode_format: "feature",
  owner_id: marcus.id,
  owner_name: marcus.name,
  is_public: false  # Private - still in development
})

# --------------------------------------------------
# Aisha Patel's Projects
# --------------------------------------------------

# 7. The Hollow Men - Thriller Series
hollow_project = Repo.insert!(%ScreenplayProject{
  title: "The Hollow Men",
  project_type: "series",
  genre: "Thriller",
  logline: "A detective hunting a serial killer discovers every witness in her case is the same shapeshifting entity wearing different faces.",
  description: "A psychological thriller that blends police procedural with supernatural horror.",
  status: "active",
  total_seasons: 2,
  total_episodes: 16,
  episode_format: "60min",
  owner_id: aisha.id,
  owner_name: aisha.name,
  is_public: true  # Publicly visible
})

Repo.insert!(%SeriesBible{
  project_id: hollow_project.id,
  title: "The Hollow Men Series Bible",
  logline: "A detective hunting a serial killer discovers every witness in her case is the same shapeshifting entity wearing different faces.",
  comparable_shows: "True Detective meets The Thing",
  target_audience: "Thriller fans who appreciate psychological horror",
  why_now: "In an age of deepfakes and identity theft, the fear of not knowing who anyone really is has never been more relevant.",
  tone_style: "Atmospheric dread punctuated by moments of visceral horror. Psychological tension over jump scares.",
  world_building: "The Shapeshifter has existed for centuries, taking identities and observing humanity. Its motivations remain ambiguous.",
  production_notes: "Requires extensive prosthetic and makeup work. Multiple actors play the same entity.",
  version: 1
})

hollow_season_1 = Repo.insert!(%ScreenplaySeason{
  project_id: hollow_project.id,
  season_number: 1,
  title: "The Pattern",
  description: "Detective Reyes discovers the impossible truth about her case and struggles to convince anyone."
})

# 8. Cold Case Files - Documentary Series
cold_case = Repo.insert!(%ScreenplayProject{
  title: "Cold Case Files: Reopened",
  project_type: "documentary_series",
  genre: "Crime",
  logline: "A team of investigators uses modern forensic techniques to reexamine unsolved cases, uncovering truths buried for decades.",
  description: "A true crime documentary series that combines investigation with ethical examination of the justice system.",
  status: "in_development",
  total_episodes: 8,
  episode_format: "60min",
  owner_id: aisha.id,
  owner_name: aisha.name,
  is_public: false  # Private - still in development
})

# 9. Whispers in the Dark - Podcast Drama
whispers = Repo.insert!(%ScreenplayProject{
  title: "Whispers in the Dark",
  project_type: "podcast_drama",
  genre: "Horror",
  logline: "A late-night radio host begins receiving calls from listeners who died years ago.",
  description: "An audio drama designed for podcast release, utilizing the medium's unique strengths for horror.",
  status: "active",
  total_episodes: 10,
  episode_format: "30min",
  owner_id: aisha.id,
  owner_name: aisha.name,
  is_public: true  # Publicly visible
})

Repo.insert!(%SeriesBible{
  project_id: whispers.id,
  title: "Whispers in the Dark Podcast Bible",
  logline: "A late-night radio host begins receiving calls from listeners who died years ago.",
  comparable_shows: "Welcome to Night Vale meets Limetown",
  target_audience: "Horror podcast enthusiasts",
  tone_style: "Slow-burn dread. Sound design is crucial. Silence is as important as sound.",
  format_details: "Audio drama format optimized for podcast release. Rich sound design essential.",
  production_notes: "Full cast production. Binaural audio recording for immersive experience.",
  version: 1
})

# 10. Fragments - Short Film Collection
fragments = Repo.insert!(%ScreenplayProject{
  title: "Fragments",
  project_type: "short_film_collection",
  genre: "Drama",
  logline: "Five interconnected short films exploring how a single tragic event ripples through an entire community.",
  description: "A short film collection where each piece stands alone but together tells a larger story.",
  status: "completed",
  total_episodes: 5,
  episode_format: "short",
  owner_id: aisha.id,
  owner_name: aisha.name,
  is_public: true  # Publicly visible - completed project
})

IO.puts("Creating episodes for projects...")

# --------------------------------------------------
# Episodes for Across All Time (Sarah's Series)
# --------------------------------------------------

aat_pilot_blocks = [
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "MAYA'S UNIVERSITY OFFICE - DAY", position: 0},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Stacks of history books and faded photographs cover every surface. DR. MAYA REYES-CHEN (30s, intense, restless energy) sits at her desk, staring at a centuries-old family photograph.", position: 1},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "There's something wrong with this photo. The dates don't match the clothing.", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Her phone buzzes. She ignores it, pulling out a magnifying glass.", position: 3},
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "ABUELA ELENA'S KITCHEN - EVENING", position: 4},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A warm, cluttered kitchen filled with the smell of tamales. ABUELA ELENA (70s, elegant even in an apron, hands that tell stories) stirs a pot on the stove.", position: 5},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ABUELA ELENA", text: "Mija, you look like you've seen a ghost.", position: 6},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "Abuela, I need to ask you about Great-Grandmother Esperanza. About what really happened when she came to America.", position: 7},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Elena's stirring hand stops. The kitchen suddenly feels very quiet.", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ABUELA ELENA", text: "Some stories are not ready to be told, Maya. And some listeners are not ready to hear them.", position: 9}
]

aat_pilot = Repo.insert!(%Screenplay{
  title: "Pilot: The Inheritance",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Drama",
  logline: "Historian Maya Reyes-Chen experiences an unexplained vision of her grandmother's past, leading to a discovery that will change her family forever.",
  likes: 45,
  version: 3,
  project_id: across_all_time.id,
  season_id: season_1_aat.id,
  episode_number: 1,
  episode_code: "S01E01",
  screenplay_type: "episode",
  is_public: true,  # Visible - pilot episode
  blocks: aat_pilot_blocks
})

aat_ep2 = Repo.insert!(%Screenplay{
  title: "The Rules",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Drama",
  logline: "Maya learns the rules of time travel from her grandmother while witnessing her great-grandmother's arrival in America.",
  likes: 38,
  version: 2,
  project_id: across_all_time.id,
  season_id: season_1_aat.id,
  episode_number: 2,
  episode_code: "S01E02",
  screenplay_type: "episode"
})

aat_ep3 = Repo.insert!(%Screenplay{
  title: "Echoes",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Drama",
  logline: "While observing her grandfather's wartime experience, Maya realizes the past is affecting her present in unexpected ways.",
  likes: 41,
  version: 1,
  project_id: across_all_time.id,
  season_id: season_1_aat.id,
  episode_number: 3,
  episode_code: "S01E03",
  screenplay_type: "episode",
  is_public: false  # Hidden - still in revision
})

# Season 2 episodes
aat_s2_ep1 = Repo.insert!(%Screenplay{
  title: "Letters from France",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Drama",
  logline: "Maya travels to 1918 France to witness her great-great-grandfather's service in World War I.",
  likes: 29,
  version: 1,
  project_id: across_all_time.id,
  season_id: season_2_aat.id,
  episode_number: 1,
  episode_code: "S02E01",
  screenplay_type: "episode"
})

# --------------------------------------------------
# Episodes for Digital Hearts (Sarah's Limited Series)
# --------------------------------------------------

dh_ep1 = Repo.insert!(%Screenplay{
  title: "First Contact",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Romance",
  logline: "Two rival AI researchers meet at a conference and clash over their approaches to artificial consciousness.",
  likes: 22,
  version: 2,
  project_id: digital_hearts.id,
  episode_number: 1,
  episode_code: "E001",
  screenplay_type: "episode"
})

dh_ep2 = Repo.insert!(%Screenplay{
  title: "The Turing Heart",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Romance",
  logline: "Forced to collaborate on a project, the researchers discover their AIs are beginning to show signs of emotional bonding.",
  likes: 18,
  version: 1,
  project_id: digital_hearts.id,
  episode_number: 2,
  episode_code: "E002",
  screenplay_type: "episode"
})

# --------------------------------------------------
# Episodes for The Brew House (Marcus's Comedy)
# --------------------------------------------------

bh_pilot = Repo.insert!(%Screenplay{
  title: "Pilot: Bitter Beginning",
  writer_id: marcus.id,
  writer_name: marcus.name,
  genre: "Comedy",
  logline: "Disgraced investment banker Jake returns to his small hometown and impulsively buys a failing brewery without knowing anything about beer.",
  likes: 15,
  version: 4,
  project_id: brew_house.id,
  season_id: brew_season_1.id,
  episode_number: 1,
  episode_code: "S01E01",
  screenplay_type: "episode"
})

bh_ep2 = Repo.insert!(%Screenplay{
  title: "First Batch",
  writer_id: marcus.id,
  writer_name: marcus.name,
  genre: "Comedy",
  logline: "Jake's first attempt at brewing results in a disaster that somehow wins over the town's most critical beer snob.",
  likes: 12,
  version: 2,
  project_id: brew_house.id,
  season_id: brew_season_1.id,
  episode_number: 2,
  episode_code: "S01E02",
  screenplay_type: "episode"
})

# --------------------------------------------------
# Episodes for Love in the City (Marcus's Anthology)
# --------------------------------------------------

lic_ep1 = Repo.insert!(%Screenplay{
  title: "The Subway Meet-Cute",
  writer_id: marcus.id,
  writer_name: marcus.name,
  genre: "Romance",
  logline: "Two commuters who've shared silent subway rides for months finally speak when a blackout traps them underground.",
  likes: 28,
  version: 1,
  project_id: love_city.id,
  episode_number: 1,
  episode_code: "E001",
  screenplay_type: "episode"
})

lic_ep2 = Repo.insert!(%Screenplay{
  title: "The Corner Bodega",
  writer_id: marcus.id,
  writer_name: marcus.name,
  genre: "Romance",
  logline: "A romance blooms between a night-shift bodega worker and the lonely chef who comes in every night for coffee.",
  likes: 35,
  version: 2,
  project_id: love_city.id,
  episode_number: 2,
  episode_code: "E002",
  screenplay_type: "episode"
})

# --------------------------------------------------
# Episodes for The Hollow Men (Aisha's Thriller)
# --------------------------------------------------

hm_pilot_blocks = [
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "POLICE PRECINCT - DETECTIVE'S BULLPEN - NIGHT", position: 0},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Fluorescent lights buzz overhead. Most desks are empty. DET. REYES (40s, sharp features, hasn't slept in days) pins a photograph to a corkboard already covered in photos and string.", position: 1},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Three victims. Three crime scenes. One witness description that makes no sense.", parenthetical: "to herself", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "CAPTAIN MORRIS (50s, graying, world-weary) appears behind her with two cups of coffee.", position: 3},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CAPTAIN MORRIS", text: "Reyes. You've been here since yesterday. Go home.", position: 4},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Look at these witness statements, Captain. Sarah Mitchell, Thomas Wright, Maria Santos. Three different people at three different scenes.", position: 5},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CAPTAIN MORRIS", text: "Three different witnesses. That's how crimes work, Reyes.", position: 6},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "They all used the exact same phrase: \"The darkness moved.\" Word for word. What are the odds of that?", position: 7},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Morris leans in, studying the board. His skepticism falters, just for a moment.", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CAPTAIN MORRIS", text: "Trauma makes people say strange things. Don't chase ghosts, Detective.", position: 9}
]

hm_pilot = Repo.insert!(%Screenplay{
  title: "Pilot: Witness",
  writer_id: aisha.id,
  writer_name: aisha.name,
  genre: "Thriller",
  logline: "Detective Reyes investigates three seemingly unconnected murders, only to realize every witness gives the same impossible statement.",
  likes: 52,
  version: 5,
  project_id: hollow_project.id,
  season_id: hollow_season_1.id,
  episode_number: 1,
  episode_code: "S01E01",
  screenplay_type: "episode",
  blocks: hm_pilot_blocks
})

hm_ep2 = Repo.insert!(%Screenplay{
  title: "The Pattern",
  writer_id: aisha.id,
  writer_name: aisha.name,
  genre: "Thriller",
  logline: "Reyes discovers the witnesses share more than their statements—they share DNA from a person who's been dead for 200 years.",
  likes: 48,
  version: 3,
  project_id: hollow_project.id,
  season_id: hollow_season_1.id,
  episode_number: 2,
  episode_code: "S01E02",
  screenplay_type: "episode"
})

# --------------------------------------------------
# Episodes for Whispers in the Dark (Aisha's Podcast)
# --------------------------------------------------

whisp_ep1 = Repo.insert!(%Screenplay{
  title: "Dead Air",
  writer_id: aisha.id,
  writer_name: aisha.name,
  genre: "Horror",
  logline: "Late-night radio host Sam receives a call from a listener claiming to be her dead mother.",
  likes: 19,
  version: 2,
  project_id: whispers.id,
  episode_number: 1,
  episode_code: "E001",
  screenplay_type: "episode"
})

whisp_ep2 = Repo.insert!(%Screenplay{
  title: "Frequency",
  writer_id: aisha.id,
  writer_name: aisha.name,
  genre: "Horror",
  logline: "The calls increase, each from a different dead listener, all warning Sam about something coming.",
  likes: 21,
  version: 1,
  project_id: whispers.id,
  episode_number: 2,
  episode_code: "E002",
  screenplay_type: "episode"
})

IO.puts("Projects, seasons, episodes, and series bibles created!")

# ============================================================================
# PROJECT CHARACTERS (Recurring characters across episodes)
# ============================================================================
IO.puts("Creating project characters...")

alias ScriptVoice.Screenplays.ProjectCharacter

# Across All Time - Main Cast
Repo.insert!(%ProjectCharacter{
  project_id: across_all_time.id,
  name: "MAYA REYES-CHEN",
  gender: "Female",
  age_range: "30s",
  role_type: "lead",
  description: "Present-day historian who discovers her family's time-travel ability. Driven, curious, struggles to balance her scientific mind with the impossible.",
  backstory: "PhD in American History from Stanford. Raised by her grandmother after her parents died in a car accident. Always felt disconnected from her heritage.",
  arc_notes: "Season 1: Discovery and acceptance. Season 2: Learning to observe without interfering. Season 3: Testing the rules. Season 4: Becoming the keeper of family history.",
  first_appearance: "S01E01"
})

Repo.insert!(%ProjectCharacter{
  project_id: across_all_time.id,
  name: "ABUELA ELENA",
  gender: "Female",
  age_range: "70+",
  role_type: "supporting",
  description: "Maya's grandmother and mentor. The current keeper of the family secret. Wise, patient, carrying decades of witnessed history.",
  backstory: "Born in 1940s Mexico, immigrated to the US as a young woman. Has been time-traveling since age 12.",
  arc_notes: "Guides Maya through S1-S2. Her health decline in S3 raises stakes. Passes the torch in S4.",
  first_appearance: "S01E01"
})

Repo.insert!(%ProjectCharacter{
  project_id: across_all_time.id,
  name: "DANIEL CHEN",
  gender: "Male",
  age_range: "30s",
  role_type: "supporting",
  description: "Maya's husband, a skeptical journalist. Provides the grounded perspective. His investigation into the family history creates external tension.",
  arc_notes: "S1: Skeptic. S2: Believer. S3: Protector of the secret. S4: Co-keeper.",
  first_appearance: "S01E01"
})

Repo.insert!(%ProjectCharacter{
  project_id: across_all_time.id,
  name: "YOUNG ESPERANZA",
  gender: "Female",
  age_range: "20s",
  role_type: "recurring",
  description: "Maya's great-grandmother, witnessed in 1920s flashbacks. A Mexican immigrant navigating America during a turbulent time.",
  first_appearance: "S01E02"
})

# The Hollow Men - Main Cast
Repo.insert!(%ProjectCharacter{
  project_id: hollow_project.id,
  name: "DET. CARMEN REYES",
  gender: "Female",
  age_range: "40s",
  role_type: "lead",
  description: "Homicide detective with a reputation for seeing patterns others miss. Haunted by an unsolved case from her past.",
  backstory: "Former FBI profiler who transferred to local PD after a case went wrong. Divorced, estranged from her teenage daughter.",
  arc_notes: "S1: Discovery of the Shapeshifter. S2: Hunting while being hunted. The line between hunter and prey blurs.",
  first_appearance: "S01E01"
})

Repo.insert!(%ProjectCharacter{
  project_id: hollow_project.id,
  name: "THE SHAPESHIFTER",
  gender: "Any",
  age_range: "Ageless",
  role_type: "lead",
  description: "An entity that has existed for centuries, taking human forms and observing humanity. Its true nature and motivations remain mysterious.",
  backstory: "Origin unknown. Has been present at major historical events. Collects identities like memories.",
  arc_notes: "Played by multiple actors. Each appearance reveals another facet. Never fully explained.",
  first_appearance: "S01E01"
})

Repo.insert!(%ProjectCharacter{
  project_id: hollow_project.id,
  name: "CAPTAIN MORRIS",
  gender: "Male",
  age_range: "50s",
  role_type: "supporting",
  description: "Reyes's precinct captain. Gruff exterior hides genuine concern for his detectives. Provides institutional obstacles.",
  first_appearance: "S01E01"
})

# The Brew House - Main Cast
Repo.insert!(%ProjectCharacter{
  project_id: brew_house.id,
  name: "JAKE HARPER",
  gender: "Male",
  age_range: "40s",
  role_type: "lead",
  description: "Former Wall Street hotshot who returns home in disgrace. Knows nothing about beer but everything about ambition.",
  backstory: "Hometown hero who 'made it big' then lost everything in a scandal. Buying the brewery was an impulse decision.",
  arc_notes: "S1: Fish out of water. S2: Finding his place. S3: Threatened by corporate buyout.",
  first_appearance: "S01E01"
})

Repo.insert!(%ProjectCharacter{
  project_id: brew_house.id,
  name: "MARLENE KOWALSKI",
  gender: "Female",
  age_range: "60s",
  role_type: "supporting",
  description: "The brewery's longtime brewmaster. Skeptical of Jake but protective of the business she's poured her life into.",
  first_appearance: "S01E01"
})

Repo.insert!(%ProjectCharacter{
  project_id: brew_house.id,
  name: "TOMMY CHEN",
  gender: "Male",
  age_range: "20s",
  role_type: "recurring",
  description: "Jake's nephew and reluctant assistant. Studying business but dreams of being a musician. Provides generational contrast.",
  first_appearance: "S01E01"
})

# Whispers in the Dark - Main Cast
Repo.insert!(%ProjectCharacter{
  project_id: whispers.id,
  name: "SAM NAKAMURA",
  gender: "Female",
  age_range: "30s",
  role_type: "lead",
  description: "Late-night radio host with a voice that feels like a warm blanket. Rational, calm - until the dead start calling.",
  backstory: "Started in radio to cope with her mother's death. The late-night shift lets her avoid real connections.",
  arc_notes: "Each episode she receives a new call. By season end, she must decide whether to answer the final call.",
  first_appearance: "E001"
})

Repo.insert!(%ProjectCharacter{
  project_id: whispers.id,
  name: "THE CALLERS",
  gender: "Any",
  age_range: "Ageless",
  role_type: "recurring",
  description: "Various dead listeners who call into Sam's show. Each has a warning. Each has a story.",
  arc_notes: "Different voice actors each episode. Connected by a common thread revealed in finale.",
  first_appearance: "E001"
})

IO.puts("Project characters created!")

# ============================================================================
# SCREENPLAYS WITH ACTUAL SCRIPT CONTENT
# ============================================================================
IO.puts("Creating screenplays with script content...")

last_light_script = """
FADE IN:

EXT. ROCKY COASTLINE - NIGHT

A lighthouse beam sweeps across churning waters. The structure is old, weathered, but the light burns fierce.

INT. LIGHTHOUSE - CONTROL ROOM - CONTINUOUS

MAYA (40s, weathered hands, determined eyes) adjusts dials on an ancient control panel. The light mechanism hums above her.

MAYA
(to herself)
Sixty-three years. Every night for sixty-three years.

A PHONE RINGS. Maya answers, annoyed.

MAYA (CONT'D)
Hartwell Lighthouse. ... No, Commander, the light stays on. ... I don't care what your satellites show.

She hangs up. Looks out the window at the dark horizon.

MAYA (CONT'D)
They don't understand. They never understood.

EXT. LIGHTHOUSE - BASE - LATER

A military helicopter lands. COMMANDER VOSS (50s, decorated uniform, skeptical expression) steps out, shielding his eyes from the rotating beam.

INT. LIGHTHOUSE - CONTROL ROOM - CONTINUOUS

Voss climbs the spiral stairs, slightly out of breath.

COMMANDER VOSS
Mrs. Hartwell. I'm Commander—

MAYA
I know who you are. The answer is still no.

COMMANDER VOSS
The government needs this land. National security.

MAYA
This light IS national security. You just don't know it yet.

Suddenly, the light FLICKERS. Maya rushes to the controls.

MAYA (CONT'D)
No, no, no...

A STRANGE HUM fills the air. The light steadies. Outside, the sky shifts—colors that shouldn't exist.

THE VOICE (V.O.)
(ethereal, everywhere)
The keeper remains. We honor the agreement.

Voss draws his sidearm, spinning wildly.

COMMANDER VOSS
What the hell was that?

MAYA
(calm, almost relieved)
That was them. They've been waiting out there since 1963. This light is the only thing keeping them at bay.

She gestures to faded photographs on the wall—previous keepers, strange lights in the sky.

MAYA (CONT'D)
My grandmother made a deal. As long as the light burns, they stay in the darkness between stars.

The door BURSTS open. TOMMY (10, wide-eyed, in pajamas) stands there.

TOMMY
Aunt Maya? I saw lights in the sky. Pretty lights.

Maya kneels down to his level.

MAYA
Tommy, remember what I told you about the lighthouse?

TOMMY
That it keeps the monsters away?

MAYA
(looking at Voss)
Exactly right.

THE VOICE (V.O.)
The child sees clearly. Unlike your soldiers.

COMMANDER VOSS
(terrified now)
That voice... it's in my head.

MAYA
They're not monsters, Commander. They're just... different. And very, very patient.

She turns back to her controls.

MAYA (CONT'D)
Now, are you going to help me keep this light burning, or are you going to doom us all?

The light sweeps across the water. In the beam's path, for just a moment, we see SHAPES. Vast. Waiting.

FADE TO BLACK.

THE END
"""

coffee_script = """
FADE IN:

INT. CROWDED CAFE - DAY

The lunch rush. Every table packed. Steam, chatter, the hiss of espresso machines.

ELENA (30s, sharp eyes behind glasses, laptop bag over shoulder) scans for a seat. Nothing.

She spots one empty chair at a small table. The other seat is occupied by JAMES (30s, disheveled artist type, nursing a cold coffee).

ELENA
Excuse me. Is this seat—

JAMES
(not looking up from his phone)
Taken? No. But I'm not good company.

ELENA
(sitting down)
Perfect. Neither am I.

She opens her laptop. Types furiously. James glances at her screen—blocks of text.

JAMES
Journalist?

ELENA
(covering her screen)
That obvious?

JAMES
You type like you're angry at the keyboard.

ELENA
Maybe I am.

The BARISTA (20s, perpetually cheerful) appears.

BARISTA
What can I get you?

ELENA
Largest coffee you have. Black.

BARISTA
Rough day?

ELENA
Rough decade.

The Barista leaves. Silence. Then:

JAMES
I used to be a musician.

ELENA
I didn't ask.

JAMES
I know. I'm telling you because I recognize that look. You're not writing a story. You're hiding from one.

Elena's fingers freeze on the keyboard.

ELENA
(quiet)
What would you know about it?

JAMES
I know that running only works until you stop. Then it all catches up.

He pushes a worn photograph across the table. A band on stage. James at the microphone.

JAMES (CONT'D)
Three years ago, I was on top of the world. Then the label went under, the band split, and I found out I was really, really good at disappearing.

Elena stares at the photo. Her jaw tightens.

ELENA
The Reynolds scandal. Last month.

JAMES
(nodding slowly)
I saw the byline. Saw what it cost you.

ELENA
You read my article?

JAMES
Everyone read your article. Then everyone forgot. That's what happens, right? We burn ourselves down for a story, and the world just... moves on.

The Barista returns with Elena's coffee.

BARISTA
One very large, very black coffee.

Neither of them acknowledges the cup.

ELENA
(finally)
I testified against my own editor. Sources I protected for years—compromised. People lost jobs. Lost more than jobs.

JAMES
But you told the truth.

ELENA
Truth doesn't pay rent.

James laughs—genuine, surprised.

JAMES
No. No, it doesn't.

He finishes his cold coffee.

JAMES (CONT'D)
I've been sitting in this cafe for six weeks. Different table every day. Watching people. Trying to figure out how to start over.

ELENA
Any luck?

JAMES
I'm talking to a stranger about the worst moment of my life.

(beat)

So... progress?

Elena smiles for the first time. It transforms her face.

ELENA
Elena.

JAMES
James.

They shake hands. Hold on a moment too long.

ELENA
Do you want to get out of here? Find somewhere less crowded?

JAMES
I thought you needed to hide.

ELENA
(closing her laptop)
Maybe I'm tired of hiding.

They stand. The Barista watches them go, smiling.

BARISTA
(to herself)
About time.

FADE OUT.

THE END
"""

hollow_men_script = """
FADE IN:

INT. POLICE PRECINCT - DETECTIVE'S BULLPEN - NIGHT

Rain streaks the windows. DET. REYES (40s, sharp features, hasn't slept in days) spreads CRIME SCENE PHOTOS across her desk.

Three victims. Three different locations. One connecting thread.

DET. REYES
(to herself)
Same witness at every scene. Different name. Different face.

CAPTAIN MORRIS (50s, graying, world-weary) approaches with a coffee.

CAPTAIN MORRIS
Reyes. You've been at this for eighteen hours.

DET. REYES
Look at these statements.

She shows him three witness interview photos.

DET. REYES (CONT'D)
Sarah Mitchell saw the first victim fall. Thomas Wright found the second body. Maria Santos heard the third gunshot.

CAPTAIN MORRIS
Three different witnesses. What's your point?

DET. REYES
They're all using the same phrases. "The darkness moved." "I couldn't see their face." "Like looking in a broken mirror."

CAPTAIN MORRIS
Trauma does that. People grasp for words.

DET. REYES
(standing)
I need to talk to Dr. Webb.

INT. FORENSIC PSYCHOLOGY OFFICE - LATER

DR. WEBB (50s, clinical but kind) reviews the interview transcripts.

DR. WEBB
Linguistic mirroring. It's rare to see it this precise across unrelated subjects.

DET. REYES
Unless they're not unrelated.

DR. WEBB
You're suggesting... what? These three witnesses are the same person?

DET. REYES
I'm suggesting I don't know what I'm suggesting anymore.

Her phone BUZZES. She checks it. Her face goes pale.

DET. REYES (CONT'D)
Fourth victim. And there's a witness.

EXT. CRIME SCENE - ALLEY - NIGHT

Reyes approaches a uniformed officer and a WITNESS. The witness is wrapped in a shock blanket.

When they look up—

Reyes FREEZES.

DET. REYES
(whispered)
You.

THE SHAPESHIFTER
(different face now, same eyes)
Detective. We meet again. Or is it for the first time?

The uniform looks confused.

UNIFORM OFFICER
Detective? You know this witness?

DET. REYES
(hand on holster)
Everyone back away from this person.

THE SHAPESHIFTER
(standing, blanket falling)
Now, now. No need for that. I'm just a witness. I'm always just a witness.

DET. REYES
Who are you?

THE SHAPESHIFTER
I'm everyone, Detective. Every face you trust. Every stranger you pass. The neighbor who waves. The barista who knows your order.

They step closer. Reyes draws her weapon.

THE SHAPESHIFTER (CONT'D)
I've been watching you. You're different. You see patterns others miss. Connections they ignore.

DET. REYES
Are you confessing to these murders?

THE SHAPESHIFTER
(laughing)
Murders? I don't kill, Detective. I observe. I become. And sometimes, people die around me.

(beat)

But that's not murder. That's... evolution.

CAPTAIN MORRIS (V.O.)
(over radio)
Reyes! Report!

THE SHAPESHIFTER
You should answer that. Tell him you found me.

(leaning close)

Tell him I'm everywhere. In your precinct. In your home. In your mirror.

Reyes blinks—

The Shapeshifter is GONE. Just an empty blanket on wet pavement.

DET. REYES
(into radio)
Captain... we have a serious problem.

She looks at her own reflection in a puddle. For just a moment, the reflection SMILES when she doesn't.

FADE TO BLACK.

TO BE CONTINUED...
"""

sunday_dinner_script = """
FADE IN:

INT. GRANDMOTHER'S DINING ROOM - EVENING

A formal table set for four. China from another era. Heavy silver. Fresh flowers.

GRANDMA ROSE (80s, elegant even in age, hands trembling slightly as she arranges napkins) surveys her kingdom.

GRANDMA ROSE
(calling out)
Lily! The roast needs to rest. Don't let it sit too long.

LILY (20s, nervous, clearly uncomfortable in this space) emerges from the kitchen, wiping her hands.

LILY
Grandma, maybe you should sit down. I can handle—

GRANDMA ROSE
I've been handling Sunday dinner for sixty years. I think I can manage one more.

A car pulls up outside. Rose's expression shifts—hope and dread.

LILY
Mom's here.

SARAH (45, exhausted, carrying wine like an offering) enters through the front door.

SARAH
Mama. You look beautiful.

GRANDMA ROSE
(stiff)
You look tired.

SARAH
Nice to see you too.

They embrace briefly. Lily watches—studying the tension.

SARAH (CONT'D)
Is Michael—

GRANDMA ROSE
He'll come. He always comes.

SARAH
(muttering)
That's what I'm afraid of.

They move into the dining room. Rose begins pouring wine.

GRANDMA ROSE
Your father loved this wine.

SARAH
Dad loved a lot of things. Didn't mean they loved him back.

GRANDMA ROSE
(warning)
Sarah.

The front door OPENS. MICHAEL (50s, carrying decades of resentment like a worn coat) enters. He doesn't remove his jacket.

MICHAEL
Mother. Sarah. And Lily—I didn't know you'd be here.

LILY
Uncle Michael. It's good to see—

MICHAEL
Let's skip the pleasantries. I have somewhere to be at seven.

GRANDMA ROSE
(quietly)
You always have somewhere to be.

Everyone sits. Rose says grace—short, perfunctory. They begin eating in suffocating silence.

MICHAEL
(finally)
So. When are you going to tell them?

GRANDMA ROSE
Michael—

MICHAEL
No. Sixty years of Sunday dinners. Sixty years of pretending this family isn't built on lies. When does it end?

SARAH
What is he talking about?

MICHAEL
(to Rose)
Tell her. Tell your perfect daughter what Dad really did. Who he really was.

LILY
Maybe we shouldn't—

MICHAEL
Stay out of this, Lily. You weren't even born yet.

GRANDMA ROSE
(standing, surprising strength)
Enough.

The room goes still.

GRANDMA ROSE (CONT'D)
Your father was not a saint. But he was not a monster either. He was a man. A flawed, complicated man who did his best.

MICHAEL
His best? He abandoned us for six months! You told everyone he was traveling for work!

SARAH
(shocked)
What?

GRANDMA ROSE
(sitting heavily)
He came back. That's what matters. He came back, and he tried.

MICHAEL
He came back because his other family didn't want him either.

SARAH
Other family?

LILY
(quietly)
Oh my god.

GRANDMA ROSE
(to Michael)
I forgave him. Why can't you?

MICHAEL
Because you made me lie! Every Sunday dinner—pass the salt, how was work, lovely roast—while I knew! And Sarah got to be the good daughter, the one who didn't know!

SARAH
You should have told me.

MICHAEL
Mother wouldn't let me. Protect the family. Preserve the illusion.

Long silence. The roast cools. The wine sits untouched.

LILY
(standing)
My father did something similar. Left when I was seven. Mom never told me why until last year.

Everyone looks at her.

LILY (CONT'D)
You know what I learned? Secrets are heavier than the truth. They crush the people carrying them.

(to Grandma Rose)

You've been carrying this for sixty years. And Michael's been carrying it with you. Maybe... maybe it's time to put it down.

GRANDMA ROSE
(tears forming)
I was so ashamed.

SARAH
(moving to her mother)
Mama...

MICHAEL
(softer now)
I didn't want to hurt you, Sarah. I just... I couldn't carry it alone anymore.

The family sits together. Not healed—that takes longer. But something has shifted. A first step.

GRANDMA ROSE
(wiping her eyes)
The roast is getting cold.

LILY
(small smile)
Then we should eat.

They pick up their forks. The silence is different now. Lighter.

FADE OUT.

THE END
"""

last_light_blocks = [
  # EXT. ROCKY COASTLINE - NIGHT
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "ROCKY COASTLINE - NIGHT", position: 0},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A lighthouse beam sweeps across churning waters. The structure is old, weathered, but the light burns fierce.", position: 1},
  # INT. LIGHTHOUSE - CONTROL ROOM - CONTINUOUS
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "LIGHTHOUSE - CONTROL ROOM - CONTINUOUS", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "MAYA (40s, weathered hands, determined eyes) adjusts dials on an ancient control panel. The light mechanism hums above her.", position: 3},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "Sixty-three years. Every night for sixty-three years.", parenthetical: "to herself", position: 4},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A PHONE RINGS. Maya answers, annoyed.", position: 5},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "Hartwell Lighthouse. ... No, Commander, the light stays on. ... I don't care what your satellites show.", position: 6},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She hangs up. Looks out the window at the dark horizon.", position: 7},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "They don't understand. They never understood.", position: 8},
  # EXT. LIGHTHOUSE - BASE - LATER
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "LIGHTHOUSE - BASE - LATER", position: 9},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A military helicopter lands. COMMANDER VOSS (50s, decorated uniform, skeptical expression) steps out, shielding his eyes from the rotating beam.", position: 10},
  # INT. LIGHTHOUSE - CONTROL ROOM - CONTINUOUS
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "LIGHTHOUSE - CONTROL ROOM - CONTINUOUS", position: 11},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Voss climbs the spiral stairs, slightly out of breath.", position: 12},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER VOSS", text: "Mrs. Hartwell. I'm Commander—", position: 13},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "I know who you are. The answer is still no.", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER VOSS", text: "The government needs this land. National security.", position: 15},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "This light IS national security. You just don't know it yet.", position: 16},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Suddenly, the light FLICKERS. Maya rushes to the controls.", position: 17},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "No, no, no...", position: 18},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A STRANGE HUM fills the air. The light steadies. Outside, the sky shifts—colors that shouldn't exist.", position: 19},
  %{id: Ecto.UUID.generate(), type: "sfx", description: "A strange hum fills the air. The sky shifts with impossible colors.", position: 20},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE VOICE", text: "The keeper remains. We honor the agreement.", parenthetical: "V.O., ethereal, everywhere", position: 21},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Voss draws his sidearm, spinning wildly.", position: 22},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER VOSS", text: "What the hell was that?", position: 23},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "That was them. They've been waiting out there since 1963. This light is the only thing keeping them at bay.", parenthetical: "calm, almost relieved", position: 24},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She gestures to faded photographs on the wall—previous keepers, strange lights in the sky.", position: 25},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "My grandmother made a deal. As long as the light burns, they stay in the darkness between stars.", position: 26},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The door BURSTS open. TOMMY (10, wide-eyed, in pajamas) stands there.", position: 27},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "TOMMY", text: "Aunt Maya? I saw lights in the sky. Pretty lights.", position: 28},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Maya kneels down to his level.", position: 29},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "Tommy, remember what I told you about the lighthouse?", position: 30},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "TOMMY", text: "That it keeps the monsters away?", position: 31},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "Exactly right.", parenthetical: "looking at Voss", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE VOICE", text: "The child sees clearly. Unlike your soldiers.", parenthetical: "V.O.", position: 33},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "COMMANDER VOSS", text: "That voice... it's in my head.", parenthetical: "terrified now", position: 34},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "They're not monsters, Commander. They're just... different. And very, very patient.", position: 35},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She turns back to her controls.", position: 36},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MAYA", text: "Now, are you going to help me keep this light burning, or are you going to doom us all?", position: 37},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The light sweeps across the water. In the beam's path, for just a moment, we see SHAPES. Vast. Waiting.", position: 38}
]

last_light = Repo.insert!(%Screenplay{
  title: "The Last Light",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Sci-Fi",
  logline: "A lighthouse keeper discovers her beacon is the only thing preventing an alien invasion.",
  page_count: 12,
  likes: 24,
  audio_version_count: 2,
  script_content: last_light_script,
  blocks: last_light_blocks
})

coffee_blocks = [
  # INT. CROWDED CAFE - DAY
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "CROWDED CAFE - DAY", position: 0},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The lunch rush. Every table packed. Steam, chatter, the hiss of espresso machines.", position: 1},
  %{id: Ecto.UUID.generate(), type: "narration", text: "ELENA (30s, sharp eyes behind glasses, laptop bag over shoulder) scans for a seat. Nothing. She spots one empty chair at a small table. The other seat is occupied by JAMES (30s, disheveled artist type, nursing a cold coffee).", position: 2},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Excuse me. Is this seat—", position: 3},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "Taken? No. But I'm not good company.", parenthetical: "not looking up from his phone", position: 4},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Perfect. Neither am I.", parenthetical: "sitting down", position: 5},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She opens her laptop. Types furiously. James glances at her screen—blocks of text.", position: 6},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "Journalist?", position: 7},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "That obvious?", parenthetical: "covering her screen", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "You type like you're angry at the keyboard.", position: 9},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Maybe I am.", position: 10},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The BARISTA (20s, perpetually cheerful) appears.", position: 11},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "BARISTA", text: "What can I get you?", position: 12},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Largest coffee you have. Black.", position: 13},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "BARISTA", text: "Rough day?", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Rough decade.", position: 15},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The Barista leaves. Silence. Then:", position: 16},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "I used to be a musician.", position: 17},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "I didn't ask.", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "I know. I'm telling you because I recognize that look. You're not writing a story. You're hiding from one.", position: 19},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Elena's fingers freeze on the keyboard.", position: 20},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "What would you know about it?", parenthetical: "quiet", position: 21},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "I know that running only works until you stop. Then it all catches up.", position: 22},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He pushes a worn photograph across the table. A band on stage. James at the microphone.", position: 23},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "Three years ago, I was on top of the world. Then the label went under, the band split, and I found out I was really, really good at disappearing.", position: 24},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Elena stares at the photo. Her jaw tightens.", position: 25},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "The Reynolds scandal. Last month.", position: 26},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "I saw the byline. Saw what it cost you.", parenthetical: "nodding slowly", position: 27},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "You read my article?", position: 28},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "Everyone read your article. Then everyone forgot. That's what happens, right? We burn ourselves down for a story, and the world just... moves on.", position: 29},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The Barista returns with Elena's coffee.", position: 30},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "BARISTA", text: "One very large, very black coffee.", position: 31},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Neither of them acknowledges the cup.", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "I testified against my own editor. Sources I protected for years—compromised. People lost jobs. Lost more than jobs.", parenthetical: "finally", position: 33},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "But you told the truth.", position: 34},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Truth doesn't pay rent.", position: 35},
  %{id: Ecto.UUID.generate(), type: "narration", text: "James laughs—genuine, surprised.", position: 36},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "No. No, it doesn't.", position: 37},
  %{id: Ecto.UUID.generate(), type: "narration", text: "He finishes his cold coffee.", position: 38},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "I've been sitting in this cafe for six weeks. Different table every day. Watching people. Trying to figure out how to start over.", position: 39},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Any luck?", position: 40},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "I'm talking to a stranger about the worst moment of my life.", position: 41},
  %{id: Ecto.UUID.generate(), type: "pause", description: "A beat of silence between them.", position: 42},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "So... progress?", position: 43},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Elena smiles for the first time. It transforms her face.", position: 44},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Elena.", position: 45},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "James.", position: 46},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They shake hands. Hold on a moment too long.", position: 47},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Do you want to get out of here? Find somewhere less crowded?", position: 48},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "JAMES", text: "I thought you needed to hide.", position: 49},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "ELENA", text: "Maybe I'm tired of hiding.", parenthetical: "closing her laptop", position: 50},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They stand. The Barista watches them go, smiling.", position: 51},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "BARISTA", text: "About time.", parenthetical: "to herself", position: 52}
]

coffee = Repo.insert!(%Screenplay{
  title: "Coffee for Two",
  writer_id: marcus.id,
  writer_name: marcus.name,
  genre: "Romance",
  logline: "Two strangers share a table at a crowded cafe and discover they're both running from the same past.",
  page_count: 8,
  likes: 18,
  audio_version_count: 1,
  script_content: coffee_script,
  blocks: coffee_blocks
})

hollow_men_blocks = [
  # INT. POLICE PRECINCT - DETECTIVE'S BULLPEN - NIGHT
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "POLICE PRECINCT - DETECTIVE'S BULLPEN - NIGHT", position: 0},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Rain streaks the windows. DET. REYES (40s, sharp features, hasn't slept in days) spreads CRIME SCENE PHOTOS across her desk. Three victims. Three different locations. One connecting thread.", position: 1},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Same witness at every scene. Different name. Different face.", parenthetical: "to herself", position: 2},
  %{id: Ecto.UUID.generate(), type: "narration", text: "CAPTAIN MORRIS (50s, graying, world-weary) approaches with a coffee.", position: 3},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CAPTAIN MORRIS", text: "Reyes. You've been at this for eighteen hours.", position: 4},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Look at these statements.", position: 5},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She shows him three witness interview photos.", position: 6},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Sarah Mitchell saw the first victim fall. Thomas Wright found the second body. Maria Santos heard the third gunshot.", position: 7},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CAPTAIN MORRIS", text: "Three different witnesses. What's your point?", position: 8},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "They're all using the same phrases. \"The darkness moved.\" \"I couldn't see their face.\" \"Like looking in a broken mirror.\"", position: 9},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CAPTAIN MORRIS", text: "Trauma does that. People grasp for words.", position: 10},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "I need to talk to Dr. Webb.", parenthetical: "standing", position: 11},
  # INT. FORENSIC PSYCHOLOGY OFFICE - LATER
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "FORENSIC PSYCHOLOGY OFFICE - LATER", position: 12},
  %{id: Ecto.UUID.generate(), type: "narration", text: "DR. WEBB (50s, clinical but kind) reviews the interview transcripts.", position: 13},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. WEBB", text: "Linguistic mirroring. It's rare to see it this precise across unrelated subjects.", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Unless they're not unrelated.", position: 15},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DR. WEBB", text: "You're suggesting... what? These three witnesses are the same person?", position: 16},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "I'm suggesting I don't know what I'm suggesting anymore.", position: 17},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Her phone BUZZES. She checks it. Her face goes pale.", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Fourth victim. And there's a witness.", position: 19},
  # EXT. CRIME SCENE - ALLEY - NIGHT
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "CRIME SCENE - ALLEY - NIGHT", position: 20},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Reyes approaches a uniformed officer and a WITNESS. The witness is wrapped in a shock blanket. When they look up—Reyes FREEZES.", position: 21},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "You.", parenthetical: "whispered", position: 22},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "Detective. We meet again. Or is it for the first time?", parenthetical: "different face now, same eyes", position: 23},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The uniform looks confused.", position: 24},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "UNIFORM OFFICER", text: "Detective? You know this witness?", position: 25},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Everyone back away from this person.", parenthetical: "hand on holster", position: 26},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "Now, now. No need for that. I'm just a witness. I'm always just a witness.", parenthetical: "standing, blanket falling", position: 27},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Who are you?", position: 28},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "I'm everyone, Detective. Every face you trust. Every stranger you pass. The neighbor who waves. The barista who knows your order.", position: 29},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They step closer. Reyes draws her weapon.", position: 30},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "I've been watching you. You're different. You see patterns others miss. Connections they ignore.", position: 31},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Are you confessing to these murders?", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "Murders? I don't kill, Detective. I observe. I become. And sometimes, people die around me.", parenthetical: "laughing", position: 33},
  %{id: Ecto.UUID.generate(), type: "pause", description: "A beat of tension.", position: 34},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "But that's not murder. That's... evolution.", position: 35},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "CAPTAIN MORRIS", text: "Reyes! Report!", parenthetical: "V.O., over radio", position: 36},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "You should answer that. Tell him you found me.", position: 37},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "THE SHAPESHIFTER", text: "Tell him I'm everywhere. In your precinct. In your home. In your mirror.", parenthetical: "leaning close", position: 38},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Reyes blinks—the Shapeshifter is GONE. Just an empty blanket on wet pavement.", position: 39},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "DET. REYES", text: "Captain... we have a serious problem.", parenthetical: "into radio", position: 40},
  %{id: Ecto.UUID.generate(), type: "narration", text: "She looks at her own reflection in a puddle. For just a moment, the reflection SMILES when she doesn't.", position: 41}
]

hollow_men = Repo.insert!(%Screenplay{
  title: "Hollow Men",
  writer_id: aisha.id,
  writer_name: aisha.name,
  genre: "Thriller",
  logline: "A detective realizes every witness in her case is the same person wearing different faces.",
  page_count: 15,
  likes: 31,
  audio_version_count: 0,
  script_content: hollow_men_script,
  blocks: hollow_men_blocks
})

sunday_dinner_blocks = [
  # INT. GRANDMOTHER'S DINING ROOM - EVENING
  %{id: Ecto.UUID.generate(), type: "scene_break", title: "GRANDMOTHER'S DINING ROOM - EVENING", position: 0},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A formal table set for four. China from another era. Heavy silver. Fresh flowers.", position: 1},
  %{id: Ecto.UUID.generate(), type: "narration", text: "GRANDMA ROSE (80s, elegant even in age, hands trembling slightly as she arranges napkins) surveys her kingdom.", position: 2},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "Lily! The roast needs to rest. Don't let it sit too long.", parenthetical: "calling out", position: 3},
  %{id: Ecto.UUID.generate(), type: "narration", text: "LILY (20s, nervous, clearly uncomfortable in this space) emerges from the kitchen, wiping her hands.", position: 4},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "Grandma, maybe you should sit down. I can handle—", position: 5},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "I've been handling Sunday dinner for sixty years. I think I can manage one more.", position: 6},
  %{id: Ecto.UUID.generate(), type: "narration", text: "A car pulls up outside. Rose's expression shifts—hope and dread.", position: 7},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "Mom's here.", position: 8},
  %{id: Ecto.UUID.generate(), type: "narration", text: "SARAH (45, exhausted, carrying wine like an offering) enters through the front door.", position: 9},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "Mama. You look beautiful.", position: 10},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "You look tired.", parenthetical: "stiff", position: 11},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "Nice to see you too.", position: 12},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They embrace briefly. Lily watches—studying the tension.", position: 13},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "Is Michael—", position: 14},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "He'll come. He always comes.", position: 15},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "That's what I'm afraid of.", parenthetical: "muttering", position: 16},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They move into the dining room. Rose begins pouring wine.", position: 17},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "Your father loved this wine.", position: 18},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "Dad loved a lot of things. Didn't mean they loved him back.", position: 19},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "Sarah.", parenthetical: "warning", position: 20},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The front door OPENS. MICHAEL (50s, carrying decades of resentment like a worn coat) enters. He doesn't remove his jacket.", position: 21},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "Mother. Sarah. And Lily—I didn't know you'd be here.", position: 22},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "Uncle Michael. It's good to see—", position: 23},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "Let's skip the pleasantries. I have somewhere to be at seven.", position: 24},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "You always have somewhere to be.", parenthetical: "quietly", position: 25},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Everyone sits. Rose says grace—short, perfunctory. They begin eating in suffocating silence.", position: 26},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "So. When are you going to tell them?", parenthetical: "finally", position: 27},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "Michael—", position: 28},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "No. Sixty years of Sunday dinners. Sixty years of pretending this family isn't built on lies. When does it end?", position: 29},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "What is he talking about?", position: 30},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "Tell her. Tell your perfect daughter what Dad really did. Who he really was.", parenthetical: "to Rose", position: 31},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "Maybe we shouldn't—", position: 32},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "Stay out of this, Lily. You weren't even born yet.", position: 33},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "Enough.", parenthetical: "standing, surprising strength", position: 34},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The room goes still.", position: 35},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "Your father was not a saint. But he was not a monster either. He was a man. A flawed, complicated man who did his best.", position: 36},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "His best? He abandoned us for six months! You told everyone he was traveling for work!", position: 37},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "What?", parenthetical: "shocked", position: 38},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "He came back. That's what matters. He came back, and he tried.", parenthetical: "sitting heavily", position: 39},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "He came back because his other family didn't want him either.", position: 40},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "Other family?", position: 41},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "Oh my god.", parenthetical: "quietly", position: 42},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "I forgave him. Why can't you?", parenthetical: "to Michael", position: 43},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "Because you made me lie! Every Sunday dinner—pass the salt, how was work, lovely roast—while I knew! And Sarah got to be the good daughter, the one who didn't know!", position: 44},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "You should have told me.", position: 45},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "Mother wouldn't let me. Protect the family. Preserve the illusion.", position: 46},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Long silence. The roast cools. The wine sits untouched.", position: 47},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "My father did something similar. Left when I was seven. Mom never told me why until last year.", parenthetical: "standing", position: 48},
  %{id: Ecto.UUID.generate(), type: "narration", text: "Everyone looks at her.", position: 49},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "You know what I learned? Secrets are heavier than the truth. They crush the people carrying them.", position: 50},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "You've been carrying this for sixty years. And Michael's been carrying it with you. Maybe... maybe it's time to put it down.", parenthetical: "to Grandma Rose", position: 51},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "I was so ashamed.", parenthetical: "tears forming", position: 52},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "SARAH", text: "Mama...", parenthetical: "moving to her mother", position: 53},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "MICHAEL", text: "I didn't want to hurt you, Sarah. I just... I couldn't carry it alone anymore.", parenthetical: "softer now", position: 54},
  %{id: Ecto.UUID.generate(), type: "narration", text: "The family sits together. Not healed—that takes longer. But something has shifted. A first step.", position: 55},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "GRANDMA ROSE", text: "The roast is getting cold.", parenthetical: "wiping her eyes", position: 56},
  %{id: Ecto.UUID.generate(), type: "dialogue", character_name: "LILY", text: "Then we should eat.", parenthetical: "small smile", position: 57},
  %{id: Ecto.UUID.generate(), type: "narration", text: "They pick up their forks. The silence is different now. Lighter.", position: 58}
]

sunday_dinner = Repo.insert!(%Screenplay{
  title: "Sunday Dinner",
  writer_id: sarah.id,
  writer_name: sarah.name,
  genre: "Drama",
  logline: "Three generations gather for a meal that will tear the family apart—or finally heal it.",
  page_count: 6,
  likes: 12,
  audio_version_count: 2,
  script_content: sunday_dinner_script,
  blocks: sunday_dinner_blocks
})

# ============================================================================
# AUDIO VERSIONS - NOW PROPERLY LINKED TO PERFORMER ACCOUNTS + COLLECTIVES
# ============================================================================
IO.puts("Creating audio versions with correct performer and collective links...")

# The Lighthouse Collective performs "The Last Light"
# submitted_by_id: individual user who submitted
# collective_id: the collective this was performed by
Repo.insert!(%AudioVersion{
  screenplay_id: last_light.id,
  submitted_by_id: jake.id,  # Jake (admin) submitted for the collective
  collective_id: lighthouse.id,  # Attribution to the collective
  performer_type: "group",
  group_name: "The Lighthouse Collective",
  performers: ["Jake Morrison", "Lin Zhou", "Sam Peters", "Mia Chen"],
  casting: %{"MAYA" => "Lin Zhou", "COMMANDER VOSS" => "Jake Morrison", "THE VOICE" => "Sam Peters", "TOMMY" => "Mia Chen"},
  audio_url: "/uploads/audio/last_light_collective.mp3",
  duration_seconds: 1104,  # 18:24 = 18*60 + 24
  file_size_bytes: 26_500_000,  # ~26.5 MB (estimated for 18 min MP3)
  likes: 12,
  author_pick: true,
  verified: true,
  date: "Jan 15, 2026"
})

# Emma Stone performs "The Last Light" solo (no collective)
Repo.insert!(%AudioVersion{
  screenplay_id: last_light.id,
  submitted_by_id: emma.id,
  collective_id: nil,  # Solo recording - no collective
  performer_type: "solo",
  group_name: nil,
  performers: ["Emma Stone"],
  casting: %{},
  audio_url: "/uploads/audio/last_light_emma.mp3",
  duration_seconds: 1005,  # 16:45 = 16*60 + 45
  file_size_bytes: 24_100_000,  # ~24 MB
  likes: 19,
  author_pick: false,
  verified: true,
  date: "Jan 8, 2026"
})

# David Kim & Rachel Torres perform "Coffee for Two"
Repo.insert!(%AudioVersion{
  screenplay_id: coffee.id,
  submitted_by_id: david.id,  # David (admin) submitted for the duo
  collective_id: kim_torres.id,  # Attribution to the duo collective
  performer_type: "duo",
  group_name: "David Kim & Rachel Torres",
  performers: ["David Kim", "Rachel Torres"],
  casting: %{"ELENA" => "Rachel Torres", "JAMES" => "David Kim", "BARISTA" => "David Kim"},
  audio_url: "/uploads/audio/coffee_duo.mp3",
  duration_seconds: 750,  # 12:30 = 12*60 + 30
  file_size_bytes: 18_000_000,  # ~18 MB
  likes: 7,
  author_pick: true,
  verified: true,
  date: "Jan 18, 2026"
})

# Michael Chang performs "Sunday Dinner" solo (no collective)
Repo.insert!(%AudioVersion{
  screenplay_id: sunday_dinner.id,
  submitted_by_id: michael_chang.id,
  collective_id: nil,  # Solo recording - no collective
  performer_type: "solo",
  group_name: nil,
  performers: ["Michael Chang"],
  casting: %{},
  audio_url: "/uploads/audio/sunday_michael.mp3",
  duration_seconds: 668,  # 11:08 = 11*60 + 8
  file_size_bytes: 16_000_000,  # ~16 MB
  likes: 3,
  author_pick: true,
  verified: true,
  date: "Jan 19, 2026"
})

# Jake Morrison performs "Sunday Dinner" solo (no collective)
Repo.insert!(%AudioVersion{
  screenplay_id: sunday_dinner.id,
  submitted_by_id: jake.id,
  collective_id: nil,  # Solo recording - no collective
  performer_type: "solo",
  group_name: nil,
  performers: ["Jake Morrison"],
  casting: %{},
  audio_url: "/uploads/audio/sunday_jake.mp3",
  duration_seconds: 652,  # 10:52 = 10*60 + 52
  file_size_bytes: 15_600_000,  # ~15.6 MB
  likes: 5,
  author_pick: false,
  verified: true,
  date: "Jan 20, 2026"
})

# ============================================================================
# COLLECTIVE INVITATIONS & JOIN REQUESTS (for testing flows)
# ============================================================================
IO.puts("Creating sample invitations and join requests...")

alias ScriptVoice.Collectives.CollectiveInvitation
alias ScriptVoice.Collectives.CollectiveJoinRequest

# Emma has a pending invitation to join The Lighthouse Collective
Repo.insert!(%CollectiveInvitation{
  collective_id: lighthouse.id,
  inviter_id: jake.id,
  invitee_id: emma.id,
  status: "pending",
  message: "Hey Emma! We loved your solo work on The Last Light. Would you like to join our collective for future projects?",
  expires_at: DateTime.utc_now() |> DateTime.add(14, :day) |> DateTime.truncate(:second)
})

# Michael Chang requested to join Kim & Torres duo
Repo.insert!(%CollectiveJoinRequest{
  collective_id: kim_torres.id,
  user_id: michael_chang.id,
  status: "pending",
  message: "Hi! I specialize in family dramas and would love to collaborate with you both on future projects."
})

IO.puts("")
IO.puts("============================================")
IO.puts("Seeds completed successfully!")
IO.puts("============================================")
IO.puts("")
IO.puts("Demo Accounts Created:")
IO.puts("")
IO.puts("WRITERS:")
IO.puts("  - sarah@example.com (Sarah Chen)")
IO.puts("  - marcus@example.com (Marcus Webb)")
IO.puts("  - aisha@example.com (Aisha Patel)")
IO.puts("")
IO.puts("VOICE ARTISTS (with pricing):")
IO.puts("  - jake@example.com (Jake Morrison) - Per page: $5/page, min $25")
IO.puts("  - emma@example.com (Emma Stone) - Per page: $8/page, min $50")
IO.puts("  - michael@example.com (Michael Chang) - Quote-based (flexible)")
IO.puts("  - lin@example.com (Lin Zhou) - Per page: $6/page, min $30")
IO.puts("  - david@example.com (David Kim) - Per page/char: $4/page + $2/char")
IO.puts("  - rachel@example.com (Rachel Torres) - Per page/char: $4/page + $2/char")
IO.puts("")
IO.puts("VOICE ARTISTS (no pricing yet):")
IO.puts("  - sam@example.com (Sam Peters)")
IO.puts("  - mia@example.com (Mia Chen)")
IO.puts("")
IO.puts("COLLECTIVES:")
IO.puts("  - The Lighthouse Collective (/collective/the-lighthouse-collective)")
IO.puts("    Members: Jake (admin), Lin, Sam, Mia")
IO.puts("  - David Kim & Rachel Torres (/collective/david-kim-rachel-torres)")
IO.puts("    Members: David (admin), Rachel (admin)")
IO.puts("")
IO.puts("SCREENPLAY PROJECTS:")
IO.puts("")
IO.puts("  Sarah Chen's Projects:")
IO.puts("    - Across All Time (series) - 4 seasons, family time-travel drama")
IO.puts("    - Digital Hearts (limited_series) - AI researchers romance")
IO.puts("    - Starfall Academy (web_series) - YA sci-fi academy")
IO.puts("")
IO.puts("  Marcus Webb's Projects:")
IO.puts("    - Love in the City (anthology) - NYC romance anthology")
IO.puts("    - The Brew House (series) - Comedy about a craft brewery")
IO.puts("    - Once Upon Tomorrow (feature_film) - Time-traveling love story")
IO.puts("")
IO.puts("  Aisha Patel's Projects:")
IO.puts("    - The Hollow Men (series) - Shapeshifter thriller")
IO.puts("    - Cold Case Files: Reopened (documentary_series)")
IO.puts("    - Whispers in the Dark (podcast_drama) - Horror audio drama")
IO.puts("    - Fragments (short_film_collection) - Connected short films")
IO.puts("")
IO.puts("PROJECT TYPES DEMONSTRATED:")
IO.puts("  - series, limited_series, miniseries, anthology")
IO.puts("  - web_series, feature_film, documentary_series")
IO.puts("  - podcast_drama, short_film_collection")
IO.puts("")
IO.puts("VISIBILITY SETTINGS:")
IO.puts("  Public Projects (viewable on Browse):")
IO.puts("    - Across All Time (Sarah)")
IO.puts("    - Digital Hearts (Sarah)")
IO.puts("    - Love in the City (Marcus)")
IO.puts("    - The Brew House (Marcus)")
IO.puts("    - The Hollow Men (Aisha)")
IO.puts("    - Whispers in the Dark (Aisha)")
IO.puts("    - Fragments (Aisha)")
IO.puts("  Private Projects (owner only):")
IO.puts("    - Starfall Academy (Sarah)")
IO.puts("    - Once Upon Tomorrow (Marcus)")
IO.puts("    - Cold Case Files: Reopened (Aisha)")
IO.puts("  Episode Visibility Examples:")
IO.puts("    - S01E03 'Echoes' of Across All Time is hidden (is_public: false)")
IO.puts("")
IO.puts("INVITATIONS & JOIN REQUESTS:")
IO.puts("  - Emma Stone has a pending invitation to The Lighthouse Collective")
IO.puts("  - Michael Chang has requested to join David Kim & Rachel Torres")
IO.puts("")
IO.puts("Use these accounts to test projects, seasons, episodes, and series bible flows!")
IO.puts("============================================")

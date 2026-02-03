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
  logline: "Two strangers share a table at a crowded cafe and discover they're both running from the same past.",
  page_count: 8,
  likes: 18,
  audio_version_count: 1,
  script_content: coffee_script,
  characters: [
    %{id: Ecto.UUID.generate(), name: "ELENA", gender: "Female", estimated_lines: 52, description: "Journalist, 30s, guarded"},
    %{id: Ecto.UUID.generate(), name: "JAMES", gender: "Male", estimated_lines: 48, description: "Former musician, 30s, melancholic"},
    %{id: Ecto.UUID.generate(), name: "BARISTA", gender: "Any", estimated_lines: 6, description: "Friendly cafe worker"}
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
  script_content: hollow_men_script,
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
  script_content: sunday_dinner_script,
  characters: [
    %{id: Ecto.UUID.generate(), name: "GRANDMA ROSE", gender: "Female", estimated_lines: 28, description: "Family matriarch, 80s"},
    %{id: Ecto.UUID.generate(), name: "MICHAEL", gender: "Male", estimated_lines: 32, description: "Son, 50s, resentful"},
    %{id: Ecto.UUID.generate(), name: "SARAH", gender: "Female", estimated_lines: 26, description: "Daughter, 45, peacemaker"},
    %{id: Ecto.UUID.generate(), name: "LILY", gender: "Female", estimated_lines: 18, description: "Granddaughter, 20s, outsider perspective"}
  ]
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
IO.puts("INVITATIONS & JOIN REQUESTS:")
IO.puts("  - Emma Stone has a pending invitation to The Lighthouse Collective")
IO.puts("  - Michael Chang has requested to join David Kim & Rachel Torres")
IO.puts("")
IO.puts("Use these accounts to test commission request and collective flows!")
IO.puts("============================================")

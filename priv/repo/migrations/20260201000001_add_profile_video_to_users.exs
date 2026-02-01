defmodule ScriptVoice.Repo.Migrations.AddProfileVideoToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_video_url, :string
      add :bio, :text
    end
  end
end

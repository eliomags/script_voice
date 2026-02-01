defmodule ScriptVoice.Repo.Migrations.ChangeDurationToSeconds do
  use Ecto.Migration

  def change do
    # Add new duration_seconds column as integer
    alter table(:audio_versions) do
      add :duration_seconds, :integer
      add :file_size_bytes, :bigint
    end

    # Note: In production, you would need to migrate existing string data:
    # execute """
    #   UPDATE audio_versions
    #   SET duration_seconds = (
    #     CASE
    #       WHEN duration ~ '^[0-9]+:[0-9]+$' THEN
    #         (SPLIT_PART(duration, ':', 1)::integer * 60) + SPLIT_PART(duration, ':', 2)::integer
    #       ELSE 0
    #     END
    #   )
    # """

    # For now in development, we'll handle this in seeds
    # After data migration, you could remove the old column:
    # alter table(:audio_versions) do
    #   remove :duration
    # end
  end
end

require_relative "sound"

class SoundboardManager
  def initialize(bot:)
    @bot = bot
    @sound_lists_per_server = {}
    @currently_playing = {}
    @switching_sounds = []

    @stop_threads = false
  end

  def play_sound(server_id, sound)
    @currently_playing[server_id] = sound
    @bot.voices[server_id].play_file(sound.file)
  end

  def stop(server_id)
    @currently_playing.delete(server_id)
    @bot.voices[server_id]&.stop_playing
  end

  def set_soundboard(server_id, sounds)
    @sound_lists_per_server[server_id] = sounds
  end

  def get_soundboard(server_id)
    @sound_lists_per_server[server_id]
  end

  def is_soundboard_configured?(server_id)
    !@sound_lists_per_server[server_id].nil?
  end

  def start_threads
    Thread.new do
      while !@stop_threads
        sleep 10

        @bot.voices.each do |server_id, voice|
          if voice.channel.users.none? {|user| user.id != @bot.profile.id}
            @currently_playing.delete(server_id)
            voice.destroy
          end
        end
      end
    end

    Thread.new do
      while !@stop_threads
        sleep 1

        @currently_playing.each do |server_id, sound|
          if !@bot.voices[server_id]&.playing?
            @bot.voices[server_id]&.play_file(sound.file)
          end
        end
      end
    end
  end
end

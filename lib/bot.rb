# frozen_string_literal: true

require "pry"
require "discordrb"
require "open-uri"
require_relative "config"
require_relative "sound"
require_relative "soundboard_manager"

module Bard
  class Bot
    def initialize
      @bot = Discordrb::Bot.new(token: Bard::Config.discord.token)
      @soundboard_manager = SoundboardManager.new(bot: @bot)

      setup_commands
    end

    def start
      @soundboard_manager.start_threads
      @bot.run
    end

    private

    def setup_commands
      @bot.register_application_command(:bard, "Open the soundboard panel") do |bard_cmd|
        bard_cmd.subcommand(:list, "List all songs")
        bard_cmd.subcommand(:play, "Play a sound") do |play_cmd|
          play_cmd.string("sound", "Which sound to play", required: true)
        end
        bard_cmd.subcommand(:configure, "Configure the soundboard") do |configure_cmd|
          configure_cmd.attachment(:sound_list, "List of sounds to use", required: true)
        end
        bard_cmd.subcommand(:controls, "Print the controls")
        bard_cmd.subcommand(:stop, "Stop the playback")
        bard_cmd.subcommand(:disconnect, "Disconnect the bot from voice channel")
      end

      @bot.application_command(:bard).subcommand(:list) do |event|
        sound_list = <<~STR
          ```
          #{Sound.all.map(&:name).join("\n")}
          ```
        STR

        event.respond(content: sound_list, ephemeral: true)
      end

      @bot.application_command(:bard).subcommand(:play) do |event|
        sound = Sound.find(name: event.options["sound"])
        next event.respond(content: "Sound not found: `#{event.options["sound"]}`", ephemeral: true) if !sound

        channel = event.user.voice_channel
        next event.respond(content: "You're not in any voice channel!", ephemeral: true) unless channel
        @bot.voice_connect(channel)

        event.respond(content: "You selected: #{sound.name}", ephemeral: true)

        @soundboard_manager.play_sound(event.server.id, sound)
      end

      @bot.application_command(:bard).subcommand(:configure) do |event|
        sound_list_attachment = event.resolved.attachments[event.options["sound_list"].to_i]

        data = ""

        URI.open(sound_list_attachment.url) do |f|
          data = f.read
        end

        sounds = data.split(/\n|\r\n/).map do |sound|
          [sound, Sound.find(name: sound)]
        end

        sounds_not_found = sounds.filter do |name, sound|
          sound.nil?
        end.map(&:first)

        if sounds_not_found.any?
          response = <<~STR
            Some sounds were not found:
            `#{sounds_not_found.join("`\n`")}`
          STR
          next event.respond(content: response, ephemeral: true)
        end

        next event.respond(content: "Maximum of 25 sounds allowed", ephemeral: true) if sounds.count > 25

        @soundboard_manager.set_soundboard(
          event.server.id,
          sounds.map do |_name, sound|
            sound
          end
        )

        response = <<~STR
          The soundboard has been configured with the following sounds:
          `#{sounds.map(&:first).join("`\n`")}`
        STR
        event.respond(content: response, ephemeral: true)
      end

      @bot.application_command(:bard).subcommand(:controls) do |event|
        next event.respond(content: "No list prepared", ephemeral: true) if !@soundboard_manager.is_soundboard_configured?(event.server.id)

        event.respond(content: "Select a sound to start", ephemeral: true) do |_, view|
          view.row do |r|
            r.select_menu(custom_id: "sound_select", placeholder: "Select me!") do |s|
              @soundboard_manager.get_soundboard(event.server.id).map do |sound|
                s.option(label: sound.name, value: sound.file)
              end
            end
          end
        end
      end

      @bot.application_command(:bard).subcommand(:stop) do |event|
        @soundboard_manager.stop(event.server.id)
        event.respond(content: "Stopped the playback", ephemeral: true)
      end

      @bot.application_command(:bard).subcommand(:disconnect) do |event|
        next event.respond(content: "Bard is not connected to any voice channel on this server", ephemeral: true) unless @bot.voices[event.server.id]

        @soundboard_manager.stop(event.server.id)
        @bot.voices[event.server.id]&.destroy
        event.respond(content: "I disconnected from the voice channel. Until we meet again _*runs away*_", ephemeral: true)
      end

      @bot.select_menu(custom_id: "sound_select") do |event|
        channel = event.user.voice_channel
        next event.respond(content: "You're not in any voice channel!", ephemeral: true) unless channel
        @bot.voice_connect(channel)

        event.respond(content: "You selected: #{event.values.first}", ephemeral: true)

        @soundboard_manager.play_sound(event.server.id, Sound.find(file: event.values.first))
      end
    end
  end
end

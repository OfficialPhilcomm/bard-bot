class Sound
  attr_reader :file, :name

  def initialize(sound_file)
    @file = sound_file
    @name = sound_file.split("/").last.gsub(".mp3", "")
  end

  def self.find(file: nil, name: nil)
    @@sounds.find do |sound|
      sound.file == file || sound.name == name
    end
  end

  def self.from_name(name)
    new("sounds/#{name}.mp3")
  end

  def self.all
    @@sounds
  end

  def self.initialize
    @@sounds = Dir["sounds/**/*.mp3"]
      .map do |sound_file|
        Sound.new(sound_file)
      end.sort_by(&:name)
  end
end

Sound.initialize

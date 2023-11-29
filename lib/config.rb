require "strong_yaml"

module DndMusic
  class Config
    include StrongYAML

    file "config.yml"

    schema do
      group :discord do
        integer :application_id
        string :public_key
        string :token
        list :allowed_servers
      end

      group :esrgan do
        string :home
      end

      group :webserver do
        string :home
        string :domain
      end
    end
  end
end

DndMusic::Config.create_or_load
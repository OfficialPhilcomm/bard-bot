require "strong_yaml"

module Bard
  class Config
    include StrongYAML

    file "config.yml"

    schema do
      group :discord do
        integer :application_id
        string :public_key
        string :token
      end
    end
  end
end

Bard::Config.create_or_load

# frozen_string_literal: true

require 'yaml'

module MoneyGone
  class ConfigLoader
    def initialize(root:)
      @root = root
    end

    def load_all
      {
        categories: load_yaml('categories.yml'),
        rules: load_yaml('rules.yml'),
        lmstudio: load_yaml('lmstudio.yml')
      }
    end

    private

    def load_yaml(filename)
      path = File.join(@root, 'config', filename)
      YAML.safe_load_file(path)
    end
  end
end

# frozen_string_literal: false

module SensuPluginsMeta
  # The version of this Sensu plugin.
  module Version
    # The major version.
    MAJOR = 1
    # The minor version.
    MINOR = 0
    # The patch version.
    PATCH = 5
    # Concat them into a version string
    VER_STRING = [MAJOR, MINOR, PATCH].compact.join('.')
  end
end

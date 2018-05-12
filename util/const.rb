# frozen_string_literal: true

# Global constants
module Const
  # Server variable specification class
  class SVarSpec
    attr_reader :internal, :human, :default, :type

    def initialize(internal, human, default, type)
      @internal = internal
      @human = human
      @default = default
      @type = type
    end
  end

  PERMISSION_RANKS = %i[
    user
    superuser
    administrator
  ].freeze

  SVARS_TYPES = %i[
    bool
    int
  ].freeze

  SVAR_ALLOW_CENSUS = Const::SVarSpec.new('census_allow_normal_users', 'Allow all users to use !census', true, :bool)
  SVAR_ALLOW_SHOWME = Const::SVarSpec.new('showme_allow_normal_users', 'Allow all users to use !showme', true, :bool)
  SVAR_ALLOW_QUOTES = Const::SVarSpec.new('quotes_allow_normal_user', 'Allow all users to use !quotes', true, :bool)
  SVAR_RMHIST_ALLOW_SU = Const::SVarSpec.new('rmhist_allow_su', 'Allow superusers to use !rmhist', true, :bool)
  SVAR_USE_SNARK = Const::SVarSpec.new('snark_enabled', 'Enable snarky responses', false, :bool)
  SVAR_ALLOW_GAMES = Const::SVarSpec.new('games_enabled', 'Enable games commands such as !roll', true, :bool)
  SVAR_ROLL_MIN = Const::SVarSpec.new('roll_min', 'Default minimum for !roll', 1, :int)
  SVAR_ROLL_MAX = Const::SVarSpec.new('roll_max', 'Default maximum for !roll', 100, :int)
  SVAR_DISC_ALLOW_SU = Const::SVarSpec.new('disc_allow_su', 'Allow superusers to use !disc', false, :bool)

  ALL_SVARS = Const.constants(false).select { |c| c.to_s.start_with? 'SVAR_' }.map { |c| Const.const_get c }
end

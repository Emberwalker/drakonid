module Const
  # Container classes
  class SVarSpec
    attr_reader :internal, :human, :default

    def initialize(internal, human, default)
      @internal = internal
      @human = human
      @default = default
    end
  end

  # Permissions
  PERMISSION_RANKS = [
      :user,
      :superuser,
      :administrator
  ]

  # SVars
  SVAR_ALLOW_CENSUS = Const::SVarSpec.new('census_allow_normal_users', 'Allow all users to use !census', true)
  SVAR_ALLOW_SHOWME = Const::SVarSpec.new('showme_allow_normal_users', 'Allow all users to use !showme', true)
  SVAR_ALLOW_QUOTES = Const::SVarSpec.new('quotes_allow_normal_user', 'Allow all users to use !quotes', true)
  SVAR_RMHIST_ALLOW_SU = Const::SVarSpec.new('rmhist_allow_su', 'Allow superusers to use !rmhist', true)
  SVAR_USE_SNARK = Const::SVarSpec.new('snark_enabled', 'Enable snarky responses', false)

  ALL_SVARS = Const.constants(false).select { |c| c.to_s.start_with? 'SVAR_' }.map { |c| Const.const_get c }
end
module Const
  class SVarSpec
    attr_reader :internal, :human, :default

    def initialize(internal, human, default)
      @internal = internal
      @human = human
      @default = default
    end
  end

  SVAR_ALLOW_CENSUS = Const::SVarSpec.new('census_allow_normal_users', 'Allow all users to use !census', true)
  SVAR_ALLOW_QUOTES = Const::SVarSpec.new('quotes_allow_normal_user', 'Allow all users to use !quotes', true)
  SVAR_USE_SNARK = Const::SVarSpec.new('snark_enabled', 'Enable snarky responses', false)

  ALL_SVARS = [SVAR_ALLOW_CENSUS, SVAR_ALLOW_QUOTES, SVAR_USE_SNARK]
end
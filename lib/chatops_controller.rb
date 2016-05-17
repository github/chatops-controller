require "chatops_controller/version"
require "chatops/controller"

::ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym("ChatOps")
end

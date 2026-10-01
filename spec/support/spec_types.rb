# Domain models live under app/domain rather than app/models, so RSpec's
# directory-based type inference does not reach them. Without a :model type the
# shoulda-matchers validation matchers are not included.
RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/domain/}) do |metadata|
    metadata[:type] ||= :model
  end

  config.define_derived_metadata(file_path: %r{/spec/integrations/}) do |metadata|
    metadata[:type] ||= :model
  end
end

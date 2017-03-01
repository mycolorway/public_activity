module PublicActivity
  module ORM
    # Support for ActiveRecord for PublicActivity. Used by default and supported
    # officialy.
    module ActiveRecord
      # Provides ActiveRecord specific, database-related routines for use by
      # PublicActivity.
      class Adapter
        # Creates the activity on `trackable` with `options`
        def self.create_activity(trackable, options)
          trackable.activities.where(key: options[:opposite_key]).destroy_all if options[:opposite_key]
          trackable.activities.create options.except(:opposite_key)
        end
      end
    end
  end
end

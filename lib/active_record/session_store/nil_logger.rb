module ActiveRecord
  module SessionStore
     class NilLogger
      def self.silence
        yield
      end
    end
  end
end

module Conekta
  module APIOperations
    module ModifyMember
      module ClassMethods
        def modify_member(parent, member, params={}, action, method, api_key=nil)
          path = "#{path}/#{member}/#{action}"
          response, api_key = Conekta.request(method.to_sym, path, api_key, params)
          self.try("#{parent}".to_sym).try("#{member}".to_sym) = self
          self
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end
    end
  end
end

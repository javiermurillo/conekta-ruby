module Conekta
  module APIOperations
    module ModifyMember
      module ClassMethods
        def modify_member(method, member, action=nil, params={}, api_key=nil)
          if action
            path = "#{self.url}/#{member}/#{action}"
          else
            path = "#{self.url}/#{member}"
          end
          response, api_key = Conekta.request(method.to_sym, path, api_key, params)
          Util.convert_to_conekta_object(response, api_key)
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end
    end
  end
end

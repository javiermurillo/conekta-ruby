module Conekta
  module APIOperations
    module CreateMember
      module ClassMethods
        def create_member(member, params={}, api_key=nil)
          path = "#{path}/#{member}"
          response, api_key = Conekta.request(:post, path, api_key, params)
          obj = Util.convert_to_conekta_object(response, api_key)
          obj.try("#{parent}".to_sym) = self
          if obj.class == ConektaObject
            count = self.try("#{member}".to_sym).count
            self.try("#{member}".to_sym)[count] = obj
          else
            self.try("#{member}".to_sym) = obj
          end
          obj
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end
    end
  end
end

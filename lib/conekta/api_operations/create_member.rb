module Conekta
  module APIOperations
    module CreateMember
      def create_member(member, params={}, api_key=nil)
        path = "/customers/#{self.id}/#{member}"
        response, api_key = Conekta.request(:post, path, api_key, params)
        obj = Util.convert_to_conekta_object(response, api_key)
        if obj.class == ConektaObject
          count = self.cards.count
          self.cards[count] = obj
        else
          self.subscription = obj
        end
        obj
      end
    end
  end
end

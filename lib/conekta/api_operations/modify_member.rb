module Conekta
  module APIOperations
    module ModifyMember
      def modify_member(member, action, params={}, api_key=nil)
        path = "/customers/#{customer.id}/#{member}/#{action}"
        response, api_key = Conekta.request("post", path, api_key, {:foo => "var"})
        refresh_from(response, api_key)
        self
      end
    end
  end
end

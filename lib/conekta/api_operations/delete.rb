module Conekta
  module APIOperations
    module Delete
      def delete
        response, api_key = Conekta.request(:delete, url, @api_key)
        refresh_from(response, api_key)
        self
      end
    end
  end
end

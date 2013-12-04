module Conekta
  class Card < APIResource
    include Conekta::APIOperations::Update

    attr_accessor :customer
    
    def customer
      @customer
    end

    def customer=(customer)
      @customer = customer
    end

    def delete
      response, api_key = Conekta.request(:delete, url, @api_key)
      refresh_from(response, api_key)
      deleted_card = self
      i = 0
      for card in self.customer.cards
        if deleted_card.id == card.id
          self.customer.cards.delete_at(i)
          break
        end
        i = i + 1
      end
      deleted_card
    end

    def url
      unless id = self['id']
        raise ParameterValidationError.new("Could not determine which URL to request: #{self.class} instance has invalid ID: #{id.inspect}", 'id')
      end
      unless customer = self.customer
        raise ParameterValidationError.new("Could not determine which URL to request: #{self.class} instance has invalid customer: #{customer.inspect}", 'customer')
      end
      "#{Conekta::Customer.url}/#{CGI.escape(customer.id)}/cards/#{CGI.escape(id)}"
    end
  end
end

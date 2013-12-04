module Conekta
  class Subscription < APIResource
    include Conekta::APIOperations::Update
    include Conekta::APIOperations::ModifyMember

    attr_accessor :customer
    
    def customer
      @customer
    end

    def customer=(customer)
      @customer = customer
    end

    def cancel
      self.modify_member("subscription", "cancel")
    end

    def pause
      subscription = self.modify_member("subscription", "pause")
    end

    def resume
      subscription = self.modify_member("subscription", "resume")
    end

    def url
      unless customer = self.customer
        raise ParameterValidationError.new("Could not determine which URL to request: #{self.class} instance has invalid customer: #{customer.inspect}", 'customer')
      end
      "#{Conekta::Customer.url}/#{CGI.escape(customer.id)}/subscription"
    end
  end
end

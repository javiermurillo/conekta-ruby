module Conekta
  class Subscription < APIResource
    include Conekta::APIOperations::Update
    include Conekta::APIOperations::ModifyMember

    def cancel
      self.modify_member("customer", "subscription", nil, "cancel", "post")
    end

    def pause
      self.modify_member("customer", "subscription", nil, "pause", "post")
    end

    def resume
      self.modify_member("customer", "subscription", nil, "resume", "post")
    end

    def url
      unless customer = self.customer
        raise ParameterValidationError.new("Could not determine which URL to request: #{self.class} instance has invalid customer: #{customer.inspect}", 'customer')
      end
      "#{Conekta::Customer.url}/#{CGI.escape(customer.id)}/subscription"
    end
  end
end

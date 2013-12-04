module Conekta
  class Customer < APIResource
    include Conekta::APIOperations::Create
    include Conekta::APIOperations::Delete
    include Conekta::APIOperations::Update
    include Conekta::APIOperations::List
    include Conekta::APIOperations::CreateMember

    def refresh_from(values, api_key, partial=false)
      super
      customer = self
      for i in 0..(customer.cards.count - 1)
        puts "entra"
        customer.cards[i].customer = customer
      end
      if customer.subscription
        customer.subscription.customer = customer
      end
    end

    def create_subscription(params={})
      subscription = create_member('subscription', params)
      subscription.customer = self
      self.subscription = subscription
      subscription
    end

    def create_card(params={})
      card = create_member('cards', params)
      card.customer = self
      self.cards << card
      card
    end
  end
end

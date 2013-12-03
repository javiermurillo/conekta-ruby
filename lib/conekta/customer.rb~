module Conekta
  class Customer < APIResource
    include Conekta::APIOperations::Create
    include Conekta::APIOperations::Delete
    include Conekta::APIOperations::Update
    include Conekta::APIOperations::List
    include Conekta::APIOperations::CreateMember

    def create_subscription(params={})
      self.create_member('subscription', params)
    end

    def create_card(params={})
      self.create_member('cards', params)
    end
  end
end

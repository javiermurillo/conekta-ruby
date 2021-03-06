module Conekta
  class Customer < APIResource
    include Conekta::APIOperations::Create
    include Conekta::APIOperations::Delete
    include Conekta::APIOperations::Update
    include Conekta::APIOperations::List
    include Conekta::APIOperations::ModifyMember

    def create_subscription(params={})
      self.modify_member('post', 'subscription', nil, params)
    end

    def cancel_subscription(params={})
      self.modify_member('post', 'subscription', 'cancel')
    end

    def resume_subscription(params={})
      self.modify_member('post', 'subscription', 'resume')
    end

    def pause_subscription(params={})
      self.modify_member('post', 'subscription', 'pause')
    end

    def update_subscription(params)
      self.modify_member('put', 'subscription', nil, params)
    end

    private

    def subscription_url
      url + '/subscription'
    end
  end
end

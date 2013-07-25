module Conekta
  class Charge < APIResource
    include Conekta::APIOperations::List
    include Conekta::APIOperations::Create
    include Conekta::APIOperations::Update

    def refund(params={})
      response, api_key = Conekta.request(:post, refund_url, @api_key, params)
      refresh_from(response, api_key)
      self
    end

    def capture(params={})
      response, api_key = Conekta.request(:post, capture_url, @api_key, params)
      refresh_from(response, api_key)
      self
    end

    def update_dispute(params)
      response, api_key = Conekta.request(:post, dispute_url, @api_key, params)
      refresh_from({ :dispute => response }, api_key, true)
      dispute
    end

    private

    def refund_url
      url + '/refund'
    end

    def capture_url
      url + '/capture'
    end

    def dispute_url
      url + '/dispute'
    end
  end
end

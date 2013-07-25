# -*- coding: utf-8 -*-
require File.expand_path('../test_helper', __FILE__)
#require 'test/unit'
#require 'shoulda'
require 'rspec'
require 'mocha/setup'
require 'pp'
require 'rest-client'
require 'cgi'
require 'uri'

class ConektaTest < Test::Unit::TestCase
  include Mocha

  describe Conekta::Util, "#symbolize_names" do
    it "symbolize_names should convert names to symbols" do
      start = {
        'foo' => 'bar',
        'array' => [{ 'foo' => 'bar' }],
        'nested' => {
          1 => 2,
          :symbol => 9,
          'string' => nil
        }
      }
      finish = {
        :foo => 'bar',
        :array => [{ :foo => 'bar' }],
        :nested => {
          1 => 2,
          :symbol => 9,
          :string => nil
        }
      }

      symbolized = Conekta::Util.symbolize_names(start)
      finish.should eq(symbolized)
    end
  end

  describe Conekta::ConektaObject, "#new" do

    it "creating a new APIResource should not fetch over the network" do
      @mock = double
      Conekta.mock_rest_client = @mock
      @mock.expects(:get).never
      @mock.expects(:post).never
      c = Conekta::Charge.new("someid")
      Conekta.mock_rest_client = nil
    end

    it "creating a new APIResource from a hash should not fetch over the network" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.expects(:get).never
      @mock.expects(:post).never
      c = Conekta::Charge.construct_from({
        id: "somecharge",
        amount: 10000,
        currency: 'MXN',
        card: {
          number: '4242424242424242',
          cvc:'123',
          exp_month:12,
          exp_year:19,
          name:'Sebastian Q.'
        }
      })

      Conekta.mock_rest_client = nil
    end

    it "setting an attribute should not cause a network request" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.expects(:get).never
      @mock.expects(:post).never
      c = Conekta::Charge.new("test_charge");
      c = Conekta::Charge.construct_from({
        id: "somecharge",
        amount: 10000,
        card: {
          number: '4242424242424242',
          cvc:'123',
          exp_month:12,
          exp_year:19,
          name:'Sebastian Q.'
        }
      })
      c.currency = 'MXN'

      Conekta.mock_rest_client = nil
    end

    it "accessing id should not issue a fetch" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.expects(:get).never
      c = Conekta::Charge.new("test_charge");
      c.id

      Conekta.mock_rest_client = nil
    end
  end

  describe Conekta, "#api_key" do
    it "not specifying api credentials should raise an exception" do
      Conekta.api_key = nil
      expect{Conekta::Charge.new("test_charge").refresh}.to raise_error(Conekta::AuthenticationError)
    end

    it "specifying api credentials containing whitespace should raise an exception" do
      Conekta.api_key = "key "
      expect{Conekta::Charge.new("test_charge").refresh}.to raise_error(Conekta::AuthenticationError)
    end

    it "specifying invalid api credentials should raise an exception" do
      @mock = double
      Conekta.mock_rest_client = @mock

      Conekta.api_key = "invalid"
      response = test_response(test_invalid_api_key_error, 401)

      @mock.expects(:get).once.raises(RestClient::ExceptionWithResponse.new(response, 401))
      expect{Conekta::Charge.retrieve("failing_charge")}.to raise_error(Conekta::AuthenticationError)

      Conekta.mock_rest_client = nil
    end

    it "AuthenticationErrors should have an http status, http body, and JSON body" do
      @mock = double
      Conekta.mock_rest_client = @mock

      Conekta.api_key = "invalid"
      response = test_response(test_invalid_api_key_error, 401)

      begin
        @mock.expects(:get).once.raises(RestClient::ExceptionWithResponse.new(response, 401))
        Conekta::Charge.retrieve("failing_charge")
      rescue Conekta::AuthenticationError => e
        401.should eq(e.http_status)
        true.should_not eq(e.http_body)
        true.should_not eq(e.json_body[:message])
        test_invalid_api_key_error['message'].should eq(e.json_body[:message])
      end

      Conekta.mock_rest_client = nil
    end
  end

  describe Conekta::ConektaObject, "#create" do

    it "when specifying per-object credentials with no global API key set, use the per-object credential when creating" do
      Conekta.api_key = nil

      Conekta.should_receive(:execute_request){|opts|
        opts[:headers][:authorization].should eq("Token token='sk_test_local'")
        test_response(test_charge)
      }

      Conekta::Charge.create({:card => {:number => '4242424242424242'}},
        'sk_test_local')
    end

    it "when specifying per-object credentials with global API key set, use the per-object credential when creating" do
      Conekta.api_key = "global"

      Conekta.should_receive(:execute_request){|opts|
        opts[:headers][:authorization].should eq("Token token='sk_test_local'")
        test_response(test_charge)
      }

      Conekta::Charge.create({:card => {:number => '4242424242424242'}},
        'sk_test_local')
    end

    it "when specifying per-object credentials with a global API key set, use the per-object credential when retrieving and making other calls" do
      Conekta.api_key = "global"

      Conekta.should_receive(:execute_request){|opts|
        opts[:url].should eq("#{Conekta.api_base}/charges/ch_test_charge.json")
        opts[:headers][:authorization].should eq("Token token='sk_test_local'")
        test_response(test_charge)
      }
      Conekta.should_receive(:execute_request){|opts|
        opts[:url].should eq("#{Conekta.api_base}/charges/ch_test_charge/refund.json")
        opts[:headers][:authorization].should eq("Token token='sk_test_local'")
        test_response(test_charge)
      }

      ch = Conekta::Charge.retrieve('ch_test_charge', 'sk_test_local')
      ch.refund
    end
  end

  describe Conekta, "#execute_request" do
    it "with valid credential, urlencode values in GET params" do
      @mock = double
      Conekta.mock_rest_client = @mock

      Conekta.api_key = 'foo'
      response = test_response(test_charge_array)
      @mock.should_receive(:get){|arg1, arg2, arg3|

        arg1.should eq("#{Conekta.api_base}/charges.json?amount=500")
        arg2.should eq(nil)
        arg3.should eq(nil)
        response
      }
      charges = Conekta::Charge.all(amount: 500).data
      charges.should be_kind_of(Array)

      Conekta.mock_rest_client = nil
    end

    it "with valid credential, construct URL properly with base query parameters" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_charge_array)

      Conekta.api_key = 'foo'
      response = test_response(test_charge_array_filtered)
      @mock.should_receive(:get){|arg1, arg2, arg3|
        arg1.should eq("#{Conekta.api_base}/charges.json?amount=500")
        arg2.should eq(nil)
        arg3.should eq(nil)
        response
      }
      charges = Conekta::Charge.all(amount:  500)

      response = test_response(test_charge_array_filtered)
      @mock.should_receive(:get){|arg1, arg2, arg3|
        arg1.should eq("#{Conekta.api_base}/charges.json?amount=500&status=paid")
        arg2.should eq(nil)
        arg3.should eq(nil)
        response
      }
      charges.all(:status=>'paid')

      Conekta.mock_rest_client = nil
    end

    it "with valid credential, a 401 should give an AuthenticationError with http status, body, and JSON body" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_missing_id_error, 401)
      @mock.should_receive(:get){|args|
        raise RestClient::ExceptionWithResponse.new(response, 401)
      }.once

      begin
        Conekta::Charge.retrieve("foo")
      rescue Conekta::AuthenticationError => e
        e.http_status.should eq(401)
        e.http_body.should_not eq(true)
        e.json_body.should be_kind_of(Hash)
      end

      Conekta.mock_rest_client = nil
    end

    it "with valid credential, a 402 should give an CardError with http status, body, and JSON body" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_missing_id_error, 402)
      @mock.should_receive(:post){|args|
        raise RestClient::ExceptionWithResponse.new(response, 402)
      }.once

      begin
        Conekta::Charge.create({
          amount:10000,
          description:'Test',
          card: {
            name:'Leo Fischer',
            number:4000000000000119,
            cvc:123,
            exp_month:8,
            exp_year:19
          }
        })

      rescue Conekta::CardError => e
        e.http_status.should eq(402)
        e.http_body.should_not eq(true)
        e.json_body.should be_kind_of(Hash)
      end

      Conekta.mock_rest_client = nil
    end

    it "with valid credential, a 404 should give an ResourceNotFoundError with http status, body, and JSON body" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_missing_id_error, 404)
      @mock.should_receive(:get){|args|
        raise RestClient::ExceptionWithResponse.new(response, 404)
      }.once

      begin
        Conekta::Charge.retrieve("foo")
      rescue Conekta::ResourceNotFoundError => e
        e.http_status.should eq(404)
        e.http_body.should_not eq(true)
        e.json_body.should be_kind_of(Hash)
      end

      Conekta.mock_rest_client = nil
    end

    it "with valid credential, a 422 should give an ParameterValidationError with http status, body, and JSON body" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_missing_id_error, 422)
      @mock.should_receive(:post){|args|
        raise RestClient::ExceptionWithResponse.new(response, 422)
      }.once

      begin
        Conekta::Charge.create({amount:-10000})
      rescue Conekta::ParameterValidationError => e
        e.http_status.should eq(422)
        e.http_body.should_not eq(true)
        e.json_body.should be_kind_of(Hash)
      end

      Conekta.mock_rest_client = nil
    end

    it "with valid credential, setting a nil value for a param should exclude that param from the request" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){|url, api_key, params|
        uri = URI(url)
        query = CGI.parse(uri.query)
        url.should match(%r{^#{Conekta.api_base}/charges?})
        query.keys.sort.should eq(['offset', 'sad'])

        test_response({ :count => 1, :data => [test_charge] })
      }
      c = Conekta::Charge.all(:count => nil, :offset => 5, :sad => false)

      @mock.should_receive(:post){|url, api_key, params|
        "#{Conekta.api_base}/charges.json".should eq(url)
        api_key.should eq(nil)
        {:amount => 50, :currency=>'usd', :card=>{}}.should eq(params)

        test_response({ :count => 1, :data => [test_charge] })
      }
      c = Conekta::Charge.create(:amount => 50, :currency => 'usd', :card => { :number => nil })
      Conekta.mock_rest_client = nil
    end

    it "requesting with a unicode ID should result in a request" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_missing_id_error, 400)
      @mock.should_receive(:get){|arg1, arg2, arg3|
        arg1.should eq("#{Conekta.api_base}/charges/%E2%98%83.json")
        arg2.should eq(nil)
        arg3.should eq(nil)
        raise RestClient::ExceptionWithResponse.new(response, 400)
      }.once
      c = Conekta::Charge.new("☃")
      expect{c.refresh}.to raise_error(Conekta::MalformedRequestError)

      Conekta.mock_rest_client = nil
    end

    it "requesting with no ID should result in an ParameterValidationError with no request" do
      c = Conekta::Charge.new
      expect{c.refresh}.to raise_error(Conekta::ParameterValidationError)
    end

    it "making a GET request with parameters should have a query string and no body" do
      @mock = double
      Conekta.mock_rest_client = @mock

      params = { :limit => 1 }
      @mock.should_receive(:get){|arg1, arg2, arg3|
        arg1.should eq("#{Conekta.api_base}/charges.json?limit=1")
        arg2.should eq(nil)
        arg3.should eq(nil)
        test_response([test_charge])
      }.once
      c = Conekta::Charge.all(params)

      Conekta.mock_rest_client = nil
    end

    it "making a POST request with parameters should have a body and no query string" do
      @mock = double
      Conekta.mock_rest_client = @mock

      params = { :amount => 100, :currency => 'usd', :card => 'sc_token' }
      @mock.should_receive(:post){|url, get, post|
        get.should eq(nil)
        post.should eq({:amount => 100, :currency => 'usd', :card => 'sc_token'})
        test_response(test_charge)
      }
      c = Conekta::Charge.create(params)

      Conekta.mock_rest_client = nil
    end

    it "loading an object should issue a GET request" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){|arg1, arg2, arg3|
        test_response(test_charge)
      }.once
      c = Conekta::Charge.new("test_charge")
      c.refresh

      Conekta.mock_rest_client = nil
    end

    it "using array accessors should be the same as the method interface" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){|arg1, arg2, arg3|
        test_response(test_charge)
      }.once
      c = Conekta::Charge.new("test_charge")
      c.refresh
      c.created.should eq(c[:created])
      c.created.should eq(c['created'])
      c['created'] = 12345
      c.created.should eq(12345)

      Conekta.mock_rest_client = nil
    end

#    it "accessing a property other than id or parent on an unfetched object should fetch it" do
#      @mock = double
#      Conekta.mock_rest_client = @mock
#
#      @mock.should_receive(:get){
#        test_response(test_charge)
#      }.once
#      c = Conekta::Charge.new("test_charge")
#      c.card
#
#      Conekta.mock_rest_client = nil
#    end

    it "updating an object should issue a POST request with only the changed properties" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:post){|url, api_key, params|
        url.should eq("#{Conekta.api_base}/charges/ch_test_charge.json")
        api_key.should eq(nil)
        params.should eq({:mnemonic => 'another_mn'})
        test_response(test_charge)
      }.once
      c = Conekta::Charge.construct_from(test_charge)
      c.mnemonic = "another_mn"
      c.save

      Conekta.mock_rest_client = nil
    end

    it "updating should merge in returned properties" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:post){
        test_response(test_charge)
      }.once
      c = Conekta::Charge.new("c_test_charge")
      c.mnemonic = "another_mn"
      c.save
      c.livemode.should eq(false)

      Conekta.mock_rest_client = nil
    end

#    it "deleting should send no props and result in an object that has no props other deleted" do
#      @mock = double
#      Conekta.mock_rest_client = @mock
#
#      @mock.expects(:get).never
#      @mock.expects(:post).never
#      @mock.should_receive(:delete){|arg1, arg2, arg3|
#        arg1.should eq("#{Conekta.api_base}/v1/charges/ch_test_charge")
#        arg2.should eq(nil)
#        arg3.should eq(nil)
#
#        test_response({ "id" => "test_charge", "deleted" => true })
#      }.once
#
#      c = Conekta::Customer.construct_from(test_charge)
#      c.delete
#      c.deleted.should eq(true)
#
#      c.livemode.to raise_error(NoMethodError)
#    end

    it "loading an object with properties that have specific types should instantiate those classes" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){
        test_response(test_charge)
      }.once

      c = Conekta::Charge.retrieve("test_charge")
      c.card.should be_kind_of(Conekta::ConektaObject)
      #c.card.object == 'card'

      Conekta.mock_rest_client = nil
    end

    it "loading all of an APIResource should return an array of recursively instantiated objects" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){
        test_response(test_charge_array)
      }.once
      c = Conekta::Charge.all
      c = c.data
      c.should be_kind_of(Array)
      c[0].should be_kind_of(Conekta::Charge)
      c[0].card.should be_kind_of(Conekta::ConektaObject)
      #c[0].card.object == 'card'
      
      Conekta.mock_rest_client = nil
    end
  end

  describe Conekta::Account, "#retrieve" do
    it "account should be retrievable" do
      @mock = double
      Conekta.mock_rest_client = @mock

      resp = {:email => "test+bindings@conekta.com", :charge_enabled => false, :details_submitted => false}
      @mock.should_receive(:get){test_response(resp)}.once
      a = Conekta::Account.retrieve
      "test+bindings@conekta.com".should eq(a.email)
      a.charge_enabled.should eq(false)
      a.details_submitted.should eq(false)

      Conekta.mock_rest_client = nil
    end
  end

  describe Conekta::ListObject, "#all" do
    it "be able to retrieve full lists given a listobject" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){
        test_response(test_charge_array)
      }.twice

      c = Conekta::Charge.all
      c.should be_kind_of(Conekta::ListObject)
      '/charges'.should eq(c.url)
      all = c.all
      all.should be_kind_of(Conekta::ListObject)
      '/charges'.should eq(all.url)
      all.data.should be_kind_of(Array)

      Conekta.mock_rest_client = nil
    end
  end


  describe "charge tests" do
    it "charges should be listable" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){
        test_response(test_charge_array)
      }.once
      c = Conekta::Charge.all
      c.data.should be_kind_of(Array)
      c.each do |charge|
        charge.should be_kind_of(Conekta::Charge)
      end

      Conekta.mock_rest_client = nil
    end

    it "charges should be refundable" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.expects(:get).never
      @mock.should_receive(:post){test_response({:id => "ch_test_charge", :refunded => true})}.once
      c = Conekta::Charge.new("test_charge")
      c.refund
      c.refunded.should eq(true)

      Conekta.mock_rest_client = nil
    end

    it "charges should not be deletable" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){test_response(test_charge)}.once
      c = Conekta::Charge.retrieve("test_charge")
      expect{c.delete}.to raise_error(NoMethodError)

      Conekta.mock_rest_client = nil
    end


    it "charges should be updateable" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){test_response(test_charge)}.once
      @mock.should_receive(:post){test_response(test_charge)}.once
      c = Conekta::Charge.new("test_charge")
      c.refresh
      c.mnemonic = "New charge description"
      c.save

      Conekta.mock_rest_client = nil
    end

    it "charges should have Card objects associated with their Card property" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:get){test_response(test_charge)}.once
      c = Conekta::Charge.retrieve("test_charge")
      c.card.should be_kind_of(Conekta::ConektaObject)
      #&& c.card.object == 'card'

      Conekta.mock_rest_client = nil
    end

    it "execute should return a new, fully executed charge when passed correct parameters" do
      @mock = double
      Conekta.mock_rest_client = @mock

      @mock.should_receive(:post){|url, api_key, params|
        url.should eq("#{Conekta.api_base}/charges.json") 
        api_key.should eq(nil) 
        params.should eq({
          :currency => 'usd', 
          :amount => 100,
          :card=>{
            :number => '4242424242424242',
            :exp_month => 11,
            :exp_year => 2012
          }
        })

        test_response(test_charge)
      }.once

      c = Conekta::Charge.create({
        :amount => 100,
        :card => {
          :number => "4242424242424242",
          :exp_month => 11,
          :exp_year => 2012,
        },
        :currency => "usd"
      })
      c.paid.should eq(true)

      Conekta.mock_rest_client = nil
    end
  end

  describe Conekta::ConektaError do
    it "404s should raise an ResourceNotFoundError" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_missing_id_error, 404)
      @mock.should_receive(:get){raise RestClient::ExceptionWithResponse.new(response, 404)}.once

      begin
        Conekta::Charge.new("test_charge").refresh
      rescue Conekta::ResourceNotFoundError => e # we don't use assert_raises because we want to examine e
        e.should be_kind_of(Conekta::ResourceNotFoundError)
        "id".should eq(e.param)
        "Invalid id value".should eq(e.message)
      end

      Conekta.mock_rest_client = nil
    end

    it "5XXs should raise an APIError" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_api_error, 500)
      @mock.should_receive(:get){raise RestClient::ExceptionWithResponse.new(response, 500)}.once

      begin
        Conekta::Charge.new("test_charge").refresh
      rescue Conekta::APIError => e # we don't use assert_raises because we want to examine e
        e.should be_kind_of(Conekta::APIError)
      end

      Conekta.mock_rest_client = nil
    end

    it "402s should raise a CardError" do
      @mock = double
      Conekta.mock_rest_client = @mock

      response = test_response(test_invalid_exp_year_error, 402)
      @mock.should_receive(:get){raise RestClient::ExceptionWithResponse.new(response, 402)}.once

      begin
        Conekta::Charge.new("test_charge").refresh
      rescue Conekta::CardError => e # we don't use assert_raises because we want to examine e
        e.should be_kind_of(Conekta::CardError)
        "invalid_expiry_year".should eq(e.code)
        "exp_year".should eq(e.param)
        "Your card's expiration year is invalid".should eq(e.message)
      end

      Conekta.mock_rest_client = nil
    end
  end
end

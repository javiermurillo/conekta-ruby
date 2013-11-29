module Conekta
  class Plan < APIResource
    include Conekta::APIOperations::Create
    include Conekta::APIOperations::Delete
    include Conekta::APIOperations::List
    include Conekta::APIOperations::Update
  end
end

require_relative "../base"

module LinkedData
  module Client
    module Models
      class Collection < LinkedData::Client::Base
        include LinkedData::Client::Collection
        @media_type =  "http://www.w3.org/2004/02/skos/core#Collection"
      end
    end
  end
end
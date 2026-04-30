require_relative "../base"

module LinkedData
  module Client
    module Models
      class Label < LinkedData::Client::Base
        include LinkedData::Client::Collection
        @media_type = "http://www.w3.org/2008/05/skos-xl#Label"
      end
    end
  end
end

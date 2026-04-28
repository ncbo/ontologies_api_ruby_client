require_relative "../base"
require_relative "../http"

module LinkedData
  module Client
    module Models
      class User < LinkedData::Client::Base
        include LinkedData::Client::Collection
        include LinkedData::Client::ReadWrite

        @media_type = "http://data.bioontology.org/metadata/User"
        @include_attrs = "username,email,role,firstName,lastName,created"

        def self.all(*args)
          params = args.shift || {}
          super({ display_context: false, display_links: false }.merge(params), *args)
        end

        def self.authenticate(user, password)
          auth_params = {user: user, password: password, include: "all"}
          LinkedData::Client::HTTP.post("#{LinkedData::Client.settings.rest_url}/users/authenticate", auth_params)
        end

        def admin?
          respond_to?(:role) && role.include?("ADMINISTRATOR")
        end

        def invalidate_cache(cache_refresh_all = true)
          super(cache_refresh_all)
          ## IMPORTANT
          # We have to invalidate ontologies here because the user could be setting
          # custom ontologies. If we don't do this both on the REST and here then
          # the UI cache will not update.
          Ontology.all(invalidate_cache: true)
          Ontology.all(invalidate_cache: true, include: LinkedData::Client::Models::Ontology.include_params)
        end

      end
    end
  end
end

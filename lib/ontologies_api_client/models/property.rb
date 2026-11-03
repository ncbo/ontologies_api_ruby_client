require_relative "../base"

module LinkedData
  module Client
    module Models
      class Property < LinkedData::Client::Base
        @media_type = "http://data.bioontology.org/metadata/Property"
        @act_as_media_type = ["http://www.w3.org/2002/07/owl#DatatypeProperty", "http://www.w3.org/2002/07/owl#ObjectProperty", "http://www.w3.org/2002/07/owl#AnnotationProperty"]
        @include_attrs = "all"

        def self.properties_to_hash(ary)
          ary = ary.is_a?(Array) ? ary : [ary]
          ary.map {|p| p.to_hash}
        end

        def prefLabel(options = {})
          return "" if @label.nil? && @id.nil?
          label = @label.first || id_to_label
          if options[:use_html]
            return "<span class='prefLabel'>#{label}</span>"
          else
            return label
          end
        end

        def id_to_label
          @id.split("/").last.split("#").last
        end

        def childrenCount
          (@children ||= []).length
        end

        def children
          (@children ||= [])
        end

        def expanded?
          self.childrenCount > 0
        end

        def to_hash(ancestors = [])
          hash = super()
          hash[:prefLabel] = self.prefLabel

          # Track only the current path so shared descendants appear under each parent.
          path = ancestors + [object_id]
          child_properties = children.reject { |p| path.include?(p.object_id) }
          hash[:childrenCount] = child_properties.length
          if children.length > 0
            hash[:children] = child_properties.map { |p| p.to_hash(path) }
          end
          hash
        end

        def ontology
          # hack to get ontology, split the submission URI and trust the path hasn't changed
          acronym = @submission.split("/")[4]
          LinkedData::Client::Models::Ontology.find_by_acronym(acronym).first
        end

      end
    end
  end
end

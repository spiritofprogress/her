module Her
  module Middleware
    # This middleware requires the resource/collection
    # data to be contained in the `data` key of the JSON object
    class JsonApiParser < ParseJSON
      # Parse the response body
      #
      # @param [String] body The response body
      # @return [Mixed] the parsed response
      # @private
      def parse(body)
        json = parse_json(body)

        included = json.fetch(:included, [])
        primary_data = json.fetch(:data, {})
        resources = Array.wrap(primary_data)
        resources.each do |resource|
          if resource[:attributes]
            resource.fetch(:attributes).merge!(build_relationships(resource, included))
          end
        end

        {
          :data => primary_data || {},
          :errors => json[:errors] || [],
          :metadata => json[:meta] || {},
        }
      end

      def build_relationships(resource, included)
        relationships = resource.fetch(:relationships, {})
        {}.tap do |built|
          relationships.each do |rel_name, linkage|
            if linkage_data = linkage.fetch(:data, {})
              built_relationship = if linkage_data.is_a? Array
                linkage_data.map { |l| included.detect { |i| i && i.values_at(:id, :type) == l.values_at(:id, :type) } }
              else
                included.detect { |i| i && i.values_at(:id, :type) == linkage_data.values_at(:id, :type) }
              end

              built[rel_name] = built_relationship if built_relationship
            end
          end
        end
      end

      # This method is triggered when the response has been received. It modifies
      # the value of `env[:body]`.
      #
      # @param [Hash] env The response environment
      # @private
      def on_complete(env)
        assert_response_ok(env[:status], env[:body])
        env[:body] = case env[:status]
        when 204
          {
            :data => {},
            :errors => [],
            :metadata => {},
          }
        else
          parse(env[:body])
        end
      end
      
    end
  end
end

module Her
  module Errors

    # Base class so that all Her errors can be handled generically.
    class Error < StandardError
    end
    
    class PathError < Error
      attr_reader :missing_parameter

      def initialize(message, missing_parameter=nil)
        super(message)
        @missing_parameter = missing_parameter
      end
    end

    class AssociationUnknownError < Error
    end

    class ParseError < Error
    end

    class ResourceInvalid < Error
      attr_reader :resource
      def initialize(resource)
        @resource = resource
        errors = @resource.response_errors.join(", ")
        super("Remote validation failed: #{errors}")
      end
    end
    
    # Base class so that response errors can be handled generically.
    class ResponseError < Error
      def status
        0
      end
    end

    # Status code 401: authentication required
    class Unauthorized < ResponseError
      def status
        401
      end
    end

    # Status code 403: authenticated but not authorized
    class Forbidden < ResponseError
      def status
        403
      end
    end

    # Status code 404: resource not found
    class NotFound < ResponseError
      def status
        404
      end
    end

    # Status code 500: we blew up
    class ServerError < ResponseError
      def status
        500
      end
    end

    # Status code 502: proxy says API has gone away
    class BadGateway < ResponseError
      def status
        502
      end
    end

    # Status code 503: API has definitely gone away
    class Unavailable < ResponseError
      def status
        503
      end
    end

    # Status code 504: API has probably gone away
    class TimeOut < ResponseError
      def status
        504
      end
    end

    def self.exception_class_for_status(status)
      errors = {
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "NotFound",
        500 => "ServerError",
        502 => "BadGateway",
        503 => "Unavailable",
        504 => "TimeOut"
      }
      if errors[status]
        "Her::Errors::#{errors[status]}".constantize
      end
    end

  end
end

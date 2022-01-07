# Rahel: PropertyUrl
# 2014-01-15 martin.stricker@gmail.com 

module Rahel
  class PropertyUrl < Property

    # Attribute Write value
    # :url
    def value=(value)
      url = value.to_s.strip
      unless uri? url
        url = "http://#{url}"
      end
      self.data = url
    end
    
    def uri? uri
      begin
        uri = URI.parse(uri)
        %w(http https ftp ftps).include?(uri.scheme)
      rescue
        true
      end
    end

    # Property Type
    # :url
    def property_type
      :url
    end

    def index_value
      # Strip everything except domain
      if data =~ /\A(?:http|https|ftp|ftps):\/\/((?:[a-z0-9\-]+\.)+[a-z]+)/i
        $1 # Return group 1 of last match
      else
        ""
      end
    end
  end
end

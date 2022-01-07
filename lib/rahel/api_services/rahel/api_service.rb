# 2014-01-31 marius.gawrisch@gmail.com

module Rahel
  class ApiService
    def self.get_result method, query, primary_client=nil, secondary_client=nil
      result = {}
      exception = nil

      # Versuche Primärklienten
      if primary_client && primary_client.respond_to?(method)
        begin
          result = primary_client.send method, query
        rescue ApiServiceNotAvailable => e
          exception = e
        end
      end

      # Bei Erfolglosigkeit versuche Sekundär-Klienten
      if (result.empty? || exception) && secondary_client && secondary_client.respond_to?(method)
        result = secondary_client.send method, query
        # Falls hier auch ApiServiceNotAvailable geworfen wird, wird sie nicht mehr
        # abgefangen sondern direkt weitergereicht, da es keinen Tertiär-Klienten gibt.
      end

      result
    end
  end
end

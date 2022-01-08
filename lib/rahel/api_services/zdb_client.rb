# 2014-01-24 marius.gawrisch@gmail.com

module Rahel
  class ZdbClient < ApiClient

    def self.isil_data isil
      cached_data = get_cache "ZDB", "ISIL", isil
      if cached_data then return cached_data end

      begin
        data = parse_response_body(isil)["RDF"]["Organization"]
        if data.nil? then raise RahelException end
      rescue StandardError
        raise ApiServiceNotAvailable, "ZDB lieferte XML mit unerwarteter Struktur"
      end
      set_cache "Zdb", "ISIL", isil, data
      data
    end

    private

    def self.parse_response_body isil
      http = Net::HTTP.new "ld.zdb-services.de"
      http.read_timeout = @@query_ttl
      response = http.get "/data/organisations/#{isil}.rdf"
      case response
      when Net::HTTPSuccess
        Hash.from_xml response.body
      else
        raise ApiServiceNotAvailable, "HTTP-Status #{response.code}: #{response.message}"
      end
    rescue Net::ReadTimeout => e
      raise ApiServiceNotAvailable, "ZDB antwortete nicht innerhalb von #{@@query_ttl} Sekunden"
    rescue Net::HTTPBadResponse => e
      raise ApiServiceNotAvailable, "ZDB lieferte eine schlechte HTTP-Response"
    rescue REXML::ParseException => e
      raise ApiServiceNotAvailable, "ZDB lieferte invalides XML"
    end
  end
end

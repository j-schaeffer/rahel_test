# 2014-02-18 marius.gawrisch@gmail.com

module Rahel
  class GeoNamesIwusClient < ApiClient

    def self.city_ids query
      results = parse_response_body("cities", "name", query)["hits"]["hits"]
      ids_hash = {}
      results.each do |item|
        ids_hash[item["_source"]["id"]] = item["_source"]["name"]
      end
      ids_hash
    end

    def self.all_ids query
      results = parse_response_body("search", "name", query)["hits"]["hits"]
      ids_hash = {}
      results.each do |item|
        ids_hash[item["_source"]["id"]] = item["_source"]["name"]
      end
      ids_hash
    end

    def self.data id
      cached_data = get_cache "IWUS", "GeoNames", id
      if cached_data then return cached_data end

      data = parse_response_body("search", "id", id)["hits"]["hits"][0]
      if data.nil? then raise InvalidGeoNameId, "Keine Daten für diese GeoName-Id vorhanden" end
      data = data["_source"]

      set_cache "IWUS", "GeoNames", id, data
      data
    end

    private

    def self.parse_response_body context, field, query
      http = Net::HTTP.new "geonames.iwus.org"
      http.read_timeout = @@query_ttl
      response = http.get "/#{context}?#{field}=#{URI.encode query.to_s}"
      case response
      when Net::HTTPSuccess
        JSON.parse response.body
      else
        raise ApiServiceNotAvailable, "HTTP-Status #{response.code}: #{response.message}"
      end
    rescue Net::ReadTimeout => e
      raise ApiServiceNotAvailable, "IWUS antwortete nicht innerhalb von #{@@query_ttl} Sekunden"
    rescue Net::HTTPBadResponse => e
      raise ApiServiceNotAvailable, "IWUS lieferte eine schlechte HTTP-Response"
    rescue JSON::ParserError => e
      raise ApiServiceNotAvailable, "IWUS lieferte invalides JSON"
    end
  end
end

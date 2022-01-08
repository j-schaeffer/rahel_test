# 2014-01-24 marius.gawrisch@gmail.com
module Rahel
  class LobidClient < ApiClient
    

    def self.person_ids query
      results = parse_response_body("person", "name", query, "ids")
      ids_hash = {}
      results.each do |item|
        uri = item["value"] # z.B. "http://d-nb.info/gnd/117548626"
        id = uri.sub("http://d-nb.info/gnd/", "")
        ids_hash[id] = item["label"]
      end
      ids_hash
    end

    def self.isils query
      results = parse_response_body("organisation", "name", query, "ids")
      isils_hash = {}
      results.each do |item|
        uri = item["value"] # z.B. "http://lobid.org/organisation/DE-MUS-942310"
        id = uri.sub("http://lobid.org/organisation/", "")

        # Müssen jetzt entscheiden, ob die ID wirklich ein ISIL ist.
        # http://www.loc.gov/marc/organizationrequire "lobid_client"
        s/#struct klingt so, als
        # würden bei MARC keine Zahlen vorkommen. Dagegen klingt
        # http://sigel.staatsbibliothek-berlin.de/vergabe/isil/ so, als
        # würde immer mindestens eine Zahl vorkommen. Daher prüfen wir
        # hier, ob mindestens eine Zahl vorkommt.
        isils_hash[id] = item["label"] if id =~ /\d/
      end
      isils_hash
    end

    def self.gnd_data gnd_id
      cached_data = get_cache "Lobid", "GND", gnd_id
      if cached_data then return cached_data end

      # Rufe ".first" auf, da der Hash, der uns interessiert, das erste
      # Element in einem 1-elementigen Array ist.
      data = parse_response_body("person", "id", gnd_id, "full").first

      # Für manche GND-Ids gibt es keine Daten, zum Beispiel
      # http://d-nb.info/gnd/1012100694/about/html
      if data.nil? then raise InvalidGndId, "Keine Daten für diese GND-Id vorhanden" end
      set_cache "Lobid", "GND", gnd_id, data
      data
    end

    def self.isil_data isil
      cached_data = get_cache "Lobid", "ISIL", isil
      if cached_data then return cached_data end

      # Rufe ".first" auf, da der Hash, der uns interessiert, das erste
      # Element in einem 1-elementigen Array ist.
      data = parse_response_body("organisation", "id", isil, "full").first
      if data.nil? then raise InvalidIsil, "Keine Daten für diesen ISIL vorhanden" end
      set_cache "Lobid", "ISIL", isil, data
      data
    end

    private

    def self.parse_response_body context, field, query, format
      http = Net::HTTP.new "api.lobid.org"
      http.read_timeout = @@query_ttl
      response = http.get "/#{context}?#{field}=#{URI.encode query.to_s}&format=#{format}"
      case response
      when Net::HTTPSuccess
        JSON.parse response.body
      else
        raise ApiServiceNotAvailable, "HTTP-Status #{response.code}: #{response.message}"
      end
    rescue Net::ReadTimeout => e
      raise ApiServiceNotAvailable, "Lobid antwortete nicht innerhalb von #{@@query_ttl} Sekunden"
    rescue Net::HTTPBadResponse => e
      raise ApiServiceNotAvailable, "Lobid lieferte eine schlechte HTTP-Response"
    rescue JSON::ParserError => e
      raise ApiServiceNotAvailable, "Lobid lieferte invalides JSON"
    end
  end
end

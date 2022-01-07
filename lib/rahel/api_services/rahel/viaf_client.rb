# 2014-01-24 marius.gawrisch@gmail.com

# Auskommentiert am 2014-01-31 von Marius, da wird VIAF (zunächst) nicht nutzen werden
# module Rahel
#   class VIAFClient < Rahel::GNDClient
#     def self.get_data_by_viaf_id viaf_id
#       # Aus http://semanticweb.org/wiki/Getting_data_from_the_Semantic_Web_%28Ruby%29
#       # Das ganz scheint unnötig kompliziert, geht es einfacher?
#       graph = RDF::Graph.load("http://viaf.org/viaf/#{viaf_id}/rdf.xml")
#       str = ""
# 
#       query = RDF::Query.new({ person: { RDF::URI("http://xmlns.com/foaf/0.1/name") => :value }})
#       query.execute(graph).each { |res| str << "Name: #{res[:value].to_s}\n" }
# 
#       query = RDF::Query.new({ person: { RDF::URI("http://rdvocab.info/ElementsGr2/dateOfBirth") => :value }})
#       query.execute(graph).each { |res| str << "Geburtsdatum: #{res[:value].to_s}\n" }
# 
#       query = RDF::Query.new({ person: { RDF::URI("http://www.w3.org/2002/07/owl#sameAs") => :value }})
#       query.execute(graph).each { |res| str << "sameAs: #{res[:value].to_s}\n" }
# 
#       str
#     end
# 
#     def self.suggest_ids terms
#       terms = URI.escape terms
#       response = Net::HTTP.get_response(URI("http://viaf.org/viaf/AutoSuggest?terms=#{terms}"))
#       results = JSON.parse(response.body)["result"]
#       results.map { |r| "#{r["term"]} (GND: #{r["dnb"]}, VIAF: #{r["viafid"]})" }.join("\n")
#     end
#   end
# end

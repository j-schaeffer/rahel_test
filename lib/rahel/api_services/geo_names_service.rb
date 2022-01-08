# 2014-02-18 marius.gawrisch@gmail.com

module Rahel
  class GeoNamesService < ApiService
    @vailable_clients = {
      iwus: GeoNamesIwusClient,
    }
    @primary_client = GeoNamesIwusClient
    @secondary_client = nil

    def self.city_ids query
      get_result :city_ids, query, @primary_client, @secondary_client
    end

    def self.all_ids query
      get_result :all_ids, query, @primary_client, @secondary_client
    end

    def self.data id
      get_result :data, id, @primary_client, @secondary_client
    end
  end
end

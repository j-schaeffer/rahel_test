# 2014-02-07 marius.gawrisch@gmail.com

module Rahel
  class IsilService < ApiService
    @vailable_clients = {
      lobid: LobidClient,
      zdb: ZdbClient,
    }
    @primary_client = LobidClient
    @secondary_client = ZdbClient

    def self.isils query
      get_result :isils, query, @primary_client, @secondary_client
    end

    def self.data id
      get_result :isil_data, id, @primary_client, @secondary_client
    end
  end
end

# 2014-01-31 marius.gawrisch@gmail.com

module Rahel
  class GndService < ApiService
    @vailable_clients = {
      lobid: LobidClient,
    }
    @primary_client = LobidClient
    @secondary_client = nil

    def self.person_ids query
      get_result :person_ids, query, @primary_client, @secondary_client
    end

    def self.subject_ids query
    end

    def self.organisation_ids query
    end

    def self.all_ids query
    end

    def self.data id
      get_result :gnd_data, id, @primary_client, @secondary_client
    end
  end
end

# 2014-01-31 marius.gawrisch@gmail.com

module Rahel
  class ApiCache < ActiveRecord::Base
    self.table_name = "api_cache"

    def data
      @data ||= JSON.parse(data_json)
    end

    def data= data_hash
      @data = data_hash
      self.data_json = data_hash.to_json
      # Änderung wurde noch nicht in die Datenbank geschrieben!
    end
  end
end

# Erwartetes Verhalten:
#
# a = Rahel::ApiCache.create
# => throws ActiveRecord::StatementInvalid (da Felder nicht NULL sein dürfen)
# 
# a = Rahel::ApiCache.create(api: "Lobid", authority_file: "GND", authority_id: "salkdj", data_json: "{}")
# => OK
# 
# a = Rahel::ApiCache.create(api: "Lobid", authority_file: "GND", authority_id: "salkdj", data_json: "{}")
# => throws ActiveRecord::RecordNotUnique

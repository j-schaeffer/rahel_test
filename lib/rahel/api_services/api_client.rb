# 2014-01-31 marius.gawrisch@gmail.com

module Rahel
  class ApiClient
    @@query_ttl = 2.seconds # TTL für Queries über HTTP
    @@cache_ttl = 90.days   # Cache Limit

    def self.get_cache api, file, id
      c = ApiCache.where(api: api, authority_file: file, authority_id: id)
                  .where("updated_at >= ?", @@cache_ttl.ago)
                  .first
      c ? c.data : nil
    end

    def self.set_cache api, file, id, data
      c = ApiCache.find_or_initialize_by(api: api, authority_file: file, authority_id: id)
      c.data = data
      c.save
    end
  end
end

require "rahel/version"

module Rahel
  
  #autoload Glass, 'rahel/glass'
  require 'rahel/glass'
  require 'rahel/exceptions'
  
  require 'rahel/models/property'
  require 'rahel/models/property_bool'
  require 'rahel/models/property_date'
  require 'rahel/models/property_email'
  require 'rahel/models/property_float'
  require 'rahel/models/property_integer'
  require 'rahel/models/property_objekt'
  #require 'rahel/models/property_phone'
  require 'rahel/models/property_string'
  require 'rahel/models/property_text'
  require 'rahel/models/property_url'
  require 'rahel/models/property_string'
  
  
  
  require 'rahel/models/ontology_base'
  #require 'rahel/models/accessible'
  #require 'rahel/models/indexable'
  
  
  require 'rahel/models/individual'
  require 'rahel/models/actor'
  require 'rahel/models/event'
  require 'rahel/models/place'
  require 'rahel/models/revision'
  require 'rahel/models/time_span'
  #require 'rahel/models/user'
  require 'rahel/models/skos_concept_scheme'
  require 'rahel/models/skos_concept'
  
  
  require 'rahel/models/api_cache'
  
  require 'rahel/api_services/api_client'
  require 'rahel/api_services/lobid_client'
  require 'rahel/api_services/viaf_client'
  require 'rahel/api_services/zdb_client'
  require 'rahel/api_services/geo_names_iwus_client'
  require 'rahel/api_services/api_service'
  require 'rahel/api_services/geo_names_service'
  require 'rahel/api_services/gnd_service'
  require 'rahel/api_services/isil_service'

  class Engine < Rails::Engine
  end
  
  #class Error < StandardError; end
  # Your code goes here...
end

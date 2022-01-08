# 2014-02-05 marius.gawrisch@gmail.com

module Rahel
  # Ein eigenes Module "Exceptions" ist eigentlich unnötig, aber ohne werden
  # die Klassen nicht von Rails auto-geloadet.
  # TODO RahelExceptions: Refaktorieren!
  module Exceptions
    class RahelException < StandardError; end
    class ApiServiceNotAvailable < RahelException; end
    class InvalidGndId < RahelException; end
    class InvalidIsil < RahelException; end
    class InvalidGeoNameId < RahelException; end
  end
end

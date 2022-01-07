# 2014-02-05 marius.gawrisch@gmail.com

# Achtung: Änderungen an dieser Datei werden nur berücksichtigt, wenn man den Server
# bzw. die Console neu startet. Das liegt daran, das hier mit der Rails-Konvention
# gebrochen wird, nach der in einer Datei immer genau eine Klasse definiert werden soll,
# die auch genau wie der Dateiname heißt.

module Rahel
  # Ein allgemeiner Rahel-Fehler.
  # Inspiriert von: https://github.com/ryanb/cancan/blob/master/lib/cancan/exceptions.rb#L3
  class Error < StandardError; end

  # Exceptions für die Api-Services
  class ApiServiceNotAvailable < Error; end
  class InvalidGndId < Error; end
  class InvalidIsil < Error; end
  class InvalidGeoNameId < Error; end

  # Rechtesystem-Exceptions
  class ForbiddenAction < Error; end
end

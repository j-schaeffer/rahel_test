# 2015-03-02 marius.gawrisch@mgaw.de
# Accessible: Methoden, mit denen Individual erweitert wird, um Rechte definieren
# und abfragen zu können.

module Rahel
  module Accessible
    # Zum definieren von Rechten. Soll in den Individual-Klassen aufgerufen werden.
    def access_rule action: nil, minimum_required_role: nil
      raise "Bitte sowohl Action als auch Rolle angeben" unless action && minimum_required_role
      action = [action] unless action.is_a? Array

      # NOTE Dieser Hash ist einen Instanz-Variable der Individual-Klassen (nicht der
      # Individual-Instanzen!).
      @minimum_role_required ||= {}
      action.each do |act|
        @minimum_role_required[act.to_sym] = minimum_required_role.to_sym
      end
    end

    # Zum abfragen von Rechten. Soll in erster Linie von User#can? aufgerufen werden.
    def minimum_role_required action
      role = @minimum_role_required[action] if @minimum_role_required
      if role
        # Bei der angefragten Klasse wurde eine Mindest-Rolle hinterlegt. In diesem
        # Fall einfach diese Rolle zurückgeben.
        role
      elsif superclass <= Individual
        # Es wurde hier direkt keine Rolle angegeben, aber es gibt noch Superklassen,
        # bei denen vielleicht etwas spezifiziert wurde. Gehe also einen Schritt in der
        # Hierachie nach oben.
        superclass.minimum_role_required(action)
      else
        # Wir sind schon bei Individual angekommen, und es wurde nirgendwo eine Mindest-Rolle
        # hinterlegt. Gebe in diesem Fall die höchste Rolle (:admin) zurück.
        User::ROLES.last
      end
    end
  end
end
